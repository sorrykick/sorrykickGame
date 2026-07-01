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

local function getNpcClipDir(npcId)
    local dir = "image/npcClip/" .. tostring(npcId)
    local testPath = dir .. "/01.png"
    if cache and not cache:GetFile(testPath) then
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
    if cache and not cache:GetFile(path) then
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

return LevelManager
