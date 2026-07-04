local UI = require("urhox-libs/UI")
local LevelManager = require("Level.LevelManager")

local SecretRealmDialog = {}
SecretRealmDialog.__index = SecretRealmDialog

local DESIGN_WIDTH = 720
local DESIGN_HEIGHT = 1280

local QUALITY_COLORS = {
    N = { 181, 181, 181, 255 },
    R = { 162, 255, 148, 255 },
    SR = { 114, 242, 245, 255 },
    SSR = { 239, 121, 255, 255 },
    UR = { 255, 237, 0, 255 },
}

local SLOT_POSITIONS = {
    front1 = { left = 18, top = 54, label = "前1" },
    front2 = { left = 18, top = 133, label = "前2" },
    front3 = { left = 18, top = 212, label = "前3" },
    mid1 = { left = 119, top = 54, label = "中1" },
    mid2 = { left = 119, top = 133, label = "中2" },
    mid3 = { left = 119, top = 212, label = "中3" },
    back1 = { left = 220, top = 54, label = "后1" },
    back2 = { left = 220, top = 133, label = "后2" },
    back3 = { left = 220, top = 212, label = "后3" },
}

local SLOT_ORDER = { "front1", "front2", "front3", "mid1", "mid2", "mid3", "back1", "back2", "back3" }

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

local function GetRewardText(reward)
    if not reward then return "奖励 x1" end
    return tostring(reward.name or "奖励") .. " x" .. FormatNumber(reward.count or 1)
end

local function GetRewardIcon(reward)
    return tostring(reward and reward.icon or "奖")
end

local function GetQualityColor(enemy)
    return QUALITY_COLORS[tostring(enemy and enemy.qualityText or "N")] or QUALITY_COLORS.N
end

function SecretRealmDialog:new(options)
    local o = setmetatable({}, self)
    o.onClose = options and options.onClose or nil
    o.onChallenge = options and options.onChallenge or nil
    o.saveDataProvider = options and options.saveDataProvider or nil
    o.root = nil
    o.selectedSubLevelId = nil
    o.stage = nil
    o.subLevels = {}
    return o
end

function SecretRealmDialog:Destroy()
    self.root = nil
end

function SecretRealmDialog:GetSaveData()
    if self.saveDataProvider then
        return self.saveDataProvider() or {}
    end
    return {}
end

function SecretRealmDialog:GetData()
    local saveData = self:GetSaveData()
    local stage, subLevels = LevelManager.GetCurrentChapterSubLevels(saveData)
    self.stage = stage
    self.subLevels = subLevels or {}
    if #self.subLevels > 0 then
        local exists = false
        for _, item in ipairs(self.subLevels) do
            if item.subLevelId == self.selectedSubLevelId then
                exists = true
                break
            end
        end
        if not exists then
            self.selectedSubLevelId = self.subLevels[1].subLevelId
        end
    else
        self.selectedSubLevelId = nil
    end
    return saveData, stage, self.subLevels
end

function SecretRealmDialog:GetSelectedSubLevel(subLevels)
    for _, item in ipairs(subLevels or {}) do
        if item.subLevelId == self.selectedSubLevelId then
            return item
        end
    end
    return subLevels and subLevels[1] or nil
end

function SecretRealmDialog:Refresh()
    self.root = self:CreateRoot()
    UI.SetRoot(self.root, true)
end

function SecretRealmDialog:SelectSubLevel(subLevelId)
    self.selectedSubLevelId = subLevelId
    self:Refresh()
end

function SecretRealmDialog:Close()
    if self.onClose then
        self.onClose()
    end
end

function SecretRealmDialog:ChallengeSelected()
    if self.onChallenge then
        self.onChallenge(self:GetSelectedSubLevel(self.subLevels))
    end
end

