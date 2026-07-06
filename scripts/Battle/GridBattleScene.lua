local UI = require("urhox-libs/UI")
local NormalizedSprite = require("UI.NormalizedSprite")
local SaveManager = require("Save.SaveManager")
local LevelManager = require("Level.LevelManager")
local ConfigManager = require("Config.ConfigManager")

local GridBattleScene = {}
GridBattleScene.__index = GridBattleScene

local GRID_COLS = 20
local GRID_ROWS = 20
local CELL_SIZE = 32
local GRID_SIZE = GRID_COLS * CELL_SIZE
local GRID_LEFT = 40
local GRID_TOP = 360
local MOVE_SPEED = 10
local AI_TICK_INTERVAL = 0.25
local UNIT_WIDTH = 96
local UNIT_HEIGHT = 76
local IDLE_FRAMES = { 1, 2, 3, 4 }
local MOVE_FRAMES = { 6, 7, 8, 9 }
local ATTACK_FRAMES = { 10, 11, 12, 13, 14 }
local IDLE_FPS = 5
local MOVE_FPS = 8
local ATTACK_FPS = 10

local UNIT_DEFS = {
    hero = { name = "勇者1", camp = "hero", color = { 88, 190, 255, 255 }, border = { 225, 250, 255, 255 }, tint = { 255, 255, 255, 255 }, flipX = false, hp = 120, damage = 18, attackInterval = 0.8 },
    enemy = { name = "森林守卫", camp = "enemy", color = { 226, 84, 72, 255 }, border = { 255, 226, 210, 255 }, tint = { 255, 120, 105, 255 }, flipX = true, hp = 80, damage = 8, attackInterval = 1.2 },
}

local BATTLE_SLOT_POSITIONS = {
    front1 = { x = 6, y = 8 },
    front2 = { x = 6, y = 11 },
    front3 = { x = 6, y = 14 },
    mid1 = { x = 4, y = 8 },
    mid2 = { x = 4, y = 11 },
    mid3 = { x = 4, y = 14 },
    back1 = { x = 2, y = 8 },
    back2 = { x = 2, y = 11 },
    back3 = { x = 2, y = 14 },
}

local BATTLE_SLOT_ORDER = { "front1", "front2", "front3", "mid1", "mid2", "mid3", "back1", "back2", "back3" }

local DIRECTIONS = {
    { x = 1, y = 0 },
    { x = -1, y = 0 },
    { x = 0, y = 1 },
    { x = 0, y = -1 },
    { x = 1, y = 1 },
    { x = 1, y = -1 },
    { x = -1, y = 1 },
    { x = -1, y = -1 },
}

local STAT_DEFAULTS = {
    moveSpeed = 1,
    hp = 100,
    atk = 10,
    def = 0,
    critRate = 0,
    critResist = 0,
    dmgBonus = 0,
    dmgReduce = 0,
    critDmgBonus = 0,
}

local function GridKey(x, y)
    return tostring(x) .. ":" .. tostring(y)
end

local function GridToPixel(x, y)
    return GRID_LEFT + (x - 1) * CELL_SIZE, GRID_TOP + (y - 1) * CELL_SIZE
end

local function GridDistance(a, b)
    return math.max(math.abs(a.gridX - b.gridX), math.abs(a.gridY - b.gridY))
end

local function Clamp(value, minValue, maxValue)
    value = tonumber(value) or minValue
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function Sign(value)
    if value > 0 then return 1 end
    if value < 0 then return -1 end
    return 0
end

