local UI = require("urhox-libs/UI")
local NormalizedSprite = require("UI.NormalizedSprite")
local SaveManager = require("Save.SaveManager")
local ConfigManager = require("Config.ConfigManager")

local HeroCodexScene = {}
HeroCodexScene.__index = HeroCodexScene

local DESIGN_WIDTH = 720
local DESIGN_HEIGHT = 1280
local HERO_IMAGE = "image/npcClip/0001/01.png"

local QUALITY_COLORS = {
    [1] = { 181, 181, 181, 255 },
    [2] = { 162, 255, 148, 255 },
    [3] = { 114, 242, 245, 255 },
    [4] = { 239, 121, 255, 255 },
    [5] = { 255, 237, 0, 255 },
    [6] = { 255, 0, 0, 255 },
    [7] = { 255, 237, 0, 255 },
}

local QUALITY_NAMES = {
    [1] = "普通",
    [2] = "优质",
    [3] = "稀有",
    [4] = "史诗",
    [5] = "传说",
    [6] = "至臻",
    [7] = "传说",
}

local QUALITY_ICON_PATHS = {
    [1] = "image/品质/_D.png",
    [2] = "image/品质/_C.png",
    [3] = "image/品质/_B.png",
    [4] = "image/品质/_A.png",
    [5] = "image/品质/_S.png",
    [6] = "image/品质/_SS.png",
    [7] = "image/品质/_L.png",
}

local STAR_ICON_PATH = "image/品质/星级.png"
local STAR_REWARD_STARS = { 2, 3, 4, 5, 6 }

