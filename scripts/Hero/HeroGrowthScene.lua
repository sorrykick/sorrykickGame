local UI = require("urhox-libs/UI")
local NormalizedSprite = require("UI.NormalizedSprite")
local SaveManager = require("Save.SaveManager")
local ConfigManager = require("Config.ConfigManager")
local QualityUtil = require("Config.QualityUtil")

local HeroGrowthScene = {}
HeroGrowthScene.__index = HeroGrowthScene

local DESIGN_WIDTH = 720
local DESIGN_HEIGHT = 1280
local HERO_IMAGE = "image/npcClip/0001/01.png"
local MAX_STAR = 6

local STAR_ICON_PATH = "image/品质/星级.png"

local ATTRIBUTE_DEFS = {
    { label = "生命", keys = { "hp", "MaxHP", "maxHp" } },
    { label = "攻击", keys = { "atk", "Att", "attack" } },
    { label = "防御", keys = { "def", "Def", "defense" } },
    { label = "移动", keys = { "moveSpeed", "Speed", "speed" } },
    { label = "暴击", keys = { "critRate" } },
    { label = "抗暴", keys = { "critResist" } },
    { label = "增伤", keys = { "dmgBonus" } },
    { label = "减伤", keys = { "dmgReduce" } },
    { label = "暴伤", keys = { "critDmgBonus" } },
}

local function FormatNumber(value)
    value = math.floor(tonumber(value) or 0)
    if value >= 100000000 then
        return string.format("%.1f亿", value / 100000000)
    end
    if value >= 10000 then
        return string.format("%.1f万", value / 10000)
    end
    return tostring(value)
end

