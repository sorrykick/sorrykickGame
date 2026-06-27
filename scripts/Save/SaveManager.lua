local SaveSchema = require("Save.SaveSchema")
local SaveValidator = require("Save.SaveValidator")
local RuntimeSave = require("Save.RuntimeSave")

local SaveManager = {}

local runtimeSave_ = nil
local pendingOfflineCoin_ = 0
local lastValidationIssues_ = {}

local function now()
    return os.time()
end

local function isCloudAvailable()
    return type(clientCloud) == "table" and clientCloud.BatchGet ~= nil and clientCloud.BatchSet ~= nil
end

local function pullRemoteSave(onSuccess, onError)
    print("[SaveManager] Pull remote save")

    if not isCloudAvailable() then
        print("[SaveManager] clientCloud unavailable, using development fallback save")
        if onSuccess then onSuccess(nil) end
        return
    end

    clientCloud:BatchGet()
        :Key(SaveSchema.SAVE_KEY)
        :Fetch({
            ok = function(values)
                if onSuccess then
                    onSuccess(values and values[SaveSchema.SAVE_KEY] or nil)
                end
            end,
            error = function(code, reason)
                print("[SaveManager] Pull failed: " .. tostring(code) .. " " .. tostring(reason))
                if onError then onError(reason or "读取存档失败") end
            end,
            timeout = function()
                print("[SaveManager] Pull timeout")
                if onError then onError("读取存档超时") end
            end,
        })
end

local function applyOfflineSettlement(currentTime)
    local data = runtimeSave_:GetData()
    local elapsed = math.max(0, currentTime - data.idle.lastCollectTime)
    local cappedElapsed = math.min(elapsed, data.idle.maxOfflineSeconds or SaveSchema.MAX_OFFLINE_SECONDS)
    local rate = data.idle.baseRate + data.partner.level * 2
    local earned = math.floor(cappedElapsed * rate)

    pendingOfflineCoin_ = earned
    data.coin = data.coin + earned
    data.lastLoginTime = currentTime
    data.idle.lastCollectTime = currentTime
    data.stats.loginCount = data.stats.loginCount + 1
    data.stats.totalOfflineCoin = data.stats.totalOfflineCoin + earned

    print(string.format("[SaveManager] Offline elapsed=%d capped=%d rate=%d earned=%d", elapsed, cappedElapsed, rate, earned))
    return earned
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

function SaveManager.SaveGameSnapshot(reason, onSuccess, onError)
    if not runtimeSave_ then
        if onError then onError("没有可保存的数据") end
        return
    end

    local currentTime = now()
    local snapshot = runtimeSave_:CreateSnapshot()
    snapshot.saveVersion = (snapshot.saveVersion or 0) + 1
    snapshot.updatedAt = currentTime
    snapshot = SaveSchema.Normalize(snapshot, currentTime)
    snapshot, lastValidationIssues_ = SaveValidator.ValidateAndRepair(snapshot, currentTime)
    runtimeSave_ = RuntimeSave.new(snapshot)

    print("[SaveManager] Save snapshot: " .. tostring(reason))

    if not isCloudAvailable() then
        print("[SaveManager] clientCloud unavailable, development fallback save completed")
        if onSuccess then onSuccess(snapshot) end
        return
    end

    clientCloud:BatchSet()
        :Set(SaveSchema.SAVE_KEY, snapshot)
        :Save(reason or "更新存档", {
            ok = function()
                print("[SaveManager] Save uploaded")
                if onSuccess then onSuccess(snapshot) end
            end,
            error = function(code, reasonText)
                print("[SaveManager] Save failed: " .. tostring(code) .. " " .. tostring(reasonText))
                if onError then onError(reasonText or "保存失败") end
            end,
            timeout = function()
                print("[SaveManager] Save timeout")
                if onError then onError("保存超时") end
            end,
        })
end

function SaveManager.LoginSyncPlayerSave(onSuccess, onError)
    pullRemoteSave(function(rawSave)
        local currentTime = now()
        local baseSave = SaveSchema.Normalize(rawSave, currentTime)
        baseSave, lastValidationIssues_ = SaveValidator.ValidateAndRepair(baseSave, currentTime)
        runtimeSave_ = RuntimeSave.new(baseSave)
        applyOfflineSettlement(currentTime)
        SaveManager.SaveGameSnapshot("登录离线收益结算", function()
            if onSuccess then onSuccess(runtimeSave_, pendingOfflineCoin_) end
        end, onError)
    end, onError)
end

function SaveManager.CollectIdleReward(amount, onSuccess, onError)
    if not runtimeSave_ then
        if onError then onError("没有可保存的数据") end
        return
    end

    amount = math.floor(tonumber(amount) or 0)
    runtimeSave_:AddCoin(amount, "manual_idle_reward")
    runtimeSave_:SetOfflineCollectedAt(now())
    pendingOfflineCoin_ = 0
    SaveManager.SaveGameSnapshot("领取挂机收益", onSuccess, onError)
end

function SaveManager.ResetForTests()
    runtimeSave_ = nil
    pendingOfflineCoin_ = 0
    lastValidationIssues_ = {}
end

return SaveManager
