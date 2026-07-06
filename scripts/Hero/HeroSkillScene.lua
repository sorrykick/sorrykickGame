local UI = require("urhox-libs/UI")
local NormalizedSprite = require("UI.NormalizedSprite")
local SaveManager = require("Save.SaveManager")
local ConfigManager = require("Config.ConfigManager")
local QualityUtil = require("Config.QualityUtil")

local HeroSkillScene = {}
HeroSkillScene.__index = HeroSkillScene

local DESIGN_WIDTH = 720
local DESIGN_HEIGHT = 1280
local HERO_IMAGE = "image/npcClip/0001/01.png"
local MAX_STAR = 6
local MAX_SKILL_LEVEL = 10
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

local function GetHeroSkillLevels(hero)
    if not hero then return {} end
    hero.skillLevels = type(hero.skillLevels) == "table" and hero.skillLevels or {}
    return hero.skillLevels
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

local function GetSkillConfig(skillId)
    if not skillId then return nil end
    local tables = ConfigManager.GetTables()
    return tables.skill and tables.skill[tostring(skillId)] or nil
end

local function GetSkillName(skillId)
    if not skillId then return "未学习" end
    local skill = GetSkillConfig(skillId)
    if skill and skill.name then
        return tostring(skill.name)
    end
    return "技能" .. tostring(skillId)
end

