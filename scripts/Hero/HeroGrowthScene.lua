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

local function GetHeroSkills(hero)
    if not hero then return {} end
    hero.skills = type(hero.skills) == "table" and hero.skills or {}
    return hero.skills
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

local function GetOpenSkillNum(hero)
    local starConfig = GetStarConfig(GetHeroStar(hero))
    return math.max(0, math.floor(tonumber(starConfig.OpenSkillNum) or 0))
end

local function GetSkillCandidates(hero)
    local npcConfig = GetNpcConfig(hero)
    if npcConfig and type(npcConfig.Skill) == "table" then
        return npcConfig.Skill
    end
    return {}
end

local function GetSkillName(skillId)
    if not skillId then return "未学习" end
    local tables = ConfigManager.GetTables()
    local skill = tables.skill and tables.skill[tostring(skillId)] or nil
    if skill and skill.name then
        return tostring(skill.name)
    end
    return "技能" .. tostring(skillId)
end

local function GetUpgradeCost(hero)
    return GetHeroLevel(hero) * 120 + GetHeroStar(hero) * 300
end

local function GetStarCost(hero)
    return GetHeroStar(hero) * 180 + GetQuality(hero) * 80
end

local function GetSkillCost(hero)
    return (#GetHeroSkills(hero) + 1) * 80
end

local function CreateStarBadge(star)
    local starCount = GetHeroStar({ star = star })
    return UI.Panel {
        width = 86,
        height = 26,
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
            UI.Label { text = tostring(starCount), fontSize = 15, fontWeight = "bold", fontColor = { 255, 255, 255, 255 }, textStroke = { width = 1, color = { 68, 45, 25, 220 } }, textAlign = "center" },
        },
    }
end

function HeroGrowthScene:new(options)
    local o = setmetatable({}, self)
    o.onExit = options and options.onExit or nil
    o.createTopResourceRow = options and options.createTopResourceRow or nil
    o.onRootChanged = options and options.onRootChanged or nil
    o.root = nil
    o.selectedHeroId = options and options.selectedHeroId or nil
    o.statusText = "选择勇者后可进行升级、升星和学习技能。"
    return o
end

function HeroGrowthScene:Destroy()
    self.root = nil
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

function HeroGrowthScene:SaveAndRefresh(reason, fields)
    SaveManager.MarkFieldsDirty(fields or { "heroes" })
    SaveManager.SaveGameSnapshot(reason, function()
        print("[HeroGrowth] Saved: " .. tostring(reason))
        self:Refresh()
    end, function(errorMessage)
        print("[HeroGrowth] Save failed: " .. tostring(errorMessage))
        self:SetStatus("保存失败，请稍后重试。")
        self:Refresh()
    end)
end

function HeroGrowthScene:SelectHero(heroId)
    self.selectedHeroId = heroId
    local _, _, hero = self:GetData()
    self:SetStatus(hero and ("已选择" .. tostring(hero.name) .. "。") or "请选择勇者。")
    self:Refresh()
end

function HeroGrowthScene:UpgradeHero()
    local saveData, _, hero = self:GetData()
    if not hero then
        self:SetStatus("请先选择一个勇者。")
        self:Refresh()
        return
    end

    local level = GetHeroLevel(hero)
    local limit = GetLevelLimit(hero)
    if level >= limit then
        self:SetStatus("当前星级等级上限为" .. tostring(limit) .. "，请先升星。")
        self:Refresh()
        return
    end

    local cost = GetUpgradeCost(hero)
    if math.floor(tonumber(saveData.coin) or 0) < cost then
        self:SetStatus("金币不足，升级需要" .. FormatNumber(cost) .. "金币。")
        self:Refresh()
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
        self:Refresh()
        return
    end

    local star = GetHeroStar(hero)
    if star >= MAX_STAR then
        self:SetStatus("该勇者已经达到最高星级。")
        self:Refresh()
        return
    end

    local cost = GetStarCost(hero)
    if math.floor(tonumber(saveData.crystal) or 0) < cost then
        self:SetStatus("白钻不足，升星需要" .. FormatNumber(cost) .. "白钻。")
        self:Refresh()
        return
    end

    saveData.crystal = math.max(0, math.floor(tonumber(saveData.crystal) or 0) - cost)
    hero.star = star + 1
    hero.power = math.max(1, math.floor(tonumber(hero.power) or 1) + 240 + GetQuality(hero) * 45 + GetHeroLevel(hero) * 4)
    self:SetStatus(hero.name .. "升到" .. tostring(hero.star) .. "星，技能槽同步扩展。")
    self:SaveAndRefresh("勇者升星", { "heroes", "crystal" })
end