function SecretRealmDialog:CreateRoot()
    local _, stage, subLevels = self:GetData()
    local selected = self:GetSelectedSubLevel(subLevels)
    local title = stage and ("第" .. tostring(stage.stageId) .. "章 · " .. tostring(stage.sceneName)) or "秘境挑战"
    return UI.Panel {
        id = "secretRealmDialogRoot",
        width = DESIGN_WIDTH,
        height = DESIGN_HEIGHT,
        backgroundColor = { 42, 30, 24, 255 },
        overflow = "hidden",
        children = {
            self:CreateBackground(),
            UI.Label { text = "秘境挑战", position = "absolute", left = 19, top = 66, zIndex = 10, fontSize = 30, fontWeight = "bold", fontColor = { 255, 235, 178, 255 }, textAlign = "center", textStroke = { width = 2, color = { 0, 0, 0, 220 } } },
            UI.Label { text = title, position = "absolute", left = 330, top = 114, width = 368, zIndex = 10, fontSize = 20, fontWeight = "bold", fontColor = { 255, 234, 0, 255 }, textAlign = "right", textStroke = { width = 2, color = { 0, 0, 0, 220 } }, maxLines = 1 },
            UI.Button { width = 164, height = 58, position = "absolute", left = 0, top = 1183, zIndex = 10, paddingTop = 0, paddingRight = 0, paddingBottom = 0, paddingLeft = 0, fontSize = 18, backgroundImage = "image/BT-返回.png", backgroundFit = "cover", backgroundColor = { 251, 251, 251, 0 }, opacity = 1, textColor = { 255, 255, 255, 0 }, borderRadius = 0, onClick = function() self:Close() end },
            UI.Panel {
                position = "absolute",
                left = 16,
                right = 26,
                top = 170,
                height = 890,
                zIndex = 5,
                flexDirection = "row",
                gap = 12,
                children = {
                    self:CreateLevelList(subLevels),
                    self:CreateDetailPanel(selected),
                },
            },
            self:CreateFooter(selected),
        },
    }
end

function SecretRealmDialog:CreateBackground()
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

function SecretRealmDialog:CreateHeader(stage)
    local title = stage and ("第" .. tostring(stage.stageId) .. "章 · " .. tostring(stage.sceneName)) or "秘境挑战"
    return UI.Panel {
        width = "100%",
        height = 70,
        flexDirection = "row",
        alignItems = "center",
        backgroundColor = { 113, 74, 58, 255 },
        borderColor = { 68, 45, 25, 255 },
        borderWidth = 2,
        borderRadius = 18,
        paddingLeft = 18,
        paddingRight = 10,
        children = {
            UI.Label {
                text = title,
                flexGrow = 1,
                flexShrink = 1,
                fontSize = 28,
                fontWeight = "bold",
                fontColor = { 255, 235, 178, 255 },
                textStroke = { width = 2, color = { 0, 0, 0, 220 } },
            },
            UI.Button {
                text = "关闭",
                width = 104,
                height = 46,
                fontSize = 20,
                backgroundColor = { 158, 48, 30, 255 },
                pressedBackgroundColor = { 120, 32, 22, 255 },
                textColor = { 255, 245, 220, 255 },
                borderRadius = 16,
                onClick = function()
                    self:Close()
                end,
            },
        },
    }
end

function SecretRealmDialog:CreateLevelList(subLevels)
    local levelItems = {}
    for _, item in ipairs(subLevels or {}) do
        levelItems[#levelItems + 1] = self:CreateLevelRow(item)
    end
    return UI.Panel {
        width = 282,
        height = "100%",
        gap = 10,
        padding = 10,
        backgroundColor = { 113, 74, 58, 245 },
        borderColor = { 68, 45, 25, 255 },
        borderWidth = 3,
        borderRadius = 18,
        children = {
            UI.Label {
                text = "当前章节关卡",
                fontSize = 23,
                fontWeight = "bold",
                fontColor = { 255, 235, 178, 255 },
                textAlign = "center",
                textStroke = { width = 2, color = { 0, 0, 0, 200 } },
            },
            UI.ScrollView {
                width = "100%",
                flexGrow = 1,
                flexBasis = 0,
                scrollY = true,
                showScrollbar = true,
                children = {
                    UI.Panel {
                        width = "100%",
                        gap = 8,
                        children = levelItems,
                    },
                },
            },
        },
    }
end

function SecretRealmDialog:CreateLevelRow(item)
    local selected = item and item.subLevelId == self.selectedSubLevelId
    local rewards = item and item.firstClearRewards or {}
    local previewReward = rewards[1]
    return UI.Panel {
        width = "100%",
        height = 92,
        padding = 8,
        gap = 5,
        backgroundColor = selected and { 245, 228, 200, 255 } or { 207, 166, 119, 220 },
        borderColor = selected and { 255, 234, 0, 255 } or { 68, 45, 25, 255 },
        borderWidth = selected and 3 or 2,
        borderRadius = 16,
        onClick = function()
            if item then
                self:SelectSubLevel(item.subLevelId)
            end
        end,
        children = {
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                alignItems = "center",
                children = {
                    UI.Label { text = item and item.name or "未知关卡", flexGrow = 1, flexShrink = 1, fontSize = 19, fontWeight = "bold", fontColor = { 68, 45, 25, 255 }, maxLines = 1 },
                    UI.Label { text = item and (item.cleared and "已通关" or "未首通") or "", fontSize = 15, fontColor = item and item.cleared and { 38, 126, 56, 255 } or { 172, 56, 38, 255 } },
                },
            },
            UI.Panel {
                width = "100%",
                height = 34,
                flexDirection = "row",
                alignItems = "center",
                gap = 6,
                children = {
                    UI.Panel { width = 30, height = 30, borderRadius = 8, backgroundColor = { 88, 46, 45, 255 }, alignItems = "center", justifyContent = "center", children = { UI.Label { text = GetRewardIcon(previewReward), fontSize = 17, fontWeight = "bold", fontColor = { 255, 234, 0, 255 }, textAlign = "center" } } },
                    UI.Label { text = "首通 " .. GetRewardText(previewReward), flexGrow = 1, flexShrink = 1, fontSize = 15, fontColor = { 88, 46, 45, 255 }, maxLines = 1 },
                },
            },
        },
    }
