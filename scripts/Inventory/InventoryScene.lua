local UI = require("urhox-libs/UI")
local SaveManager = require("Save.SaveManager")

local InventoryScene = {}
InventoryScene.__index = InventoryScene

local DESIGN_WIDTH = 720
local DESIGN_HEIGHT = 1280
local SLOT_SIZE = 94
local SLOT_GAP = 10
local GRID_COLUMNS = 5

local QUALITY_COLORS = {
    [1] = { 181, 181, 181, 255 },
    [2] = { 162, 255, 148, 255 },
    [3] = { 114, 242, 245, 255 },
    [4] = { 239, 121, 255, 255 },
    [5] = { 255, 237, 0, 255 },
    [6] = { 255, 0, 0, 255 },
}

local QUALITY_NAMES = {
    [1] = "普通",
    [2] = "优质",
    [3] = "稀有",
    [4] = "史诗",
    [5] = "传说",
    [6] = "至臻",
}

local TAB_DEFS = {
    { id = "all", label = "全部" },
    { id = "equipment", label = "装备" },
    { id = "material", label = "材料" },
    { id = "consumable", label = "消耗" },
    { id = "fragment", label = "碎片" },
}

local TYPE_LABELS = {
    equipment = "装备",
    material = "材料",
    consumable = "消耗品",
    ticket = "票券",
    fragment = "碎片",
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

local function GetSaveData()
    return SaveManager.GetSaveData() or {}
end

local function GetInventory(saveData)
    saveData.inventory = type(saveData.inventory) == "table" and saveData.inventory or { capacity = 36, selectedTab = "all", items = {} }
    saveData.inventory.items = type(saveData.inventory.items) == "table" and saveData.inventory.items or {}
    saveData.inventory.capacity = math.max(24, math.floor(tonumber(saveData.inventory.capacity) or 36))
    saveData.inventory.selectedTab = tostring(saveData.inventory.selectedTab or "all")
    return saveData.inventory
end

local function GetQualityColor(quality)
    return QUALITY_COLORS[math.max(1, math.min(6, math.floor(tonumber(quality) or 1)))] or QUALITY_COLORS[1]
end

local function FindItemIndex(items, uid)
    for index, item in ipairs(items or {}) do
        if item.uid == uid then
            return index
        end
    end
    return nil
end

local function CountItems(items)
    local count = 0
    for _, item in ipairs(items or {}) do
        count = count + math.max(1, math.floor(tonumber(item.count) or 1))
    end
    return count
end

local function CopyArray(source)
    local result = {}
    for i, value in ipairs(source or {}) do
        result[i] = value
    end
    return result
end

function InventoryScene:new(options)
    local o = setmetatable({}, self)
    o.onExit = options and options.onExit or nil
    o.createTopResourceRow = options and options.createTopResourceRow or nil
    o.onRootChanged = options and options.onRootChanged or nil
    o.root = nil
    o.selectedItemUid = nil
    o.activeTab = "all"
    o.statusText = "选择物品查看详情，金币袋可直接使用。"
    return o
end

function InventoryScene:Destroy()
    self.root = nil
end

function InventoryScene:GetData()
    local saveData = GetSaveData()
    local inventory = GetInventory(saveData)
    self.activeTab = inventory.selectedTab or self.activeTab or "all"
    return saveData, inventory, inventory.items or {}
end

function InventoryScene:SetStatus(text)
    self.statusText = text
end

function InventoryScene:Refresh()
    self.root = self:CreateRoot()
    UI.SetRoot(self.root, true)
    if self.onRootChanged then
        self.onRootChanged(self.root)
    end
end

function InventoryScene:SaveAndRefresh(reason)
    SaveManager.MarkDirty("inventory")
    SaveManager.SaveGameSnapshot(reason, function()
        print("[Inventory] Saved: " .. tostring(reason))
    end, function(errorMessage)
        print("[Inventory] Save failed: " .. tostring(errorMessage))
    end)
    self:Refresh()
end

function InventoryScene:SetTab(tabId)
    local _, inventory = self:GetData()
    inventory.selectedTab = tabId
    self.activeTab = tabId
    self.selectedItemUid = nil
    self:SetStatus("已切换到" .. self:GetTabLabel(tabId) .. "分类。")
    SaveManager.MarkDirty("inventory")
    SaveManager.SaveGameSnapshot("切换背包分类", nil, function(reason)
        print("[Inventory] Save selected tab failed: " .. tostring(reason))
    end)
    self:Refresh()
end

function InventoryScene:GetTabLabel(tabId)
    for _, tab in ipairs(TAB_DEFS) do
        if tab.id == tabId then
            return tab.label
        end
    end
    return "全部"
end

function InventoryScene:GetFilteredItems(items)
    local result = {}
    local activeTab = self.activeTab or "all"
    for _, item in ipairs(items or {}) do
        if activeTab == "all" or item.type == activeTab then
            result[#result + 1] = item
        end
    end
    table.sort(result, function(a, b)
        if a.quality ~= b.quality then return (a.quality or 1) > (b.quality or 1) end
        if a.type ~= b.type then return tostring(a.type) < tostring(b.type) end
        return tostring(a.name) < tostring(b.name)
    end)
    return result
end

function InventoryScene:GetSelectedItem(items)
    if not self.selectedItemUid then return nil end
    for _, item in ipairs(items or {}) do
        if item.uid == self.selectedItemUid then
            return item
        end
    end
    return nil
end

function InventoryScene:SelectItem(item)
    self.selectedItemUid = item and item.uid or nil
    if item then
        self:SetStatus("已选择" .. item.name .. "。")
    end
    self:Refresh()
end

function InventoryScene:UseSelectedItem()
    local saveData, inventory, items = self:GetData()
    local index = FindItemIndex(items, self.selectedItemUid)
    local item = index and items[index] or nil
    if not item then
        self:SetStatus("请先选择一个物品。")
        self:Refresh()
        return
    end

    if item.configId == "coin_box_small" then
        local reward = math.max(0, math.floor(tonumber(item.value) or 0))
        saveData.coin = math.max(0, math.floor(tonumber(saveData.coin) or 0) + reward)
        item.count = math.max(0, math.floor(tonumber(item.count) or 1) - 1)
        if item.count <= 0 then
            table.remove(items, index)
            self.selectedItemUid = nil
        end
        SaveManager.MarkFieldsDirty({ "coin", "inventory" })
        SaveManager.SaveGameSnapshot("使用背包金币袋", function()
            self:SetStatus("已使用小袋金币，获得" .. FormatNumber(reward) .. "金币。")
            self:Refresh()
        end, function(errorMessage)
            print("[Inventory] Use item save failed: " .. tostring(errorMessage))
            self:SetStatus("保存失败，请稍后重试。")
            self:Refresh()
        end)
        return
    end

    self:SetStatus("该物品暂未开放使用，后续会接入对应系统。")
    self:Refresh()
end

function InventoryScene:SortInventory()
    local _, inventory, items = self:GetData()
    table.sort(items, function(a, b)
        if a.quality ~= b.quality then return (a.quality or 1) > (b.quality or 1) end
        if a.type ~= b.type then return tostring(a.type) < tostring(b.type) end
        return tostring(a.name) < tostring(b.name)
    end)
    inventory.items = items
    self:SetStatus("背包已按品质和类型整理。")
    self:SaveAndRefresh("整理背包")
end

function InventoryScene:ExpandCapacity()
    local _, inventory = self:GetData()
    inventory.capacity = math.min(120, math.floor(tonumber(inventory.capacity) or 36) + 6)
    self:SetStatus("背包容量提升到" .. tostring(inventory.capacity) .. "格。")
    self:SaveAndRefresh("扩充背包容量")
end

function InventoryScene:CreateRoot()
    local saveData, inventory, items = self:GetData()
    local selectedItem = self:GetSelectedItem(items)
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
    local headerChildren = self:CreateHeader(inventory, items)
    for _, child in ipairs(headerChildren) do
        children[#children + 1] = child
    end
    children[#children + 1] = self:CreateContent(saveData, inventory, items, selectedItem)
    children[#children + 1] = self:CreateBottomActions(selectedItem)

    return UI.Panel {
        id = "inventoryScreen",
        width = DESIGN_WIDTH,
        height = DESIGN_HEIGHT,
        backgroundColor = { 42, 30, 24, 255 },
        overflow = "hidden",
        children = children,
    }
end

function InventoryScene:CreateBackground()
    return UI.Panel {
        id = "background",
        position = "absolute",
        width = DESIGN_WIDTH,
        height = DESIGN_HEIGHT,
        right = 0,
        zIndex = 0,
        backgroundImage = "image/page_background.png",
        backgroundFit = "cover",
        backgroundColor = { 0, 0, 0, 255 },
    }
end

function InventoryScene:CreateHeader(inventory, items)
    return {
        UI.Label { text = "背包", position = "absolute", left = 19, top = 66, zIndex = 10, fontSize = 30, fontWeight = "bold", fontColor = { 255, 235, 178, 255 }, textAlign = "center", textStroke = { width = 2, color = { 0, 0, 0, 220 } } },
        UI.Label { text = "容量 " .. tostring(#items) .. "/" .. tostring(inventory.capacity) .. " · 总数量 " .. FormatNumber(CountItems(items)), position = "absolute", left = 378, top = 69, width = 320, zIndex = 10, fontSize = 20, fontWeight = "bold", fontColor = { 255, 234, 0, 255 }, textAlign = "right", textStroke = { width = 2, color = { 0, 0, 0, 220 } } },
        UI.Button { width = 164, height = 58, position = "absolute", left = 0, top = 1183, zIndex = 10, paddingTop = 0, paddingRight = 0, paddingBottom = 0, paddingLeft = 0, fontSize = 18, backgroundImage = "image/BT-返回.png", backgroundFit = "cover", backgroundColor = { 251, 251, 251, 0 }, opacity = 1, textColor = { 255, 255, 255, 0 }, borderRadius = 0, onClick = function() if self.onExit then self.onExit() end end },
    }
end

function InventoryScene:CreateContent(saveData, inventory, items, selectedItem)
    return UI.Panel {
        id = "backBag",
        position = "absolute",
        width = 696,
        left = 13,
        right = 29,
        top = 164,
        height = 951,
        children = {
            self:CreateInventoryGridPanel(inventory, items),
            self:CreateDetailPanel(selectedItem),
        },
    }
end

function InventoryScene:CreateTabButton(tab)
    local active = self.activeTab == tab.id
    return UI.Button {
        text = tab.label,
        flexGrow = 1,
        height = 34,
        fontSize = 15,
        backgroundColor = active and { 202, 92, 44, 255 } or { 88, 46, 45, 255 },
        pressedBackgroundColor = { 155, 62, 36, 255 },
        textColor = { 255, 244, 220, 255 },
        borderRadius = 12,
        onClick = function()
            self:SetTab(tab.id)
        end,
    }
end

function InventoryScene:CreateInventoryGridPanel(inventory, items)
    local tabs = {}
    for _, tab in ipairs(TAB_DEFS) do
        tabs[#tabs + 1] = self:CreateTabButton(tab)
    end

    local filteredItems = self:GetFilteredItems(items)
    local slotChildren = {}
    for slotIndex = 1, inventory.capacity do
        slotChildren[#slotChildren + 1] = self:CreateItemSlot(slotIndex, filteredItems[slotIndex])
    end

    return UI.Panel {
        position = "absolute",
        left = 4,
        top = -37,
        width = 676,
        height = "76.8%",
        gap = 8,
        backgroundColor = { 113, 74, 58, 245 },
        borderColor = { 68, 45, 25, 255 },
        borderWidth = 3,
        borderRadius = 0,
        children = {
            UI.Panel { width = "100%", height = 36, left = 0, top = -53, flexDirection = "row", gap = 6, children = tabs },
            UI.ScrollView {
                width = "100%",
                flexGrow = 1,
                flexBasis = 684,
                top = -44,
                scrollY = true,
                showScrollbar = true,
                children = {
                    UI.Panel {
                        width = "94.6%",
                        left = 20,
                        top = 74,
                        flexDirection = "row",
                        flexWrap = "wrap",
                        gap = SLOT_GAP,
                        children = slotChildren,
                    },
                },
            },
        },
    }
end

function InventoryScene:CreateItemSlot(slotIndex, item)
    local selected = item and item.uid == self.selectedItemUid
    local qualityColor = item and GetQualityColor(item.quality) or { 117, 79, 62, 255 }
    local bgColor = selected and { 255, 244, 205, 255 } or (item and { 245, 228, 200, 255 } or { 207, 166, 119, 150 })
    return UI.Panel {
        width = SLOT_SIZE,
        height = SLOT_SIZE,
        flexShrink = 0,
        alignItems = "center",
        justifyContent = "center",
        backgroundColor = bgColor,
        borderColor = selected and { 255, 234, 0, 255 } or qualityColor,
        borderWidth = selected and 4 or 2,
        borderRadius = 16,
        onClick = function()
            if item then
                self:SelectItem(item)
            else
                self.selectedItemUid = nil
                self:SetStatus("第" .. tostring(slotIndex) .. "格为空。")
                self:Refresh()
            end
        end,
        children = item and self:CreateItemSlotContent(item) or {
            UI.Label { text = tostring(slotIndex), fontSize = 18, fontColor = { 88, 46, 45, 140 }, textAlign = "center" },
        },
    }
end

function InventoryScene:CreateItemSlotContent(item)
    local qualityColor = GetQualityColor(item.quality)
    return {
        UI.Panel {
            width = 52,
            height = 52,
            alignItems = "center",
            justifyContent = "center",
            backgroundColor = { 88, 46, 45, 220 },
            borderColor = qualityColor,
            borderWidth = 2,
            borderRadius = 14,
            children = {
                UI.Label { text = tostring(item.icon or "物"), fontSize = 26, fontWeight = "bold", fontColor = { 255, 244, 220, 255 }, textAlign = "center", textStroke = { width = 1, color = { 0, 0, 0, 220 } } },
            },
        },
        UI.Label { text = "x" .. tostring(item.count or 1), position = "absolute", right = 8, bottom = 6, fontSize = 14, fontWeight = "bold", fontColor = { 255, 255, 255, 255 }, textStroke = { width = 2, color = { 0, 0, 0, 220 } } },
        UI.Label { text = item.name, position = "absolute", left = 4, right = 4, bottom = 23, fontSize = 11, fontColor = { 88, 46, 45, 255 }, textAlign = "center", maxLines = 1 },
    }
end

function InventoryScene:CreateDetailPanel(item)
    return UI.Panel {
        position = "absolute",
        left = -5,
        top = 657,
        width = 693,
        height = "31%",
        gap = 10,
        backgroundImage = "image/IM-说明-底.png",
        backgroundFit = "none",
        backgroundColor = { 245, 228, 200, 245 },
        borderRadius = 0,
        children = item and self:CreateSelectedDetail(item) or self:CreateEmptyDetail(),
    }
end

function InventoryScene:CreateEmptyDetail()
    return {
        UI.Label { text = "物品详情", left = 24, top = 23, fontSize = 24, fontWeight = "bold", fontColor = { 117, 79, 62, 255 }, textAlign = "center" },
        UI.Panel { flexGrow = 1, flexBasis = 0, alignItems = "center", justifyContent = "center", children = {
            UI.Label { text = "请选择背包物品", fontSize = 20, fontColor = { 88, 46, 45, 180 }, textAlign = "center" },
        } },
        UI.Label { text = self.statusText, minHeight = 52, left = 292, top = -23, fontSize = 16, fontColor = { 88, 46, 45, 255 }, textAlign = "center", maxLines = 2 },
    }
end

function InventoryScene:CreateSelectedDetail(item)
    local quality = math.max(1, math.min(6, math.floor(tonumber(item.quality) or 1)))
    local qualityColor = GetQualityColor(quality)
    return {
        UI.Label { text = "物品详情", position = "absolute", left = 270, top = 28, fontSize = 24, fontWeight = "bold", fontColor = { 117, 79, 62, 255 }, textAlign = "center" },
        UI.Panel {
            width = 95,
            height = 96,
            position = "absolute",
            left = 34,
            top = 32,
            alignItems = "center",
            justifyContent = "center",
            backgroundColor = { 255, 244, 220, 255 },
            borderColor = qualityColor,
            borderWidth = 3,
            borderRadius = 18,
            children = {
                UI.Label { text = tostring(item.icon or "物"), width = 66, height = 63, minHeight = 60, fontSize = 32, fontWeight = "bold", fontColor = { 88, 46, 45, 255 }, textAlign = "center", textStroke = { width = 2, color = { 255, 244, 220, 255 } } },
            },
        },
        UI.Label { text = item.name, position = "absolute", left = 147, top = 71, fontSize = 22, fontWeight = "bold", fontColor = { 88, 46, 45, 255 }, textAlign = "center", maxLines = 1 },
        UI.Label { text = (QUALITY_NAMES[quality] or "普通") .. " · " .. (TYPE_LABELS[item.type] or item.type), position = "absolute", left = 528, top = 77, fontSize = 17, fontWeight = "bold", fontColor = qualityColor, textAlign = "center", textStroke = { width = 1, color = { 68, 45, 25, 180 } }, maxLines = 1 },
        UI.Panel { width = "93.1%", height = 94, minHeight = 70, position = "absolute", left = 25, top = 136, paddingTop = 2, paddingRight = 2, paddingBottom = 2, paddingLeft = 2, backgroundColor = { 255, 244, 220, 255 }, borderColor = { 207, 166, 119, 255 }, borderWidth = 1, borderRadius = 0, children = {
            UI.Label { text = item.description, fontSize = 16, fontColor = { 88, 46, 45, 255 }, textAlign = "left", whiteSpace = "normal", maxLines = 4 },
        } },
        UI.Label { text = "数量：" .. tostring(item.count or 1) .. "    价值：" .. FormatNumber(item.value or 0), position = "absolute", left = 312, top = 80, fontSize = 16, fontColor = { 117, 79, 62, 255 }, textAlign = "center" },
        UI.Label { text = self.statusText, minHeight = 52, position = "absolute", left = 496, top = 25, fontSize = 16, fontColor = { 88, 46, 45, 255 }, textAlign = "center", maxLines = 2 },
    }
end

function InventoryScene:CreateBottomActions(selectedItem)
    return UI.Panel {
        position = "absolute",
        width = "87.1%",
        height = 51,
        left = 49,
        top = 1120,
        flexDirection = "row",
        gap = 12,
        children = {
            UI.Button { text = "使用", width = 138, height = 46, position = "absolute", left = 0, top = 0, paddingTop = 0, paddingRight = 16, paddingBottom = 4, paddingLeft = 16, fontSize = 20, backgroundColor = selectedItem and { 202, 92, 44, 255 } or { 117, 79, 62, 180 }, textColor = { 255, 244, 220, 255 }, borderRadius = 18, onClick = function() self:UseSelectedItem() end },
            UI.Button { text = "整理", width = 137.65, height = 46, position = "absolute", left = 240, top = 3, paddingTop = 0, paddingRight = 16, paddingBottom = 4, paddingLeft = 16, fontSize = 20, backgroundColor = { 117, 79, 62, 255 }, textColor = { 255, 244, 220, 255 }, borderRadius = 18, onClick = function() self:SortInventory() end },
            UI.Button { text = "扩充", width = 137.65, height = 46, position = "absolute", left = 478, top = 2, paddingTop = 0, paddingRight = 16, paddingBottom = 4, paddingLeft = 16, fontSize = 20, backgroundColor = { 88, 130, 72, 255 }, textColor = { 255, 244, 220, 255 }, borderRadius = 18, onClick = function() self:ExpandCapacity() end },
        },
    }
end

return InventoryScene
