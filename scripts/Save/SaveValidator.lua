local SaveSchema = require("Save.SaveSchema")

local SaveValidator = {}

local LIMITS = {
    coin = 999999999999,
    diamond = 999999999,
    crystal = 999999999,
    energy = 999999,
    partnerLevel = 999,
    partnerExp = 999999999,
    partnerPower = 99999999,
    baseRate = 1000000,
}

local function clampInt(value, minValue, maxValue)
    value = math.floor(tonumber(value) or minValue)
    if value < minValue then
        return minValue, true
    end
    if value > maxValue then
        return maxValue, true
    end
    return value, false
end

local function addIssue(issues, key)
    issues[#issues + 1] = key
end

function SaveValidator.ValidateAndRepair(save, now)
    local issues = {}
    local changed = false

    save.coin, changed = clampInt(save.coin, 0, LIMITS.coin)
    if changed then addIssue(issues, "coin") end
    save.diamond, changed = clampInt(save.diamond, 0, LIMITS.diamond)
    if changed then addIssue(issues, "diamond") end
    save.crystal, changed = clampInt(save.crystal, 0, LIMITS.crystal)
    if changed then addIssue(issues, "crystal") end
    save.energy, changed = clampInt(save.energy, 0, LIMITS.energy)
    if changed then addIssue(issues, "energy") end

    save.partner.level, changed = clampInt(save.partner.level, 1, LIMITS.partnerLevel)
    if changed then addIssue(issues, "partner.level") end
    save.partner.exp, changed = clampInt(save.partner.exp, 0, LIMITS.partnerExp)
    if changed then addIssue(issues, "partner.exp") end
    save.partner.power, changed = clampInt(save.partner.power, 1, LIMITS.partnerPower)
    if changed then addIssue(issues, "partner.power") end

    save.idle.baseRate, changed = clampInt(save.idle.baseRate, 1, LIMITS.baseRate)
    if changed then addIssue(issues, "idle.baseRate") end
    save.idle.maxOfflineSeconds, changed = clampInt(save.idle.maxOfflineSeconds, 60, SaveSchema.MAX_OFFLINE_SECONDS)
    if changed then addIssue(issues, "idle.maxOfflineSeconds") end

    if save.createdAt > now then
        save.createdAt = now
        addIssue(issues, "createdAt.future")
    end
    if save.updatedAt > now then
        save.updatedAt = now
        addIssue(issues, "updatedAt.future")
    end
    if save.lastLoginTime > now then
        save.lastLoginTime = now
        addIssue(issues, "lastLoginTime.future")
    end
    if save.idle.lastCollectTime > now then
        save.idle.lastCollectTime = now
        addIssue(issues, "idle.lastCollectTime.future")
    end

    save.stats.loginCount, changed = clampInt(save.stats.loginCount, 0, 999999999)
    if changed then addIssue(issues, "stats.loginCount") end
    save.stats.totalOfflineCoin, changed = clampInt(save.stats.totalOfflineCoin, 0, LIMITS.coin)
    if changed then addIssue(issues, "stats.totalOfflineCoin") end
    save.security.suspiciousCount, changed = clampInt(save.security.suspiciousCount, 0, 999999)
    if changed then addIssue(issues, "security.suspiciousCount") end

    if #issues > 0 then
        save.security.suspiciousCount = save.security.suspiciousCount + 1
        print("[SaveValidator] Repaired save issues: " .. table.concat(issues, ","))
    end
    save.security.lastValidationAt = now

    return save, issues
end

return SaveValidator
