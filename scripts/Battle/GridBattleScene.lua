local UI = require("urhox-libs/UI")
local ImageCache = require("urhox-libs/UI/Core/ImageCache")

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

local DIRECTIONS = {
    { x = 1, y = 0 },
    { x = -1, y = 0 },
    { x = 0, y = 1 },
    { x = 0, y = -1 },
}

local function GridKey(x, y)
    return tostring(x) .. ":" .. tostring(y)
end

local function GridToPixel(x, y)
    return GRID_LEFT + (x - 1) * CELL_SIZE, GRID_TOP + (y - 1) * CELL_SIZE
end

local function GridDistance(a, b)
    return math.abs(a.gridX - b.gridX) + math.abs(a.gridY - b.gridY)
end

local function GetNpcClipFramePath(frameNumber)
    return string.format("image/npcClip/1/%02d.png", frameNumber)
end

local function GetActionDef(action)
    if action == "move" then
        return MOVE_FRAMES, MOVE_FPS, true
    end
    if action == "attack" then
        return ATTACK_FRAMES, ATTACK_FPS, false
    end
    return IDLE_FRAMES, IDLE_FPS, true
end

local function Sign(value)
    if value > 0 then return 1 end
    if value < 0 then return -1 end
    return 0
end

local function CreateCellColor(x, y)
    local checker = (x + y) % 2 == 0
    if checker then
        return { 46, 70, 58, 228 }
    end
    return { 36, 58, 50, 228 }
end

local UnitSprite = UI.Panel:Extend("UnitSprite")

function UnitSprite:Init(props)
    ---@diagnostic disable-next-line: param-type-mismatch
    UI.Panel.Init(self, props)
end

function UnitSprite:Render(nvg)
    local props = self.props
    local imagePath = props.backgroundImage
    if not imagePath or imagePath == "" then return end

    local l = self:GetAbsoluteLayout()
    local imgHandle = ImageCache.Get(imagePath)
    if not imgHandle or imgHandle <= 0 then return end

    local imgW, imgH = ImageCache.GetSize(imagePath)
    if imgW <= 0 or imgH <= 0 then return end

    local drawX, drawY, drawW, drawH = l.x, l.y, l.w, l.h
    local imgRatio = imgW / imgH
    local boxRatio = l.w / l.h
    if imgRatio > boxRatio then
        drawW = l.w
        drawH = l.w / imgRatio
        drawX = l.x
        drawY = l.y + (l.h - drawH) / 2
    else
        drawH = l.h
        drawW = l.h * imgRatio
        drawX = l.x + (l.w - drawW) / 2
        drawY = l.y
    end

    local tint = props.imageTint
    local paint
    if props.flipX then
        nvgSave(nvg)
        nvgTranslate(nvg, drawX + drawW * 0.5, drawY + drawH * 0.5)
        nvgScale(nvg, -1, 1)
        nvgTranslate(nvg, -(drawX + drawW * 0.5), -(drawY + drawH * 0.5))
    end
    if tint then
        paint = nvgImagePatternTinted(nvg, drawX, drawY, drawW, drawH, 0, imgHandle, nvgRGBA(tint[1], tint[2], tint[3], tint[4] or 255))
    else
        paint = nvgImagePattern(nvg, drawX, drawY, drawW, drawH, 0, imgHandle, 1)
    end

    nvgBeginPath(nvg)
    nvgRect(nvg, l.x, l.y, l.w, l.h)
    nvgFillPaint(nvg, paint)
    nvgFill(nvg)
    if props.flipX then
        nvgRestore(nvg)
    end
end