local function CloneValue(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do
        result[CloneValue(key)] = CloneValue(child)
    end
    return result
end

local function GetNpcIdFromData(heroData)
    local npcId = tostring(heroData and (heroData.configId or heroData.npcId or heroData.id) or "")
    if string.sub(npcId, 1, 4) == "npc_" then
        npcId = string.sub(npcId, 5)
    end
    return npcId
end

local function GetConfigForData(heroData)
    local npcId = GetNpcIdFromData(heroData)
    if npcId == "" then return nil end
    return ConfigManager.GetNpcConfig(npcId)
end

local function GetNpcClipFramePath(clipDir, frameNumber)
    local dir = clipDir or "image/npcClip/0001"
    local path = string.format("%s/%02d.png", dir, frameNumber)
    if cache and not cache:Exists(path) then
        return string.format("image/npcClip/0001/%02d.png", frameNumber)
    end
    return path
end

local function GetActionDef(action)
    if action == "move" then
        return MOVE_FRAMES, MOVE_FPS, true
    end
    if action == "attack" or action == "skill" then
        return ATTACK_FRAMES, ATTACK_FPS, false
    end
    return IDLE_FRAMES, IDLE_FPS, true
end

local function CreateCellColor(x, y)
    local checker = (x + y) % 2 == 0
    if checker then
        return { 46, 70, 58, 228 }
    end
    return { 36, 58, 50, 228 }
end

local function PickStat(sourceStats, key, fallback)
    if type(sourceStats) == "table" and sourceStats[key] ~= nil then
        return tonumber(sourceStats[key]) or fallback
    end
    return fallback
end

local function BuildBattleStats(heroData, npcConfig, def)
    local sourceStats = type(heroData and heroData.stats) == "table" and heroData.stats or nil
    if not sourceStats and type(npcConfig and npcConfig.stats) == "table" then
        sourceStats = npcConfig.stats
    end

    local stats = {}
    for key, fallback in pairs(STAT_DEFAULTS) do
        stats[key] = PickStat(sourceStats, key, fallback)
    end

    if not sourceStats then
        local power = heroData and math.max(1, math.floor(tonumber(heroData.power) or def.hp)) or def.hp
        stats.hp = math.max(60, math.floor(power * 0.12))
        stats.atk = math.max(8, math.floor(power * 0.018))
        stats.def = math.max(0, math.floor(power * 0.006))
    end

    local level = math.max(1, math.floor(tonumber(heroData and heroData.level) or tonumber(npcConfig and npcConfig.level) or 1))
    local star = math.max(1, math.floor(tonumber(heroData and heroData.star or heroData and heroData.starLevel or npcConfig and npcConfig.BaseStarID) or 1))
    local growthScale = 1 + (level - 1) * 0.03 + (star - 1) * 0.12
    stats.hp = math.max(1, math.floor(stats.hp * growthScale))
    stats.atk = math.max(1, math.floor(stats.atk * growthScale))
    stats.def = math.max(0, math.floor(stats.def * growthScale))
    stats.moveSpeed = math.max(1, math.floor(tonumber(stats.moveSpeed) or 1))
    stats.critRate = math.max(0, math.floor(tonumber(stats.critRate) or 0))
    stats.critResist = math.max(0, math.floor(tonumber(stats.critResist) or 0))
    stats.dmgBonus = math.floor(tonumber(stats.dmgBonus) or 0)
    stats.dmgReduce = math.max(0, math.floor(tonumber(stats.dmgReduce) or 0))
    stats.critDmgBonus = math.max(0, math.floor(tonumber(stats.critDmgBonus) or 0))
    stats.maxHp = stats.hp
    return stats
end

local function CreateUnit(def, id, gridX, gridY, heroData)
    heroData = type(heroData) == "table" and heroData or nil
    local npcConfig = GetConfigForData(heroData) or {}
    local activeSkill = CloneValue(heroData and heroData.activeSkill or npcConfig.activeSkill or {})
    local passiveSkills = CloneValue(heroData and heroData.passiveSkills or npcConfig.passiveSkills or {})
    local ai = CloneValue(heroData and heroData.ai or npcConfig.ai or {})
    local stats = BuildBattleStats(heroData, npcConfig, def)
    local skillCd = math.max(0, tonumber(activeSkill.cooldown) or 0)
    local moveSpeed = math.max(1, stats.moveSpeed)
    return {
        id = id,
        npcId = GetNpcIdFromData(heroData),
        name = heroData and heroData.name or npcConfig.name or def.name,
        camp = def.camp,
        color = def.color,
        border = def.border,
        sprite = GetNpcClipFramePath(heroData and heroData.clipDir or npcConfig.clipDir, IDLE_FRAMES[1]),
        clipDir = heroData and heroData.clipDir or npcConfig.clipDir or "image/npcClip/0001",
        tint = def.tint,
        flipX = def.flipX == true,
        profession = heroData and (heroData.profession or heroData.job) or npcConfig.profession,
        action = "idle",
        actionFrameIndex = 1,
        actionFrameTimer = 0,
        actionLoop = true,
        hp = stats.hp,
        maxHp = stats.maxHp,
        stats = stats,
        baseStats = CloneValue(stats),
        damage = stats.atk,
        attackInterval = math.max(0.55, (def.attackInterval or 1.0) - moveSpeed * 0.05),
        attackTimer = 0,
        skillTimer = 0,
        skillCooldown = skillCd,
        activeSkill = activeSkill,
        passiveSkills = passiveSkills,
        passiveTimers = {},
        ai = ai,
        buffs = {},
        dots = {},
        shield = 0,
        moveTimer = 0,
        moveInterval = math.max(0.12, 0.78 / moveSpeed),
        lowHpTriggered = false,
        nextDamageBonus = 0,
        nextCrit = false,
        gridX = gridX,
        gridY = gridY,
        targetGridX = gridX,
        targetGridY = gridY,
        facingX = def.camp == "hero" and 1 or -1,
        facingY = 0,
        pixelX = 0,
        pixelY = 0,
        widget = nil,
        spriteWidget = nil,
        hpLabel = nil,
        moving = false,
        dead = false,
    }
end

local function GetHpPercent(unit)
    if not unit or unit.maxHp <= 0 then return 0 end
    return unit.hp / unit.maxHp
end

local function GetBuffStat(unit, key)
    local amount = 0
    for _, buff in ipairs(unit.buffs or {}) do
        if buff.stat == key then
            amount = amount + (tonumber(buff.amount) or 0)
        end
    end
    return amount
end

local function GetStat(unit, key)
    if not unit then return 0 end
    local base = unit.stats and unit.stats[key] or 0
    return (tonumber(base) or 0) + GetBuffStat(unit, key)
end

local function HasDebuff(unit, kind)
    for _, buff in ipairs(unit.buffs or {}) do
        if buff.kind == kind then
            return true
        end
    end
    return false
end

local function AddBuff(unit, kind, stat, amount, duration)
    if not unit or unit.dead then return end
    unit.buffs = type(unit.buffs) == "table" and unit.buffs or {}
    unit.buffs[#unit.buffs + 1] = {
        kind = kind,
        stat = stat,
        amount = amount or 0,
        duration = duration or 3,
    }
end

local function AddShield(unit, amount, duration)
    if not unit or unit.dead then return end
    unit.shield = math.max(0, (unit.shield or 0) + math.max(1, math.floor(amount or 0)))
    AddBuff(unit, "shield", nil, 0, duration or 5)
end

local function AddDot(unit, caster, kind, dps, duration)
    if not unit or unit.dead then return end
    unit.dots = type(unit.dots) == "table" and unit.dots or {}
    unit.dots[#unit.dots + 1] = {
        kind = kind,
        source = caster,
        dps = math.max(1, math.floor(dps or 1)),
        duration = duration or 4,
        tickTimer = 1,
    }
end

local function ExtractPercent(text, fallback)
    local value = tostring(text or ""):match("(%d+)%%")
    return tonumber(value) or fallback
end

local function ExtractSeconds(text, fallback)
    local value = tostring(text or ""):match("(%d+)秒")
    return tonumber(value) or fallback
end

local function PassiveChance(text)
    local percent = tostring(text or ""):match("(%d+)%%概率")
    if not percent then return true end
    return math.random(100) <= tonumber(percent)
end

function GridBattleScene:new(options)
    local o = setmetatable({}, self)
    o.onExit = options and options.onExit or nil
    o.root = nil
    o.gridLayer = nil
    o.unitLayer = nil
    o.statusLabel = nil
    o.battleTime = 0
    o.aiTimer = 0
    o.cells = {}
    o.stage = nil
    o.subLevel = nil
    o.victoryHandled = false
    return o
end

function GridBattleScene:CreateRoot()
    self:CreateBattleData()

    self.gridLayer = UI.Panel {
        position = "absolute",
        left = GRID_LEFT,
        top = GRID_TOP,
        width = GRID_SIZE,
        height = GRID_SIZE,
        visible = false,
        flexDirection = "row",
        flexWrap = "wrap",
        backgroundColor = { 18, 24, 26, 255 },
        borderColor = { 205, 176, 108, 255 },
        borderWidth = 3,
        overflow = "hidden",
        children = self:CreateGridCells(),
    }

    self.unitLayer = UI.Panel {
        position = "absolute",
        left = 0,
        top = 0,
        right = 0,
        bottom = 0,
        pointerEvents = "box-none",
        children = self:CreateUnitWidgets(),
    }

    self.statusLabel = UI.Label {
        text = LevelManager.GetCurrentStageSummary(SaveManager.GetSaveData()),
        fontSize = 22,
        fontColor = { 255, 244, 210, 255 },
        textAlign = "center",
        textStroke = { width = 2, color = { 20, 18, 14, 230 } },
    }

    self.root = UI.Panel {
        id = "battleScreen",
        width = 720,
        height = 1280,
        backgroundColor = { 18, 27, 30, 255 },
        overflow = "hidden",
        children = {
            self:CreateBackground(),
            self:CreateTopPanel(),
            self.gridLayer,
            self.unitLayer,
            self:CreateBottomPanel(),
        },
    }

    self:RefreshUnitWidgets(true)
    print("[Battle] Auto grid battle scene created: 20x20 with NPC AI and skills")
    return self.root
end

local function GetHeroMap(heroes)
    local heroMap = {}
    for _, hero in ipairs(heroes or {}) do
        heroMap[hero.id] = hero
    end
    return heroMap
end

local function GetActiveFormation(saveData)
    local lineup = saveData and saveData.lineup or {}
    local activeIndex = math.max(1, math.min(3, math.floor(tonumber(lineup.activeFormation) or 1)))
    return lineup.formations and lineup.formations[activeIndex] or nil
end

local function GetEnemyMirrorPosition(slotId)
    local pos = BATTLE_SLOT_POSITIONS[slotId]
    if not pos then return nil end
    return { x = GRID_COLS - pos.x + 1, y = pos.y }
end

function GridBattleScene:CreateBattleData()
    self.cells = {}
    self.units = {}
    self.occupancy = {}
    self.battleTime = 0
    self.aiTimer = 0
    self.victoryHandled = false

    local saveData = SaveManager.GetSaveData() or {}
    local heroMap = GetHeroMap(saveData.heroes or {})
    local formation = GetActiveFormation(saveData)
    self.subLevel, self.stage = LevelManager.GetCurrentSubLevel(saveData)
    local levelEnemies = LevelManager.GetCurrentEnemies(saveData)
    local createdHeroCount = 0
    local createdEnemyCount = 0

    for _, slotId in ipairs(BATTLE_SLOT_ORDER) do
        local hero = formation and formation.slots and heroMap[formation.slots[slotId]] or nil
        local heroPos = BATTLE_SLOT_POSITIONS[slotId]
        if hero and heroPos then
            createdHeroCount = createdHeroCount + 1
            local heroUnit = CreateUnit(UNIT_DEFS.hero, "hero_" .. slotId, heroPos.x, heroPos.y, hero)
            self.units[heroUnit.id] = heroUnit
        end
    end

    for index, enemy in ipairs(levelEnemies) do
        local slotId = LevelManager.GetEnemySlotId(index)
        local enemyPos = GetEnemyMirrorPosition(slotId)
        if enemy and enemyPos then
            createdEnemyCount = createdEnemyCount + 1
            local enemyUnit = CreateUnit(UNIT_DEFS.enemy, "enemy_" .. tostring(index), enemyPos.x, enemyPos.y, enemy)
            self.units[enemyUnit.id] = enemyUnit
        end
    end

    if createdHeroCount == 0 then
        local fallbackHero = CreateUnit(UNIT_DEFS.hero, "hero_front2", 6, 11, { name = "勇者1", npcId = "0001", configId = "0001", power = 1280 })
        self.units[fallbackHero.id] = fallbackHero
    end
    if createdEnemyCount == 0 then
        local fallbackEnemy = CreateUnit(UNIT_DEFS.enemy, "enemy_front2", 15, 11, { name = "草原守卫", npcId = "0001", configId = "0001", power = 1280 })
        self.units[fallbackEnemy.id] = fallbackEnemy
    end

    for _, unit in pairs(self.units) do
        local px, py = GridToPixel(unit.gridX, unit.gridY)
        unit.pixelX = px
        unit.pixelY = py
        self.occupancy[GridKey(unit.gridX, unit.gridY)] = unit.id
        print(string.format("[Battle] Spawn %s hp=%d atk=%d def=%d crit=%d ai=%s skill=%s", unit.name, unit.maxHp, GetStat(unit, "atk"), GetStat(unit, "def"), GetStat(unit, "critRate"), tostring(unit.ai.behaviorType or "默认"), tostring(unit.activeSkill.name or "无")))
    end
end

function GridBattleScene:CreateBackground()
    return UI.Panel {
        position = "absolute",
        left = 0,
        top = 0,
        right = 0,
        bottom = 0,
        zIndex = 0,
        borderRadius = 0,
        backgroundImage = LevelManager.GetCurrentSceneImagePath(SaveManager.GetSaveData()),
        backgroundFit = "cover",
        pointerEvents = "none",
    }
end

function GridBattleScene:CreateTopPanel()
    return UI.Panel {
        position = "absolute",
        left = 24,
        top = 28,
        right = 24,
        height = 180,
        padding = 18,
        gap = 10,
        backgroundColor = { 44, 35, 28, 218 },
        borderColor = { 217, 178, 92, 210 },
        borderWidth = 2,
        borderRadius = 18,
        children = {
            UI.Panel {
                width = "100%",
                height = 54,
                flexDirection = "row",
                alignItems = "center",
                justifyContent = "space-between",
                children = {
                    UI.Label {
                        text = LevelManager.GetCurrentStageTitle(SaveManager.GetSaveData()),
                        fontSize = 30,
                        fontWeight = "bold",
                        fontColor = { 255, 235, 178, 255 },
                        textStroke = { width = 2, color = { 42, 24, 12, 240 } },
                    },
                    UI.Button {
                        text = "返回",
                        width = 112,
                        height = 46,
                        fontSize = 22,
                        backgroundColor = { 126, 57, 42, 255 },
                        pressedBackgroundColor = { 90, 37, 28, 255 },
                        textColor = { 255, 244, 220, 255 },
                        borderRadius = 20,
                        onClick = function()
                            print("[Battle] Exit battle scene")
                            if self.onExit then
                                self.onExit()
                            end
                        end,
                    },
                },
            },
            self.statusLabel,
            UI.Label {
                text = "双方按 NPC 配置执行行为 AI、主动技能、被动触发、低血量反应与扩展属性伤害公式。",
                fontSize = 18,
                fontColor = { 218, 232, 212, 235 },
                textAlign = "left",
                flexShrink = 1,
            },
        },
    }
end

function GridBattleScene:CreateBottomPanel()
    return UI.Panel {
        position = "absolute",
        left = 37,
        right = 27,
        bottom = 832,
        height = 170,
        padding = 18,
        gap = 12,
        backgroundColor = { 16, 18, 20, 222 },
        borderColor = { 100, 150, 130, 180 },
        borderWidth = 2,
        borderRadius = 18,
        children = {
            UI.Label {
                text = "自动战斗逻辑",
                fontSize = 24,
                fontWeight = "bold",
                fontColor = { 255, 242, 205, 255 },
            },
            UI.Label {
                text = "行为类型决定目标优先级和移动方式；技能按 CD、范围、面积类型与战况条件自动释放。",
                fontSize = 19,
                fontColor = { 225, 242, 226, 235 },
                flexShrink = 1,
            },
            UI.Label {
                text = "伤害使用攻击、防御、暴击、抗暴、增伤、减伤、暴伤等扩展属性。",
                fontSize = 18,
                fontColor = { 185, 214, 205, 220 },
            },
        },
    }
end

function GridBattleScene:CreateGridCells()
    local children = {}
    for y = 1, GRID_ROWS do
        for x = 1, GRID_COLS do
            children[#children + 1] = UI.Panel {
                width = CELL_SIZE,
                height = CELL_SIZE,
                backgroundColor = CreateCellColor(x, y),
                borderColor = { 92, 122, 104, 82 },
                borderWidth = 1,
                pointerEvents = "none",
            }
        end
    end
    return children
end

function GridBattleScene:CreateUnitWidgets()
    local children = {}
    for _, unit in pairs(self.units) do
        unit.hpLabel = UI.Label {
            text = tostring(unit.hp),
            position = "absolute",
            left = -16,
            right = -16,
            top = 0,
            fontSize = 13,
            fontColor = { 255, 248, 220, 255 },
            textAlign = "center",
            textStroke = { width = 1, color = { 0, 0, 0, 220 } },
        }
        unit.spriteWidget = NormalizedSprite {
            width = UNIT_WIDTH,
            height = UNIT_HEIGHT,
            backgroundImage = unit.sprite,
            backgroundFit = "contain",
            imageTint = unit.tint,
            flipX = unit.flipX,
        }
        unit.widget = UI.Panel {
            position = "absolute",
            left = unit.pixelX - UNIT_WIDTH * 0.5 + CELL_SIZE * 0.5,
            top = unit.pixelY - UNIT_HEIGHT + CELL_SIZE,
            width = UNIT_WIDTH,
            height = UNIT_HEIGHT + 18,
            alignItems = "center",
            justifyContent = "flex-end",
            pointerEvents = "box-none",
            children = {
                unit.hpLabel,
                unit.spriteWidget,
                UI.Label {
                    text = unit.camp == "hero" and "勇" or "敌",
                    position = "absolute",
                    left = 0,
                    right = 0,
                    bottom = 5,
                    fontSize = 18,
                    fontWeight = "bold",
                    fontColor = unit.camp == "hero" and { 20, 70, 120, 255 } or { 115, 20, 18, 255 },
                    textAlign = "center",
                    textStroke = { width = 1, color = { 255, 255, 255, 190 } },
                },
            },
        }
        children[#children + 1] = unit.widget
    end
    return children
end

function GridBattleScene:IsInsideGrid(x, y)
    return x >= 1 and x <= GRID_COLS and y >= 1 and y <= GRID_ROWS
end

function GridBattleScene:IsOccupied(x, y, ignoreUnitId)
    local occupant = self.occupancy[GridKey(x, y)]
    return occupant ~= nil and occupant ~= ignoreUnitId
end

function GridBattleScene:GetUnitAt(x, y)
    local unitId = self.occupancy[GridKey(x, y)]
    if not unitId then return nil end
    return self.units[unitId]
end

function GridBattleScene:GetLivingUnits(camp)
    local result = {}
    for _, unit in pairs(self.units or {}) do
        if not unit.dead and (not camp or unit.camp == camp) then
            result[#result + 1] = unit
        end
    end
    return result
end

function GridBattleScene:GetEnemies(unit)
    local result = {}
    for _, candidate in pairs(self.units or {}) do
        if not candidate.dead and candidate.camp ~= unit.camp then
            result[#result + 1] = candidate
        end
    end
    return result
end

function GridBattleScene:GetAllies(unit, includeSelf)
    local result = {}
    for _, candidate in pairs(self.units or {}) do
        if not candidate.dead and candidate.camp == unit.camp and (includeSelf or candidate ~= unit) then
            result[#result + 1] = candidate
        end
    end
    return result
end

function GridBattleScene:SetFacingToTarget(unit, target)
    local dx = target.gridX - unit.gridX
    local dy = target.gridY - unit.gridY
    unit.facingX = Sign(dx)
    unit.facingY = Sign(dy)
    if unit.facingX == 0 and unit.facingY == 0 then
        unit.facingX = unit.camp == "hero" and 1 or -1
    end
end

function GridBattleScene:GetFrontCell(unit)
    return unit.gridX + unit.facingX, unit.gridY + unit.facingY
end

function GridBattleScene:FindNearestEnemy(unit)
    local sameColumnNearest = nil
    local sameColumnDistance = 99999
    local nearest = nil
    local nearestDistance = 99999

    for _, candidate in pairs(self.units) do
        if not candidate.dead and candidate.camp ~= unit.camp then
            local distance = GridDistance(unit, candidate)
            if candidate.gridX == unit.gridX and distance < sameColumnDistance then
                sameColumnNearest = candidate
                sameColumnDistance = distance
            end
            if distance < nearestDistance then
                nearest = candidate
                nearestDistance = distance
            end
        end
    end

    return sameColumnNearest or nearest
end

function GridBattleScene:FindLowestHpEnemy(unit, maxRange)
    local target = nil
    local value = 2
    for _, candidate in ipairs(self:GetEnemies(unit)) do
        if not maxRange or GridDistance(unit, candidate) <= maxRange then
            local hpPercent = GetHpPercent(candidate)
            if hpPercent < value then
                value = hpPercent
                target = candidate
            end
        end
    end
    return target
end

function GridBattleScene:FindHighestAtkEnemy(unit, maxRange)
    local target = nil
    local value = -1
    for _, candidate in ipairs(self:GetEnemies(unit)) do
        if not maxRange or GridDistance(unit, candidate) <= maxRange then
            local atk = GetStat(candidate, "atk")
            if atk > value then
                value = atk
                target = candidate
            end
        end
    end
    return target
end

function GridBattleScene:FindLowestHpAlly(unit, includeSelf, maxRange)
    local target = nil
    local value = 2
    for _, candidate in ipairs(self:GetAllies(unit, includeSelf)) do
        if not maxRange or GridDistance(unit, candidate) <= maxRange then
            local hpPercent = GetHpPercent(candidate)
            if hpPercent < value then
                value = hpPercent
                target = candidate
            end
        end
    end
    return target
end

function GridBattleScene:CountEnemiesAround(target, range)
    local count = 0
    for _, candidate in ipairs(self:GetEnemies(target)) do
        if GridDistance(target, candidate) <= range then
            count = count + 1
        end
    end
    return count
end

function GridBattleScene:FindDenseEnemy(unit, maxRange)
    local target = nil
    local bestCount = -1
    local bestDistance = 99999
    for _, candidate in ipairs(self:GetEnemies(unit)) do
        local distance = GridDistance(unit, candidate)
        if not maxRange or distance <= maxRange then
            local count = self:CountEnemiesAround(candidate, 1)
            if count > bestCount or (count == bestCount and distance < bestDistance) then
                target = candidate
                bestCount = count
                bestDistance = distance
            end
        end
    end
    return target
end

function GridBattleScene:SelectEnemyTarget(unit, maxRange)
    local ai = unit.ai or {}
    local priority = tostring(ai.priorityTarget or "最近敌人")
    if priority == "血量最低敌人" then
        return self:FindLowestHpEnemy(unit, maxRange) or self:FindNearestEnemy(unit)
    end
    if priority == "攻击力最高敌人" then
        return self:FindHighestAtkEnemy(unit, maxRange) or self:FindNearestEnemy(unit)
    end
    if priority == "敌人密集区域" then
        return self:FindDenseEnemy(unit, maxRange) or self:FindNearestEnemy(unit)
    end
    return self:FindNearestEnemy(unit)
end

function GridBattleScene:ChooseStepByScore(unit, scorer)
    local bestX, bestY = nil, nil
    local bestScore = -999999
    for _, dir in ipairs(DIRECTIONS) do
        local nextX = unit.gridX + dir.x
        local nextY = unit.gridY + dir.y
        if self:IsInsideGrid(nextX, nextY) and not self:IsOccupied(nextX, nextY, unit.id) then
            local score = scorer(nextX, nextY, dir)
            if score > bestScore then
                bestScore = score
                bestX = nextX
                bestY = nextY
            end
        end
    end
    if bestX then
        return bestX, bestY, Sign(bestX - unit.gridX), Sign(bestY - unit.gridY)
    end
    return nil, nil, 0, 0
end

function GridBattleScene:ChooseStepAway(unit, target)
    local currentDistance = GridDistance(unit, target)
    return self:ChooseStepByScore(unit, function(nextX, nextY)
        local distance = math.max(math.abs(nextX - target.gridX), math.abs(nextY - target.gridY))
        return (distance - currentDistance) * 100 - math.abs(nextY - unit.gridY)
    end)
end

function GridBattleScene:ChooseStepToward(unit, target, desiredRange)
    desiredRange = desiredRange or 1
    local strategy = tostring(unit.ai and (unit.ai._moveOverride or unit.ai.moveStrategy) or "直冲")
    local currentDistance = GridDistance(unit, target)

    if strategy == "保持距离" and currentDistance < desiredRange then
        return self:ChooseStepAway(unit, target)
    end

    if strategy == "跟随队友" and target.camp == unit.camp then
        if currentDistance <= desiredRange then
            return nil, nil, 0, 0
        end
    elseif target.camp ~= unit.camp and currentDistance <= desiredRange then
        return nil, nil, 0, 0
    end

    local flankBiasX, flankBiasY = 0, 0
    if strategy == "迂回" then
        flankBiasX = Sign(target.gridY - unit.gridY)
        flankBiasY = -Sign(target.gridX - unit.gridX)
    end

    return self:ChooseStepByScore(unit, function(nextX, nextY)
        local distance = math.max(math.abs(nextX - target.gridX), math.abs(nextY - target.gridY))
        local score = -math.abs(distance - desiredRange) * 100
        if strategy == "直冲" or strategy == "跟随队友" then
            score = score - distance * 2
        elseif strategy == "迂回" then
            score = score + (nextX - unit.gridX) * flankBiasX * 12 + (nextY - unit.gridY) * flankBiasY * 12
        elseif strategy == "保持距离" then
            score = score - math.abs(distance - desiredRange) * 8
        end
        return score
    end)
end

function GridBattleScene:SetUnitAction(unit, action)
    if unit.dead then return end
    local frames, fps, loop = GetActionDef(action)
    unit.action = action
    unit.actionFrameIndex = 1
    unit.actionFrameTimer = 0
    unit.actionLoop = loop
    unit.actionFps = fps
    unit.actionFrames = frames
    if unit.spriteWidget then
        unit.spriteWidget:SetBackgroundImage(GetNpcClipFramePath(unit.clipDir, frames[1]))
    end
end

function GridBattleScene:UpdateUnitActionAnimation(unit, timeStep)
    if not unit.spriteWidget then return end
    local frames = unit.actionFrames
    if not frames then
        frames, unit.actionFps, unit.actionLoop = GetActionDef(unit.action or "idle")
        unit.actionFrames = frames
    end

    unit.actionFrameTimer = unit.actionFrameTimer + timeStep
    local frameDuration = 1 / unit.actionFps
    if unit.actionFrameTimer < frameDuration then return end

    unit.actionFrameTimer = unit.actionFrameTimer - frameDuration
    unit.actionFrameIndex = unit.actionFrameIndex + 1
    if unit.actionFrameIndex > #frames then
        if unit.actionLoop then
            unit.actionFrameIndex = 1
        else
            self:SetUnitAction(unit, "idle")
            return
        end
    end

    unit.spriteWidget:SetBackgroundImage(GetNpcClipFramePath(unit.clipDir, frames[unit.actionFrameIndex]))
end

function GridBattleScene:RequestMoveUnit(unitId, x, y)
    local unit = self.units[unitId]
    if not unit or unit.dead or unit.moving then return false end

    if not self:IsInsideGrid(x, y) then
        return false
    end

    if self:IsOccupied(x, y, unitId) then
        return false
    end

    self.occupancy[GridKey(unit.gridX, unit.gridY)] = nil
    unit.targetGridX = x
    unit.targetGridY = y
    unit.moving = true
    unit.moveTimer = unit.moveInterval
    self:SetUnitAction(unit, "move")
    self.occupancy[GridKey(x, y)] = unit.id
    self:TriggerPassive(unit, "move", { caster = unit })
    print(string.format("[Battle] Move %s to (%d,%d)", unit.id, x, y))
    return true
end

function GridBattleScene:SetStatus(text)
    if self.statusLabel then
        self.statusLabel:SetText(text)
    end
end

function GridBattleScene:RefreshHpLabel(unit)
    if unit and unit.hpLabel then
        local shieldText = unit.shield and unit.shield > 0 and (" +" .. tostring(math.floor(unit.shield))) or ""
        unit.hpLabel:SetText(tostring(math.max(0, math.floor(unit.hp))) .. shieldText)
    end
end

function GridBattleScene:Update(timeStep)
    self.battleTime = self.battleTime + timeStep

    for _, unit in pairs(self.units) do
        if not unit.dead then
            unit.attackTimer = math.max(0, unit.attackTimer - timeStep)
            unit.skillTimer = math.max(0, unit.skillTimer - timeStep)
            unit.moveTimer = math.max(0, unit.moveTimer - timeStep)
            self:UpdateBuffs(unit, timeStep)
            self:UpdateDots(unit, timeStep)
            self:CheckLowHp(unit)
            self:UpdateUnitActionAnimation(unit, timeStep)
            if unit.moving then
                self:UpdateUnitMove(unit, timeStep)
            end
        end
    end

    self.aiTimer = self.aiTimer + timeStep
    if self.aiTimer >= AI_TICK_INTERVAL then
        self.aiTimer = 0
        self:UpdateIntervalPassives(AI_TICK_INTERVAL)
        self:UpdateAutoBattle()
    end
end

function GridBattleScene:UpdateBuffs(unit, timeStep)
    for index = #(unit.buffs or {}), 1, -1 do
        local buff = unit.buffs[index]
        buff.duration = (tonumber(buff.duration) or 0) - timeStep
        if buff.duration <= 0 then
            if buff.kind == "shield" then
                unit.shield = 0
                self:RefreshHpLabel(unit)
            end
            table.remove(unit.buffs, index)
        end
    end
end

function GridBattleScene:UpdateDots(unit, timeStep)
    for index = #(unit.dots or {}), 1, -1 do
        local dot = unit.dots[index]
        dot.duration = (tonumber(dot.duration) or 0) - timeStep
        dot.tickTimer = (tonumber(dot.tickTimer) or 1) - timeStep
        if dot.tickTimer <= 0 then
            dot.tickTimer = 1
            self:ApplyDamage(dot.source, unit, dot.dps, dot.kind or "持续伤害", { noPassive = true })
        end
        if dot.duration <= 0 or unit.dead then
            table.remove(unit.dots, index)
        end
    end
end

function GridBattleScene:UpdateIntervalPassives(delta)
    for _, unit in pairs(self.units) do
        if not unit.dead then
            for index, passive in ipairs(unit.passiveSkills or {}) do
                local trigger = tostring(passive.trigger or "")
                if string.find(trigger, "每3秒") or string.find(trigger, "回合开始") then
                    unit.passiveTimers[index] = (unit.passiveTimers[index] or 3) - delta
                    if unit.passiveTimers[index] <= 0 then
                        unit.passiveTimers[index] = 3
                        self:ApplyPassiveEffect(unit, passive, { caster = unit, target = unit })
                    end
                end
            end
        end
    end
end

function GridBattleScene:UpdateAutoBattle()
    if not self:HasLivingCamp("enemy") then
        self:HandleBattleVictory()
        return
    end
    if not self:HasLivingCamp("hero") then
        self:HandleBattleDefeat()
        return
    end

    for _, unit in pairs(self.units) do
        if not unit.dead and not unit.moving then
            self:UpdateUnitAI(unit)
        end
    end
end

function GridBattleScene:HasLivingCamp(camp)
    for _, unit in pairs(self.units) do
        if not unit.dead and unit.camp == camp then
            return true
        end
    end
    return false
end

function GridBattleScene:HandleBattleVictory()
    if self.victoryHandled then return end
    self.victoryHandled = true
    local saveData = SaveManager.GetSaveData()
    LevelManager.AdvanceStageProgress(saveData)
    SaveManager.MarkDirty("stageProgress")
    self:SetStatus("战斗胜利：已推进到 " .. LevelManager.GetCurrentStageTitle(saveData))
    SaveManager.SaveGameSnapshot("关卡战斗胜利", nil, function(reason)
        print("[Battle] Save stage progress failed: " .. tostring(reason))
    end)
end

function GridBattleScene:HandleBattleDefeat()
    if self.victoryHandled then return end
    self.victoryHandled = true
    self:SetStatus("战斗失败：勇者已被击败")
end

function GridBattleScene:CheckLowHp(unit)
    if unit.lowHpTriggered or unit.dead then return end
    local lowHp = type(unit.ai and unit.ai.lowHP) == "table" and unit.ai.lowHP or nil
    if not lowHp then return end
    local threshold = (ExtractPercent(lowHp.trigger, 30) or 30) / 100
    if GetHpPercent(unit) > threshold then return end

    unit.lowHpTriggered = true
    local desc = tostring(lowHp.description or "")
    local logic = tostring(lowHp.logic or "")
    if string.find(desc, "攻击力") then
        AddBuff(unit, "low_hp_atk", "atk", math.max(1, math.floor(GetStat(unit, "atk") * (ExtractPercent(desc, 15) / 100))), 999)
    end
    if string.find(desc, "防御") then
        AddBuff(unit, "low_hp_def", "def", math.max(1, math.floor(GetStat(unit, "def") * (ExtractPercent(desc, 20) / 100))), 999)
    end
    if string.find(desc, "移动") or string.find(desc, "移动力") then
        AddBuff(unit, "low_hp_speed", "moveSpeed", 1, 999)
        unit.moveInterval = math.max(0.1, 0.78 / math.max(1, GetStat(unit, "moveSpeed")))
    end
    if string.find(desc, "隐身") then
        AddBuff(unit, "invisible", "dmgReduce", 35, ExtractSeconds(desc, 3))
        unit.nextCrit = true
        unit.nextDamageBonus = math.max(unit.nextDamageBonus or 0, 0.8)
    end
    if string.find(desc, "护盾") then
        AddShield(unit, unit.maxHp * 0.25, 6)
    end
    if string.find(logic, "保持距离") or string.find(logic, "生存") then
        unit.ai._moveOverride = "保持距离"
    elseif string.find(logic, "直冲") or string.find(logic, "继续进攻") or string.find(logic, "更激进") then
        unit.ai._moveOverride = "直冲"
        unit.ai._skillUsageOverride = "CD好了就用"
    end
    self:SetStatus(unit.name .. " 触发濒危反应：「" .. tostring(lowHp.name or "觉醒") .. "」")
    print("[Battle] LowHP triggered: " .. unit.id .. " " .. tostring(lowHp.name))
end

function GridBattleScene:ShouldUseSkill(unit, primaryTarget)
    local skill = unit.activeSkill or {}
    if not skill.name or unit.skillTimer > 0 or HasDebuff(unit, "stun") or HasDebuff(unit, "silence") then
        return false
    end
    local usage = tostring(unit.ai and (unit.ai._skillUsageOverride or unit.ai.skillUsage) or "CD好了就用")
    local skillType = tostring(skill.type or "攻击")
    local skillRange = math.max(1, math.floor(tonumber(skill.range) or 1))

    if skillType == "治愈" or skillType == "增益" then
        local ally = self:FindLowestHpAlly(unit, true, skillRange)
        if not ally then return false end
        if usage == "CD好了就用" then return GetHpPercent(ally) < 0.92 end
        return GetHpPercent(ally) < 0.55 or string.find(usage, "友军") ~= nil
    end

    if not primaryTarget or GridDistance(unit, primaryTarget) > skillRange and tostring(skill.areaType) ~= "全屏" then
        return false
    end

    if usage == "CD好了就用" then
        return true
    end
    if usage == "保留到关键时刻" then
        return GetHpPercent(primaryTarget) <= 0.55 or GetStat(primaryTarget, "atk") >= GetStat(unit, "atk") * 1.2
    end
    if string.find(usage, "2个") or string.find(usage, "2 个") or string.find(usage, "多个") or string.find(usage, "聚集") then
        return #self:SelectSkillTargets(unit, primaryTarget, skill) >= 2
    end
    if string.find(usage, "3") then
        return #self:SelectSkillTargets(unit, primaryTarget, skill) >= 3
    end
    if string.find(usage, "HP低于") or string.find(usage, "血量") then
        return GetHpPercent(primaryTarget) <= 0.5
    end
    if string.find(usage, "直线") then
        return unit.gridX == primaryTarget.gridX or unit.gridY == primaryTarget.gridY
    end
    return true
end

function GridBattleScene:UpdateUnitAI(unit)
    if HasDebuff(unit, "stun") then
        self:SetStatus(unit.name .. " 被眩晕，无法行动")
        return
    end

    local skillTarget = self:GetSkillPrimaryTarget(unit)
    if self:ShouldUseSkill(unit, skillTarget) and self:CastSkill(unit, skillTarget) then
        return
    end

    local target = self:SelectEnemyTarget(unit)
    if not target then
        if unit.camp == "hero" then
            self:SetStatus("战斗胜利：敌方已清除")
        elseif not self:HasLivingCamp("hero") then
            self:SetStatus("战斗失败：勇者已被击败")
        end
        return
    end

    self:SetFacingToTarget(unit, target)

    if GridDistance(unit, target) <= 1 then
        if unit.attackTimer <= 0 and not HasDebuff(unit, "disarm") then
            self:AttackTarget(unit, target)
        end
        return
    end

    if unit.moveTimer > 0 then
        return
    end

    local desiredRange = tostring(unit.ai and unit.ai.moveStrategy or "") == "保持距离" and math.max(2, math.floor(tonumber(unit.activeSkill and unit.activeSkill.range) or 2)) or 1
    local nextX, nextY, faceX, faceY = self:ChooseStepToward(unit, target, desiredRange)
    if nextX and nextY then
        unit.facingX = faceX
        unit.facingY = faceY
        self:RequestMoveUnit(unit.id, nextX, nextY)
        self:SetStatus(unit.name .. " 按" .. tostring(unit.ai.behaviorType or "默认") .. "AI接近 " .. target.name)
    else
        self:SetStatus(unit.name .. " 正在寻找可移动格子")
    end
end

function GridBattleScene:GetSkillPrimaryTarget(unit)
    local skill = unit.activeSkill or {}
    local skillType = tostring(skill.type or "攻击")
    local range = math.max(1, math.floor(tonumber(skill.range) or 1))
    if tostring(skill.areaType) == "全屏" then
        range = nil
    end
    if skillType == "治愈" or skillType == "增益" then
        return self:FindLowestHpAlly(unit, true, range) or unit
    end
    return self:SelectEnemyTarget(unit, range)
end

function GridBattleScene:SelectSkillTargets(unit, primaryTarget, skill)
    local skillType = tostring(skill and skill.type or "攻击")
    local areaType = tostring(skill and skill.areaType or "单体")
    local range = math.max(1, math.floor(tonumber(skill and skill.range) or 1))
    local targetCamp = (skillType == "治愈" or skillType == "增益") and unit.camp or nil
    local sourceUnits = targetCamp and self:GetLivingUnits(targetCamp) or self:GetEnemies(unit)
    local result = {}

    if areaType == "全屏" then
        for _, candidate in ipairs(sourceUnits) do
            result[#result + 1] = candidate
        end
        return result
    end

    if not primaryTarget then return result end

    if areaType == "AoE_3x3" then
        for _, candidate in ipairs(sourceUnits) do
            if math.max(math.abs(candidate.gridX - primaryTarget.gridX), math.abs(candidate.gridY - primaryTarget.gridY)) <= 1 then
                result[#result + 1] = candidate
            end
        end
    elseif areaType == "十字" then
        for _, candidate in ipairs(sourceUnits) do
            if GridDistance(unit, candidate) <= range and (candidate.gridX == primaryTarget.gridX or candidate.gridY == primaryTarget.gridY) then
                result[#result + 1] = candidate
            end
        end
    elseif areaType == "直线" then
        local dx = Sign(primaryTarget.gridX - unit.gridX)
        local dy = Sign(primaryTarget.gridY - unit.gridY)
        if math.abs(primaryTarget.gridX - unit.gridX) >= math.abs(primaryTarget.gridY - unit.gridY) then
            dy = 0
        else
            dx = 0
        end
        for _, candidate in ipairs(sourceUnits) do
            local cx = candidate.gridX - unit.gridX
            local cy = candidate.gridY - unit.gridY
            local inLine = dx ~= 0 and Sign(cx) == dx and cy == 0 or dy ~= 0 and Sign(cy) == dy and cx == 0
            if inLine and GridDistance(unit, candidate) <= range then
                result[#result + 1] = candidate
            end
        end
    else
        if GridDistance(unit, primaryTarget) <= range or skillType == "治愈" or skillType == "增益" then
            result[#result + 1] = primaryTarget
        end
    end
    return result
end

function GridBattleScene:CastSkill(unit, primaryTarget)
    local skill = unit.activeSkill or {}
    if not skill.name then return false end
    local targets = self:SelectSkillTargets(unit, primaryTarget, skill)
    if #targets == 0 then return false end

    unit.skillTimer = math.max(1, tonumber(skill.cooldown) or unit.skillCooldown or 6)
    unit.attackTimer = math.max(unit.attackTimer, 0.35)
    self:SetUnitAction(unit, "skill")
    self:TriggerPassive(unit, "skill_before", { caster = unit, skill = skill, target = primaryTarget })

    local skillType = tostring(skill.type or "攻击")
    local multiplier = tonumber(skill.damageMultiplier) or 1
    local effectText = tostring(skill.effect or "")
    if skillType == "治愈" then
        for _, target in ipairs(targets) do
            local heal = math.max(1, math.floor(GetStat(unit, "atk") * multiplier + target.maxHp * 0.12))
            self:HealUnit(target, heal)
        end
        self:SetStatus(unit.name .. " 施放「" .. tostring(skill.name) .. "」治疗友军")
    elseif skillType == "增益" then
        for _, target in ipairs(targets) do
            AddShield(target, target.maxHp * 0.22, ExtractSeconds(effectText, 6))
            AddBuff(target, "skill_atk_up", "atk", math.max(1, math.floor(GetStat(unit, "atk") * 0.15)), ExtractSeconds(effectText, 6))
            self:RefreshHpLabel(target)
        end
        self:SetStatus(unit.name .. " 施放「" .. tostring(skill.name) .. "」强化友军")
    else
        for _, target in ipairs(targets) do
            local damage = self:CalculateDamage(unit, target, multiplier, { forceCrit = string.find(effectText, "暴击") ~= nil })
            self:ApplyDamage(unit, target, damage, tostring(skill.name), { skill = skill })
            if string.find(effectText, "减速") then
                AddBuff(target, "slow", "moveSpeed", -1, ExtractSeconds(effectText, 3))
            end
            if string.find(effectText, "眩晕") or string.find(effectText, "定身") or skillType == "控制" then
                AddBuff(target, "stun", nil, 0, ExtractSeconds(effectText, 2))
            end
            if string.find(effectText, "流血") then
                AddDot(target, unit, "流血", GetStat(unit, "atk") * 0.12, ExtractSeconds(effectText, 6))
            elseif string.find(effectText, "中毒") or string.find(effectText, "灼烧") then
                AddDot(target, unit, string.find(effectText, "中毒") and "中毒" or "灼烧", GetStat(unit, "atk") * 0.10, ExtractSeconds(effectText, 5))
            end
            self:TriggerPassive(unit, "skill_hit", { caster = unit, target = target, skill = skill })
        end
        self:SetStatus(unit.name .. " 施放「" .. tostring(skill.name) .. "」命中" .. tostring(#targets) .. "个目标")
    end
    self:TriggerPassive(unit, "skill_after", { caster = unit, skill = skill, target = primaryTarget })
    print(string.format("[Battle] %s casts %s on %d targets", unit.id, tostring(skill.name), #targets))
    return true
end

function GridBattleScene:CalculateDamage(caster, target, multiplier, options)
    options = type(options) == "table" and options or {}
    local atk = GetStat(caster, "atk")
    local def = GetStat(target, "def")
    local base = math.max(1, atk * (multiplier or 1) - def * 0.5)
    base = base * (1 + (GetStat(caster, "dmgBonus") + (caster.nextDamageBonus or 0) * 100) / 100)
    base = base * math.max(0.1, 1 - GetStat(target, "dmgReduce") / 100)
    local critChance = Clamp(GetStat(caster, "critRate") - GetStat(target, "critResist"), 0, 100)
    local isCrit = options.forceCrit == true or caster.nextCrit == true or math.random(100) <= critChance
    if isCrit then
        base = base * (1.5 + GetStat(caster, "critDmgBonus") / 100)
    end
    caster.nextDamageBonus = 0
    caster.nextCrit = false
    return math.max(1, math.floor(base + 0.5)), isCrit
end

function GridBattleScene:ApplyDamage(caster, target, damage, reason, options)
    if not target or target.dead then return 0 end
    options = type(options) == "table" and options or {}
    damage = math.max(1, math.floor(tonumber(damage) or 1))

    if not options.noPassive and self:TryDefensivePassive(target, caster, damage) then
        self:SetStatus(target.name .. " 闪避了攻击")
        return 0
    end

    if target.shield and target.shield > 0 then
        local blocked = math.min(target.shield, damage)
        target.shield = target.shield - blocked
        damage = damage - blocked
    end

    if damage > 0 then
        target.hp = math.max(0, target.hp - damage)
    end
    self:RefreshHpLabel(target)

    if caster and not options.noPassive then
        self:TriggerPassive(caster, options.skill and "skill_hit" or "hit", { caster = caster, target = target, damage = damage, reason = reason })
    end
    self:TriggerPassive(target, "damaged", { caster = caster, target = target, damage = damage, reason = reason })

    if target.hp <= 0 then
        self:KillUnit(target, caster)
    end
    return damage
end

function GridBattleScene:HealUnit(target, amount)
    if not target or target.dead then return end
    target.hp = math.min(target.maxHp, target.hp + math.max(1, math.floor(amount or 1)))
    self:RefreshHpLabel(target)
end

function GridBattleScene:TryDefensivePassive(target, caster, damage)
    for _, passive in ipairs(target.passiveSkills or {}) do
        local trigger = tostring(passive.trigger or "")
        local effect = tostring(passive.effect or "")
        if string.find(trigger, "被") or string.find(trigger, "受到") then
            if string.find(effect, "闪避") and PassiveChance(effect) then
                AddBuff(target, "dodge_speed", "moveSpeed", 1, ExtractSeconds(effect, 3))
                return true
            end
            if string.find(effect, "减少") or string.find(effect, "减伤") then
                AddBuff(target, "hit_reduce", "dmgReduce", ExtractPercent(effect, 10), 2)
            end
            if string.find(effect, "反击") and caster and not caster.dead then
                local reflect = math.max(1, math.floor(GetStat(target, "def") * 0.6))
                self:ApplyDamage(target, caster, reflect, tostring(passive.name or "反击"), { noPassive = true })
            end
        end
    end
    return false
end

function GridBattleScene:TriggerPassive(unit, eventName, context)
    for _, passive in ipairs(unit.passiveSkills or {}) do
        local trigger = tostring(passive.trigger or "")
        local matched = false
        if eventName == "hit" then
            matched = string.find(trigger, "普通攻击命中") ~= nil or trigger == "攻击命中时"
        elseif eventName == "skill_hit" then
            matched = string.find(trigger, "技能命中") ~= nil
        elseif eventName == "skill_before" then
            matched = string.find(trigger, "施放") ~= nil or string.find(trigger, "释放") ~= nil
        elseif eventName == "skill_after" then
            matched = string.find(trigger, "施放主动技能后") ~= nil
        elseif eventName == "kill" then
            matched = string.find(trigger, "击杀") ~= nil
        elseif eventName == "move" then
            matched = string.find(trigger, "移动") ~= nil
        elseif eventName == "damaged" then
            matched = string.find(trigger, "被") ~= nil or string.find(trigger, "受到") ~= nil
        end
        if matched then
            self:ApplyPassiveEffect(unit, passive, context or {})
        end
    end
end

function GridBattleScene:ApplyPassiveEffect(unit, passive, context)
    if not passive or not PassiveChance(passive.effect) then return end
    local effect = tostring(passive.effect or "")
    local target = context.target or unit

    if string.find(effect, "追加") and target and target.camp ~= unit.camp then
        local multiplier = (ExtractPercent(effect, 50) or 50) / 100
        local damage = self:CalculateDamage(unit, target, multiplier, { forceCrit = false })
        self:ApplyDamage(unit, target, damage, tostring(passive.name or "追击"), { noPassive = true })
    end
    if string.find(effect, "攻击力提升") then
        local percent = ExtractPercent(effect, 3)
        AddBuff(unit, "passive_atk_up", "atk", math.max(1, math.floor(GetStat(unit, "atk") * percent / 100)), 999)
    end
    if string.find(effect, "防御") and (string.find(effect, "提升") or string.find(effect, "+")) then
        local percent = ExtractPercent(effect, 10)
        AddBuff(unit, "passive_def_up", "def", math.max(1, math.floor(GetStat(unit, "def") * percent / 100)), 5)
    end
    if string.find(effect, "移动") or string.find(effect, "移动力") then
        AddBuff(unit, "passive_speed", "moveSpeed", 1, ExtractSeconds(effect, 3))
        unit.moveInterval = math.max(0.1, 0.78 / math.max(1, GetStat(unit, "moveSpeed")))
    end
    if string.find(effect, "回复") then
        local percent = ExtractPercent(effect, 10)
        self:HealUnit(unit, unit.maxHp * percent / 100)
    end
    if string.find(effect, "冷却减少") then
        local seconds = ExtractSeconds(effect, 3)
        unit.skillTimer = math.max(0, unit.skillTimer - seconds)
    end
    if string.find(effect, "伤害%+") or string.find(effect, "伤害+") then
        unit.nextDamageBonus = math.max(unit.nextDamageBonus or 0, ExtractPercent(effect, 20) / 100)
    end
    if string.find(effect, "暴击") then
        AddBuff(unit, "passive_crit", "critRate", ExtractPercent(effect, 20), 4)
    end
    if string.find(effect, "护盾") then
        AddShield(unit, unit.maxHp * (ExtractPercent(effect, 20) / 100), ExtractSeconds(effect, 5))
    end
end

function GridBattleScene:AttackTarget(unit, target)
    unit.attackTimer = unit.attackInterval
    self:SetUnitAction(unit, "attack")

    if not target or target.dead or target.camp == unit.camp then
        self:SetStatus(unit.name .. " 没有可攻击目标")
        return false
    end

    local damage, isCrit = self:CalculateDamage(unit, target, 1, {})
    local finalDamage = self:ApplyDamage(unit, target, damage, "普通攻击")
    self:SetStatus(unit.name .. " 普攻 " .. target.name .. " -" .. tostring(finalDamage) .. (isCrit and " 暴击" or ""))
    print(string.format("[Battle] %s attacks %s for %d", unit.id, target.id, finalDamage))
    return true
end

function GridBattleScene:AttackFrontCell(unit)
    local frontX, frontY = self:GetFrontCell(unit)
    local target = self:GetUnitAt(frontX, frontY)
    return self:AttackTarget(unit, target)
end

function GridBattleScene:KillUnit(unit, killer)
    if unit.dead then return end
    unit.dead = true
    unit.moving = false
    self.occupancy[GridKey(unit.gridX, unit.gridY)] = nil
    if unit.spriteWidget then
        unit.spriteWidget:SetBackgroundImage(unit.sprite)
    end
    if unit.widget then
        unit.widget:SetStyle({ opacity = 0.25 })
    end
    if killer and not killer.dead then
        self:TriggerPassive(killer, "kill", { caster = killer, target = unit })
    end
    self:SetStatus(unit.name .. " 被击败")
    print("[Battle] Unit defeated: " .. unit.id)
end

function GridBattleScene:UpdateUnitMove(unit, timeStep)
    local targetX, targetY = GridToPixel(unit.targetGridX, unit.targetGridY)
    local alpha = math.min(1, MOVE_SPEED * timeStep)
    unit.pixelX = unit.pixelX + (targetX - unit.pixelX) * alpha
    unit.pixelY = unit.pixelY + (targetY - unit.pixelY) * alpha

    if math.abs(unit.pixelX - targetX) < 0.5 and math.abs(unit.pixelY - targetY) < 0.5 then
        unit.pixelX = targetX
        unit.pixelY = targetY
        unit.gridX = unit.targetGridX
        unit.gridY = unit.targetGridY
        unit.moving = false
        self:SetUnitAction(unit, "idle")
    end

    self:ApplyUnitWidgetPosition(unit)
end

function GridBattleScene:ApplyUnitWidgetPosition(unit)
    if not unit.widget then return end
    unit.widget:SetStyle({
        left = unit.pixelX - UNIT_WIDTH * 0.5 + CELL_SIZE * 0.5,
        top = unit.pixelY - UNIT_HEIGHT + CELL_SIZE,
    })
end

function GridBattleScene:RefreshUnitWidgets(force)
    for _, unit in pairs(self.units) do
        if force or unit.moving then
            self:ApplyUnitWidgetPosition(unit)
        end
    end
end

function GridBattleScene:Destroy()
    self.root = nil
    self.gridLayer = nil
    self.unitLayer = nil
    self.statusLabel = nil
    self.cells = {}
    self.units = {}
    self.occupancy = {}
end

return GridBattleScene
