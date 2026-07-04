local SaveSchema = require("Save.SaveSchema")
local SaveValidator = require("Save.SaveValidator")
local RuntimeSave = require("Save.RuntimeSave")

local SaveManager = {}

local MAX_RETRY_COUNT = 3

local runtimeSave_ = nil
local pendingOfflineCoin_ = 0
local lastValidationIssues_ = {}
local isClearingSave_ = false

local function now()
    return os.time()
end

local function isCloudAvailable()
    return type(clientCloud) == "table" and clientCloud.BatchGet ~= nil and clientCloud.BatchSet ~= nil
end

local function notifyStatus(onStatus, text)
    print("[SaveManager] " .. text)
    if onStatus then
        onStatus(text)
    end
end

local function forceExitAfterSaveFailure(reason)
    print("[SaveManager] Upload failed after retries, force exit: " .. tostring(reason))
    pcall(function()
        engine:Exit()
    end)
end

local function getFieldPayload(values, fieldName)
    local fieldKey = SaveSchema.GetFieldKey(fieldName)
    local payload = values and values[fieldKey] or nil
    if type(payload) ~= "table" then
        return nil, false, "missing"
    end

    local expected = RuntimeSave.CalculateFieldChecksum(fieldName, payload.value)
    if payload.checksum ~= expected then
        return nil, false, "checksum"
    end

    return SaveSchema.DeepClone(payload.value), true, nil
end