local function CreateUnit(def, id, gridX, gridY)
    return {
        id = id,
        name = def.name,
        camp = def.camp,
        color = def.color,
        border = def.border,
        sprite = GetNpcClipFramePath(IDLE_FRAMES[1]),
        tint = def.tint,
        flipX = def.flipX == true,
        action = "idle",
        actionFrameIndex = 1,
        actionFrameTimer = 0,
        actionLoop = true,
        hp = def.hp,
        maxHp = def.hp,
        damage = def.damage,
        attackInterval = def.attackInterval,
        attackTimer = 0,
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
    o.units = {}
    o.occupancy = {}
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
        text = "战场 20×20：双方单位自动寻敌，攻击身前 1 格",
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
    print("[Battle] Auto grid battle scene created: 20x20")
    return self.root
end

function GridBattleScene:CreateBattleData()
    self.cells = {}
    self.units = {}
    self.occupancy = {}
    self.battleTime = 0
    self.aiTimer = 0

    local hero = CreateUnit(UNIT_DEFS.hero, "hero1", 4, 11)
    local enemyA = CreateUnit(UNIT_DEFS.enemy, "enemy1", 17, 8)
    local enemyB = CreateUnit(UNIT_DEFS.enemy, "enemy2", 16, 15)

    self.units[hero.id] = hero
    self.units[enemyA.id] = enemyA
    self.units[enemyB.id] = enemyB

    for _, unit in pairs(self.units) do
        local px, py = GridToPixel(unit.gridX, unit.gridY)
        unit.pixelX = px
        unit.pixelY = py
        self.occupancy[GridKey(unit.gridX, unit.gridY)] = unit.id
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
        backgroundImage = "image/BattleRes/1.png",
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
                        text = "秘境战斗",
                        fontSize = 34,
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
                text = "规则：双方单位自动行动；每个单位占 1 格；只有敌人在身前 1 格时才会攻击。",
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
                text = "双方都会选择最近敌对单位，优先调整面向；目标不在身前 1 格时按格子靠近。",
                fontSize = 19,
                fontColor = { 225, 242, 226, 235 },
                flexShrink = 1,
            },
            UI.Label {
                text = "下一步可接入技能范围、寻路权重、敌方 AI 与战斗结算存档。",
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
            left = -10,
            right = -10,
            top = 0,
            fontSize = 13,
            fontColor = { 255, 248, 220, 255 },
            textAlign = "center",
            textStroke = { width = 1, color = { 0, 0, 0, 220 } },
        }
        unit.spriteWidget = UnitSprite {
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

function GridBattleScene:SetFacingToTarget(unit, target)
    local dx = target.gridX - unit.gridX
    local dy = target.gridY - unit.gridY
    if math.abs(dx) >= math.abs(dy) and dx ~= 0 then
        unit.facingX = Sign(dx)
        unit.facingY = 0
    elseif dy ~= 0 then
        unit.facingX = 0
        unit.facingY = Sign(dy)
    end
end

function GridBattleScene:GetFrontCell(unit)
    return unit.gridX + unit.facingX, unit.gridY + unit.facingY
end

function GridBattleScene:IsTargetInFront(unit, target)
    local frontX, frontY = self:GetFrontCell(unit)
    return target.gridX == frontX and target.gridY == frontY
end

function GridBattleScene:FindNearestEnemy(unit)
    local nearest = nil
    local nearestDistance = 99999
    for _, candidate in pairs(self.units) do
        if not candidate.dead and candidate.camp ~= unit.camp then
            local distance = GridDistance(unit, candidate)
            if distance < nearestDistance then
                nearest = candidate
                nearestDistance = distance
            end
        end
    end
    return nearest
end

function GridBattleScene:ChooseStepToward(unit, target)
    local candidates = {}
    local dx = Sign(target.gridX - unit.gridX)
    local dy = Sign(target.gridY - unit.gridY)

    if math.abs(target.gridX - unit.gridX) >= math.abs(target.gridY - unit.gridY) then
        candidates[#candidates + 1] = { x = dx, y = 0 }
        candidates[#candidates + 1] = { x = 0, y = dy }
    else
        candidates[#candidates + 1] = { x = 0, y = dy }
        candidates[#candidates + 1] = { x = dx, y = 0 }
    end

    for _, dir in ipairs(DIRECTIONS) do
        candidates[#candidates + 1] = dir
    end

    for _, dir in ipairs(candidates) do
        if dir.x ~= 0 or dir.y ~= 0 then
            local nextX = unit.gridX + dir.x
            local nextY = unit.gridY + dir.y
            if self:IsInsideGrid(nextX, nextY) and not self:IsOccupied(nextX, nextY, unit.id) then
                local currentDistance = GridDistance(unit, target)
                local nextDistance = math.abs(nextX - target.gridX) + math.abs(nextY - target.gridY)
                if nextDistance < currentDistance then
                    return nextX, nextY, dir.x, dir.y
                end
            end
        end
    end

    return nil, nil, 0, 0
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
        unit.spriteWidget:SetBackgroundImage(GetNpcClipFramePath(frames[1]))
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

    unit.spriteWidget:SetBackgroundImage(GetNpcClipFramePath(frames[unit.actionFrameIndex]))
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
    self:SetUnitAction(unit, "move")
    self.occupancy[GridKey(x, y)] = unit.id
    print(string.format("[Battle] Move %s to (%d,%d)", unit.id, x, y))
    return true
end

function GridBattleScene:SetStatus(text)
    if self.statusLabel then
        self.statusLabel:SetText(text)
    end
end

function GridBattleScene:Update(timeStep)
    self.battleTime = self.battleTime + timeStep

    for _, unit in pairs(self.units) do
        if not unit.dead then
            unit.attackTimer = math.max(0, unit.attackTimer - timeStep)
            self:UpdateUnitActionAnimation(unit, timeStep)
            if unit.moving then
                self:UpdateUnitMove(unit, timeStep)
            end
        end
    end

    self.aiTimer = self.aiTimer + timeStep
    if self.aiTimer >= AI_TICK_INTERVAL then
        self.aiTimer = 0
        self:UpdateAutoBattle()
    end
end

function GridBattleScene:UpdateAutoBattle()
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

function GridBattleScene:UpdateUnitAI(unit)
    local target = self:FindNearestEnemy(unit)
    if not target then
        if unit.camp == "hero" then
            self:SetStatus("战斗胜利：敌方已清除")
        elseif not self:HasLivingCamp("hero") then
            self:SetStatus("战斗失败：勇者已被击败")
        end
        return
    end

    self:SetFacingToTarget(unit, target)

    if self:IsTargetInFront(unit, target) then
        if unit.attackTimer <= 0 then
            self:AttackFrontCell(unit)
        end
        return
    end

    local nextX, nextY, faceX, faceY = self:ChooseStepToward(unit, target)
    if nextX and nextY then
        unit.facingX = faceX
        unit.facingY = faceY
        self:RequestMoveUnit(unit.id, nextX, nextY)
        self:SetStatus(unit.name .. " 自动靠近 " .. target.name)
    else
        self:SetStatus(unit.name .. " 正在寻找可移动格子")
    end
end

function GridBattleScene:AttackFrontCell(unit)
    local frontX, frontY = self:GetFrontCell(unit)
    local target = self:GetUnitAt(frontX, frontY)
    unit.attackTimer = unit.attackInterval
    self:SetUnitAction(unit, "attack")

    if not target or target.dead or target.camp == unit.camp then
        self:SetStatus(unit.name .. " 身前无敌方")
        return false
    end

    target.hp = math.max(0, target.hp - unit.damage)
    self:SetStatus(unit.name .. " 攻击身前1格，" .. target.name .. " -" .. tostring(unit.damage))
    print(string.format("[Battle] %s attacks %s for %d", unit.id, target.id, unit.damage))

    if target.hpLabel then
        target.hpLabel:SetText(tostring(target.hp))
    end

    if target.hp <= 0 then
        self:KillUnit(target)
    end

    return true
end

function GridBattleScene:KillUnit(unit)
    unit.dead = true
    unit.moving = false
    self.occupancy[GridKey(unit.gridX, unit.gridY)] = nil
    if unit.spriteWidget then
        unit.spriteWidget:SetBackgroundImage(unit.sprite)
    end
    if unit.widget then
        unit.widget:SetStyle({ opacity = 0.25 })
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
