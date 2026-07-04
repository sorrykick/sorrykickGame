local ConfigManager = require("Config.ConfigManager")

local LevelManager = {}

local QUALITY_POWER_MULTIPLIER = {
    N = 1.0,
    R = 1.18,
    SR = 1.42,
    SSR = 1.75,
    UR = 2.1,
}

local ROLE_BY_PROFESSION = {
    ["战士"] = "前排",
    ["骑士"] = "前排",
    ["刺客"] = "中排",
    ["射手"] = "后排",
    ["法师"] = "后排",
    ["祭司"] = "后排",
}

local ENEMY_SLOT_ORDER = {
    "front1",
    "front2",
    "front3",
    "mid1",
    "mid2",
    "mid3",
    "back1",
    "back2",
    "back3",
}

local function clampInt(value, minValue, maxValue)
    value = math.floor(tonumber(value) or minValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function getStages()
    local tables = ConfigManager.GetTables()
    local levelDesign = tables.levelDesign or {}
    return type(levelDesign.stages) == "table" and levelDesign.stages or {}
end

local function getStageById(stageId)
    stageId = clampInt(stageId, 1, 9999)
    for _, stage in ipairs(getStages()) do
        if tonumber(stage.stageId) == stageId then
            return stage
        end
    end
    return getStages()[1]
end

local function getSubLevel(stage, subLevelId)
    local subLevels = stage and stage.subLevels or {}
    if #subLevels == 0 then return nil end
    subLevelId = clampInt(subLevelId, 1, #subLevels)
    return subLevels[subLevelId] or subLevels[1]
end

local function formatNumber(value)
    value = math.floor(tonumber(value) or 0)
    if value >= 100000000 then
        return string.format("%.1f亿", value / 100000000)
    end
    if value >= 10000 then
        return string.format("%.1f万", value / 10000)
    end
    return tostring(value)
end

local function getConfiguredRewards(source, keys)
    for _, key in ipairs(keys) do
        local rewards = source and source[key]
        if type(rewards) == "table" and #rewards > 0 then
            return rewards
        end
    end
    return nil
end

local function normalizeReward(rawReward, fallbackIcon)
    if type(rawReward) == "table" then
        local name = rawReward.name or rawReward.itemName or rawReward.id or rawReward.itemId or "奖励"
        local count = rawReward.count or rawReward.num or rawReward.amount or rawReward.value or 1
        local icon = rawReward.icon or rawReward.iconText or fallbackIcon or "奖"
        return { name = tostring(name), count = math.max(1, math.floor(tonumber(count) or 1)), icon = tostring(icon) }
    end
    return { name = tostring(rawReward or "奖励"), count = 1, icon = fallbackIcon or "奖" }
end

local function buildFallbackFirstClearRewards(stage, subLevel)
    local stageId = math.max(1, math.floor(tonumber(stage and stage.stageId) or 1))
    local subLevelId = math.max(1, math.floor(tonumber(subLevel and subLevel.subLevelId) or 1))
    local difficulty = math.max(1, math.floor(tonumber(stage and stage.difficulty) or 1))
    local rewards = {
        { name = "金币", count = 800 + stageId * 160 + subLevelId * 40, icon = "金" },
        { name = "伙伴经验", count = 45 + difficulty * 10 + subLevelId * 5, icon = "书" },
    }
    if subLevel and subLevel.isBoss then
        rewards[#rewards + 1] = { name = "召唤券", count = 1, icon = "券" }
    end
    return rewards
end

local function buildFallbackSweepRewards(stage, subLevel)
    local stageId = math.max(1, math.floor(tonumber(stage and stage.stageId) or 1))
    local subLevelId = math.max(1, math.floor(tonumber(subLevel and subLevel.subLevelId) or 1))
    local rewards = {
        { name = "金币", count = 260 + stageId * 60 + subLevelId * 18, icon = "金" },
        { name = "伙伴经验", count = 18 + subLevelId * 3, icon = "书" },
    }
    if subLevel and subLevel.isBoss then
        rewards[#rewards + 1] = { name = "魔力结晶", count = 1, icon = "晶" }
    end
    return rewards
end

local function buildRewards(stage, subLevel, rewardKeys, fallbackBuilder, fallbackIcon)
    local configured = getConfiguredRewards(subLevel, rewardKeys) or getConfiguredRewards(stage, rewardKeys)
    if configured then
        local rewards = {}
        for _, reward in ipairs(configured) do
            rewards[#rewards + 1] = normalizeReward(reward, fallbackIcon)
        end
        return rewards
    end
    return fallbackBuilder(stage, subLevel)
end

local function getClearedSubLevelCount(saveData)
    local progress = saveData and saveData.stageProgress or {}
    return math.max(0, math.floor(tonumber(progress.clearedSubLevels) or 0))
end

local function getStageStartClearCount(stageId)
    local total = 0
    for _, stage in ipairs(getStages()) do
        local currentStageId = math.floor(tonumber(stage.stageId) or 0)
        if currentStageId < stageId then
            total = total + #(stage.subLevels or {})
        end
    end
    return total
end

local function getNpcClipDir(npcId)
    local dir = "image/npcClip/" .. tostring(npcId)
    local testPath = dir .. "/01.png"
    if cache and not cache:Exists(testPath) then
        return "image/npcClip/0001"
    end
    return dir
end

function LevelManager.GetTotalStages()
    local tables = ConfigManager.GetTables()
    local levelDesign = tables.levelDesign or {}
    return math.max(0, math.floor(tonumber(levelDesign.totalStages) or #getStages()))
end

function LevelManager.GetCurrentStageProgress(saveData)
    local progress = saveData and saveData.stageProgress or {}
    local stageId = clampInt(progress.currentStageId, 1, math.max(1, LevelManager.GetTotalStages()))
    local stage = getStageById(stageId)
    local maxSubLevel = stage and #(stage.subLevels or {}) or 1
    local subLevelId = clampInt(progress.currentSubLevelId, 1, math.max(1, maxSubLevel))
    return stageId, subLevelId
end

function LevelManager.GetStage(stageId)
    return getStageById(stageId)
end

function LevelManager.GetCurrentStage(saveData)
    local stageId = LevelManager.GetCurrentStageProgress(saveData)
    return getStageById(stageId)
end

function LevelManager.GetCurrentSubLevel(saveData)
    local stageId, subLevelId = LevelManager.GetCurrentStageProgress(saveData)
    local stage = getStageById(stageId)
    return getSubLevel(stage, subLevelId), stage
end

function LevelManager.BuildEnemyHeroData(enemy, index)
    enemy = type(enemy) == "table" and enemy or {}
    local npcId = tostring(enemy.npcId or "0001")
    local level = math.max(1, math.floor(tonumber(enemy.level) or 1))
    local star = clampInt(enemy.starLevel, 1, 6)
    local quality = tostring(enemy.quality or "N")
    local multiplier = QUALITY_POWER_MULTIPLIER[quality] or 1.0
    local power = math.floor((level * 36 + star * 180 + 420 + index * 35) * multiplier)
    return {
        id = "level_enemy_" .. npcId .. "_" .. tostring(index),
        npcId = npcId,
        configId = npcId,
        name = tostring(enemy.name or ("敌人" .. tostring(index))),
        qualityText = quality,
        star = star,
        level = level,
        power = power,
        job = tostring(enemy.profession or "战士"),
        profession = tostring(enemy.profession or "战士"),
        faction = tostring(enemy.faction or "未知"),
        role = ROLE_BY_PROFESSION[tostring(enemy.profession or "战士")] or "前排",
        clipDir = getNpcClipDir(npcId),
    }
end

function LevelManager.GetCurrentEnemies(saveData)
    local subLevel = LevelManager.GetCurrentSubLevel(saveData)
    local enemies = {}
    for index, enemy in ipairs((subLevel and subLevel.enemies) or {}) do
        enemies[#enemies + 1] = LevelManager.BuildEnemyHeroData(enemy, index)
    end
    return enemies
end

function LevelManager.GetEnemySlotId(index)
    return ENEMY_SLOT_ORDER[index] or ENEMY_SLOT_ORDER[#ENEMY_SLOT_ORDER]
end

function LevelManager.GetCurrentStageTitle(saveData)
    local stageId, subLevelId = LevelManager.GetCurrentStageProgress(saveData)
    local stage = getStageById(stageId)
    local subLevel = getSubLevel(stage, subLevelId)
    local sceneName = stage and stage.sceneName or "未知区域"
    local suffix = subLevel and subLevel.isBoss and " BOSS" or ""
    return string.format("第%d章  %s-%d%s", stageId, sceneName, subLevelId, suffix)
end

function LevelManager.GetCurrentStageSummary(saveData)
    local stageId, subLevelId = LevelManager.GetCurrentStageProgress(saveData)
    local stage = getStageById(stageId)
    local subLevel = getSubLevel(stage, subLevelId)
    local sceneName = stage and stage.sceneName or "未知区域"
    local enemyCount = #(subLevel and subLevel.enemies or {})
    if subLevel and subLevel.isBoss then
        return string.format("%s · BOSS %s · 敌人%d", sceneName, tostring(subLevel.bossName or "首领"), enemyCount)
    end
    return string.format("%s · 第%d小关 · 敌人%d", sceneName, subLevelId, enemyCount)
end

function LevelManager.GetStageSceneImagePath(stage)
    local sceneImage = stage and stage.sceneImage or "1"
    local path = "image/BattleRes/" .. tostring(sceneImage) .. ".png"
    if cache and not cache:Exists(path) then
        return "image/BattleRes/1.png"
    end
    return path
end

function LevelManager.GetCurrentSceneImagePath(saveData)
    local stage = LevelManager.GetCurrentStage(saveData)
    return LevelManager.GetStageSceneImagePath(stage)
end

function LevelManager.AdvanceStageProgress(saveData)
    if not saveData then return false end
    saveData.stageProgress = type(saveData.stageProgress) == "table" and saveData.stageProgress or {}
    local stageId, subLevelId = LevelManager.GetCurrentStageProgress(saveData)
    local stage = getStageById(stageId)
    local subLevels = stage and stage.subLevels or {}
    if subLevelId < #subLevels then
        saveData.stageProgress.currentStageId = stageId
        saveData.stageProgress.currentSubLevelId = subLevelId + 1
    elseif stageId < LevelManager.GetTotalStages() then
        saveData.stageProgress.currentStageId = stageId + 1
        saveData.stageProgress.currentSubLevelId = 1
    else
        saveData.stageProgress.currentStageId = stageId
        saveData.stageProgress.currentSubLevelId = subLevelId
    end
    saveData.stageProgress.clearedSubLevels = math.floor(tonumber(saveData.stageProgress.clearedSubLevels) or 0) + 1
    return true
end

function LevelManager.IsSubLevelCleared(saveData, stageId, subLevelId)
    local cleared = getClearedSubLevelCount(saveData)
    local globalIndex = getStageStartClearCount(math.max(1, math.floor(tonumber(stageId) or 1))) + math.max(1, math.floor(tonumber(subLevelId) or 1))
    return cleared >= globalIndex
end

function LevelManager.GetCurrentChapterSubLevels(saveData)
    local stageId = LevelManager.GetCurrentStageProgress(saveData)
    local stage = getStageById(stageId)
    local result = {}
    for _, subLevel in ipairs((stage and stage.subLevels) or {}) do
        result[#result + 1] = LevelManager.BuildSubLevelInfo(saveData, stage, subLevel)
    end
    return stage, result
end

function LevelManager.BuildSubLevelInfo(saveData, stage, subLevel)
    stage = type(stage) == "table" and stage or LevelManager.GetCurrentStage(saveData)
    subLevel = type(subLevel) == "table" and subLevel or getSubLevel(stage, 1)
    local stageId = math.max(1, math.floor(tonumber(stage and stage.stageId) or 1))
    local subLevelId = math.max(1, math.floor(tonumber(subLevel and subLevel.subLevelId) or 1))
    local sceneName = tostring(stage and stage.sceneName or "未知区域")
    local isBoss = subLevel and subLevel.isBoss == true
    local enemies = {}
    local totalPower = 0
    for index, enemy in ipairs((subLevel and subLevel.enemies) or {}) do
        local enemyData = LevelManager.BuildEnemyHeroData(enemy, index)
        enemyData.slotId = LevelManager.GetEnemySlotId(index)
        enemies[#enemies + 1] = enemyData
        totalPower = totalPower + math.max(0, math.floor(tonumber(enemyData.power) or 0))
    end
    local firstRewards = buildRewards(stage, subLevel, { "firstClearRewards", "firstRewards", "firstDrop", "firstDrops", "rewards", "drops" }, buildFallbackFirstClearRewards, "奖")
    local sweepRewards = buildRewards(stage, subLevel, { "sweepRewards", "sweepDrops", "repeatRewards", "repeatDrops" }, buildFallbackSweepRewards, "扫")
    local cleared = LevelManager.IsSubLevelCleared(saveData, stageId, subLevelId)
    return {
        stageId = stageId,
        subLevelId = subLevelId,
        sceneName = sceneName,
        name = string.format("%s-%d%s", sceneName, subLevelId, isBoss and " BOSS" or ""),
        title = string.format("第%d章 %s-%d%s", stageId, sceneName, subLevelId, isBoss and " BOSS" or ""),
        isBoss = isBoss,
        bossName = tostring(subLevel and subLevel.bossName or ""),
        cleared = cleared,
        enemies = enemies,
        totalPower = totalPower,
        totalPowerText = formatNumber(totalPower),
        firstClearRewards = firstRewards,
        sweepRewards = sweepRewards,
        previewRewards = cleared and sweepRewards or firstRewards,
    }
end

return LevelManager