local function rebuildSaveFromCloudValues(values, currentTime)
    values = type(values) == "table" and values or {}

    local legacySave = type(values[SaveSchema.SAVE_KEY]) == "table" and values[SaveSchema.SAVE_KEY] or nil
    local meta = type(values[SaveSchema.META_KEY]) == "table" and values[SaveSchema.META_KEY] or nil
    local hasFieldPayload = false

    for _, fieldName in ipairs(SaveSchema.DELTA_FIELDS) do
        if values[SaveSchema.GetFieldKey(fieldName)] ~= nil then
            hasFieldPayload = true
            break
        end
    end

    if not legacySave and not meta and not hasFieldPayload then
        return nil, 1, true, true
    end

    local rawSave = legacySave and SaveSchema.DeepClone(legacySave) or SaveSchema.CreateDefaultSave(currentTime)
    local damagedFields = {}

    if hasFieldPayload then
        for _, fieldName in ipairs(SaveSchema.DELTA_FIELDS) do
            local fieldValue, ok, reason = getFieldPayload(values, fieldName)
            if ok then
                rawSave[fieldName] = fieldValue
            elseif values[SaveSchema.GetFieldKey(fieldName)] ~= nil then
                damagedFields[#damagedFields + 1] = fieldName .. ":" .. tostring(reason)
            end
        end
    end

    local cloudVersion = math.max(1, math.floor(tonumber(meta and meta.saveVersion or rawSave.saveVersion) or 1))
    rawSave.saveVersion = cloudVersion
    if meta and meta.updatedAt then
        rawSave.updatedAt = math.floor(tonumber(meta.updatedAt) or rawSave.updatedAt or currentTime)
    end

    if #damagedFields > 0 then
        print("[SaveManager] Damaged cloud fields ignored: " .. table.concat(damagedFields, ","))
    end

    return rawSave, cloudVersion, false, meta == nil
end

local function pullRemoteSave(onSuccess, onError, onStatus)
    if not isCloudAvailable() then
        notifyStatus(onStatus, "开发环境未连接云存档，使用本次会话默认存档")
        if onSuccess then onSuccess(nil, 1, true, true) end
        return
    end

    local function fetch(attempt)
        notifyStatus(onStatus, string.format("正在下载云存档（%d/%d）...", attempt, MAX_RETRY_COUNT))

        local request = clientCloud:BatchGet()
        for _, key in ipairs(SaveSchema.GetAllCloudKeys()) do
            request:Key(key)
        end
        request:Fetch({
            ok = function(values)
                local rawSave, cloudVersion, isNewSave, shouldUploadAll = rebuildSaveFromCloudValues(values, now())
                notifyStatus(onStatus, "云存档下载完成")
                if onSuccess then
                    onSuccess(rawSave, cloudVersion, isNewSave, shouldUploadAll)
                end
            end,
            error = function(code, reason)
                local message = tostring(reason or "读取存档失败")
                print("[SaveManager] Pull failed: " .. tostring(code) .. " " .. message)
                if attempt < MAX_RETRY_COUNT then
                    fetch(attempt + 1)
                elseif onError then
                    onError("下载云存档失败：" .. message)
                end
            end,
            timeout = function()
                print("[SaveManager] Pull timeout")
                if attempt < MAX_RETRY_COUNT then
                    fetch(attempt + 1)
                elseif onError then
                    onError("下载云存档超时")
                end
            end,
        })
    end

    fetch(1)
end

local function applyOfflineSettlement(currentTime)
    local data = runtimeSave_:GetData()
    local elapsed = math.max(0, currentTime - data.idle.lastCollectTime)
    local cappedElapsed = math.min(elapsed, data.idle.maxOfflineSeconds or SaveSchema.MAX_OFFLINE_SECONDS)
    local rate = data.idle.baseRate + data.partner.level * 2
    local earned = math.floor(cappedElapsed * rate)
    local dirtyFields = { "lastLoginTime", "idle", "stats" }

    pendingOfflineCoin_ = earned
    if earned > 0 then
        data.coin = data.coin + earned
        data.stats.totalOfflineCoin = data.stats.totalOfflineCoin + earned
        dirtyFields[#dirtyFields + 1] = "coin"
    end
    data.lastLoginTime = currentTime
    data.idle.lastCollectTime = currentTime
    data.stats.loginCount = data.stats.loginCount + 1
    runtimeSave_:MarkFieldsDirty(dirtyFields)

    print(string.format("[SaveManager] Offline elapsed=%d capped=%d rate=%d earned=%d", elapsed, cappedElapsed, rate, earned))
    return earned
end

local function uploadDeltaWithRetry(delta, reason, attempt, onSuccess, onError)
    print(string.format("[SaveManager] Upload delta attempt=%d/%d version=v%d fields=%s", attempt, MAX_RETRY_COUNT, delta.meta.saveVersion, table.concat(delta.fields, ",")))

    local request = clientCloud:BatchSet()
    request:Set(SaveSchema.META_KEY, delta.meta)
    for _, fieldName in ipairs(delta.fields) do
        request:Set(SaveSchema.GetFieldKey(fieldName), delta.payloads[fieldName])
    end
    request:Save(reason or "更新存档", {
        ok = function()
            print("[SaveManager] Delta uploaded")
            runtimeSave_:CommitDelta()
            if onSuccess then onSuccess(runtimeSave_:CreateSnapshot()) end
        end,
        error = function(code, reasonText)
            local message = tostring(reasonText or "保存失败")
            print("[SaveManager] Upload failed: " .. tostring(code) .. " " .. message)
            if attempt < MAX_RETRY_COUNT then
                uploadDeltaWithRetry(delta, reason, attempt + 1, onSuccess, onError)
            else
                if onError then onError(message) end
                forceExitAfterSaveFailure(message)
            end
        end,
        timeout = function()
            print("[SaveManager] Upload timeout")
            if attempt < MAX_RETRY_COUNT then
                uploadDeltaWithRetry(delta, reason, attempt + 1, onSuccess, onError)
            else
                if onError then onError("保存超时") end
                forceExitAfterSaveFailure("保存超时")
            end
        end,
    })
end

function SaveManager.GetRuntimeSave()
    return runtimeSave_
end

function SaveManager.GetSaveData()
    return runtimeSave_ and runtimeSave_:GetData() or nil
end

function SaveManager.GetPendingOfflineCoin()
    return pendingOfflineCoin_
end

function SaveManager.GetLastValidationIssues()
    return lastValidationIssues_
end

function SaveManager.MarkDirty(fieldName)
    if runtimeSave_ then
        runtimeSave_:MarkDirty(fieldName)
    end
end

function SaveManager.MarkFieldsDirty(fields)
    if runtimeSave_ then
        runtimeSave_:MarkFieldsDirty(fields)
    end
end

function SaveManager.UpdatePlayerSave(reason, onSuccess, onError)
    if not runtimeSave_ then
        if onError then onError("没有可保存的数据") end
        return
    end

    if not runtimeSave_:HasPendingChanges() then
        print("[SaveManager] Skip upload, no dirty fields: " .. tostring(reason))
        if onSuccess then onSuccess(runtimeSave_:CreateSnapshot()) end
        return
    end

    local currentTime = now()
    local snapshot = runtimeSave_:CreateSnapshot()
    snapshot.updatedAt = currentTime
    snapshot = SaveSchema.Normalize(snapshot, currentTime)
    snapshot, lastValidationIssues_ = SaveValidator.ValidateAndRepair(snapshot, currentTime)
    runtimeSave_:SetData(snapshot)

    local delta = runtimeSave_:PrepareDelta(currentTime)
    if not delta then
        print("[SaveManager] Skip upload, no dirty fields: " .. tostring(reason))
        if onSuccess then onSuccess(runtimeSave_:CreateSnapshot()) end
        return
    end

    if runtimeSave_:GetLocalVersion() <= runtimeSave_:GetCloudVersion() then
        print("[SaveManager] Skip upload, local version is not newer than cloud")
        if onSuccess then onSuccess(runtimeSave_:CreateSnapshot()) end
        return
    end

    print("[SaveManager] Update player save: " .. tostring(reason))

    if not isCloudAvailable() then
        print("[SaveManager] clientCloud unavailable, development delta save completed")
        runtimeSave_:CommitDelta()
        if onSuccess then onSuccess(runtimeSave_:CreateSnapshot()) end
        return
    end

    uploadDeltaWithRetry(delta, reason, 1, onSuccess, onError)
end

function SaveManager.SaveGameSnapshot(reason, onSuccess, onError)
    SaveManager.UpdatePlayerSave(reason, onSuccess, onError)
end

function SaveManager.LoginSyncPlayerSave(onSuccess, onError, onStatus)
    pullRemoteSave(function(rawSave, cloudVersion, isNewSave, shouldUploadAll)
        local currentTime = now()
        local baseSave = SaveSchema.Normalize(rawSave, currentTime)
        baseSave, lastValidationIssues_ = SaveValidator.ValidateAndRepair(baseSave, currentTime)
        runtimeSave_ = RuntimeSave.new(baseSave, cloudVersion)
        if isNewSave or shouldUploadAll then
            runtimeSave_:MarkFieldsDirty(SaveSchema.DELTA_FIELDS)
        end
        applyOfflineSettlement(currentTime)
        notifyStatus(onStatus, "正在上传本次登录变更...")
        SaveManager.UpdatePlayerSave("登录同步与离线收益结算", function()
            if onSuccess then onSuccess(runtimeSave_, pendingOfflineCoin_) end
        end, onError)
    end, onError, onStatus)
end

function SaveManager.CollectIdleReward(amount, onSuccess, onError)
    if not runtimeSave_ then
        if onError then onError("没有可保存的数据") end
        return
    end

    if pendingOfflineCoin_ > 0 then
        print("[SaveManager] Offline reward already settled on login: " .. tostring(pendingOfflineCoin_))
        pendingOfflineCoin_ = 0
        if onSuccess then onSuccess(runtimeSave_:CreateSnapshot()) end
        return
    end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then
        print("[SaveManager] No idle reward to collect")
        if onSuccess then onSuccess(runtimeSave_:CreateSnapshot()) end
        return
    end

    runtimeSave_:AddCoin(amount, "manual_idle_reward")
    runtimeSave_:SetOfflineCollectedAt(now())
    SaveManager.UpdatePlayerSave("领取挂机收益", onSuccess, onError)
end

function SaveManager.ClearCloudSave(onSuccess, onError, onStatus)
    if isClearingSave_ then
        if onError then onError("正在清除存档，请稍候") end
        return
    end

    isClearingSave_ = true

    local function finishSuccess()
        pendingOfflineCoin_ = 0
        runtimeSave_ = nil
        lastValidationIssues_ = {}
        isClearingSave_ = false
        notifyStatus(onStatus, "云存档已清除")
        if onSuccess then onSuccess() end
    end

    local function finishError(message)
        isClearingSave_ = false
        if onError then onError(message) end
    end

    if not isCloudAvailable() then
        notifyStatus(onStatus, "开发环境未连接云存档，已重置本次会话数据")
        finishSuccess()
        return
    end

    local function clear(attempt)
        notifyStatus(onStatus, string.format("正在清除云存档（%d/%d）...", attempt, MAX_RETRY_COUNT))

        local request = clientCloud:BatchSet()
        for _, key in ipairs(SaveSchema.GetAllCloudKeys()) do
            request:Delete(key)
        end
        request:Save("清除玩家存档", {
            ok = function()
                print("[SaveManager] Cloud save cleared")
                finishSuccess()
            end,
            error = function(code, reason)
                local message = tostring(reason or "清除存档失败")
                print("[SaveManager] Clear cloud save failed: " .. tostring(code) .. " " .. message)
                if attempt < MAX_RETRY_COUNT then
                    clear(attempt + 1)
                else
                    finishError("清除云存档失败：" .. message)
                end
            end,
            timeout = function()
                print("[SaveManager] Clear cloud save timeout")
                if attempt < MAX_RETRY_COUNT then
                    clear(attempt + 1)
                else
                    finishError("清除云存档超时")
                end
            end,
        })
    end

    clear(1)
end

function SaveManager.ResetForTests()
    runtimeSave_ = nil
    pendingOfflineCoin_ = 0
    lastValidationIssues_ = {}
    isClearingSave_ = false
end

return SaveManager
