local UI = require("urhox-libs/UI")
local SaveManager = require("Save.SaveManager")

local FormationScene = {}
FormationScene.__index = FormationScene

local DESIGN_WIDTH = 720
local DESIGN_HEIGHT = 1280
local HERO_IMAGE = "image/npcClip/1/01.png"

local SLOT_ROWS = {
    { label = "前排", ids = { "front1", "front2", "front3" } },
    { label = "后排", ids = { "back1", "back2", "back3" } },
}

local SLOT_LABELS = {
    front1 = "前排1",
    front2 = "前排2",
    front3 = "前排3",
    back1 = "后排1",
    back2 = "后排2",
    back3 = "后排3",
}

local SLOT_UNLOCK_LEVEL = {
    front1 = 1,
    front2 = 1,
    back1 = 1,
    back2 = 1,
    front3 = 10,
    back3 = 15,
}

local QUALITY_COLORS = {
    [1] = { 181, 181, 181, 255 },
    [2] = { 162, 255, 148, 255 },
    [3] = { 114, 242, 245, 255 },
    [4] = { 239, 121, 255, 255 },
    [5] = { 255, 237, 0, 255 },
    [6] = { 255, 0, 0, 255 },
}

local SORT_LABELS = {
    power = "战力",
    quality = "品质",
    job = "职业",
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

local function CopyArray(source)
    local result = {}
    for i, value in ipairs(source or {}) do
        result[i] = value
    end
    return result
end

local function GetSaveData()
    return SaveManager.GetSaveData() or {}
end

local function GetPlayerLevel()
    local saveData = GetSaveData()
    return saveData.partner and saveData.partner.level or 1
end

local function GetActiveFormation(lineup)
    lineup = lineup or {}
    local activeIndex = math.max(1, math.min(3, math.floor(tonumber(lineup.activeFormation) or 1)))
    return activeIndex, lineup.formations and lineup.formations[activeIndex] or nil
end

local function GetHeroMap(heroes)
    local heroMap = {}
    for _, hero in ipairs(heroes or {}) do
        heroMap[hero.id] = hero
    end
    return heroMap
end

local function IsSlotUnlocked(slotId)
    return GetPlayerLevel() >= (SLOT_UNLOCK_LEVEL[slotId] or 1)
end

local function IsHeroAssigned(formation, heroId)
    if not formation or not formation.slots then return false end
    for _, row in ipairs(SLOT_ROWS) do
        for _, slotId in ipairs(row.ids) do
            if formation.slots[slotId] == heroId then
                return true
            end
        end
    end
    return false
end

local function CountAssignedSlots(formation)
    local count = 0
    if not formation or not formation.slots then return count end
    for _, row in ipairs(SLOT_ROWS) do
        for _, slotId in ipairs(row.ids) do
            if formation.slots[slotId] then
                count = count + 1
            end
        end
    end
    return count
end

local function CalculateFormationPower(formation, heroMap)
    local power = 0
    if not formation or not formation.slots then return power end
    for _, row in ipairs(SLOT_ROWS) do
        for _, slotId in ipairs(row.ids) do
            local hero = heroMap[formation.slots[slotId]]
            if hero then
                power = power + (hero.power or 0)
            end
        end
    end
    return power
end

local function GetBondInfo(formation, heroMap)
    local jobCounts = {}
    local factionCounts = {}
    if formation and formation.slots then
        for _, row in ipairs(SLOT_ROWS) do
            for _, slotId in ipairs(row.ids) do
                local hero = heroMap[formation.slots[slotId]]
                if hero then
                    jobCounts[hero.job] = (jobCounts[hero.job] or 0) + 1
                    factionCounts[hero.faction] = (factionCounts[hero.faction] or 0) + 1
                end
            end
        end
    end

    local bonds = {}
    for job, count in pairs(jobCounts) do
        if count >= 2 then
            bonds[#bonds + 1] = { text = job .. "职业 x" .. count .. "  攻击+" .. tostring(count * 3) .. "%", active = true }
        end
    end
    for faction, count in pairs(factionCounts) do
        if count >= 2 then
            bonds[#bonds + 1] = { text = faction .. "阵营 x" .. count .. "  生命+" .. tostring(count * 3) .. "%", active = true }
        end
    end
    if #bonds == 0 then
        bonds[1] = { text = "暂无羁绊，尝试上阵同职业或同阵营勇者", active = false }
    end
    return bonds
end

function FormationScene:new(options)
    local o = setmetatable({}, self)
    o.onExit = options and options.onExit or nil
    o.root = nil
    o.selectedHeroId = nil
    o.selectedSlotId = nil
    o.sortMode = "power"
    o.statusText = "选择待机勇者后点击空位上阵，或先选站位再替换。"
    return o
end

function FormationScene:GetData()
    local saveData = GetSaveData()
    local lineup = saveData.lineup or {}
    local heroes = saveData.heroes or {}
    local heroMap = GetHeroMap(heroes)
    local activeIndex, formation = GetActiveFormation(lineup)
    return saveData, lineup, heroes, heroMap, activeIndex, formation
end

function FormationScene:SetStatus(text)
    self.statusText = text
end

function FormationScene:SaveAndRefresh(reason)
    SaveManager.SaveGameSnapshot(reason, function()
        print("[Formation] Saved: " .. tostring(reason))
    end, function(errorMessage)
        print("[Formation] Save failed: " .. tostring(errorMessage))
    end)
    self:Refresh()
end

function FormationScene:Refresh()
    self.root = self:CreateRoot()
    UI.SetRoot(self.root, true)
end

function FormationScene:IsFormationLocked(formation)
    return formation and formation.locked == true
end

function FormationScene:IsSlotLocked(formation, slotId)
    return self:IsFormationLocked(formation) or (formation and formation.slotLocks and formation.slotLocks[slotId] == true)
end

function FormationScene:AssignHeroToSlot(heroId, slotId)
    local _, _, _, _, activeIndex, formation = self:GetData()
    if not formation then return end
    if not IsSlotUnlocked(slotId) then
        self:SetStatus("该站位尚未解锁。")
        self:Refresh()
        return
    end
    if self:IsSlotLocked(formation, slotId) then
        self:SetStatus("该站位已锁定，无法替换。")
        self:Refresh()
        return
    end

    for _, row in ipairs(SLOT_ROWS) do
        for _, currentSlotId in ipairs(row.ids) do
            if formation.slots[currentSlotId] == heroId then
                formation.slots[currentSlotId] = nil
            end
        end
    end

    formation.slots[slotId] = heroId
    formation.savedAt = os.time()
    self.selectedHeroId = heroId
    self.selectedSlotId = slotId
    self:SetStatus("已更新阵容" .. tostring(activeIndex) .. "的" .. SLOT_LABELS[slotId] .. "。")
    self:SaveAndRefresh("编队上阵/替换")
end

function FormationScene:RemoveSlot(slotId)
    local _, _, _, _, _, formation = self:GetData()
    if not formation or not formation.slots or not formation.slots[slotId] then return end
    if self:IsSlotLocked(formation, slotId) then
        self:SetStatus("该站位已锁定，无法下阵。")
        self:Refresh()
        return
    end
    formation.slots[slotId] = nil
    formation.savedAt = os.time()
    self.selectedSlotId = nil
    self:SetStatus("已下阵" .. SLOT_LABELS[slotId] .. "。")
    self:SaveAndRefresh("编队下阵")
end

function FormationScene:ToggleSlotLock(slotId)
    local _, _, _, _, _, formation = self:GetData()
    if not formation then return end
    formation.slotLocks = formation.slotLocks or {}
    formation.slotLocks[slotId] = not formation.slotLocks[slotId]
    formation.savedAt = os.time()
    self:SetStatus(SLOT_LABELS[slotId] .. (formation.slotLocks[slotId] and "已锁定。" or "已解锁。"))
    self:SaveAndRefresh("编队单格锁定")
end

function FormationScene:ToggleFormationLock()
    local _, _, _, _, activeIndex, formation = self:GetData()
    if not formation then return end
    formation.locked = not formation.locked
    formation.savedAt = os.time()
    self:SetStatus("阵容" .. tostring(activeIndex) .. (formation.locked and "已全锁。" or "已解除全锁。"))
    self:SaveAndRefresh("编队全锁")
end

function FormationScene:SwitchFormation(index)
    local _, lineup = self:GetData()
    lineup.activeFormation = index
    self.selectedHeroId = nil
    self.selectedSlotId = nil
    self:SetStatus("已切换到阵容" .. tostring(index) .. "。")
    self:SaveAndRefresh("切换编队")
end

function FormationScene:ClearFormation()
    local _, _, _, _, activeIndex, formation = self:GetData()
    if not formation then return end
    if self:IsFormationLocked(formation) then
        self:SetStatus("阵容已全锁，无法清空。")
        self:Refresh()
        return
    end
    formation.slots = {}
    formation.slotLocks = {}
    formation.savedAt = os.time()
    self.selectedHeroId = nil
    self.selectedSlotId = nil
    self:SetStatus("阵容" .. tostring(activeIndex) .. "已清空。")
    self:SaveAndRefresh("清空编队")
end

function FormationScene:AutoFillFormation()
    local _, _, heroes, _, activeIndex, formation = self:GetData()
    if not formation then return end
    if self:IsFormationLocked(formation) then
        self:SetStatus("阵容已全锁，无法一键上阵。")
        self:Refresh()
        return
    end

    local sortedHeroes = CopyArray(heroes)
    table.sort(sortedHeroes, function(a, b)
        if a.quality ~= b.quality then return a.quality > b.quality end
        if a.star ~= b.star then return a.star > b.star end
        return a.power > b.power
    end)

    local used = {}
    for _, row in ipairs(SLOT_ROWS) do
        for _, slotId in ipairs(row.ids) do
            if IsSlotUnlocked(slotId) and not self:IsSlotLocked(formation, slotId) then
                local preferredRole = row.label
                local chosen = nil
                for _, hero in ipairs(sortedHeroes) do
                    if not used[hero.id] and hero.role == preferredRole then
                        chosen = hero
                        break
                    end
                end
                if not chosen then
                    for _, hero in ipairs(sortedHeroes) do
                        if not used[hero.id] then
                            chosen = hero
                            break
                        end
                    end
                end
                if chosen then
                    formation.slots[slotId] = chosen.id
                    used[chosen.id] = true
                end
            elseif formation.slots[slotId] then
                used[formation.slots[slotId]] = true
            end
        end
    end

    formation.savedAt = os.time()
    self:SetStatus("阵容" .. tostring(activeIndex) .. "已按品质、星级、战力推荐上阵。")
    self:SaveAndRefresh("智能上阵推荐")
end

function FormationScene:ToggleRecommend()
    local _, lineup = self:GetData()
    lineup.recommendEnabled = not (lineup.recommendEnabled == true)
    self:SetStatus(lineup.recommendEnabled and "已开启智能推荐。" or "已关闭智能推荐。")
    self:SaveAndRefresh("切换智能推荐")
end

function FormationScene:SetSortMode(sortMode)
    self.sortMode = sortMode
    self:SetStatus("勇者列表按" .. SORT_LABELS[sortMode] .. "排序。")
    self:Refresh()
end

function FormationScene:CreateRoot()
    local _, lineup, heroes, heroMap, activeIndex, formation = self:GetData()
    local totalPower = CalculateFormationPower(formation, heroMap)

    return UI.Panel {
        id = "formationScreen",
        width = DESIGN_WIDTH,
        height = DESIGN_HEIGHT,
        backgroundColor = { 42, 30, 24, 255 },
        overflow = "hidden",
        children = {
            self:CreateBackground(),
            self:CreateTopBar(totalPower, lineup, activeIndex, formation),
            self:CreateContent(heroes, heroMap, formation),
            self:CreateBottomActions(formation, heroMap),
        },
    }
end

function FormationScene:CreateBackground()
    return UI.Panel {
        position = "absolute",
        left = 0,
        top = 0,
        right = 0,
        bottom = 0,
        backgroundColor = { 88, 52, 34, 255 },
        children = {
            UI.Panel { position = "absolute", left = 18, top = 92, right = 18, bottom = 132, backgroundColor = { 245, 228, 200, 238 }, borderColor = { 68, 45, 25, 255 }, borderWidth = 4, borderRadius = 22 },
        },
    }
end

function FormationScene:CreateTopBar(totalPower, lineup, activeIndex, formation)
    local tabs = {}
    for i = 1, 3 do
        tabs[#tabs + 1] = UI.Button {
            text = "阵容" .. tostring(i),
            width = 104,
            height = 42,
            fontSize = 18,
            backgroundColor = i == activeIndex and { 202, 92, 44, 255 } or { 113, 74, 58, 255 },
            pressedBackgroundColor = { 155, 62, 36, 255 },
            textColor = { 255, 244, 220, 255 },
            borderRadius = 16,
            onClick = function()
                self:SwitchFormation(i)
            end,
        }
    end

    return UI.Panel {
        position = "absolute",
        left = 0,
        top = 0,
        right = 0,
        height = 162,
        paddingTop = 16,
        paddingHorizontal = 22,
        gap = 8,
        backgroundColor = { 68, 45, 25, 255 },
        children = {
            UI.Panel {
                width = "100%",
                height = 48,
                flexDirection = "row",
                alignItems = "center",
                justifyContent = "space-between",
                children = {
                    UI.Button { text = "返回", width = 86, height = 38, fontSize = 18, backgroundColor = { 117, 79, 62, 255 }, textColor = { 255, 244, 220, 255 }, borderRadius = 16, onClick = function() if self.onExit then self.onExit() end end },
                    UI.Label { text = "勇者编队", fontSize = 30, fontWeight = "bold", fontColor = { 255, 235, 178, 255 }, textAlign = "center", textStroke = { width = 2, color = { 0, 0, 0, 220 } } },
                    UI.Button { text = formation and formation.locked and "全锁" or "锁定", width = 86, height = 38, fontSize = 18, backgroundColor = formation and formation.locked and { 168, 48, 40, 255 } or { 117, 79, 62, 255 }, textColor = { 255, 244, 220, 255 }, borderRadius = 16, onClick = function() self:ToggleFormationLock() end },
                },
            },
            UI.Panel {
                width = "100%",
                height = 38,
                flexDirection = "row",
                alignItems = "center",
                justifyContent = "space-between",
                children = {
                    UI.Label { text = "总战力 " .. FormatNumber(totalPower), fontSize = 24, fontWeight = "bold", fontColor = { 255, 234, 0, 255 }, textStroke = { width = 2, color = { 0, 0, 0, 220 } } },
                    UI.Label { text = lineup.recommendEnabled and "智能推荐：开" or "智能推荐：关", fontSize = 18, fontColor = { 245, 228, 200, 255 } },
                },
            },
            UI.Panel { width = "100%", height = 44, flexDirection = "row", justifyContent = "center", gap = 12, children = tabs },
        },
    }
end

function FormationScene:CreateContent(heroes, heroMap, formation)
    return UI.Panel {
        position = "absolute",
        left = 28,
        right = 28,
        top = 178,
        bottom = 245,
        flexDirection = "row",
        gap = 12,
        children = {
            self:CreateHeroList(heroes, formation),
            self:CreateFormationBoard(heroMap, formation),
        },
    }
end

function FormationScene:CreateHeroList(heroes, formation)
    local sortedHeroes = CopyArray(heroes)
    table.sort(sortedHeroes, function(a, b)
        if self.sortMode == "quality" then
            if a.quality ~= b.quality then return a.quality > b.quality end
            if a.star ~= b.star then return a.star > b.star end
            return a.power > b.power
        end
        if self.sortMode == "job" then
            if a.job ~= b.job then return a.job < b.job end
            return a.power > b.power
        end
        return a.power > b.power
    end)

    local heroCards = {}
    for _, hero in ipairs(sortedHeroes) do
        heroCards[#heroCards + 1] = self:CreateHeroCard(hero, formation)
    end

    return UI.Panel {
        width = 288,
        height = "100%",
        padding = 10,
        gap = 8,
        backgroundColor = { 113, 74, 58, 245 },
        borderColor = { 68, 45, 25, 255 },
        borderWidth = 3,
        borderRadius = 18,
        children = {
            UI.Label { text = "勇者列表", fontSize = 24, fontWeight = "bold", fontColor = { 255, 235, 178, 255 }, textAlign = "center", textStroke = { width = 2, color = { 0, 0, 0, 200 } } },
            UI.Panel { width = "100%", height = 36, flexDirection = "row", gap = 6, children = {
                self:CreateSortButton("power"),
                self:CreateSortButton("quality"),
                self:CreateSortButton("job"),
            } },
            UI.ScrollView {
                width = "100%",
                flexGrow = 1,
                flexBasis = 0,
                scrollY = true,
                showScrollbar = true,
                gap = 8,
                children = heroCards,
            },
        },
    }
end

function FormationScene:CreateSortButton(sortMode)
    return UI.Button {
        text = SORT_LABELS[sortMode],
        flexGrow = 1,
        height = 32,
        fontSize = 15,
        backgroundColor = self.sortMode == sortMode and { 202, 92, 44, 255 } or { 88, 46, 45, 255 },
        textColor = { 255, 244, 220, 255 },
        borderRadius = 12,
        onClick = function()
            self:SetSortMode(sortMode)
        end,
    }
end

function FormationScene:CreateHeroCard(hero, formation)
    local assigned = IsHeroAssigned(formation, hero.id)
    local selected = self.selectedHeroId == hero.id
    local qualityColor = QUALITY_COLORS[hero.quality] or QUALITY_COLORS[1]
    return UI.Panel {
        width = "100%",
        height = 92,
        flexDirection = "row",
        alignItems = "center",
        padding = 8,
        gap = 8,
        backgroundColor = selected and { 255, 244, 205, 255 } or { 245, 228, 200, 255 },
        borderColor = selected and { 255, 234, 0, 255 } or qualityColor,
        borderWidth = selected and 4 or 2,
        borderRadius = 14,
        onClick = function()
            if self.selectedSlotId then
                self:AssignHeroToSlot(hero.id, self.selectedSlotId)
                return
            end
            self.selectedHeroId = hero.id
            self:SetStatus(assigned and (hero.name .. "已出战，可选择站位替换。") or ("已选择" .. hero.name .. "，点击空站位上阵。"))
            self:Refresh()
        end,
        children = {
            UI.Panel { width = 58, height = 58, backgroundImage = HERO_IMAGE, backgroundFit = "contain", imageTint = assigned and { 210, 235, 255, 255 } or { 255, 255, 255, 255 } },
            UI.Panel { flexGrow = 1, flexShrink = 1, gap = 3, children = {
                UI.Label { text = hero.name, fontSize = 18, fontWeight = "bold", fontColor = { 88, 46, 45, 255 }, maxLines = 1 },
                UI.Label { text = "品质" .. tostring(hero.quality) .. "  星" .. tostring(hero.star) .. "  " .. hero.job, fontSize = 14, fontColor = { 88, 46, 45, 220 }, maxLines = 1 },
                UI.Label { text = hero.faction .. " · " .. hero.role .. " · 战力" .. FormatNumber(hero.power), fontSize = 13, fontColor = { 74, 56, 42, 220 }, maxLines = 1 },
            } },
            UI.Label { text = assigned and "出战" or "待机", width = 42, fontSize = 15, fontWeight = "bold", fontColor = assigned and { 202, 92, 44, 255 } or { 74, 56, 42, 220 }, textAlign = "center" },
        },
    }
end

function FormationScene:CreateFormationBoard(heroMap, formation)
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
        children = {
            UI.Label { text = formation and (formation.name .. " · " .. formation.usage) or "阵容", fontSize = 24, fontWeight = "bold", fontColor = { 117, 79, 62, 255 }, textAlign = "center" },
            self:CreateSlotRows(heroMap, formation),
            self:CreateBondPanel(formation, heroMap),
            self:CreateSlotActionPanel(formation),
        },
    }
end

function FormationScene:CreateSlotRows(heroMap, formation)
    local children = {}
    for _, row in ipairs(SLOT_ROWS) do
        local slotWidgets = {}
        slotWidgets[#slotWidgets + 1] = UI.Label { text = row.label, width = 48, fontSize = 20, fontWeight = "bold", fontColor = { 88, 46, 45, 255 }, textAlign = "center" }
        for _, slotId in ipairs(row.ids) do
            slotWidgets[#slotWidgets + 1] = self:CreateSlot(slotId, heroMap, formation)
        end
        children[#children + 1] = UI.Panel { width = "100%", height = 148, flexDirection = "row", alignItems = "center", gap = 8, children = slotWidgets }
    end
    return UI.Panel { width = "100%", gap = 10, children = children }
end

function FormationScene:CreateSlot(slotId, heroMap, formation)
    local unlocked = IsSlotUnlocked(slotId)
    local hero = formation and formation.slots and heroMap[formation.slots[slotId]] or nil
    local selected = self.selectedSlotId == slotId
    local locked = self:IsSlotLocked(formation, slotId)
    return UI.Panel {
        flexGrow = 1,
        flexShrink = 1,
        height = 138,
        alignItems = "center",
        justifyContent = "center",
        padding = 6,
        gap = 4,
        backgroundColor = selected and { 255, 244, 205, 255 } or { 207, 166, 119, 255 },
        borderColor = locked and { 168, 48, 40, 255 } or { 68, 45, 25, 255 },
        borderWidth = selected and 4 or 2,
        borderRadius = 16,
        onClick = function()
            if not unlocked then
                self:SetStatus(SLOT_LABELS[slotId] .. "需要伙伴等级" .. tostring(SLOT_UNLOCK_LEVEL[slotId]) .. "解锁。")
                self:Refresh()
                return
            end
            if self.selectedHeroId then
                self:AssignHeroToSlot(self.selectedHeroId, slotId)
                return
            end
            self.selectedSlotId = slotId
            self.selectedHeroId = hero and hero.id or nil
            self:SetStatus(hero and ("已选择" .. SLOT_LABELS[slotId] .. "，可下阵/锁定/替换。") or ("已选择空位" .. SLOT_LABELS[slotId] .. "，请从左侧选择勇者。"))
            self:Refresh()
        end,
        children = unlocked and self:CreateSlotContent(slotId, hero, locked) or {
            UI.Label { text = SLOT_LABELS[slotId], fontSize = 17, fontWeight = "bold", fontColor = { 88, 46, 45, 255 }, textAlign = "center" },
            UI.Label { text = "Lv." .. tostring(SLOT_UNLOCK_LEVEL[slotId]) .. "解锁", fontSize = 15, fontColor = { 168, 48, 40, 255 }, textAlign = "center" },
        },
    }
end

function FormationScene:CreateSlotContent(slotId, hero, locked)
    if not hero then
        return {
            UI.Label { text = SLOT_LABELS[slotId], fontSize = 17, fontWeight = "bold", fontColor = { 88, 46, 45, 255 }, textAlign = "center" },
            UI.Label { text = "可上阵\n提升战力", fontSize = 16, fontColor = { 117, 79, 62, 220 }, textAlign = "center" },
        }
    end

    return {
        UI.Label { text = locked and "已锁定" or SLOT_LABELS[slotId], fontSize = 14, fontColor = locked and { 168, 48, 40, 255 } or { 88, 46, 45, 255 }, textAlign = "center" },
        UI.Panel { width = 76, height = 62, backgroundImage = HERO_IMAGE, backgroundFit = "contain" },
        UI.Label { text = hero.name, fontSize = 16, fontWeight = "bold", fontColor = { 88, 46, 45, 255 }, textAlign = "center", maxLines = 1 },
        UI.Label { text = FormatNumber(hero.power), fontSize = 14, fontColor = { 202, 92, 44, 255 }, textAlign = "center" },
    }
end

function FormationScene:CreateBondPanel(formation, heroMap)
    local children = {
        UI.Label { text = "羁绊展示", fontSize = 18, fontWeight = "bold", fontColor = { 88, 46, 45, 255 }, textAlign = "center" },
    }
    for _, bond in ipairs(GetBondInfo(formation, heroMap)) do
        children[#children + 1] = UI.Label {
            text = bond.text,
            fontSize = 16,
            fontColor = bond.active and { 202, 92, 44, 255 } or { 88, 46, 45, 200 },
            textAlign = "center",
            maxLines = 1,
        }
    end
    return UI.Panel {
        width = "100%",
        minHeight = 72,
        padding = 8,
        gap = 4,
        backgroundColor = { 255, 244, 220, 255 },
        borderColor = { 207, 166, 119, 255 },
        borderWidth = 2,
        borderRadius = 14,
        children = children,
    }
end

function FormationScene:CreateSlotActionPanel(formation)
    return UI.Panel {
        width = "100%",
        height = 86,
        gap = 6,
        children = {
            UI.Label { text = self.statusText, fontSize = 16, fontColor = { 88, 46, 45, 255 }, textAlign = "center", maxLines = 2 },
            UI.Panel { width = "100%", height = 38, flexDirection = "row", gap = 8, children = {
                UI.Button { text = "下阵", flexGrow = 1, height = 36, fontSize = 16, backgroundColor = { 117, 79, 62, 255 }, textColor = { 255, 244, 220, 255 }, borderRadius = 14, onClick = function() if self.selectedSlotId then self:RemoveSlot(self.selectedSlotId) else self:SetStatus("请先选择一个已上阵站位。") self:Refresh() end end },
                UI.Button { text = "锁定", flexGrow = 1, height = 36, fontSize = 16, backgroundColor = { 117, 79, 62, 255 }, textColor = { 255, 244, 220, 255 }, borderRadius = 14, onClick = function() if self.selectedSlotId then self:ToggleSlotLock(self.selectedSlotId) else self:SetStatus("请先选择一个站位。") self:Refresh() end end },
                UI.Button { text = "详情", flexGrow = 1, height = 36, fontSize = 16, backgroundColor = { 117, 79, 62, 255 }, textColor = { 255, 244, 220, 255 }, borderRadius = 14, onClick = function() self:SetStatus("详情入口已预留：后续接入勇者详情页。") self:Refresh() end },
            } },
        },
    }
end

function FormationScene:CreateBottomActions(formation, heroMap)
    local assignedCount = CountAssignedSlots(formation)
    return UI.Panel {
        position = "absolute",
        left = 0,
        right = 0,
        bottom = 0,
        height = 222,
        padding = 18,
        gap = 12,
        backgroundColor = { 68, 45, 25, 255 },
        children = {
            UI.Label { text = assignedCount < 6 and "空位提示：可上阵提升战力" or "阵容已满员", fontSize = 18, fontColor = { 255, 235, 178, 255 }, textAlign = "center" },
            UI.Panel { width = "100%", height = 48, flexDirection = "row", gap = 12, children = {
                UI.Button { text = "一键上阵", flexGrow = 1, height = 46, fontSize = 20, backgroundColor = { 202, 92, 44, 255 }, textColor = { 255, 244, 220, 255 }, borderRadius = 18, onClick = function() self:AutoFillFormation() end },
                UI.Button { text = "一键清空", flexGrow = 1, height = 46, fontSize = 20, backgroundColor = { 117, 79, 62, 255 }, textColor = { 255, 244, 220, 255 }, borderRadius = 18, onClick = function() self:ClearFormation() end },
            } },
            UI.Panel { width = "100%", height = 48, flexDirection = "row", gap = 12, children = {
                UI.Button { text = "保存阵容", flexGrow = 1, height = 46, fontSize = 20, backgroundColor = { 88, 130, 72, 255 }, textColor = { 255, 244, 220, 255 }, borderRadius = 18, onClick = function() self:SaveAndRefresh("手动保存编队") end },
                UI.Button { text = "推荐开关", flexGrow = 1, height = 46, fontSize = 20, backgroundColor = { 88, 46, 45, 255 }, textColor = { 255, 244, 220, 255 }, borderRadius = 18, onClick = function() self:ToggleRecommend() end },
            } },
        },
    }
end

function FormationScene:Destroy()
    self.root = nil
end

return FormationScene