local function GetSkillSubtitle(skill)
    if type(skill) ~= "table" then
        return "暂无技能配置"
    end

    local kind = tostring(skill.kind or "passive")
    if kind == "active" then
        local parts = { "主动" }
        if skill.type then parts[#parts + 1] = tostring(skill.type) end
        if skill.cooldown then parts[#parts + 1] = "冷却" .. tostring(skill.cooldown) .. "秒" end
        if skill.range then parts[#parts + 1] = "范围" .. tostring(skill.range) end
        return table.concat(parts, " · ")
    end

    if skill.trigger then
        return "被动 · " .. tostring(skill.trigger)
    end
    return "被动"
end

local function GetSkillDescription(skill)
    if type(skill) ~= "table" then
        return "该技能缺少配置描述。"
    end
    local desc = tostring(skill.description or "")
    local effect = tostring(skill.effect or "")
    if desc ~= "" and effect ~= "" and desc ~= effect then
        return desc .. "\n" .. effect
    end
    if effect ~= "" then return effect end
    if desc ~= "" then return desc end
    return "暂无技能描述。"
end

local function GetSkillLevel(hero, skillId)
    local levels = GetHeroSkillLevels(hero)
    local level = math.floor(tonumber(levels[tostring(skillId)]) or 1)
    if level < 1 then level = 1 end
    return level
end

local function GetSkillLearnCost(hero)
    return (#GetHeroSkills(hero) + 1) * 80
end

local function GetSkillUpgradeCost(hero, skillId)
    local level = GetSkillLevel(hero, skillId)
    return level * 160 + GetQuality(hero) * 70 + GetHeroStar(hero) * 40
end

local function CreateStarBadge(star, layout)
    layout = type(layout) == "table" and layout or {}
    local starCount = GetHeroStar({ star = star })
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
            UI.Label { text = tostring(starCount), fontSize = 15, fontWeight = "bold", fontColor = { 255, 255, 255, 255 }, textStroke = { width = 1, color = { 68, 45, 25, 220 } }, textAlign = "center" },
        },
    }
end

function HeroSkillScene:new(options)
    local o = setmetatable({}, self)
    o.onExit = options and options.onExit or nil
    o.createTopResourceRow = options and options.createTopResourceRow or nil
    o.onRootChanged = options and options.onRootChanged or nil
    o.root = nil
    o.selectedHeroId = options and options.selectedHeroId or nil
    o.selectedSkillIndex = ClampInt(options and options.selectedSkillIndex or 1, 1, 5)
    o.statusText = "选择技能槽，可学习新技能或升级已学习技能。"
    return o
end

function HeroSkillScene:Destroy()
    self.root = nil
end

function HeroSkillScene:GetData()
    local saveData = GetSaveData()
    local heroes = type(saveData.heroes) == "table" and saveData.heroes or {}
    local selectedHero = FindHeroById(heroes, self.selectedHeroId)
    if not selectedHero and heroes[1] then
        selectedHero = heroes[1]
        self.selectedHeroId = selectedHero.id
    end
    self.selectedSkillIndex = ClampInt(self.selectedSkillIndex, 1, 5)
    return saveData, heroes, selectedHero
end

function HeroSkillScene:SetStatus(text)
    self.statusText = text
end

function HeroSkillScene:Refresh()
    self.root = self:CreateRoot()
    UI.SetRoot(self.root, true)
    if self.onRootChanged then
        self.onRootChanged(self.root)
    end
end

function HeroSkillScene:SaveAndRefresh(reason, fields)
    SaveManager.MarkFieldsDirty(fields or { "heroes" })
    SaveManager.SaveGameSnapshot(reason, function()
        print("[HeroSkill] Saved: " .. tostring(reason))
        self:Refresh()
    end, function(errorMessage)
        print("[HeroSkill] Save failed: " .. tostring(errorMessage))
        self:SetStatus("保存失败，请稍后重试。")
        self:Refresh()
    end)
end

function HeroSkillScene:SelectHero(heroId)
    self.selectedHeroId = heroId
    self.selectedSkillIndex = 1
    local _, _, hero = self:GetData()
    self:SetStatus(hero and ("已选择" .. tostring(hero.name) .. "的技能。") or "请选择勇者。")
    self:Refresh()
end

function HeroSkillScene:SelectSkill(index)
    self.selectedSkillIndex = ClampInt(index, 1, 5)
    local _, _, hero = self:GetData()
    if hero then
        self:SetStatus("已选择第" .. tostring(self.selectedSkillIndex) .. "个技能槽。")
    end
    self:Refresh()
end

function HeroSkillScene:LearnSkill(index)
    local saveData, _, hero = self:GetData()
    if not hero then
        self:SetStatus("请先选择一个勇者。")
        self:Refresh()
        return
    end

    local skills = GetHeroSkills(hero)
    local openSkillNum = GetOpenSkillNum(hero)
    local targetIndex = ClampInt(index or (#skills + 1), 1, 5)
    if targetIndex > openSkillNum then
        self:SetStatus("该技能槽尚未开放，请先提升勇者星级。")
        self:Refresh()
        return
    end
    if targetIndex ~= #skills + 1 then
        self:SetStatus("请按顺序学习前置技能。")
        self:Refresh()
        return
    end

    local candidates = GetSkillCandidates(hero)
    local nextSkill = candidates[targetIndex]
    if not nextSkill then
        self:SetStatus("该勇者暂无可学习技能。")
        self:Refresh()
        return
    end

    local cost = GetSkillLearnCost(hero)
    if math.floor(tonumber(saveData.diamond) or 0) < cost then
        self:SetStatus("蓝钻不足，学习技能需要" .. FormatNumber(cost) .. "蓝钻。")
        self:Refresh()
        return
    end

    saveData.diamond = math.max(0, math.floor(tonumber(saveData.diamond) or 0) - cost)
    skills[targetIndex] = nextSkill
    local levels = GetHeroSkillLevels(hero)
    levels[tostring(nextSkill)] = 1
    hero.power = math.max(1, math.floor(tonumber(hero.power) or 1) + 120 + GetQuality(hero) * 20)
    self.selectedSkillIndex = targetIndex
    self:SetStatus(hero.name .. "学会" .. GetSkillName(nextSkill) .. "。")
    self:SaveAndRefresh("勇者学习技能", { "heroes", "diamond" })
end

function HeroSkillScene:UpgradeSkill(skillId)
    local saveData, _, hero = self:GetData()
    if not hero then
        self:SetStatus("请先选择一个勇者。")
        self:Refresh()
        return
    end
    if not skillId then
        self:SetStatus("请先选择已学习技能。")
        self:Refresh()
        return
    end

    local learned = false
    for _, learnedSkillId in ipairs(GetHeroSkills(hero)) do
        if tostring(learnedSkillId) == tostring(skillId) then
            learned = true
            break
        end
    end
    if not learned then
        self:SetStatus("该技能尚未学习，无法升级。")
        self:Refresh()
        return
    end

    local level = GetSkillLevel(hero, skillId)
    if level >= MAX_SKILL_LEVEL then
        self:SetStatus("该技能已达到最高等级。")
        self:Refresh()
        return
    end

    local cost = GetSkillUpgradeCost(hero, skillId)
    if math.floor(tonumber(saveData.coin) or 0) < cost then
        self:SetStatus("金币不足，升级技能需要" .. FormatNumber(cost) .. "金币。")
        self:Refresh()
        return
    end

    saveData.coin = math.max(0, math.floor(tonumber(saveData.coin) or 0) - cost)
    local levels = GetHeroSkillLevels(hero)
    levels[tostring(skillId)] = level + 1
    hero.power = math.max(1, math.floor(tonumber(hero.power) or 1) + 80 + level * 18 + GetQuality(hero) * 15)
    self:SetStatus(GetSkillName(skillId) .. "升级到 Lv." .. tostring(level + 1) .. "。")
    self:SaveAndRefresh("勇者技能升级", { "heroes", "coin" })
end

function HeroSkillScene:CreateRoot()
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
    children[#children + 1] = UI.Label {
        text = selectedHero and ("当前技能：" .. tostring(selectedHero.name)) or "请选择一个勇者",
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

    self.root = UI.Panel {
        id = "heroSkillScreen",
        width = DESIGN_WIDTH,
        height = DESIGN_HEIGHT,
        backgroundColor = { 42, 30, 24, 255 },
        overflow = "hidden",
        children = children,
    }
    return self.root
end

function HeroSkillScene:CreateBackground()
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

function HeroSkillScene:CreateHeader(saveData)
    return {
        UI.Label { text = "技能培养", position = "absolute", left = 19, top = 66, zIndex = 10, fontSize = 30, fontWeight = "bold", fontColor = { 255, 235, 178, 255 }, textAlign = "center", textStroke = { width = 2, color = { 0, 0, 0, 220 } } },
        UI.Button { width = 164, height = 58, position = "absolute", left = 0, top = 1183, zIndex = 10, paddingTop = 0, paddingRight = 0, paddingBottom = 0, paddingLeft = 0, fontSize = 18, backgroundImage = "image/BT-返回.png", backgroundFit = "cover", backgroundColor = { 251, 251, 251, 0 }, opacity = 1, textColor = { 255, 255, 255, 0 }, borderRadius = 0, onClick = function() if self.onExit then self.onExit(self.selectedHeroId) end end },
    }
end

function HeroSkillScene:CreateContent(heroes, selectedHero)
    return UI.Panel {
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
            self:CreateSkillPanel(selectedHero),
        },
    }
end

function HeroSkillScene:CreateHeroList(heroes)
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

function HeroSkillScene:CreateHeroCard(hero)
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

function HeroSkillScene:CreateSkillPanel(hero)
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
            self:CreateSkillSlotsPanel(hero),
            self:CreateSkillDetailPanel(hero),
            UI.Label { text = self.statusText, flexGrow = 1, flexBasis = 0, top = 4, fontSize = 17, fontColor = { 88, 46, 45, 255 }, textAlign = "left", verticalAlign = "top", whiteSpace = "normal", maxLines = 3 },
        } or {
            UI.Label { text = "暂无勇者", fontSize = 24, fontWeight = "bold", fontColor = { 88, 46, 45, 255 }, textAlign = "center" },
        },
    }
end

function HeroSkillScene:CreateHeroOverview(hero)
    return UI.Panel {
        width = "100%",
        height = 176,
        backgroundColor = { 255, 244, 220, 255 },
        borderColor = GetQualityColor(hero),
        borderWidth = 3,
        borderRadius = 18,
        overflow = "hidden",
        children = {
            UI.Panel { width = 132, height = 154, position = "absolute", left = 12, top = 18, backgroundColor = { 207, 166, 119, 170 }, borderColor = { 68, 45, 25, 180 }, borderWidth = 1, borderRadius = 16 },
            NormalizedSprite { width = 164, height = 164, position = "absolute", left = -4, top = 10, backgroundImage = GetHeroPreviewImage(hero) },
            UI.Panel { width = 34, height = 34, position = "absolute", left = 17, top = 20, backgroundImage = QualityUtil.GetIconPath(hero), backgroundFit = "contain" },
            UI.Label { text = hero.name, position = "absolute", left = 160, top = 18, width = 200, fontSize = 25, fontWeight = "bold", fontColor = { 88, 46, 45, 255 }, maxLines = 1 },
            UI.Label { text = tostring(hero.job or hero.profession or "战士") .. " · " .. tostring(hero.faction or "王国"), position = "absolute", left = 160, top = 58, width = 200, fontSize = 14, fontWeight = "bold", fontColor = GetQualityColor(hero), textStroke = { width = 1, color = { 68, 45, 25, 160 } }, maxLines = 1 },
            UI.Panel { position = "absolute", left = 160, top = 84, children = { CreateStarBadge(hero.star, { top = 4 }) } },
            self:CreateStatRow("已学", tostring(#GetHeroSkills(hero)) .. "/" .. tostring(GetOpenSkillNum(hero)), 160, 118, 198),
            self:CreateStatRow("战力", FormatNumber(hero.power), 160, 148, 198),
        },
    }
end

function HeroSkillScene:CreateStatRow(label, value, left, top, width)
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

function HeroSkillScene:CreateSkillSlotsPanel(hero)
    local children = {}
    for index = 1, 5 do
        children[#children + 1] = self:CreateSkillSlotCard(hero, index)
    end
    return UI.Panel {
        width = "100%",
        height = 282,
        padding = 10,
        gap = 8,
        backgroundColor = { 113, 74, 58, 230 },
        borderColor = { 68, 45, 25, 255 },
        borderWidth = 2,
        borderRadius = 16,
        children = {
            UI.Label { text = "技能槽", fontSize = 20, fontWeight = "bold", fontColor = { 255, 235, 178, 255 }, textStroke = { width = 2, color = { 0, 0, 0, 180 } } },
            UI.Panel { width = "100%", flexGrow = 1, flexBasis = 0, flexDirection = "row", flexWrap = "wrap", gap = 8, children = children },
        },
    }
end

function HeroSkillScene:CreateSkillSlotCard(hero, index)
    local learnedSkills = GetHeroSkills(hero)
    local candidates = GetSkillCandidates(hero)
    local openSkillNum = GetOpenSkillNum(hero)
    local learnedSkill = learnedSkills[index]
    local candidate = candidates[index]
    local opened = index <= openSkillNum
    local selected = index == self.selectedSkillIndex
    local skillId = learnedSkill or candidate
    local levelText = learnedSkill and ("Lv." .. tostring(GetSkillLevel(hero, learnedSkill))) or (opened and "可学习" or "升星解锁")
    local title = skillId and GetSkillName(skillId) or ("技能槽" .. tostring(index))
    return UI.Panel {
        width = 170,
        height = 72,
        padding = 7,
        backgroundColor = learnedSkill and { 245, 228, 200, 255 } or (opened and { 207, 166, 119, 255 } or { 117, 79, 62, 180 }),
        borderColor = selected and { 255, 234, 0, 255 } or (learnedSkill and { 255, 234, 0, 210 } or { 68, 45, 25, 220 }),
        borderWidth = selected and 4 or 2,
        borderRadius = 12,
        onClick = function()
            self:SelectSkill(index)
        end,
        children = {
            UI.Label { text = tostring(index), position = "absolute", left = 8, top = 5, width = 22, height = 22, fontSize = 14, fontWeight = "bold", fontColor = { 255, 255, 255, 255 }, textAlign = "center", backgroundColor = { 88, 46, 45, 220 }, borderRadius = 11 },
            UI.Label { text = title, position = "absolute", left = 34, top = 8, width = 126, fontSize = 14, fontWeight = "bold", fontColor = learnedSkill and { 88, 46, 45, 255 } or { 255, 244, 220, 255 }, maxLines = 1 },
            UI.Label { text = levelText, position = "absolute", left = 34, top = 38, width = 126, fontSize = 13, fontColor = learnedSkill and { 202, 92, 44, 255 } or { 88, 46, 45, 230 }, maxLines = 1 },
        },
    }
end

function HeroSkillScene:CreateSkillDetailPanel(hero)
    local learnedSkills = GetHeroSkills(hero)
    local candidates = GetSkillCandidates(hero)
    local index = ClampInt(self.selectedSkillIndex, 1, 5)
    local openSkillNum = GetOpenSkillNum(hero)
    local opened = index <= openSkillNum
    local learnedSkill = learnedSkills[index]
    local candidate = candidates[index]
    local skillId = learnedSkill or candidate
    local skill = GetSkillConfig(skillId)
    local learned = learnedSkill ~= nil
    local canLearn = opened and not learned and candidate ~= nil and index == #learnedSkills + 1
    local canUpgrade = learned and GetSkillLevel(hero, learnedSkill) < MAX_SKILL_LEVEL
    local actionButton = nil

    if learned then
        actionButton = UI.Button {
            text = canUpgrade and "升级" or "满级",
            disabled = not canUpgrade,
            width = 96,
            height = 42,
            fontSize = 18,
            fontWeight = "bold",
            backgroundColor = canUpgrade and { 202, 92, 44, 255 } or { 117, 79, 62, 180 },
            pressedBackgroundColor = { 155, 62, 36, 255 },
            textColor = { 255, 244, 220, 255 },
            borderRadius = 16,
            onClick = function()
                self:UpgradeSkill(learnedSkill)
            end,
        }
    elseif opened then
        actionButton = UI.Button {
            text = "学习",
            disabled = not canLearn,
            width = 96,
            height = 42,
            fontSize = 18,
            fontWeight = "bold",
            backgroundColor = canLearn and { 202, 92, 44, 255 } or { 117, 79, 62, 180 },
            pressedBackgroundColor = { 155, 62, 36, 255 },
            textColor = { 255, 244, 220, 255 },
            borderRadius = 16,
            onClick = function()
                self:LearnSkill(index)
            end,
        }
    else
        actionButton = UI.Button {
            text = "未解锁",
            disabled = true,
            width = 96,
            height = 42,
            fontSize = 18,
            fontWeight = "bold",
            backgroundColor = { 117, 79, 62, 180 },
            textColor = { 255, 244, 220, 255 },
            borderRadius = 16,
        }
    end

    local costText = ""
    if learned then
        costText = canUpgrade and ("升级消耗金币 " .. FormatNumber(GetSkillUpgradeCost(hero, learnedSkill))) or "技能已达到最高等级"
    elseif opened then
        costText = canLearn and ("学习消耗蓝钻 " .. FormatNumber(GetSkillLearnCost(hero))) or "需先学习前置技能"
    else
        costText = "提升星级后开放该技能槽"
    end

    return UI.Panel {
        width = "100%",
        height = 342,
        padding = 12,
        gap = 8,
        backgroundColor = { 255, 244, 220, 255 },
        borderColor = skillId and { 202, 92, 44, 255 } or { 68, 45, 25, 200 },
        borderWidth = 2,
        borderRadius = 16,
        children = {
            UI.Panel { width = "100%", height = 50, flexDirection = "row", alignItems = "center", children = {
                UI.Panel { flexGrow = 1, flexShrink = 1, children = {
                    UI.Label { text = skillId and GetSkillName(skillId) or ("技能槽" .. tostring(index)), fontSize = 22, fontWeight = "bold", fontColor = { 88, 46, 45, 255 }, maxLines = 1 },
                    UI.Label { text = GetSkillSubtitle(skill), top = 2, fontSize = 14, fontColor = { 202, 92, 44, 255 }, maxLines = 1 },
                } },
                actionButton,
            } },
            UI.Panel { width = "100%", height = 34, flexDirection = "row", gap = 8, children = {
                UI.Label { text = learned and ("当前等级 Lv." .. tostring(GetSkillLevel(hero, learnedSkill)) .. "/" .. tostring(MAX_SKILL_LEVEL)) or (opened and "当前状态：未学习" or "当前状态：未解锁"), flexGrow = 1, fontSize = 16, fontWeight = "bold", fontColor = { 88, 46, 45, 255 }, maxLines = 1 },
                UI.Label { text = costText, width = 190, fontSize = 14, fontWeight = "bold", fontColor = { 202, 92, 44, 255 }, textAlign = "right", maxLines = 1 },
            } },
            UI.Panel {
                width = "100%",
                flexGrow = 1,
                flexBasis = 0,
                padding = 10,
                backgroundColor = { 245, 228, 200, 255 },
                borderColor = { 207, 166, 119, 255 },
                borderWidth = 2,
                borderRadius = 12,
                children = {
                    UI.Label {
                        text = GetSkillDescription(skill),
                        width = "100%",
                        height = "100%",
                        fontSize = 16,
                        fontColor = { 88, 46, 45, 255 },
                        whiteSpace = "normal",
                        wordBreak = "break-word",
                        verticalAlign = "top",
                        maxLines = 8,
                    },
                },
            },
        },
    }
end

return HeroSkillScene