end

function SecretRealmDialog:CreateDetailPanel(selected)
    return UI.Panel {
        flexGrow = 1,
        flexShrink = 1,
        height = "100%",
        gap = 10,
        padding = 12,
        backgroundColor = { 245, 228, 200, 248 },
        borderColor = { 68, 45, 25, 255 },
        borderWidth = 3,
        borderRadius = 18,
        children = selected and {
            UI.Label { text = selected.title, fontSize = 24, fontWeight = "bold", fontColor = { 68, 45, 25, 255 }, textAlign = "center", maxLines = 1 },
            self:CreatePowerPanel(selected),
            self:CreateEnemyFormationPanel(selected),
            self:CreateRewardPanel(selected),
        } or {
            UI.Label { text = "暂无可挑战关卡", fontSize = 24, fontWeight = "bold", fontColor = { 68, 45, 25, 255 }, textAlign = "center" },
        },
    }
end

function SecretRealmDialog:CreatePowerPanel(selected)
    return UI.Panel {
        width = "100%",
        height = 48,
        flexDirection = "row",
        alignItems = "center",
        paddingLeft = 14,
        paddingRight = 14,
        backgroundColor = { 113, 74, 58, 235 },
        borderRadius = 14,
        children = {
            UI.Label { text = "关卡总战力", flexGrow = 1, fontSize = 19, fontWeight = "bold", fontColor = { 255, 235, 178, 255 } },
            UI.Label { text = selected.totalPowerText, fontSize = 22, fontWeight = "bold", fontColor = { 255, 234, 0, 255 }, textAlign = "right", textStroke = { width = 2, color = { 0, 0, 0, 200 } } },
        },
    }
end

