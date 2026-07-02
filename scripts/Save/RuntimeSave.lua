local SaveSchema = require("Save.SaveSchema")

local RuntimeSave = {}
RuntimeSave.__index = RuntimeSave

local function stableSerialize(value, buffer)
    local valueType = type(value)
    if valueType == "nil" then
        buffer[#buffer + 1] = "nil;"
    elseif valueType == "number" then
        buffer[#buffer + 1] = "number:"
        buffer[#buffer + 1] = string.format("%.17g", value)
        buffer[#buffer + 1] = ";"
    elseif valueType == "boolean" then
        buffer[#buffer + 1] = value and "boolean:true;" or "boolean:false;"
    elseif valueType == "string" then
        buffer[#buffer + 1] = "string:"
        buffer[#buffer + 1] = tostring(#value)
        buffer[#buffer + 1] = ":"
        buffer[#buffer + 1] = value
        buffer[#buffer + 1] = ";"
    elseif valueType == "table" then
        buffer[#buffer + 1] = "table:{"
        local keys = {}
        for key in pairs(value) do
            keys[#keys + 1] = key
        end
        table.sort(keys, function(a, b)
            local typeA = type(a)
            local typeB = type(b)
            if typeA ~= typeB then
                return typeA < typeB
            end
            return tostring(a) < tostring(b)
        end)
        for _, key in ipairs(keys) do
            stableSerialize(key, buffer)
            buffer[#buffer + 1] = "=>"
            stableSerialize(value[key], buffer)
        end
        buffer[#buffer + 1] = "};"
    else
        buffer[#buffer + 1] = valueType .. ":" .. tostring(value) .. ";"
    end
end

local function serializeValue(value)
    local buffer = {}
    stableSerialize(value, buffer)
    return table.concat(buffer)
end

local function hashString(text)
    local hash = 2166136261
    for index = 1, #text do
        hash = ((hash ~ string.byte(text, index)) * 16777619) & 0xffffffff
    end
    return string.format("%08x", hash)
end

local function clone(value)
    return SaveSchema.DeepClone(value)
end

function RuntimeSave.CalculateFieldChecksum(fieldName, value)
    return hashString(tostring(fieldName) .. "=" .. serializeValue(value))
end

local function buildChecksums(data)
    local checksums = {}
    for _, fieldName in ipairs(SaveSchema.DELTA_FIELDS) do
        checksums[fieldName] = RuntimeSave.CalculateFieldChecksum(fieldName, data[fieldName])
    end
    return checksums
end

function RuntimeSave.new(baseSave, cloudVersion)
    local data = clone(baseSave)
    local version = math.max(1, math.floor(tonumber(cloudVersion or data.saveVersion) or 1))
    data.saveVersion = version

    local self = setmetatable({}, RuntimeSave)
    self.data = data
    self.cloudVersion = version
    self.localVersion = version
    self.cleanChecksums = buildChecksums(data)
    self.lastGoodFields = {}
    self.dirtyFields = {}
    self.versionBumpedForPendingChanges = false

    for _, fieldName in ipairs(SaveSchema.DELTA_FIELDS) do
        self.lastGoodFields[fieldName] = clone(data[fieldName])
    end

    return self
end

function RuntimeSave:GetData()
    return self.data
end

function RuntimeSave:SetData(data)
    self.data = clone(data)
    self.data.saveVersion = self.localVersion
end

function RuntimeSave:CreateSnapshot()
    return clone(self.data)
end

function RuntimeSave:GetCloudVersion()
    return self.cloudVersion or 1
end

function RuntimeSave:GetLocalVersion()
    return self.localVersion or self:GetCloudVersion()
end

function RuntimeSave:BumpLocalVersionForChange()
    if self.versionBumpedForPendingChanges then
        return
    end
    self.localVersion = math.max((self.localVersion or 1) + 1, (self.cloudVersion or 1) + 1)
    self.data.saveVersion = self.localVersion
    self.versionBumpedForPendingChanges = true
    print("[RuntimeSave] Local version bumped to v" .. tostring(self.localVersion))
end

function RuntimeSave:MarkDirty(fieldName)
    for _, candidate in ipairs(SaveSchema.DELTA_FIELDS) do
        if candidate == fieldName then
            self:BumpLocalVersionForChange()
            self.dirtyFields[fieldName] = true
            print("[RuntimeSave] MarkDirty field=" .. tostring(fieldName))
            return
        end
    end
    print("[RuntimeSave] Ignore unknown dirty field=" .. tostring(fieldName))
end

function RuntimeSave:MarkFieldsDirty(fields)
    for _, fieldName in ipairs(fields or {}) do
        self:MarkDirty(fieldName)
    end
end

function RuntimeSave:GetDirtyFields()
    local dirty = {}
    for _, fieldName in ipairs(SaveSchema.DELTA_FIELDS) do
        local checksum = RuntimeSave.CalculateFieldChecksum(fieldName, self.data[fieldName])
        if self.dirtyFields[fieldName] or checksum ~= self.cleanChecksums[fieldName] then
            dirty[#dirty + 1] = fieldName
        end
    end
    return dirty
end

function RuntimeSave:HasPendingChanges()
    return #self:GetDirtyFields() > 0
end

function RuntimeSave:PrepareDelta(currentTime)
    local dirtyFields = self:GetDirtyFields()
    if #dirtyFields == 0 then
        return nil
    end

    if not self.versionBumpedForPendingChanges then
        self:BumpLocalVersionForChange()
    end

    self.data.saveVersion = self.localVersion
    self.data.updatedAt = currentTime

    local allChecksums = buildChecksums(self.data)
    local payloads = {}
    for _, fieldName in ipairs(dirtyFields) do
        payloads[fieldName] = {
            field = fieldName,
            value = clone(self.data[fieldName]),
            checksum = allChecksums[fieldName],
            version = self.localVersion,
            updatedAt = currentTime,
        }
    end

    return {
        fields = dirtyFields,
        payloads = payloads,
        meta = {
            schemaVersion = self.data.schemaVersion or 1,
            saveVersion = self.localVersion,
            createdAt = self.data.createdAt,
            updatedAt = currentTime,
            fields = clone(SaveSchema.DELTA_FIELDS),
            fieldChecksums = allChecksums,
        },
    }
end

function RuntimeSave:CommitDelta()
    self.cleanChecksums = buildChecksums(self.data)
    self.lastGoodFields = {}
    for _, fieldName in ipairs(SaveSchema.DELTA_FIELDS) do
        self.lastGoodFields[fieldName] = clone(self.data[fieldName])
    end
    self.dirtyFields = {}
    self.cloudVersion = self.localVersion
    self.versionBumpedForPendingChanges = false
    print("[RuntimeSave] CommitDelta version=v" .. tostring(self.cloudVersion))
end

function RuntimeSave:GetCoin()
    return self.data.coin or 0
end

function RuntimeSave:GetDiamond()
    return self.data.diamond or 0
end

function RuntimeSave:GetCrystal()
    return self.data.crystal or 0
end

function RuntimeSave:GetPartnerLevel()
    return self.data.partner and self.data.partner.level or 1
end

function RuntimeSave:AddCoin(amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount == 0 then
        return self.data.coin or 0
    end
    self.data.coin = math.max(0, (self.data.coin or 0) + amount)
    self:MarkDirty("coin")
    print(string.format("[RuntimeSave] AddCoin amount=%d reason=%s total=%d", amount, tostring(reason), self.data.coin))
    return self.data.coin
end

function RuntimeSave:SetOfflineCollectedAt(timestamp)
    self.data.idle.lastCollectTime = math.floor(tonumber(timestamp) or os.time())
    self:MarkDirty("idle")
end

return RuntimeSave
