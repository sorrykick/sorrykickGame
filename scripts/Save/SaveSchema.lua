local FALLBACK_HEROES = {
    { id = "hero_001", name = "勇者1", quality = 3, star = 1, power = 1280, job = "战士", faction = "森林", role = "前排", npcId = "0001", clipDir = "image/npcClip/0001" },
    { id = "hero_002", name = "守护者", quality = 2, star = 1, power = 960, job = "骑士", faction = "森林", role = "前排", npcId = "0004", clipDir = "image/npcClip/0004" },
    { id = "hero_003", name = "疾风弓手", quality = 4, star = 1, power = 1420, job = "射手", faction = "王国", role = "后排", npcId = "0010", clipDir = "image/npcClip/0010" },
    { id = "hero_004", name = "星辉法师", quality = 4, star = 1, power = 1580, job = "法师", faction = "奥术", role = "后排", npcId = "0009", clipDir = "image/npcClip/0009" },
    { id = "hero_005", name = "祈愿祭司", quality = 3, star = 1, power = 1330, job = "祭司", faction = "王国", role = "后排", npcId = "0015", clipDir = "image/npcClip/0015" },
    { id = "hero_006", name = "荒原剑士", quality = 2, star = 1, power = 1180, job = "战士", faction = "荒原", role = "前排", npcId = "0012", clipDir = "image/npcClip/0012" },
    { id = "hero_007", name = "影刃游侠", quality = 3, star = 1, power = 1260, job = "刺客", faction = "荒原", role = "中排", npcId = "0002", clipDir = "image/npcClip/0002" },
    { id = "hero_008", name = "秘法学徒", quality = 2, star = 1, power = 1090, job = "法师", faction = "奥术", role = "中排", npcId = "0038", clipDir = "image/npcClip/0038" },
    { id = "hero_009", name = "圣盾骑士", quality = 3, star = 1, power = 1210, job = "骑士", faction = "王国", role = "前排", npcId = "0039", clipDir = "image/npcClip/0039" },
}

local LINEUP_SLOT_IDS = { "front1", "front2", "front3", "mid1", "mid2", "mid3", "back1", "back2", "back3" }

local ROLE_BY_JOB = {
    ["战士"] = "前排",
    ["骑士"] = "前排",
    ["刺客"] = "中排",
    ["射手"] = "后排",
    ["法师"] = "后排",
    ["祭司"] = "后排",
}

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