function SecretRealmDialog:CreateEnemyFormationPanel(selected)
    local slots = {}
    local enemyBySlot = {}
    for _, enemy in ipairs(selected.enemies or {}) do
        enemyBySlot[enemy.slotId] = enemy
    end
    for _, slotId in ipairs(SLOT_ORDER) do
        local slot = SLOT_POSITIONS[slotId]
        slots[#slots + 1] = self:CreateEnemySlot(slotId, slot, enemyBySlot[slotId])
    end
    return UI.Panel {
        width = "100%",
        height = 346,
        padding = 10,
        backgroundColor = { 207, 166, 119, 170 },
        borderColor = { 113, 74, 58, 255 },
        borderWidth = 2,
        borderRadius = 16,
        children = {
            UI.Label { text = "关卡阵型信息", position = "absolute", left = 12, top = 8, fontSize = 20, fontWeight = "bold", fontColor = { 68, 45, 25, 255 } },
            table.unpack(slots),
        },
    }
end

function SecretRealmDialog:CreateEnemySlot(slotId, slot, enemy)
    local borderColor = enemy and GetQualityColor(enemy) or { 117, 79, 62, 160 }
    local bgColor = enemy and { 245, 228, 200, 255 } or { 207, 166, 119, 130 }
    return UI.Panel {
        position = "absolute",
        left = slot.left,
        top = slot.top,
        width = 88,
        height = 70,
        padding = 5,
        backgroundColor = bgColor,
        borderColor = borderColor,
        borderWidth = enemy and 3 or 2,
        borderRadius = 14,
        children = enemy and {
            UI.Label { text = enemy.name, width = "100%", fontSize = 13, fontWeight = "bold", fontColor = { 68, 45, 25, 255 }, textAlign = "center", maxLines = 1 },
            UI.Label { text = enemy.profession .. " Lv." .. tostring(enemy.level), width = "100%", fontSize = 12, fontColor = { 88, 46, 45, 255 }, textAlign = "center", maxLines = 1 },
            UI.Label { text = "战力 " .. FormatNumber(enemy.power), width = "100%", fontSize = 11, fontColor = { 172, 56, 38, 255 }, textAlign = "center", maxLines = 1 },
        } or {
            UI.Label { text = slot.label, fontSize = 15, fontColor = { 88, 46, 45, 150 }, textAlign = "center" },
        },
    }
end

function SecretRealmDialog:CreateRewardPanel(selected)
    local useSweep = selected.cleared == true
    local rewards = useSweep and selected.sweepRewards or selected.firstClearRewards
    local rewardChildren = {}
    for _, reward in ipairs(rewards or {}) do
        rewardChildren[#rewardChildren + 1] = self:CreateRewardItem(reward)
    end
    return UI.Panel {
        width = "100%",
        flexGrow = 1,
        flexBasis = 0,
        gap = 8,
        padding = 10,
        backgroundColor = { 113, 74, 58, 230 },
        borderColor = { 68, 45, 25, 255 },
        borderWidth = 2,
        borderRadius = 16,
        children = {
            UI.Label { text = useSweep and "扫荡掉落奖励" or "首通奖励", fontSize = 21, fontWeight = "bold", fontColor = { 255, 235, 178, 255 }, textStroke = { width = 2, color = { 0, 0, 0, 180 } } },
            UI.ScrollView {
                width = "100%",
                flexGrow = 1,
                flexBasis = 0,
                scrollY = true,
                showScrollbar = true,
                children = { UI.Panel { width = "100%", gap = 8, children = rewardChildren } },
            },
        },
    }
end

function SecretRealmDialog:CreateRewardItem(reward)
    return UI.Panel {
        width = "100%",
        height = 46,
        flexDirection = "row",
        alignItems = "center",
        gap = 8,
        paddingLeft = 8,
        paddingRight = 8,
        backgroundColor = { 245, 228, 200, 235 },
        borderRadius = 12,
        children = {
            UI.Panel { width = 32, height = 32, borderRadius = 8, backgroundColor = { 88, 46, 45, 255 }, alignItems = "center", justifyContent = "center", children = { UI.Label { text = GetRewardIcon(reward), fontSize = 18, fontWeight = "bold", fontColor = { 255, 234, 0, 255 }, textAlign = "center" } } },
            UI.Label { text = tostring(reward.name or "奖励"), flexGrow = 1, flexShrink = 1, fontSize = 17, fontWeight = "bold", fontColor = { 68, 45, 25, 255 }, maxLines = 1 },
            UI.Label { text = "x" .. FormatNumber(reward.count or 1), fontSize = 17, fontWeight = "bold", fontColor = { 172, 56, 38, 255 }, textAlign = "right" },
        },
    }
end

function SecretRealmDialog:CreateFooter(selected)
    return UI.Panel {
        position = "absolute",
        width = "95.2%",
        height = 51,
        left = 25,
        top = 1113,
        zIndex = 10,
        flexDirection = "row",
        gap = 12,
        children = {
            UI.Label { text = selected and (selected.cleared and "已通关关卡可查看扫荡掉落" or "未通关关卡展示首通奖励") or "", width = 330, height = 46, position = "absolute", left = 0, top = 0, fontSize = 18, fontColor = { 255, 235, 178, 255 }, textStroke = { width = 2, color = { 0, 0, 0, 180 } }, maxLines = 2 },
            UI.Button { text = "关闭", width = 137.65, height = 46, position = "absolute", left = 340, top = 0, paddingTop = 0, paddingRight = 16, paddingBottom = 4, paddingLeft = 16, fontSize = 20, backgroundColor = { 88, 46, 45, 255 }, textColor = { 255, 244, 220, 255 }, borderRadius = 18, onClick = function() self:Close() end },
            UI.Button { text = selected and (selected.cleared and "扫荡" or "挑战") or "挑战", width = 137, height = 47, position = "absolute", left = 510, top = 0, paddingTop = 0, paddingRight = 16, paddingBottom = 4, paddingLeft = 16, fontSize = 20, fontWeight = "bold", backgroundColor = { 202, 92, 44, 255 }, pressedBackgroundColor = { 155, 62, 36, 255 }, textColor = { 255, 244, 220, 255 }, borderRadius = 18, onClick = function() self:ChallengeSelected() end },
        },
    }
end

return SecretRealmDialog