function HeroGrowthScene:LearnSkill()
    local saveData, _, hero = self:GetData()
    if not hero then
        self:SetStatus("请先选择一个勇者。")
        self:Refresh()
        return
    end

    local skills = GetHeroSkills(hero)
    local openSkillNum = GetOpenSkillNum(hero)
    if #skills >= openSkillNum then
        self:SetStatus("当前星级可学习技能槽已满，请先升星。")
        self:Refresh()
        return
    end

    local candidates = GetSkillCandidates(hero)
    local nextSkill = candidates[#skills + 1]
    if not nextSkill then
        self:SetStatus("该勇者暂无可学习技能。")
        self:Refresh()
        return
    end

    local cost = GetSkillCost(hero)
    if math.floor(tonumber(saveData.diamond) or 0) < cost then
        self:SetStatus("蓝钻不足，学习技能需要" .. FormatNumber(cost) .. "蓝钻。")
        self:Refresh()
        return
    end

    saveData.diamond = math.max(0, math.floor(tonumber(saveData.diamond) or 0) - cost)
    skills[#skills + 1] = nextSkill
    hero.power = math.max(1, math.floor(tonumber(hero.power) or 1) + 120 + GetQuality(hero) * 20)
    self:SetStatus(hero.name .. "学会" .. GetSkillName(nextSkill) .. "。")
    self:SaveAndRefresh("勇者学习技能", { "heroes", "diamond" })
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
    children[#children + 1] = self:CreateBottomActions(selectedHero)

    return UI.Panel {
        id = "heroGrowthScreen",
        width = DESIGN_WIDTH,
        height = DESIGN_HEIGHT,
        backgroundColor = { 42, 30, 24, 255 },
        overflow = "hidden",
        children = children,
    }
end

function HeroGrowthScene:CreateBackground()
    return UI.Panel {
        id = "background",
        position = "absolute",
        left = -1,
        top = -1,
        right = 1,
        bottom = 1,
        zIndex = 0,
        backgroundImage = "image/page_background.png",
        backgroundFit = "cover",
        backgroundColor = { 0, 0, 0, 255 },
    }
end

function HeroGrowthScene:CreateHeader(saveData)
    return {
        UI.Label { text = "勇者养成", position = "absolute", left = 19, top = 66, zIndex = 10, fontSize = 30, fontWeight = "bold", fontColor = { 255, 235, 178, 255 }, textAlign = "center", textStroke = { width = 2, color = { 0, 0, 0, 220 } } },
        UI.Label { text = "金币 " .. FormatNumber(saveData.coin) .. "  蓝钻 " .. FormatNumber(saveData.diamond) .. "  白钻 " .. FormatNumber(saveData.crystal), position = "absolute", left = 256, top = 114, width = 442, zIndex = 10, fontSize = 18, fontWeight = "bold", fontColor = { 255, 234, 0, 255 }, textAlign = "right", textStroke = { width = 2, color = { 0, 0, 0, 220 } }, maxLines = 1 },
        UI.Button { width = 164, height = 58, position = "absolute", left = 0, top = 1183, zIndex = 10, paddingTop = 0, paddingRight = 0, paddingBottom = 0, paddingLeft = 0, fontSize = 18, backgroundImage = "image/BT-返回.png", backgroundFit = "cover", backgroundColor = { 251, 251, 251, 0 }, opacity = 1, textColor = { 255, 255, 255, 0 }, borderRadius = 0, onClick = function() if self.onExit then self.onExit() end end },
    }
end

function HeroGrowthScene:CreateContent(heroes, selectedHero)
    return UI.Panel {
        position = "absolute",
        width = 678,
        left = 16,
        right = 26,
        top = 170,
        height = 890,
        flexDirection = "row",
        gap = 12,
        children = {
            self:CreateHeroList(heroes),
            self:CreateGrowthPanel(selectedHero),
        },
    }
end

function HeroGrowthScene:CreateHeroList(heroes)
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
    return UI.Panel {
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
            UI.Label { text = "Lv." .. tostring(GetHeroLevel(hero)) .. " · " .. tostring(hero.job or hero.profession or "战士"), width = 150, position = "absolute", left = 91, top = 39, fontSize = 14, fontColor = { 74, 56, 42, 220 }, maxLines = 1 },
            UI.Label { text = "战力 " .. FormatNumber(hero.power), width = 150, position = "absolute", left = 91, top = 68, fontSize = 14, fontWeight = "bold", fontColor = { 202, 92, 44, 255 }, maxLines = 1 },
            UI.Panel { position = "absolute", left = 10, top = 78, children = { CreateStarBadge(hero.star) } },
        },
    }
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
            self:CreateUpgradePanel(hero),
            self:CreateStarPanel(hero),
            self:CreateSkillPanel(hero),
            UI.Label { text = self.statusText, flexGrow = 1, flexBasis = 0, fontSize = 17, fontColor = { 88, 46, 45, 255 }, textAlign = "center", maxLines = 3 },
        } or {
            UI.Label { text = "暂无勇者", fontSize = 24, fontWeight = "bold", fontColor = { 88, 46, 45, 255 }, textAlign = "center" },
        },
    }