local function clampInt(value, minValue, maxValue)
    value = math.floor(tonumber(value) or minValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function isCommentKey(key)
    return type(key) == "string" and string.sub(key, 1, 1) == "#"
end

local function getSortedNpcIds(npcTable)
    local ids = {}
    for key, value in pairs(npcTable or {}) do
        if not isCommentKey(key) and type(value) == "table" then
            ids[#ids + 1] = tostring(key)
        end
    end
    table.sort(ids, function(a, b)
        return (tonumber(a) or 0) < (tonumber(b) or 0)
    end)
    return ids
end

local function getNpcInitialSkills(npcConfig)
    local ok, ConfigManager = pcall(require, "Config.ConfigManager")
    if not ok or not ConfigManager then return {} end
    local okSkills, skills = pcall(ConfigManager.GetNpcInitialSkills, npcConfig)
    if okSkills and type(skills) == "table" then
        return skills
    end
    return {}
end

local function createHeroFromNpcConfig(npcId, npcConfig, index)
    local job = tostring(npcConfig.profession or npcConfig.job or "战士")
    local quality = clampInt(npcConfig.quality, 1, 7)
    return {
        id = "npc_" .. tostring(npcId),
        npcId = tostring(npcId),
        configId = tostring(npcId),
        name = tostring(npcConfig.name or ("勇者" .. tostring(index))),
        quality = quality,
        star = clampInt(npcConfig.BaseStarID or npcConfig.star, 1, 6),
        level = math.max(1, math.floor(tonumber(npcConfig.level) or 1)),
        power = math.max(1, math.floor(tonumber(npcConfig.power) or (900 + index * 17 + quality * 220))),
        job = job,
        profession = job,
        faction = tostring(npcConfig.faction or "王国"),
        role = tostring(npcConfig.role or ROLE_BY_JOB[job] or "前排"),
        story = tostring(npcConfig.story or ""),
        clipDir = tostring(npcConfig.clipDir or ("image/npcClip/" .. tostring(npcId))),
        skills = getNpcInitialSkills(npcConfig),
    }
end

local function createDefaultHeroes()
    local ok, ConfigManager = pcall(require, "Config.ConfigManager")
    if ok and ConfigManager then
        local okTables, tables = pcall(ConfigManager.GetTables)
        local npcTable = okTables and tables and tables.npc or nil
        local ids = getSortedNpcIds(npcTable)
        if #ids > 0 then
            local heroes = {}
            for index, npcId in ipairs(ids) do
                heroes[#heroes + 1] = createHeroFromNpcConfig(npcId, npcTable[npcId], index)
            end
            print("[SaveSchema] Loaded NPC heroes from config: " .. tostring(#heroes))
            return heroes
        end
    end

    print("[SaveSchema] Using fallback heroes")
    return cloneValue(FALLBACK_HEROES)
end

local function createDefaultFormations(heroes)
    local slots = {}
    for index, slotId in ipairs(LINEUP_SLOT_IDS) do
        if heroes and heroes[index] then
            slots[slotId] = heroes[index].id
        end
    end
    return {
        { name = "阵容1", usage = "通用主线", locked = false, slots = slots, slotLocks = {} },
        { name = "阵容2", usage = "副本专用", locked = false, slots = {}, slotLocks = {} },
        { name = "阵容3", usage = "竞技专用", locked = false, slots = {}, slotLocks = {} },
    }
end

local function normalizeHero(rawHero, index)
    rawHero = type(rawHero) == "table" and rawHero or {}
    local npcId = tostring(rawHero.npcId or rawHero.configId or rawHero.id or index)
    local job = tostring(rawHero.job or rawHero.profession or "战士")
    return {
        id = tostring(rawHero.id or ("hero_" .. string.format("%03d", index))),
        npcId = npcId,
        configId = tostring(rawHero.configId or npcId),
        name = tostring(rawHero.name or ("勇者" .. tostring(index))),
        quality = clampInt(rawHero.quality, 1, 7),
        star = clampInt(rawHero.star or rawHero.BaseStarID, 1, 6),
        level = math.max(1, math.floor(tonumber(rawHero.level) or 1)),
        power = math.max(1, math.floor(tonumber(rawHero.power) or 1)),
        job = job,
        profession = tostring(rawHero.profession or job),
        faction = tostring(rawHero.faction or "王国"),
        role = tostring(rawHero.role or ROLE_BY_JOB[job] or "前排"),
        story = tostring(rawHero.story or ""),
        clipDir = tostring(rawHero.clipDir or ("image/npcClip/" .. npcId)),
        skills = type(rawHero.skills) == "table" and cloneValue(rawHero.skills) or {},
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
    local sourceFormations = type(rawLineup.formations) == "table" and rawLineup.formations or createDefaultFormations(heroes)
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

local function createDefaultInventory()
    return {
        capacity = 36,
        selectedTab = "all",
        items = {
            { uid = "item_coin_box_001", configId = "coin_box_small", name = "小袋金币", type = "material", quality = 2, count = 6, icon = "金", description = "装着少量金币的钱袋，使用后获得金币。", value = 1200, obtainedAt = 0 },
            { uid = "item_exp_scroll_001", configId = "partner_exp_scroll", name = "伙伴经验书", type = "consumable", quality = 3, count = 4, icon = "书", description = "记录成长心得的经验书，后续可用于伙伴升级。", value = 80, obtainedAt = 0 },
            { uid = "item_summon_ticket_001", configId = "summon_ticket", name = "召唤券", type = "ticket", quality = 4, count = 3, icon = "券", description = "可用于召唤新勇者的珍贵凭证。", value = 1, obtainedAt = 0 },
            { uid = "item_iron_sword_001", configId = "iron_sword", name = "制式长剑", type = "equipment", quality = 2, count = 1, icon = "剑", description = "王国工坊打造的基础武器，适合前期开荒。", value = 45, obtainedAt = 0 },
            { uid = "item_guard_badge_001", configId = "guard_badge", name = "守卫徽章", type = "fragment", quality = 3, count = 18, icon = "徽", description = "收集后可兑换守卫系勇者培养材料。", value = 1, obtainedAt = 0 },
            { uid = "item_magic_crystal_001", configId = "magic_crystal", name = "魔力结晶", type = "material", quality = 5, count = 2, icon = "晶", description = "秘境中凝结出的高纯度晶体，可用于高级强化。", value = 1, obtainedAt = 0 },
        },
    }
end

local function normalizeInventory(rawInventory)
    local defaults = createDefaultInventory()
    rawInventory = type(rawInventory) == "table" and rawInventory or defaults
    local capacity = math.max(24, math.min(120, math.floor(tonumber(rawInventory.capacity) or defaults.capacity)))
    local items = {}
    local sourceItems = type(rawInventory.items) == "table" and rawInventory.items or defaults.items
    for index, rawItem in ipairs(sourceItems) do
        if type(rawItem) == "table" and index <= capacity then
            local count = math.max(1, math.floor(tonumber(rawItem.count) or 1))
            items[#items + 1] = {
                uid = tostring(rawItem.uid or ("item_" .. tostring(index))),
                configId = tostring(rawItem.configId or rawItem.id or ("item_" .. tostring(index))),
                name = tostring(rawItem.name or "未知物品"),
                type = tostring(rawItem.type or "material"),
                quality = clampInt(rawItem.quality, 1, 6),
                count = count,
                icon = tostring(rawItem.icon or "物"),
                description = tostring(rawItem.description or "暂无描述"),
                value = math.max(0, math.floor(tonumber(rawItem.value) or 0)),
                obtainedAt = math.max(0, math.floor(tonumber(rawItem.obtainedAt) or 0)),
            }
        end
    end
    return {
        capacity = capacity,
        selectedTab = tostring(rawInventory.selectedTab or "all"),
        items = items,
    }
end

local function hasNpcBackedHeroes(heroes)
    for _, hero in ipairs(heroes or {}) do
        if type(hero) == "table" and (hero.npcId or hero.configId or (type(hero.id) == "string" and string.sub(hero.id, 1, 4) == "npc_")) then
            return true
        end
    end
    return false
end

local SaveSchema = {}

SaveSchema.SAVE_KEY = "partner_idle_save_v1"
SaveSchema.META_KEY = SaveSchema.SAVE_KEY .. "__meta"
SaveSchema.FIELD_PREFIX = SaveSchema.SAVE_KEY .. "__field__"
SaveSchema.DELTA_FIELDS = {
    "lastLoginTime",
    "coin",
    "diamond",
    "crystal",
    "energy",
    "partner",
    "heroes",
    "inventory",
    "lineup",
    "stageProgress",
    "initialHeroGranted",
    "idle",
    "stats",
    "security",
}
SaveSchema.MAX_OFFLINE_SECONDS = 12 * 60 * 60

function SaveSchema.GetFieldKey(fieldName)
    return SaveSchema.FIELD_PREFIX .. tostring(fieldName)
end

function SaveSchema.GetAllCloudKeys()
    local keys = { SaveSchema.SAVE_KEY, SaveSchema.META_KEY }
    for _, fieldName in ipairs(SaveSchema.DELTA_FIELDS) do
        keys[#keys + 1] = SaveSchema.GetFieldKey(fieldName)
    end
    return keys
end

function SaveSchema.DeepClone(value)
    return cloneValue(value)
end

function SaveSchema.CreateDefaultSave(now)
    local defaultHeroes = createDefaultHeroes()
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
        heroes = SaveSchema.DeepClone(defaultHeroes),
        inventory = createDefaultInventory(),
        lineup = normalizeLineup(nil, defaultHeroes),
        stageProgress = {
            currentStageId = 1,
            currentSubLevelId = 1,
            clearedSubLevels = 0,
        },
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

    local defaultHeroes = createDefaultHeroes()
    local sourceHeroes = type(save.heroes) == "table" and save.heroes or defaultHeroes
    if not hasNpcBackedHeroes(sourceHeroes) and #defaultHeroes > #FALLBACK_HEROES then
        sourceHeroes = defaultHeroes
        save.lineup = nil
    end
    local heroes = {}
    if #sourceHeroes == 0 then
        sourceHeroes = defaultHeroes
    end
    local existingHeroIds = {}
    for i, rawHero in ipairs(sourceHeroes) do
        local hero = normalizeHero(rawHero, i)
        heroes[#heroes + 1] = hero
        existingHeroIds[hero.id] = true
    end
    for _, defaultHero in ipairs(defaultHeroes) do
        if not existingHeroIds[defaultHero.id] then
            local hero = normalizeHero(defaultHero, #heroes + 1)
            heroes[#heroes + 1] = hero
            existingHeroIds[hero.id] = true
        end
    end
    save.heroes = heroes
    save.inventory = normalizeInventory(save.inventory)
    save.lineup = normalizeLineup(save.lineup, save.heroes)
    save.stageProgress = type(save.stageProgress) == "table" and save.stageProgress or {}
    save.stageProgress.currentStageId = math.max(1, math.floor(tonumber(save.stageProgress.currentStageId) or 1))
    save.stageProgress.currentSubLevelId = math.max(1, math.floor(tonumber(save.stageProgress.currentSubLevelId) or 1))
    save.stageProgress.clearedSubLevels = math.max(0, math.floor(tonumber(save.stageProgress.clearedSubLevels) or 0))
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
