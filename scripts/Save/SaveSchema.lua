local SaveSchema = {}

SaveSchema.SAVE_KEY = "partner_idle_save_v1"
SaveSchema.MAX_OFFLINE_SECONDS = 12 * 60 * 60

local function cloneValue(value)
    if type(value) ~= "table" then
        return value
    end

    local result = {}
    for k, v in pairs(value) do
        result[cloneValue(k)] = cloneValue(v)
    end
    return result
end

function SaveSchema.DeepClone(value)
    return cloneValue(value)
end

function SaveSchema.CreateDefaultSave(now)
    return {
        schemaVersion = 1,
        saveVersion = 1,
        createdAt = now,
        updatedAt = now,
        lastLoginTime = now,
        coin = 1221300,
        diamond = 1300,
        crystal = 1300,
        energy = 2544,
        partner = {
            id = "partner_001",
            name = "初始伙伴",
            level = 1,
            exp = 0,
            power = 10,
        },
        idle = {
            baseRate = 8,
            lastCollectTime = now,
            maxOfflineSeconds = SaveSchema.MAX_OFFLINE_SECONDS,
        },
        stats = {
            loginCount = 0,
            totalOfflineCoin = 0,
        },
        security = {
            suspiciousCount = 0,
            lastValidationAt = now,
        },
    }
end

function SaveSchema.Normalize(rawSave, now)
    local save = type(rawSave) == "table" and SaveSchema.DeepClone(rawSave) or SaveSchema.CreateDefaultSave(now)

    save.schemaVersion = math.max(1, math.floor(tonumber(save.schemaVersion or save.version) or 1))
    save.saveVersion = math.max(1, math.floor(tonumber(save.saveVersion or save.version) or 1))
    save.createdAt = math.floor(tonumber(save.createdAt) or now)
    save.updatedAt = math.floor(tonumber(save.updatedAt) or now)
    save.lastLoginTime = math.floor(tonumber(save.lastLoginTime) or now)

    save.coin = math.floor(tonumber(save.coin) or 0)
    save.diamond = math.floor(tonumber(save.diamond) or 0)
    save.crystal = math.floor(tonumber(save.crystal) or 0)
    save.energy = math.floor(tonumber(save.energy) or 0)

    save.partner = type(save.partner) == "table" and save.partner or {}
    save.partner.id = tostring(save.partner.id or "partner_001")
    save.partner.name = tostring(save.partner.name or "初始伙伴")
    save.partner.level = math.floor(tonumber(save.partner.level) or 1)
    save.partner.exp = math.floor(tonumber(save.partner.exp) or 0)
    save.partner.power = math.floor(tonumber(save.partner.power) or 10)

    save.idle = type(save.idle) == "table" and save.idle or {}
    save.idle.baseRate = math.floor(tonumber(save.idle.baseRate) or 8)
    save.idle.lastCollectTime = math.floor(tonumber(save.idle.lastCollectTime) or now)
    save.idle.maxOfflineSeconds = math.floor(tonumber(save.idle.maxOfflineSeconds) or SaveSchema.MAX_OFFLINE_SECONDS)

    save.stats = type(save.stats) == "table" and save.stats or {}
    save.stats.loginCount = math.floor(tonumber(save.stats.loginCount) or 0)
    save.stats.totalOfflineCoin = math.floor(tonumber(save.stats.totalOfflineCoin) or 0)

    save.security = type(save.security) == "table" and save.security or {}
    save.security.suspiciousCount = math.floor(tonumber(save.security.suspiciousCount) or 0)
    save.security.lastValidationAt = math.floor(tonumber(save.security.lastValidationAt) or now)

    save.version = nil
    return save
end

return SaveSchema