end

function HeroGrowthScene:CreateHeroOverview(hero)
    local quality = GetQuality(hero)
    return UI.Panel {
        width = "100%",
        height = 224,
        backgroundColor = { 255, 244, 220, 255 },
        borderColor = GetQualityColor(hero),
        borderWidth = 3,
        borderRadius = 18,
        overflow = "hidden",
        children = {
            UI.Panel { width = 156, height = 188, position = "absolute", left = 12, top = 18, backgroundColor = { 207, 166, 119, 170 }, borderColor = { 68, 45, 25, 180 }, borderWidth = 1, borderRadius = 16 },
            NormalizedSprite { width = 188, height = 188, position = "absolute", left = -3, top = 18, backgroundImage = GetHeroPreviewImage(hero) },
            UI.Panel { width = 34, height = 34, position = "absolute", left = 17, top = 20, backgroundImage = QualityUtil.GetIconPath(quality), backgroundFit = "contain" },
            UI.Label { text = hero.name, position = "absolute", left = 182, top = 18, width = 190, fontSize = 25, fontWeight = "bold", fontColor = { 88, 46, 45, 255 }, maxLines = 1 },
            UI.Label { text = QualityUtil.GetName(quality) .. " · " .. tostring(hero.job or hero.profession or "战士") .. " · " .. tostring(hero.faction or "王国"), position = "absolute", left = 182, top = 56, width = 190, fontSize = 16, fontWeight = "bold", fontColor = GetQualityColor(hero), textStroke = { width = 1, color = { 68, 45, 25, 160 } }, maxLines = 1 },
            UI.Panel { position = "absolute", left = 182, top = 88, children = { CreateStarBadge(hero.star) } },
            self:CreateStatRow("等级", "Lv." .. tostring(GetHeroLevel(hero)) .. "/" .. tostring(GetLevelLimit(hero)), 182, 128),
            self:CreateStatRow("战力", FormatNumber(hero.power), 182, 162),
            self:CreateStatRow("技能", tostring(#GetHeroSkills(hero)) .. "/" .. tostring(GetOpenSkillNum(hero)), 182, 196),
        },
    }
end

function HeroGrowthScene:CreateStatRow(label, value, left, top)
    return UI.Panel {
        position = "absolute",
        left = left,
        top = top,
        width = 190,
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

function HeroGrowthScene:CreateUpgradePanel(hero)
    local cost = GetUpgradeCost(hero)
    local level = GetHeroLevel(hero)
    local limit = GetLevelLimit(hero)
    return self:CreateActionPanel("勇者升级", "提升等级并增加基础战力。当前上限 Lv." .. tostring(limit), "升级", "消耗金币 " .. FormatNumber(cost), level < limit, function()
        self:UpgradeHero()
    end)
end

function HeroGrowthScene:CreateStarPanel(hero)
    local cost = GetStarCost(hero)
    local star = GetHeroStar(hero)
    return self:CreateActionPanel("勇者升星", "提升星级，增加大量战力并开放更多技能槽。", "升星", "消耗白钻 " .. FormatNumber(cost), star < MAX_STAR, function()
        self:StarUpHero()
    end)
end

function HeroGrowthScene:CreateSkillPanel(hero)
    local skillSlots = self:CreateSkillSlots(hero)
    local canLearn = #GetHeroSkills(hero) < GetOpenSkillNum(hero) and GetSkillCandidates(hero)[#GetHeroSkills(hero) + 1] ~= nil
    return UI.Panel {
        width = "100%",
        height = 218,
        padding = 10,
        gap = 8,
        backgroundColor = { 113, 74, 58, 230 },
        borderColor = { 68, 45, 25, 255 },
        borderWidth = 2,
        borderRadius = 16,
        children = {
            UI.Panel { width = "100%", height = 34, flexDirection = "row", alignItems = "center", children = {
                UI.Label { text = "学习技能", flexGrow = 1, fontSize = 20, fontWeight = "bold", fontColor = { 255, 235, 178, 255 }, textStroke = { width = 2, color = { 0, 0, 0, 180 } } },
                UI.Button { text = "学习", width = 86, height = 32, fontSize = 16, backgroundColor = canLearn and { 202, 92, 44, 255 } or { 117, 79, 62, 180 }, textColor = { 255, 244, 220, 255 }, borderRadius = 13, onClick = function() self:LearnSkill() end },
            } },
            UI.Label { text = "消耗蓝钻 " .. FormatNumber(GetSkillCost(hero)) .. "，按配置顺序学习下一个技能。", fontSize = 15, fontColor = { 255, 244, 220, 230 }, maxLines = 1 },
            UI.Panel { width = "100%", flexGrow = 1, flexBasis = 0, flexDirection = "row", flexWrap = "wrap", gap = 6, children = skillSlots },
        },
    }
end

function HeroGrowthScene:CreateSkillSlots(hero)
    local learnedSkills = GetHeroSkills(hero)
    local candidates = GetSkillCandidates(hero)
    local openSkillNum = GetOpenSkillNum(hero)
    local children = {}
    for index = 1, 5 do
        local learnedSkill = learnedSkills[index]
        local candidate = candidates[index]
        local opened = index <= openSkillNum
        local title = learnedSkill and GetSkillName(learnedSkill) or (opened and candidate and GetSkillName(candidate) or "技能槽" .. tostring(index))
        local status = learnedSkill and "已学习" or (opened and "可学习" or "升星解锁")
        children[#children + 1] = UI.Panel {
            width = 112,
            height = 62,
            padding = 6,
            backgroundColor = learnedSkill and { 245, 228, 200, 255 } or (opened and { 207, 166, 119, 255 } or { 117, 79, 62, 180 }),
            borderColor = learnedSkill and { 255, 234, 0, 255 } or { 68, 45, 25, 220 },
            borderWidth = 2,
            borderRadius = 12,
            children = {
                UI.Label { text = title, fontSize = 14, fontWeight = "bold", fontColor = learnedSkill and { 88, 46, 45, 255 } or { 255, 244, 220, 255 }, textAlign = "center", maxLines = 1 },
                UI.Label { text = status, fontSize = 12, fontColor = learnedSkill and { 202, 92, 44, 255 } or { 88, 46, 45, 230 }, textAlign = "center", maxLines = 1 },
            },
        }
    end
    return children
end

function HeroGrowthScene:CreateActionPanel(title, desc, buttonText, costText, enabled, onClick)
    return UI.Panel {
        width = "100%",
        height = 102,
        padding = 10,
        backgroundColor = { 113, 74, 58, 230 },
        borderColor = { 68, 45, 25, 255 },
        borderWidth = 2,
        borderRadius = 16,
        children = {
            UI.Label { text = title, position = "absolute", left = 12, top = 8, width = 160, fontSize = 20, fontWeight = "bold", fontColor = { 255, 235, 178, 255 }, textStroke = { width = 2, color = { 0, 0, 0, 180 } } },
            UI.Label { text = desc, position = "absolute", left = 12, top = 40, width = 230, fontSize = 14, fontColor = { 255, 244, 220, 230 }, maxLines = 2 },
            UI.Label { text = costText, position = "absolute", left = 12, top = 76, width = 220, fontSize = 15, fontWeight = "bold", fontColor = { 255, 234, 0, 255 }, textStroke = { width = 1, color = { 0, 0, 0, 200 } }, maxLines = 1 },
            UI.Button { text = buttonText, position = "absolute", right = 12, top = 31, width = 90, height = 42, fontSize = 18, fontWeight = "bold", backgroundColor = enabled and { 202, 92, 44, 255 } or { 117, 79, 62, 180 }, pressedBackgroundColor = { 155, 62, 36, 255 }, textColor = { 255, 244, 220, 255 }, borderRadius = 16, onClick = onClick },
        },
    }
end

function HeroGrowthScene:CreateBottomActions(selectedHero)
    return UI.Panel {
        position = "absolute",
        width = "95.2%",
        height = 51,
        left = 25,
        top = 1113,
        flexDirection = "row",
        gap = 12,
        children = {
            UI.Label { text = selectedHero and ("当前培养：" .. tostring(selectedHero.name)) or "请选择一个勇者", width = 330, height = 46, position = "absolute", left = 0, top = 0, fontSize = 18, fontColor = { 255, 235, 178, 255 }, textStroke = { width = 2, color = { 0, 0, 0, 180 } }, maxLines = 2 },
            UI.Button { text = "升级", width = 137.65, height = 46, position = "absolute", left = 340, top = 0, paddingTop = 0, paddingRight = 16, paddingBottom = 4, paddingLeft = 16, fontSize = 20, backgroundColor = { 202, 92, 44, 255 }, textColor = { 255, 244, 220, 255 }, borderRadius = 18, onClick = function() self:UpgradeHero() end },
            UI.Button { text = "关闭", width = 137, height = 47, position = "absolute", left = 510, top = 0, paddingTop = 0, paddingRight = 16, paddingBottom = 4, paddingLeft = 16, fontSize = 20, backgroundColor = { 88, 46, 45, 255 }, textColor = { 255, 244, 220, 255 }, borderRadius = 18, onClick = function() if self.onExit then self.onExit() end end },
        },
    }
end

return HeroGrowthScene