local ATTRIBUTE_LABELS = {
    { id = "MaxHP", label = "生命" },
    { id = "Att", label = "攻击" },
    { id = "Def", label = "防御" },
    { id = "Speed", label = "速度" },
    { id = "Crit", label = "暴击" },
    { id = "CritDamage", label = "暴伤" },
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

local function IsCommentKey(key)
    return type(key) == "string" and string.sub(key, 1, 1) == "#"
end

local function GetQuality(config)
    return ClampInt(config and config.quality or 1, 1, 7)
end

local function GetQualityColor(config)
    return QUALITY_COLORS[GetQuality(config)] or QUALITY_COLORS[1]
end

local function GetHeroPreviewImage(config)
    if config and config.clipDir and config.clipDir ~= "" then
        local path = tostring(config.clipDir) .. "/01.png"
        if not cache or cache:Exists(path) then
            return path
        end
    end
    return HERO_IMAGE
end

local function GetSaveData()
    return SaveManager.GetSaveData() or {}
end

local function GetHeroNpcId(hero)
    if not hero then return "" end
    local npcId = tostring(hero.configId or hero.npcId or hero.id or "")
    if string.sub(npcId, 1, 4) == "npc_" then
        npcId = string.sub(npcId, 5)
    end
    return npcId
end

local function GetHeroMap(heroes)
    local heroMap = {}
    for _, hero in ipairs(heroes or {}) do
        local npcId = GetHeroNpcId(hero)
        if npcId ~= "" then
            heroMap[npcId] = hero
        end
    end
    return heroMap
end

local function GetCodex(saveData)
    saveData.codex = type(saveData.codex) == "table" and saveData.codex or {}
    saveData.codex.claimedOwned = type(saveData.codex.claimedOwned) == "table" and saveData.codex.claimedOwned or {}
    saveData.codex.claimedStars = type(saveData.codex.claimedStars) == "table" and saveData.codex.claimedStars or {}
    return saveData.codex
end

local function GetNpcEntries()
    local tables = ConfigManager.GetTables()
    local entries = {}
    for npcId, config in pairs(tables.npc or {}) do
        if not IsCommentKey(npcId) and type(config) == "table" then
            entries[#entries + 1] = {
                npcId = tostring(npcId),
                config = config,
            }
        end
    end
    table.sort(entries, function(a, b)
        return (tonumber(a.npcId) or 0) < (tonumber(b.npcId) or 0)
    end)
    return entries
end

local function FindEntry(entries, npcId)
    for _, entry in ipairs(entries or {}) do
        if tostring(entry.npcId) == tostring(npcId) then
            return entry
        end
    end
    return nil
end

local function GetSkillName(skillId)
    if not skillId then return "未配置" end
    local tables = ConfigManager.GetTables()
    local skill = tables.skill and tables.skill[tostring(skillId)] or nil
    if skill and skill.name then
        return tostring(skill.name)
    end
    return "技能" .. tostring(skillId)
end

local function GetAttributeValue(attributeConfig, attrId)
    if type(attributeConfig) ~= "table" then return 0 end
    local attr = attributeConfig[attrId]
    if type(attr) ~= "table" then return 0 end
    return math.floor(tonumber(attr.Value) or 0)
end

local function GetOwnedRewardAmount(config)
    return 30 + GetQuality(config) * 10
end

local function GetStarRewardAmount(config, star)
    return star * 20 + GetQuality(config) * 8
end

local function IsOwnedRewardClaimed(codex, npcId)
    return codex and codex.claimedOwned and codex.claimedOwned[tostring(npcId)] == true
end

local function IsStarRewardClaimed(codex, npcId, star)
    local claimedStars = codex and codex.claimedStars and codex.claimedStars[tostring(npcId)] or nil
    return type(claimedStars) == "table" and claimedStars[tostring(star)] == true
end

local function HasClaimableOwnedReward(hero, codex, npcId)
    return hero ~= nil and not IsOwnedRewardClaimed(codex, npcId)
end

local function GetNextClaimableStar(hero, codex, npcId)
    if not hero then return nil end
    local heroStar = math.max(1, math.floor(tonumber(hero.star) or 1))
    for _, star in ipairs(STAR_REWARD_STARS) do
        if heroStar >= star and not IsStarRewardClaimed(codex, npcId, star) then
            return star
        end
    end
    return nil
end

local function HasAnyClaimableReward(hero, codex, npcId)
    return HasClaimableOwnedReward(hero, codex, npcId) or GetNextClaimableStar(hero, codex, npcId) ~= nil
end

function HeroCodexScene:new(options)
    local o = setmetatable({}, self)
    o.onExit = options and options.onExit or nil
    o.createTopResourceRow = options and options.createTopResourceRow or nil
    o.onRootChanged = options and options.onRootChanged or nil
    o.root = nil
    o.selectedNpcId = options and options.selectedNpcId or nil
    o.statusText = "获得英雄后可领取激活蓝钻，升星达标还可领取星级蓝钻。"
    return o
end

function HeroCodexScene:Destroy()
    self.root = nil
end

function HeroCodexScene:SetStatus(text)
    self.statusText = text
end

function HeroCodexScene:GetData()
    local saveData = GetSaveData()
    local entries = GetNpcEntries()
    local heroMap = GetHeroMap(saveData.heroes)
    local selectedEntry = FindEntry(entries, self.selectedNpcId)
    if not selectedEntry and entries[1] then
        selectedEntry = entries[1]
        self.selectedNpcId = selectedEntry.npcId
    end
    local selectedHero = selectedEntry and heroMap[selectedEntry.npcId] or nil
    local codex = GetCodex(saveData)
    return saveData, entries, heroMap, selectedEntry, selectedHero, codex
end

function HeroCodexScene:Refresh()
    self.root = self:CreateRoot()
    UI.SetRoot(self.root, true)
    if self.onRootChanged then
        self.onRootChanged(self.root)
    end
end

function HeroCodexScene:SaveAndRefresh(reason)
    SaveManager.MarkFieldsDirty({ "codex", "diamond" })
    SaveManager.SaveGameSnapshot(reason, function()
        print("[HeroCodex] Saved: " .. tostring(reason))
        self:Refresh()
    end, function(errorMessage)
        print("[HeroCodex] Save failed: " .. tostring(errorMessage))
        self:SetStatus("保存失败，请稍后重试。")
        self:Refresh()
    end)
end

function HeroCodexScene:SelectHero(npcId)
    self.selectedNpcId = npcId
    local _, _, _, entry, hero = self:GetData()
    local name = entry and tostring(entry.config.name or ("勇者" .. tostring(npcId))) or "英雄"
    self:SetStatus(hero and ("已选择" .. name .. "，可查看图鉴和领取奖励。") or (name .. "尚未获得，获得后激活图鉴奖励。"))
    self:Refresh()
end

function HeroCodexScene:ClaimOwnedReward()
    local saveData, _, _, entry, hero, codex = self:GetData()
    if not entry then return end
    if not hero then
        self:SetStatus("尚未获得该英雄，获得后才能领取激活奖励。")
        self:Refresh()
        return
    end
    if IsOwnedRewardClaimed(codex, entry.npcId) then
        self:SetStatus("该英雄激活奖励已领取。")
        self:Refresh()
        return
    end

    local amount = GetOwnedRewardAmount(entry.config)
    saveData.diamond = math.max(0, math.floor(tonumber(saveData.diamond) or 0) + amount)
    codex.claimedOwned[entry.npcId] = true
    self:SetStatus("领取" .. tostring(entry.config.name or "英雄") .. "激活奖励：蓝钻+" .. FormatNumber(amount) .. "。")
    self:SaveAndRefresh("领取英雄图鉴激活奖励")
end

function HeroCodexScene:ClaimStarReward()
    local saveData, _, _, entry, hero, codex = self:GetData()
    if not entry then return end
    if not hero then
        self:SetStatus("尚未获得该英雄，无法领取星级奖励。")
        self:Refresh()
        return
    end

    local star = GetNextClaimableStar(hero, codex, entry.npcId)
    if not star then
        self:SetStatus("当前没有可领取的星级奖励，请继续升星。")
        self:Refresh()
        return
    end

    local amount = GetStarRewardAmount(entry.config, star)
    saveData.diamond = math.max(0, math.floor(tonumber(saveData.diamond) or 0) + amount)
    codex.claimedStars[entry.npcId] = type(codex.claimedStars[entry.npcId]) == "table" and codex.claimedStars[entry.npcId] or {}
    codex.claimedStars[entry.npcId][tostring(star)] = true
    self:SetStatus("领取" .. tostring(entry.config.name or "英雄") .. tostring(star) .. "星奖励：蓝钻+" .. FormatNumber(amount) .. "。")
    self:SaveAndRefresh("领取英雄图鉴星级奖励")
end

function HeroCodexScene:CreateRoot()
    local saveData, entries, heroMap, selectedEntry, selectedHero, codex = self:GetData()
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
    local headerChildren = self:CreateHeader(entries, heroMap)
    for _, child in ipairs(headerChildren) do
        children[#children + 1] = child
    end
    children[#children + 1] = self:CreateContent(entries, heroMap, selectedEntry, selectedHero, codex)
    children[#children + 1] = self:CreateBottomActions(saveData, selectedEntry, selectedHero, codex)

    return UI.Panel {
        id = "heroCodexScreen",
        width = DESIGN_WIDTH,
        height = DESIGN_HEIGHT,
        backgroundColor = { 42, 30, 24, 255 },
        overflow = "hidden",
        children = children,
    }
end

function HeroCodexScene:CreateBackground()
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

function HeroCodexScene:CreateHeader(entries, heroMap)
    local ownedCount = 0
    for _, entry in ipairs(entries or {}) do
        if heroMap[entry.npcId] then
            ownedCount = ownedCount + 1
        end
    end
    return {
        UI.Label { text = "英雄图鉴", position = "absolute", left = 19, top = 66, zIndex = 10, fontSize = 30, fontWeight = "bold", fontColor = { 255, 235, 178, 255 }, textAlign = "center", textStroke = { width = 2, color = { 0, 0, 0, 220 } } },
        UI.Label { text = "已激活 " .. tostring(ownedCount) .. "/" .. tostring(#entries), position = "absolute", left = 378, top = 114, width = 320, zIndex = 10, fontSize = 20, fontWeight = "bold", fontColor = { 255, 234, 0, 255 }, textAlign = "right", textStroke = { width = 2, color = { 0, 0, 0, 220 } } },
        UI.Button { width = 164, height = 58, position = "absolute", left = 0, top = 1183, zIndex = 10, paddingTop = 0, paddingRight = 0, paddingBottom = 0, paddingLeft = 0, fontSize = 18, backgroundImage = "image/BT-返回.png", backgroundFit = "cover", backgroundColor = { 251, 251, 251, 0 }, opacity = 1, textColor = { 255, 255, 255, 0 }, borderRadius = 0, onClick = function() if self.onExit then self.onExit() end end },
    }
end

function HeroCodexScene:CreateContent(entries, heroMap, selectedEntry, selectedHero, codex)
    return UI.Panel {
        position = "absolute",
        width = 688,
        left = 16,
        right = 16,
        top = 170,
        height = 890,
        flexDirection = "row",
        gap = 12,
        children = {
            self:CreateHeroGridPanel(entries, heroMap, codex),
            self:CreateDetailPanel(selectedEntry, selectedHero, codex),
        },
    }
end

function HeroCodexScene:CreateHeroGridPanel(entries, heroMap, codex)
    local cards = {}
    for _, entry in ipairs(entries or {}) do
        cards[#cards + 1] = self:CreateHeroIcon(entry, heroMap[entry.npcId], codex)
    end
    return UI.Panel {
        width = 398,
        height = "100%",
        padding = 10,
        gap = 8,
        backgroundColor = { 113, 74, 58, 245 },
        borderColor = { 68, 45, 25, 255 },
        borderWidth = 3,
        borderRadius = 18,
        children = {
            UI.Label { text = "全部英雄", fontSize = 24, fontWeight = "bold", fontColor = { 255, 235, 178, 255 }, textAlign = "center", textStroke = { width = 2, color = { 0, 0, 0, 200 } } },
            UI.ScrollView {
                width = "100%",
                flexGrow = 1,
                flexBasis = 0,
                scrollY = true,
                showScrollbar = true,
                children = {
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        flexWrap = "wrap",
                        gap = 8,
                        children = cards,
                    },
                },
            },
        },
    }
end

function HeroCodexScene:CreateHeroIcon(entry, ownedHero, codex)
    local config = entry.config
    local selected = tostring(entry.npcId) == tostring(self.selectedNpcId)
    local owned = ownedHero ~= nil
    local claimable = HasAnyClaimableReward(ownedHero, codex, entry.npcId)
    local qualityColor = GetQualityColor(config)
    return UI.Panel {
        width = 84,
        height = 108,
        padding = 5,
        overflow = "hidden",
        backgroundColor = selected and { 255, 244, 205, 255 } or (owned and { 245, 228, 200, 255 } or { 117, 79, 62, 210 }),
        borderColor = selected and { 255, 234, 0, 255 } or qualityColor,
        borderWidth = selected and 4 or 2,
        borderRadius = 14,
        onClick = function()
            self:SelectHero(entry.npcId)
        end,
        children = {
            UI.Panel { width = 72, height = 70, position = "absolute", left = 6, top = 8, backgroundColor = { 207, 166, 119, owned and 180 or 90 }, borderRadius = 11 },
            NormalizedSprite { width = 76, height = 72, position = "absolute", left = 4, top = 6, backgroundImage = GetHeroPreviewImage(config), imageTint = owned and { 255, 255, 255, 255 } or { 100, 100, 100, 210 } },
            UI.Panel { width = 24, height = 24, position = "absolute", left = 5, top = 4, backgroundImage = QUALITY_ICON_PATHS[GetQuality(config)] or QUALITY_ICON_PATHS[1], backgroundFit = "contain" },
            UI.Label { text = tostring(config.name or entry.npcId), width = 74, height = 20, position = "absolute", left = 5, top = 82, fontSize = 13, fontWeight = "bold", fontColor = owned and { 88, 46, 45, 255 } or { 255, 244, 220, 230 }, textAlign = "center", maxLines = 1 },
            UI.Label { text = owned and "已激活" or "未获得", width = 56, height = 18, position = "absolute", left = 14, top = 62, fontSize = 11, fontColor = owned and { 202, 92, 44, 255 } or { 255, 244, 220, 230 }, textAlign = "center", backgroundColor = owned and { 255, 244, 205, 210 } or { 42, 30, 24, 190 }, borderRadius = 8, maxLines = 1 },
            UI.Panel { visible = claimable, width = 18, height = 18, position = "absolute", right = 4, top = 4, backgroundColor = { 255, 80, 48, 255 }, borderRadius = 9, borderWidth = 2, borderColor = { 255, 234, 0, 255 } },
        },
    }
end

function HeroCodexScene:CreateDetailPanel(entry, hero, codex)
    if not entry then
        return UI.Panel {
            flexGrow = 1,
            flexShrink = 1,
            height = "100%",
            padding = 12,
            backgroundColor = { 245, 228, 200, 245 },
            borderColor = { 68, 45, 25, 255 },
            borderWidth = 3,
            borderRadius = 18,
            children = { UI.Label { text = "暂无英雄配置", fontSize = 22, fontColor = { 88, 46, 45, 255 }, textAlign = "center" } },
        }
    end

    return UI.Panel {
        flexGrow = 1,
        flexShrink = 1,
        height = "100%",
        padding = 12,
        gap = 8,
        backgroundColor = { 245, 228, 200, 245 },
        borderColor = { 68, 45, 25, 255 },
        borderWidth = 3,
        borderRadius = 18,
        children = {
            self:CreateHeroOverview(entry, hero),
            self:CreateAttributePanel(entry),
            self:CreateSkillPanel(entry),
            self:CreateRewardPanel(entry, hero, codex),
            UI.Label { text = self.statusText, flexGrow = 1, flexBasis = 0, fontSize = 15, fontColor = { 88, 46, 45, 255 }, textAlign = "center", maxLines = 3 },
        },
    }
end

function HeroCodexScene:CreateHeroOverview(entry, hero)
    local config = entry.config
    local quality = GetQuality(config)
    local star = hero and math.max(1, math.floor(tonumber(hero.star) or 1)) or math.max(1, math.floor(tonumber(config.BaseStarID) or 1))
    return UI.Panel {
        width = "100%",
        height = 228,
        backgroundColor = { 255, 244, 220, 255 },
        borderColor = GetQualityColor(config),
        borderWidth = 3,
        borderRadius = 18,
        overflow = "hidden",
        children = {
            UI.Panel { width = 116, height = 150, position = "absolute", left = 10, top = 18, backgroundColor = { 207, 166, 119, 170 }, borderColor = { 68, 45, 25, 180 }, borderWidth = 1, borderRadius = 16 },
            NormalizedSprite { width = 140, height = 150, position = "absolute", left = -2, top = 18, backgroundImage = GetHeroPreviewImage(config), imageTint = hero and { 255, 255, 255, 255 } or { 120, 120, 120, 220 } },
            UI.Panel { width = 32, height = 32, position = "absolute", left = 14, top = 18, backgroundImage = QUALITY_ICON_PATHS[quality] or QUALITY_ICON_PATHS[1], backgroundFit = "contain" },
            UI.Label { text = hero and "已获得" or "未获得", position = "absolute", left = 20, top = 174, width = 96, height = 26, fontSize = 15, fontWeight = "bold", fontColor = hero and { 202, 92, 44, 255 } or { 88, 46, 45, 220 }, backgroundColor = { 207, 166, 119, 190 }, borderRadius = 12, textAlign = "center" },
            UI.Label { text = tostring(config.name or entry.npcId), position = "absolute", left = 138, top = 18, width = 128, fontSize = 23, fontWeight = "bold", fontColor = { 88, 46, 45, 255 }, maxLines = 1 },
            UI.Label { text = (QUALITY_NAMES[quality] or "普通") .. " · " .. tostring(config.profession or "战士"), position = "absolute", left = 138, top = 54, width = 128, fontSize = 15, fontWeight = "bold", fontColor = GetQualityColor(config), textStroke = { width = 1, color = { 68, 45, 25, 150 } }, maxLines = 1 },
            self:CreateInfoRow("阵营", tostring(config.faction or "王国"), 138, 88),
            self:CreateInfoRow("站位", tostring(config.role or "前排"), 138, 120),
            self:CreateInfoRow("星级", tostring(star) .. "星", 138, 152),
            self:CreateInfoRow("战力", FormatNumber(hero and hero.power or config.power), 138, 184),
            UI.Panel { width = 18, height = 18, position = "absolute", left = 207, top = 154, backgroundImage = STAR_ICON_PATH, backgroundFit = "contain" },
        },
    }
end

function HeroCodexScene:CreateInfoRow(label, value, left, top)
    return UI.Panel {
        position = "absolute",
        left = left,
        top = top,
        width = 126,
        height = 26,
        flexDirection = "row",
        alignItems = "center",
        backgroundColor = { 207, 166, 119, 170 },
        borderRadius = 9,
        paddingLeft = 7,
        paddingRight = 7,
        children = {
            UI.Label { text = label, flexGrow = 1, fontSize = 14, fontColor = { 88, 46, 45, 255 }, maxLines = 1 },
            UI.Label { text = value, fontSize = 14, fontWeight = "bold", fontColor = { 255, 255, 255, 255 }, textStroke = { width = 1, color = { 68, 45, 25, 220 } }, textAlign = "right", maxLines = 1 },
        },
    }
end

function HeroCodexScene:CreateAttributePanel(entry)
    local tables = ConfigManager.GetTables()
    local config = entry.config
    local attributeConfig = tables.attributes and tables.attributes[tostring(config.BaseAttributeID or 1)] or {}
    local rows = {}
    for _, attr in ipairs(ATTRIBUTE_LABELS) do
        rows[#rows + 1] = self:CreateAttributeRow(attr.label, GetAttributeValue(attributeConfig, attr.id))
    end
    return UI.Panel {
        width = "100%",
        height = 160,
        padding = 9,
        gap = 6,
        backgroundColor = { 113, 74, 58, 230 },
        borderColor = { 68, 45, 25, 255 },
        borderWidth = 2,
        borderRadius = 16,
        children = {
            UI.Label { text = "基础属性", fontSize = 19, fontWeight = "bold", fontColor = { 255, 235, 178, 255 }, textStroke = { width = 2, color = { 0, 0, 0, 180 } } },
            UI.Panel { width = "100%", flexGrow = 1, flexBasis = 0, flexDirection = "row", flexWrap = "wrap", gap = 5, children = rows },
        },
    }
end

function HeroCodexScene:CreateAttributeRow(label, value)
    return UI.Panel {
        width = 118,
        height = 31,
        flexDirection = "row",
        alignItems = "center",
        paddingLeft = 6,
        paddingRight = 6,
        backgroundColor = { 245, 228, 200, 240 },
        borderRadius = 9,
        children = {
            UI.Label { text = label, flexGrow = 1, fontSize = 13, fontColor = { 88, 46, 45, 255 }, maxLines = 1 },
            UI.Label { text = FormatNumber(value), fontSize = 13, fontWeight = "bold", fontColor = { 202, 92, 44, 255 }, textAlign = "right", maxLines = 1 },
        },
    }
end

function HeroCodexScene:CreateSkillPanel(entry)
    local skillChildren = {}
    local skills = type(entry.config.Skill) == "table" and entry.config.Skill or {}
    for index = 1, 5 do
        local skillId = skills[index]
        skillChildren[#skillChildren + 1] = UI.Panel {
            width = 76,
            height = 54,
            padding = 5,
            backgroundColor = skillId and { 245, 228, 200, 255 } or { 117, 79, 62, 170 },
            borderColor = skillId and { 68, 45, 25, 220 } or { 68, 45, 25, 120 },
            borderWidth = 2,
            borderRadius = 12,
            children = {
                UI.Label { text = skillId and GetSkillName(skillId) or "技能槽", fontSize = 13, fontWeight = "bold", fontColor = skillId and { 88, 46, 45, 255 } or { 255, 244, 220, 220 }, textAlign = "center", maxLines = 1 },
                UI.Label { text = skillId and ("ID " .. tostring(skillId)) or "未配置", fontSize = 11, fontColor = skillId and { 202, 92, 44, 255 } or { 255, 244, 220, 180 }, textAlign = "center", maxLines = 1 },
            },
        }
    end

    return UI.Panel {
        width = "100%",
        height = 126,
        padding = 9,
        gap = 6,
        backgroundColor = { 113, 74, 58, 230 },
        borderColor = { 68, 45, 25, 255 },
        borderWidth = 2,
        borderRadius = 16,
        children = {
            UI.Label { text = "技能配置", fontSize = 19, fontWeight = "bold", fontColor = { 255, 235, 178, 255 }, textStroke = { width = 2, color = { 0, 0, 0, 180 } } },
            UI.Panel { width = "100%", flexDirection = "row", flexWrap = "wrap", gap = 5, children = skillChildren },
        },
    }
end

function HeroCodexScene:CreateRewardPanel(entry, hero, codex)
    local config = entry.config
    local ownedClaimed = IsOwnedRewardClaimed(codex, entry.npcId)
    local ownedCanClaim = HasClaimableOwnedReward(hero, codex, entry.npcId)
    local nextStar = GetNextClaimableStar(hero, codex, entry.npcId)
    local starRows = {}
    for _, star in ipairs(STAR_REWARD_STARS) do
        starRows[#starRows + 1] = self:CreateStarRewardRow(entry, hero, codex, star)
    end

    return UI.Panel {
        width = "100%",
        height = 230,
        padding = 9,
        gap = 6,
        backgroundColor = { 113, 74, 58, 230 },
        borderColor = { 68, 45, 25, 255 },
        borderWidth = 2,
        borderRadius = 16,
        children = {
            UI.Label { text = "图鉴奖励", fontSize = 19, fontWeight = "bold", fontColor = { 255, 235, 178, 255 }, textStroke = { width = 2, color = { 0, 0, 0, 180 } } },
            UI.Panel { width = "100%", height = 36, flexDirection = "row", alignItems = "center", gap = 6, children = {
                UI.Label { text = ownedClaimed and "激活奖励已领取" or (hero and "可领取激活奖励" or "获得后可领激活奖励"), flexGrow = 1, flexShrink = 1, fontSize = 14, fontColor = { 255, 244, 220, 235 }, maxLines = 1 },
                UI.Button { text = "+" .. FormatNumber(GetOwnedRewardAmount(config)), width = 76, height = 32, fontSize = 15, backgroundColor = ownedCanClaim and { 202, 92, 44, 255 } or { 117, 79, 62, 180 }, textColor = { 255, 244, 220, 255 }, borderRadius = 13, onClick = function() self:ClaimOwnedReward() end },
            } },
            UI.Panel { width = "100%", flexGrow = 1, flexBasis = 0, gap = 4, children = starRows },
            UI.Button { text = nextStar and ("领取" .. tostring(nextStar) .. "星奖励") or "暂无星级奖励", width = "100%", height = 34, fontSize = 16, fontWeight = "bold", backgroundColor = nextStar and { 202, 92, 44, 255 } or { 117, 79, 62, 180 }, textColor = { 255, 244, 220, 255 }, borderRadius = 14, onClick = function() self:ClaimStarReward() end },
        },
    }
end

function HeroCodexScene:CreateStarRewardRow(entry, hero, codex, star)
    local reached = hero and math.floor(tonumber(hero.star) or 1) >= star
    local claimed = IsStarRewardClaimed(codex, entry.npcId, star)
    local status = claimed and "已领" or (reached and "可领" or "未达成")
    return UI.Panel {
        width = "100%",
        height = 23,
        flexDirection = "row",
        alignItems = "center",
        paddingLeft = 8,
        paddingRight = 8,
        backgroundColor = reached and { 245, 228, 200, 240 } or { 207, 166, 119, 155 },
        borderRadius = 9,
        children = {
            UI.Label { text = tostring(star) .. "星", width = 44, fontSize = 13, fontWeight = "bold", fontColor = { 88, 46, 45, 255 }, maxLines = 1 },
            UI.Label { text = "蓝钻+" .. FormatNumber(GetStarRewardAmount(entry.config, star)), flexGrow = 1, fontSize = 13, fontColor = { 202, 92, 44, 255 }, maxLines = 1 },
            UI.Label { text = status, width = 42, fontSize = 12, fontColor = claimed and { 38, 126, 56, 255 } or (reached and { 202, 92, 44, 255 } or { 88, 46, 45, 200 }), textAlign = "right", maxLines = 1 },
        },
    }
end

function HeroCodexScene:CreateBottomActions(saveData, entry, hero, codex)
    local ownedCanClaim = entry and HasClaimableOwnedReward(hero, codex, entry.npcId)
    local nextStar = entry and GetNextClaimableStar(hero, codex, entry.npcId) or nil
    return UI.Panel {
        position = "absolute",
        width = "95.2%",
        height = 51,
        left = 25,
        top = 1113,
        flexDirection = "row",
        gap = 12,
        children = {
            UI.Label { text = entry and ("当前图鉴：" .. tostring(entry.config.name or entry.npcId)) or "请选择英雄", width = 330, height = 46, position = "absolute", left = 0, top = 0, fontSize = 18, fontColor = { 255, 235, 178, 255 }, textStroke = { width = 2, color = { 0, 0, 0, 180 } }, maxLines = 2 },
            UI.Button { text = ownedCanClaim and "领激活" or "激活奖励", width = 137.65, height = 46, position = "absolute", left = 340, top = 0, paddingTop = 0, paddingRight = 16, paddingBottom = 4, paddingLeft = 16, fontSize = 20, backgroundColor = ownedCanClaim and { 202, 92, 44, 255 } or { 117, 79, 62, 180 }, textColor = { 255, 244, 220, 255 }, borderRadius = 18, onClick = function() self:ClaimOwnedReward() end },
            UI.Button { text = nextStar and (tostring(nextStar) .. "星奖励") or "星级奖励", width = 137, height = 47, position = "absolute", left = 510, top = 0, paddingTop = 0, paddingRight = 16, paddingBottom = 4, paddingLeft = 16, fontSize = 20, fontWeight = "bold", backgroundColor = nextStar and { 88, 130, 72, 255 } or { 117, 79, 62, 180 }, textColor = { 255, 244, 220, 255 }, borderRadius = 18, onClick = function() self:ClaimStarReward() end },
        },
    }
end

return HeroCodexScene
