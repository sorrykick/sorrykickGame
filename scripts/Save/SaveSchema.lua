local DEFAULT_HEROES = {
    { id = "hero_001", name = "勇者1", quality = 3, star = 1, power = 1280, job = "战士", faction = "森林", role = "前排" },
    { id = "hero_002", name = "守护者", quality = 2, star = 1, power = 960, job = "坦克", faction = "森林", role = "前排" },
    { id = "hero_003", name = "疾风弓手", quality = 4, star = 1, power = 1420, job = "射手", faction = "王国", role = "后排" },
    { id = "hero_004", name = "星辉法师", quality = 4, star = 1, power = 1580, job = "法师", faction = "奥术", role = "后排" },
    { id = "hero_005", name = "祈愿祭司", quality = 3, star = 1, power = 1330, job = "辅助", faction = "王国", role = "后排" },
    { id = "hero_006", name = "荒原剑士", quality = 2, star = 1, power = 1180, job = "战士", faction = "荒原", role = "前排" },
}

local LINEUP_SLOT_IDS = { "front1", "front2", "front3", "back1", "back2", "back3" }

local function createDefaultFormations()
    return {
        { name = "阵容1", usage = "通用主线", locked = false, slots = { front1 = "hero_001", front2 = "hero_002", back1 = "hero_003", back2 = "hero_004" }, slotLocks = {} },
        { name = "阵容2", usage = "副本专用", locked = false, slots = {}, slotLocks = {} },
        { name = "阵容3", usage = "竞技专用", locked = false, slots = {}, slotLocks = {} },
    }
end

local function normalizeHero(rawHero, index)
    rawHero = type(rawHero) == "table" and rawHero or {}
    return {
        id = tostring(rawHero.id or ("hero_" .. string.format("%03d", index))),
        name = tostring(rawHero.name or ("勇者" .. tostring(index))),
        quality = math.max(1, math.min(7, math.floor(tonumber(rawHero.quality) or 1))),
        star = math.max(1, math.min(6, math.floor(tonumber(rawHero.star) or 1))),
        power = math.max(1, math.floor(tonumber(rawHero.power) or 1)),
        job = tostring(rawHero.job or "战士"),
        faction = tostring(rawHero.faction or "王国"),
        role = tostring(rawHero.role or "前排"),
    }
end

local function hasHero(heroMap, heroId)
    return heroId ~= nil and heroMap[tostring(heroId)] == true
end

local function normalizeLineup(rawLineup, heroes)
    local heroMap = {}
    for _, hero in ipairs(heroes) do
        heroMap[hero.id] = true
    end

    rawLineup = type(rawLineup) == "table" and rawLineup or {}
    local sourceFormations = type(rawLineup.formations) == "table" and rawLineup.formations or createDefaultFormations()
    local formations = {}
    for i = 1, 3 do
        local source = type(sourceFormations[i]) == "table" and sourceFormations[i] or {}
        local slots = {}
        local sourceSlots = type(source.slots) == "table" and source.slots or {}
        for _, slotId in ipairs(LINEUP_SLOT_IDS) do
            local heroId = sourceSlots[slotId]
            if hasHero(heroMap, heroId) then
                slots[slotId] = tostring(heroId)
            end
        end

        local slotLocks = {}
        local sourceLocks = type(source.slotLocks) == "table" and source.slotLocks or {}
        for _, slotId in ipairs(LINEUP_SLOT_IDS) do
            slotLocks[slotId] = sourceLocks[slotId] == true
        end

        formations[i] = {
            name = tostring(source.name or ("阵容" .. tostring(i))),
            usage = tostring(source.usage or ({ "通用主线", "副本专用", "竞技专用" })[i]),
            locked = source.locked == true,
            slots = slots,
            slotLocks = slotLocks,
            savedAt = math.floor(tonumber(source.savedAt) or 0),
        }
    end

    return {
        unlocked = rawLineup.unlocked ~= false,
        activeFormation = math.max(1, math.min(3, math.floor(tonumber(rawLineup.activeFormation) or 1))),
        recommendEnabled = rawLineup.recommendEnabled ~= false,
        formations = formations,
    }
end

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
        heroes = SaveSchema.DeepClone(DEFAULT_HEROES),
        lineup = normalizeLineup(nil, DEFAULT_HEROES),
        initialHeroGranted = true,
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

    local sourceHeroes = type(save.heroes) == "table" and save.heroes or DEFAULT_HEROES
    local heroes = {}
    if #sourceHeroes == 0 then
        sourceHeroes = DEFAULT_HEROES
    end
    for i, rawHero in ipairs(sourceHeroes) do
        heroes[#heroes + 1] = normalizeHero(rawHero, i)
    end
    save.heroes = heroes
    save.lineup = normalizeLineup(save.lineup, save.heroes)
    save.initialHeroGranted = save.initialHeroGranted ~= false

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