local function ClampInt(value, minValue, maxValue)
    value = math.floor(tonumber(value) or minValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function GetSaveData()
    return SaveManager.GetSaveData() or {}
end

local function GetQuality(hero)
    return QualityUtil.GetRank(hero)
end

local function GetQualityColor(hero)
    return QualityUtil.GetColor(hero)
end

local function GetHeroPreviewImage(hero)
    if hero and hero.clipDir and hero.clipDir ~= "" then
        local path = tostring(hero.clipDir) .. "/01.png"
        if not cache or cache:Exists(path) then
            return path
        end
    end
    return HERO_IMAGE
end

local function GetHeroLevel(hero)
    return math.max(1, math.floor(tonumber(hero and hero.level) or 1))
end

local function GetHeroStar(hero)
    return ClampInt(hero and hero.star or 1, 1, MAX_STAR)
end

local function FindHeroById(heroes, heroId)
    if not heroId then return nil end
    for _, hero in ipairs(heroes or {}) do
        if tostring(hero.id) == tostring(heroId) then
            return hero
        end
    end
    return nil
end

local function GetNpcConfig(hero)
    if not hero then return nil end
    return ConfigManager.GetNpcConfig(hero.configId or hero.npcId or hero.id)
end

local function GetStarConfig(star)
    local tables = ConfigManager.GetTables()
    return tables.npcStarLimit and tables.npcStarLimit[tostring(star)] or {}
end

local function GetLevelLimit(hero)
    local star = GetHeroStar(hero)
    local starConfig = GetStarConfig(star)
    return math.max(1, math.floor(tonumber(starConfig.LevelLimit) or (star * 60)))
end

local function GetHeroStats(hero)
    if hero and type(hero.stats) == "table" then
        return hero.stats
    end
    local npcConfig = GetNpcConfig(hero)
    if npcConfig and type(npcConfig.stats) == "table" then
        return npcConfig.stats
    end
    return {}
end

local function GetRawStatValue(stats, keys)
    for _, key in ipairs(keys or {}) do
        local value = stats and stats[key] or nil
        if type(value) == "table" then
            value = value.Value or value.value
        end
        if value ~= nil then
            return value
        end
    end
    return 0
end

local function GetUpgradeCost(hero)
    return GetHeroLevel(hero) * 120 + GetHeroStar(hero) * 300
end

local function GetStarCost(hero)
    return GetHeroStar(hero) * 180 + GetQuality(hero) * 80
end

local function CreateStarBadge(star, layout)
    layout = type(layout) == "table" and layout or {}
    local starCount = GetHeroStar({ star = star })
    local starLabel = UI.Label { text = tostring(starCount), fontSize = 15, fontWeight = "bold", fontColor = { 255, 255, 255, 255 }, textStroke = { width = 1, color = { 68, 45, 25, 220 } }, textAlign = "center" }
    if layout.starLabelRef then
        layout.starLabelRef.label = starLabel
    end
    return UI.Panel {
        width = 86,
        height = 26,
        top = layout.top,
        flexDirection = "row",
        alignItems = "center",
        justifyContent = "center",
        gap = 4,
        backgroundColor = { 88, 46, 45, 210 },
        borderColor = { 255, 234, 0, 180 },
        borderWidth = 1,
        borderRadius = 13,
        children = {
            UI.Panel { width = 21, height = 21, backgroundImage = STAR_ICON_PATH, backgroundFit = "contain" },
            starLabel,
        },
    }
end

function HeroGrowthScene:new(options)
    local o = setmetatable({}, self)
    o.onExit = options and options.onExit or nil
    o.createTopResourceRow = options and options.createTopResourceRow or nil
    o.onRootChanged = options and options.onRootChanged or nil
    o.root = nil
    o.contentPanel = nil
    o.growthPanel = nil
    o.currentHeroLabel = nil
    o.heroCardRefs = nil
    o.selectedHeroId = options and options.selectedHeroId or nil
    o.statusText = "选择勇者后可进行升级、升星。"
    return o
end

function HeroGrowthScene:Destroy()
    self.root = nil
    self.contentPanel = nil
    self.growthPanel = nil
    self.currentHeroLabel = nil
    self.heroCardRefs = nil
end

function HeroGrowthScene:GetData()
    local saveData = GetSaveData()
    local heroes = type(saveData.heroes) == "table" and saveData.heroes or {}
    local selectedHero = FindHeroById(heroes, self.selectedHeroId)
    if not selectedHero and heroes[1] then
        selectedHero = heroes[1]
        self.selectedHeroId = selectedHero.id
    end
    return saveData, heroes, selectedHero
end

function HeroGrowthScene:SetStatus(text)
    self.statusText = text
end

function HeroGrowthScene:Refresh()
    self.root = self:CreateRoot()
    UI.SetRoot(self.root, true)
    if self.onRootChanged then
        self.onRootChanged(self.root)
    end
end

function HeroGrowthScene:RefreshHeroListState()
    if not self.heroCardRefs then return end
    local _, heroes = self:GetData()
    for _, hero in ipairs(heroes or {}) do
        local ref = self.heroCardRefs[tostring(hero.id)]
        if ref and ref.card then
            local selected = tostring(hero.id) == tostring(self.selectedHeroId)
            ref.card:SetStyle({
                backgroundColor = selected and { 255, 244, 205, 255 } or { 245, 228, 200, 255 },
                borderColor = selected and { 255, 234, 0, 255 } or GetQualityColor(hero),
                borderWidth = selected and 4 or 2,
            })
            if ref.levelLabel then
                ref.levelLabel:SetText("Lv." .. tostring(GetHeroLevel(hero)) .. " · " .. tostring(hero.job or hero.profession or "战士"))
            end
            if ref.powerLabel then
                ref.powerLabel:SetText("战力 " .. FormatNumber(hero.power))
            end
            if ref.starLabel then
                ref.starLabel:SetText(tostring(GetHeroStar(hero)))
            end
        end
    end
end

function HeroGrowthScene:RefreshDetail()
    if not self.root or not self.contentPanel or not self.growthPanel or not self.currentHeroLabel then
        self:Refresh()
        return
    end

    local _, _, selectedHero = self:GetData()
    self.growthPanel:Destroy()
    self.growthPanel = self:CreateGrowthPanel(selectedHero)
    self.contentPanel:AddChild(self.growthPanel)
    self.currentHeroLabel:SetText(selectedHero and ("当前培养：" .. tostring(selectedHero.name)) or "请选择一个勇者")
    self:RefreshHeroListState()
    if self.onRootChanged then
        self.onRootChanged(self.root)
    end
end

function HeroGrowthScene:SaveAndRefresh(reason, fields)
    SaveManager.MarkFieldsDirty(fields or { "heroes" })
    SaveManager.SaveGameSnapshot(reason, function()
        print("[HeroGrowth] Saved: " .. tostring(reason))
        self:RefreshDetail()
    end, function(errorMessage)
        print("[HeroGrowth] Save failed: " .. tostring(errorMessage))
        self:SetStatus("保存失败，请稍后重试。")
        self:RefreshDetail()
    end)
end

function HeroGrowthScene:SelectHero(heroId)
    self.selectedHeroId = heroId
    local _, _, hero = self:GetData()
    self:SetStatus(hero and ("已选择" .. tostring(hero.name) .. "。") or "请选择勇者。")
    self:RefreshDetail()
end

function HeroGrowthScene:UpgradeHero()
    local saveData, _, hero = self:GetData()
    if not hero then
        self:SetStatus("请先选择一个勇者。")
        self:RefreshDetail()
        return
    end

    local level = GetHeroLevel(hero)
    local limit = GetLevelLimit(hero)
    if level >= limit then
        self:SetStatus("当前星级等级上限为" .. tostring(limit) .. "，请先升星。")
        self:RefreshDetail()
        return
    end

    local cost = GetUpgradeCost(hero)
    if math.floor(tonumber(saveData.coin) or 0) < cost then
        self:SetStatus("金币不足，升级需要" .. FormatNumber(cost) .. "金币。")
        self:RefreshDetail()
        return
    end

    saveData.coin = math.max(0, math.floor(tonumber(saveData.coin) or 0) - cost)
    hero.level = level + 1
    hero.power = math.max(1, math.floor(tonumber(hero.power) or 1) + 35 + GetHeroStar(hero) * 8 + GetQuality(hero) * 12)
    self:SetStatus(hero.name .. "升级到 Lv." .. tostring(hero.level) .. "。")
    self:SaveAndRefresh("勇者升级", { "heroes", "coin" })
end

function HeroGrowthScene:StarUpHero()
    local saveData, _, hero = self:GetData()
    if not hero then
        self:SetStatus("请先选择一个勇者。")
        self:RefreshDetail()
        return
    end

    local star = GetHeroStar(hero)
    if star >= MAX_STAR then
        self:SetStatus("该勇者已经达到最高星级。")
        self:RefreshDetail()
        return
    end

    local cost = GetStarCost(hero)
    if math.floor(tonumber(saveData.crystal) or 0) < cost then
        self:SetStatus("白钻不足，升星需要" .. FormatNumber(cost) .. "白钻。")
        self:RefreshDetail()
        return
    end

    saveData.crystal = math.max(0, math.floor(tonumber(saveData.crystal) or 0) - cost)
    hero.star = star + 1
    hero.power = math.max(1, math.floor(tonumber(hero.power) or 1) + 240 + GetQuality(hero) * 45 + GetHeroLevel(hero) * 4)
    self:SetStatus(hero.name .. "升到" .. tostring(hero.star) .. "星，战力已提升。")
    self:SaveAndRefresh("勇者升星", { "heroes", "crystal" })
end

function HeroGrowthScene:CreateRoot()
    local saveData, heroes, selectedHero = self:GetData()
    local children = {}
    children[#children + 1] = self:CreateBackground()
    if self.createTopResourceRow then
        children[#children + 1] = UI.Panel {
            position = "absolute",
            top = 10,
            left = 12,
            right = 12,
            zIndex = 20,
            children = { self.createTopResourceRow() },
        }
    end
    local headerChildren = self:CreateHeader(saveData)
    for _, child in ipairs(headerChildren) do
        children[#children + 1] = child
    end
    children[#children + 1] = self:CreateContent(heroes, selectedHero)
    children[#children + 1] = self:CreateCurrentHeroLabel(selectedHero)

    self.root = UI.Panel {
        id = "heroGrowthScreen",
        width = DESIGN_WIDTH,
        height = DESIGN_HEIGHT,
        backgroundColor = { 42, 30, 24, 255 },
        overflow = "hidden",
        children = children,
    }
    return self.root
end

function HeroGrowthScene:CreateBackground()
    return UI.Panel {
        id = "background",
        width = DESIGN_WIDTH,
        height = DESIGN_HEIGHT,
        position = "absolute",
        left = 1,
        top = 1,
        right = 0,
        bottom = -252,
        zIndex = 0,
        backgroundImage = "image/page_background.png",
        backgroundFit = "none",
        backgroundColor = { 0, 0, 0, 255 },
        borderRadius = 0,
    }
end

function HeroGrowthScene:CreateHeader(saveData)
    return {
        UI.Label { text = "勇者养成", position = "absolute", left = 19, top = 66, zIndex = 10, fontSize = 30, fontWeight = "bold", fontColor = { 255, 235, 178, 255 }, textAlign = "center", textStroke = { width = 2, color = { 0, 0, 0, 220 } } },
        UI.Button { width = 164, height = 58, position = "absolute", left = 0, top = 1183, zIndex = 10, paddingTop = 0, paddingRight = 0, paddingBottom = 0, paddingLeft = 0, fontSize = 18, backgroundImage = "image/BT-返回.png", backgroundFit = "cover", backgroundColor = { 251, 251, 251, 0 }, opacity = 1, textColor = { 255, 255, 255, 0 }, borderRadius = 0, onClick = function() if self.onExit then self.onExit() end end },
    }
end

function HeroGrowthScene:CreateContent(heroes, selectedHero)
    self.growthPanel = self:CreateGrowthPanel(selectedHero)
    self.contentPanel = UI.Panel {
        position = "absolute",
        width = 678,
        left = 22,
        right = 20,
        top = 174,
        height = 975,
        flexDirection = "row",
        gap = 12,
        children = {
            self:CreateHeroList(heroes),
            self.growthPanel,
        },
    }
    return self.contentPanel
end

function HeroGrowthScene:CreateCurrentHeroLabel(selectedHero)
    self.currentHeroLabel = UI.Label {
        text = selectedHero and ("当前培养：" .. tostring(selectedHero.name)) or "请选择一个勇者",
        width = 330,
        height = 46,
        position = "absolute",
        left = 25,
        top = 124,
        zIndex = 10,
        fontSize = 18,
        fontColor = { 255, 235, 178, 255 },
        textStroke = { width = 2, color = { 0, 0, 0, 180 } },
        maxLines = 2,
    }
    return self.currentHeroLabel
end

function HeroGrowthScene:CreateHeroList(heroes)
    self.heroCardRefs = {}
    local cards = {}
    for _, hero in ipairs(heroes or {}) do
        cards[#cards + 1] = self:CreateHeroCard(hero)
    end
    return UI.Panel {
        width = 274,
        height = "100%",
        padding = 10,
        gap = 8,
        backgroundColor = { 113, 74, 58, 245 },
        borderColor = { 68, 45, 25, 255 },
        borderWidth = 3,
        borderRadius = 18,
        children = {
            UI.Label { text = "勇者列表", fontSize = 24, fontWeight = "bold", fontColor = { 255, 235, 178, 255 }, textAlign = "center", textStroke = { width = 2, color = { 0, 0, 0, 200 } } },
            UI.ScrollView {
                width = "100%",
                flexGrow = 1,
                flexBasis = 0,
                scrollY = true,
                showScrollbar = true,
                children = { UI.Panel { width = "100%", gap = 8, children = cards } },
            },
        },
    }
end

function HeroGrowthScene:CreateHeroCard(hero)
    local selected = hero and tostring(hero.id) == tostring(self.selectedHeroId)
    local levelLabel = UI.Label { text = "Lv." .. tostring(GetHeroLevel(hero)) .. " · " .. tostring(hero.job or hero.profession or "战士"), width = 150, position = "absolute", left = 91, top = 39, fontSize = 14, fontColor = { 74, 56, 42, 220 }, maxLines = 1 }
    local powerLabel = UI.Label { text = "战力 " .. FormatNumber(hero.power), width = 150, position = "absolute", left = 91, top = 68, fontSize = 14, fontWeight = "bold", fontColor = { 202, 92, 44, 255 }, maxLines = 1 }
    local starLabelRef = {}
    local card = UI.Panel {
        width = "100%",
        height = 108,
        padding = 8,
        overflow = "hidden",
        backgroundColor = selected and { 255, 244, 205, 255 } or { 245, 228, 200, 255 },
        borderColor = selected and { 255, 234, 0, 255 } or GetQualityColor(hero),
        borderWidth = selected and 4 or 2,
        borderRadius = 14,
        onClick = function()
            self:SelectHero(hero.id)
        end,
        children = {
            UI.Panel { width = 78, height = 92, position = "absolute", left = 6, top = 7, backgroundColor = { 207, 166, 119, 170 }, borderColor = { 68, 45, 25, 180 }, borderWidth = 1, borderRadius = 12 },
            NormalizedSprite { width = 96, height = 96, position = "absolute", left = -3, top = 4, backgroundImage = GetHeroPreviewImage(hero), imageTint = { 255, 255, 255, 255 } },
            UI.Panel { width = 28, height = 28, position = "absolute", left = 9, top = 4, backgroundImage = QualityUtil.GetIconPath(hero), backgroundFit = "contain" },
            UI.Label { text = hero.name, width = 150, position = "absolute", left = 91, top = 10, fontSize = 17, fontWeight = "bold", fontColor = { 88, 46, 45, 255 }, maxLines = 1 },
            levelLabel,
            powerLabel,
            UI.Panel { position = "absolute", left = 10, top = 78, children = { CreateStarBadge(hero.star, { starLabelRef = starLabelRef }) } },
        },
    }
    if self.heroCardRefs and hero then
        self.heroCardRefs[tostring(hero.id)] = {
            card = card,
            levelLabel = levelLabel,
            powerLabel = powerLabel,
            starLabel = starLabelRef.label,
        }
    end
    return card
end

function HeroGrowthScene:CreateGrowthPanel(hero)
    return UI.Panel {
        flexGrow = 1,
        flexShrink = 1,
        height = "100%",
        padding = 12,
        gap = 10,
        backgroundColor = { 245, 228, 200, 245 },
        borderColor = { 68, 45, 25, 255 },
        borderWidth = 3,
        borderRadius = 18,
        children = hero and {
            self:CreateHeroOverview(hero),
            self:CreateAttributePanel(hero),
            self:CreateUpgradePanel(hero),
            self:CreateStarPanel(hero),
            UI.Label { text = self.statusText, flexGrow = 1, flexBasis = 0, top = 4, fontSize = 17, fontColor = { 88, 46, 45, 255 }, textAlign = "left", verticalAlign = "top", maxLines = 3 },
        } or {
            UI.Label { text = "暂无勇者", fontSize = 24, fontWeight = "bold", fontColor = { 88, 46, 45, 255 }, textAlign = "center" },
        },
    }
end

function HeroGrowthScene:CreateHeroOverview(hero)
    local quality = GetQuality(hero)
    return UI.Panel {
        width = "100%",
        height = 206,
        backgroundColor = { 255, 244, 220, 255 },
        borderColor = GetQualityColor(hero),
        borderWidth = 3,
        borderRadius = 18,
        overflow = "hidden",
        children = {
            UI.Panel { width = 156, height = 188, position = "absolute", left = 12, top = 18, backgroundColor = { 207, 166, 119, 170 }, borderColor = { 68, 45, 25, 180 }, borderWidth = 1, borderRadius = 16 },
            NormalizedSprite { width = 188, height = 188, position = "absolute", left = -3, top = 18, backgroundImage = GetHeroPreviewImage(hero) },
            UI.Panel { width = 34, height = 34, position = "absolute", left = 17, top = 20, backgroundImage = QualityUtil.GetIconPath(quality), backgroundFit = "contain" },
            UI.Label { text = hero.name, position = "absolute", left = 182, top = 18, width = 179, fontSize = 25, fontWeight = "bold", fontColor = { 88, 46, 45, 255 }, maxLines = 1 },
            UI.Label { text = tostring(hero.job or hero.profession or "战士") .. " · " .. tostring(hero.faction or "王国"), position = "absolute", left = 182, top = 60, width = 180, fontSize = 14, fontWeight = "bold", fontColor = GetQualityColor(hero), textStroke = { width = 1, color = { 68, 45, 25, 160 } }, maxLines = 1 },
            UI.Panel { position = "absolute", left = 182, top = 88, children = { CreateStarBadge(hero.star, { top = 4 }) } },
            self:CreateStatRow("等级", "Lv." .. tostring(GetHeroLevel(hero)) .. "/" .. tostring(GetLevelLimit(hero)), 182, 122, 181),
            self:CreateStatRow("战力", FormatNumber(hero.power), 182, 152, 182),
            self:CreateStatRow("定位", tostring(hero.role or "前排"), 182, 180, 183),
        },
    }
end

function HeroGrowthScene:CreateStatRow(label, value, left, top, width)
    return UI.Panel {
        position = "absolute",
        left = left,
        top = top,
        width = width or 190,
        height = 26,
        flexDirection = "row",
        alignItems = "center",
        backgroundColor = { 207, 166, 119, 180 },
        borderRadius = 9,
        paddingLeft = 8,
        paddingRight = 8,
        children = {
            UI.Label { text = label, flexGrow = 1, fontSize = 15, fontColor = { 88, 46, 45, 255 } },
            UI.Label { text = value, fontSize = 15, fontWeight = "bold", fontColor = { 255, 255, 255, 255 }, textStroke = { width = 1, color = { 68, 45, 25, 220 } }, textAlign = "right" },
        },
    }
end

function HeroGrowthScene:CreateAttributePanel(hero)
    local stats = GetHeroStats(hero)
    local rows = {}
    for _, attr in ipairs(ATTRIBUTE_DEFS) do
        rows[#rows + 1] = self:CreateAttributeRow(attr.label, GetRawStatValue(stats, attr.keys))
    end
    return UI.Panel {
        width = "100%",
        height = 158,
        padding = 8,
        gap = 6,
        backgroundColor = { 113, 74, 58, 230 },
        borderColor = { 68, 45, 25, 255 },
        borderWidth = 2,
        borderRadius = 16,
        children = {
            UI.Label { text = "具体属性", fontSize = 19, fontWeight = "bold", fontColor = { 255, 235, 178, 255 }, textStroke = { width = 2, color = { 0, 0, 0, 180 } } },
            UI.Panel { width = "100%", flexGrow = 1, flexBasis = 0, flexDirection = "row", flexWrap = "wrap", gap = 5, children = rows },
        },
    }
end

function HeroGrowthScene:CreateAttributeRow(label, value)
    return UI.Panel {
        width = 86,
        height = 28,
        flexDirection = "row",
        alignItems = "center",
        paddingLeft = 6,
        paddingRight = 6,
        backgroundColor = { 245, 228, 200, 240 },
        borderRadius = 9,
        children = {
            UI.Label { text = label, flexGrow = 1, flexShrink = 1, fontSize = 13, fontColor = { 88, 46, 45, 255 }, maxLines = 1 },
            UI.Label { text = FormatNumber(value), width = 38, fontSize = 13, fontWeight = "bold", fontColor = { 202, 92, 44, 255 }, textAlign = "right", maxLines = 1 },
        },
    }
end

function HeroGrowthScene:CreateUpgradePanel(hero)
    local cost = GetUpgradeCost(hero)
    local level = GetHeroLevel(hero)
    local limit = GetLevelLimit(hero)
    return self:CreateActionPanel("勇者升级", "提升等级并增加基础战力。当前上限 Lv." .. tostring(limit), "升级", "消耗金币 " .. FormatNumber(cost), level < limit, function()
        self:UpgradeHero()
    end, {
        height = 100,
        padding = 2,
        descHeight = 34,
        descWhiteSpace = "normal",
        descVerticalAlign = "top",
        descMaxLines = 2,
        costTop = 73,
        buttonTop = 28,
    })
end

function HeroGrowthScene:CreateStarPanel(hero)
    local cost = GetStarCost(hero)
    local star = GetHeroStar(hero)
    return self:CreateActionPanel("勇者升星", "提升星级，增加大量战力并提高成长上限。", "升星", "消耗白钻 " .. FormatNumber(cost), star < MAX_STAR, function()
        self:StarUpHero()
    end, {
        height = 100,
        padding = 2,
        descHeight = 34,
        descMaxLines = 2,
        descWhiteSpace = "normal",
        descWordBreak = "normal",
        costTop = 73,
        buttonTop = 28,
    })
end

function HeroGrowthScene:CreateActionPanel(title, desc, buttonText, costText, enabled, onClick, layout)
    layout = type(layout) == "table" and layout or {}
    local padding = layout.padding or 10
    return UI.Panel {
        width = "100%",
        height = layout.height or 102,
        padding = padding,
        backgroundColor = { 113, 74, 58, 230 },
        borderColor = { 68, 45, 25, 255 },
        borderWidth = 2,
        borderRadius = 16,
        children = {
            UI.Label { text = title, position = "absolute", left = 12, top = 8, width = 160, fontSize = 20, fontWeight = "bold", fontColor = { 255, 235, 178, 255 }, textStroke = { width = 2, color = { 0, 0, 0, 180 } } },
            UI.Label { text = desc, position = "absolute", left = 12, top = 40, width = 230, height = layout.descHeight, fontSize = 14, fontColor = { 255, 244, 220, 230 }, verticalAlign = layout.descVerticalAlign, whiteSpace = layout.descWhiteSpace, wordBreak = layout.descWordBreak, maxLines = layout.descMaxLines or 2 },
            UI.Label { text = costText, position = "absolute", left = 12, top = layout.costTop or 76, width = 220, fontSize = 15, fontWeight = "bold", fontColor = { 255, 234, 0, 255 }, textStroke = { width = 1, color = { 0, 0, 0, 200 } }, maxLines = 1 },
            UI.Button { text = buttonText, position = "absolute", right = 12, top = layout.buttonTop or 31, width = 90, height = 42, fontSize = 18, fontWeight = "bold", backgroundColor = enabled and { 202, 92, 44, 255 } or { 117, 79, 62, 180 }, pressedBackgroundColor = { 155, 62, 36, 255 }, textColor = { 255, 244, 220, 255 }, borderRadius = 16, onClick = onClick },
        },
    }
end

return HeroGrowthScene
