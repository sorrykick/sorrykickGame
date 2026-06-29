local UI = require("urhox-libs/UI")

local GridBattleScene = {}
GridBattleScene.__index = GridBattleScene

local GRID_COLS = 30
local GRID_ROWS = 30
local CELL_SIZE = 18
local GRID_SIZE = GRID_COLS * CELL_SIZE
local GRID_LEFT = 90
local GRID_TOP = 245
local MOVE_SPEED = 10

local UNIT_DEFS = {
    hero = { name = "勇者1", camp = "hero", color = { 88, 190, 255, 255 }, border = { 225, 250, 255, 255 }, hp = 120 },
    enemy = { name = "森林守卫", camp = "enemy", color = { 226, 84, 72, 255 }, border = { 255, 226, 210, 255 }, hp = 80 },
}

local function ClampGrid(value, maxValue)
    return math.max(1, math.min(maxValue, value))
end

local function GridKey(x, y)
    return tostring(x) .. ":" .. tostring(y)
end

local function GridToPixel(x, y)
    return GRID_LEFT + (x - 1) * CELL_SIZE, GRID_TOP + (y - 1) * CELL_SIZE
end

local function CreateCellColor(x, y)
    local checker = (x + y) % 2 == 0
    if checker then
        return { 46, 70, 58, 228 }
    end
    return { 36, 58, 50, 228 }
end

local function CreateUnit(def, id, gridX, gridY)
    return {
        id = id,
        name = def.name,
        camp = def.camp,
        color = def.color,
        border = def.border,
        hp = def.hp,
        maxHp = def.hp,
        gridX = gridX,
        gridY = gridY,
        targetGridX = gridX,
        targetGridY = gridY,
        pixelX = 0,
        pixelY = 0,
        widget = nil,
        label = nil,
        moving = false,
    }
end

function GridBattleScene:new(options)
    local o = setmetatable({}, self)
    o.onExit = options and options.onExit or nil
    o.root = nil
    o.gridLayer = nil
    o.unitLayer = nil
    o.statusLabel = nil
    o.selectedUnitId = "hero1"
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
        text = "战场 30×30：点击空格移动勇者1",
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
    print("[Battle] Grid battle scene created: 30x30")
    return self.root
end

function GridBattleScene:CreateBattleData()
    self.cells = {}
    self.units = {}
    self.occupancy = {}

    local hero = CreateUnit(UNIT_DEFS.hero, "hero1", 5, 16)
    local enemyA = CreateUnit(UNIT_DEFS.enemy, "enemy1", 24, 12)
    local enemyB = CreateUnit(UNIT_DEFS.enemy, "enemy2", 20, 21)

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
        backgroundGradient = {
            direction = "vertical",
            colors = {
                { 31, 51, 57, 255 },
                { 19, 28, 31, 255 },
            },
        },
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
                text = "规则：每个单位占 1 个格子；移动目标必须在 30×30 战场内，且不能被其他单位占用。",
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
        left = 32,
        right = 32,
        bottom = 38,
        height = 170,
        padding = 18,
        gap = 12,
        backgroundColor = { 16, 18, 20, 222 },
        borderColor = { 100, 150, 130, 180 },
        borderWidth = 2,
        borderRadius = 18,
        children = {
            UI.Label {
                text = "调试操作",
                fontSize = 24,
                fontWeight = "bold",
                fontColor = { 255, 242, 205, 255 },
            },
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                justifyContent = "space-between",
                children = {
                    self:CreateMoveButton("上", 0, -1),
                    self:CreateMoveButton("下", 0, 1),
                    self:CreateMoveButton("左", -1, 0),
                    self:CreateMoveButton("右", 1, 0),
                },
            },
            UI.Label {
                text = "后续可把此网格管理器接入技能范围、寻路、AI 和战斗回合。",
                fontSize = 18,
                fontColor = { 185, 214, 205, 220 },
            },
        },
    }
end

function GridBattleScene:CreateMoveButton(text, dx, dy)
    return UI.Button {
        text = text,
        width = 124,
        height = 52,
        fontSize = 22,
        backgroundColor = { 40, 92, 76, 255 },
        pressedBackgroundColor = { 28, 64, 54, 255 },
        textColor = { 245, 255, 236, 255 },
        borderRadius = 18,
        onClick = function()
            local unit = self.units[self.selectedUnitId]
            if unit then
                self:RequestMoveUnit(unit.id, unit.targetGridX + dx, unit.targetGridY + dy)
            end
        end,
    }
end

function GridBattleScene:CreateGridCells()
    local children = {}
    for y = 1, GRID_ROWS do
        for x = 1, GRID_COLS do
            local cellX, cellY = x, y
            children[#children + 1] = UI.Panel {
                width = CELL_SIZE,
                height = CELL_SIZE,
                backgroundColor = CreateCellColor(cellX, cellY),
                borderColor = { 92, 122, 104, 82 },
                borderWidth = 1,
                onClick = function()
                    self:RequestMoveUnit(self.selectedUnitId, cellX, cellY)
                end,
            }
        end
    end
    return children
end

function GridBattleScene:CreateUnitWidgets()
    local children = {}
    for _, unit in pairs(self.units) do
        unit.widget = UI.Panel {
            position = "absolute",
            left = unit.pixelX - 5,
            top = unit.pixelY - 21,
            width = CELL_SIZE + 10,
            height = CELL_SIZE + 22,
            alignItems = "center",
            justifyContent = "flex-end",
            pointerEvents = "box-none",
            children = {
                UI.Panel {
                    width = CELL_SIZE + 8,
                    height = CELL_SIZE + 8,
                    backgroundColor = unit.color,
                    borderColor = unit.border,
                    borderWidth = 2,
                    borderRadius = 14,
                },
                UI.Label {
                    text = unit.camp == "hero" and "勇" or "敌",
                    position = "absolute",
                    left = 0,
                    right = 0,
                    bottom = 3,
                    fontSize = 15,
                    fontWeight = "bold",
                    fontColor = { 20, 24, 28, 255 },
                    textAlign = "center",
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

function GridBattleScene:RequestMoveUnit(unitId, x, y)
    local unit = self.units[unitId]
    if not unit then return false end

    x = ClampGrid(x, GRID_COLS)
    y = ClampGrid(y, GRID_ROWS)

    if not self:IsInsideGrid(x, y) then
        self:SetStatus("目标越界")
        return false
    end

    if self:IsOccupied(x, y, unitId) then
        self:SetStatus("格子 (" .. x .. ", " .. y .. ") 已被占用")
        return false
    end

    self.occupancy[GridKey(unit.gridX, unit.gridY)] = nil
    unit.targetGridX = x
    unit.targetGridY = y
    unit.moving = true
    self.occupancy[GridKey(x, y)] = unit.id
    self:SetStatus(unit.name .. " 移动到格子 (" .. x .. ", " .. y .. ")")
    print(string.format("[Battle] Move %s to (%d,%d)", unit.id, x, y))
    return true
end

function GridBattleScene:SetStatus(text)
    if self.statusLabel then
        self.statusLabel:SetText(text)
    end
end

function GridBattleScene:Update(timeStep)
    for _, unit in pairs(self.units) do
        if unit.moving then
            self:UpdateUnitMove(unit, timeStep)
        end
    end
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
    end

    self:ApplyUnitWidgetPosition(unit)
end

function GridBattleScene:ApplyUnitWidgetPosition(unit)
    if not unit.widget then return end
    unit.widget:SetStyle({
        left = unit.pixelX - 5,
        top = unit.pixelY - 21,
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
