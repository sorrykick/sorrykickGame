local UI = require("urhox-libs/UI")

local DESIGN_WIDTH = 720
local DESIGN_HEIGHT = 1280
local LOGIN_BACKGROUND_IMAGE = "image/login_background.png"
local MAIN_REFERENCE_IMAGE = "image/main_reference.png"
local SAVE_KEY = "partner_idle_save_v1"
local MAX_OFFLINE_SECONDS = 12 * 60 * 60

---@type Widget|nil
local uiRoot_ = nil
---@type Widget|nil
local loginButton_ = nil
---@type Widget|nil
local loginStatusLabel_ = nil
---@type Widget|nil
local coinLabel_ = nil
---@type Widget|nil
local offlineLabel_ = nil

local playerSave_ = nil
local pendingOfflineCoin_ = 0
local isLoggingIn_ = false

local function Now()
    return os.time()
end

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

local function CreateDefaultSave(now)
    return {
        version = 1,
        createdAt = now,
        lastLoginTime = now,
        coin = 1221300,
        diamond = 1300,
        crystal = 1300,
        energy = 2544,
        partner = {
            id = "partner_001",
            name = "初始伙伴",
            level = 1,
            exp = 0,
            power = 10,
        },
        idle = {
            baseRate = 8,
            lastCollectTime = now,
        },
        stats = {
            loginCount = 0,
            totalOfflineCoin = 0,
        },
    }
end

local function NormalizeSave(save, now)
    if type(save) ~= "table" then
        return CreateDefaultSave(now)
    end

    save.version = save.version or 1
    save.createdAt = save.createdAt or now
    save.lastLoginTime = save.lastLoginTime or now
    save.coin = math.floor(tonumber(save.coin) or 0)
    save.diamond = math.floor(tonumber(save.diamond) or 0)
    save.crystal = math.floor(tonumber(save.crystal) or 0)
    save.energy = math.floor(tonumber(save.energy) or 0)

    save.partner = save.partner or {}
    save.partner.id = save.partner.id or "partner_001"
    save.partner.name = save.partner.name or "初始伙伴"
    save.partner.level = math.max(1, math.floor(tonumber(save.partner.level) or 1))
    save.partner.exp = math.max(0, math.floor(tonumber(save.partner.exp) or 0))
    save.partner.power = math.max(1, math.floor(tonumber(save.partner.power) or 10))

    save.idle = save.idle or {}
    save.idle.baseRate = math.max(1, math.floor(tonumber(save.idle.baseRate) or 8))
    save.idle.lastCollectTime = math.floor(tonumber(save.idle.lastCollectTime) or now)

    save.stats = save.stats or {}
    save.stats.loginCount = math.max(0, math.floor(tonumber(save.stats.loginCount) or 0))
    save.stats.totalOfflineCoin = math.max(0, math.floor(tonumber(save.stats.totalOfflineCoin) or 0))

    return save
end

local function IsCloudAvailable()
    return type(clientCloud) == "table" and clientCloud.BatchGet ~= nil and clientCloud.BatchSet ~= nil
end

local function RequestPlayerSave(onSuccess, onError)
    print("[Save] Requesting player save")

    if not IsCloudAvailable() then
        print("[Save] clientCloud unavailable, using development fallback save")
        if onSuccess then
            onSuccess(nil)
        end
        return
    end

    clientCloud:BatchGet()
        :Key(SAVE_KEY)
        :Fetch({
            ok = function(values)
                print("[Save] Player save loaded")
                if onSuccess then
                    onSuccess(values and values[SAVE_KEY] or nil)
                end
            end,
            error = function(code, reason)
                print("[Save] Load failed: " .. tostring(code) .. " " .. tostring(reason))
                if onError then
                    onError(reason or "读取存档失败")
                end
            end,
            timeout = function()
                print("[Save] Load timeout")
                if onError then
                    onError("读取存档超时")
                end
            end,
        })
end

local function RequestUpdateSave(reason, onSuccess, onError)
    if not playerSave_ then
        if onError then onError("没有可保存的数据") end
        return
    end

    print("[Save] Updating player save: " .. tostring(reason))

    if not IsCloudAvailable() then
        print("[Save] clientCloud unavailable, development fallback save completed")
        if onSuccess then onSuccess() end
        return
    end

    clientCloud:BatchSet()
        :Set(SAVE_KEY, playerSave_)
        :Save(reason or "更新存档", {
            ok = function()
                print("[Save] Save updated")
                if onSuccess then onSuccess() end
            end,
            error = function(code, reasonText)
                print("[Save] Save failed: " .. tostring(code) .. " " .. tostring(reasonText))
                if onError then onError(reasonText or "保存失败") end
            end,
            timeout = function()
                print("[Save] Save timeout")
                if onError then onError("保存超时") end
            end,
        })
end

local function ApplyOfflineSettlement(now)
    local idle = playerSave_.idle
    local elapsed = math.max(0, now - idle.lastCollectTime)
    local cappedElapsed = math.min(elapsed, MAX_OFFLINE_SECONDS)
    local partnerLevel = playerSave_.partner.level
    local rate = idle.baseRate + partnerLevel * 2
    local earned = math.floor(cappedElapsed * rate)

    pendingOfflineCoin_ = earned
    playerSave_.coin = playerSave_.coin + earned
    playerSave_.lastLoginTime = now
    playerSave_.idle.lastCollectTime = now
    playerSave_.stats.loginCount = playerSave_.stats.loginCount + 1
    playerSave_.stats.totalOfflineCoin = playerSave_.stats.totalOfflineCoin + earned

    print(string.format("[Idle] elapsed=%d capped=%d rate=%d earned=%d", elapsed, cappedElapsed, rate, earned))
end

local function UpdateHomeLabels()
    if not playerSave_ then return end
    if coinLabel_ then
        coinLabel_:SetText(FormatNumber(playerSave_.coin))
    end
    if offlineLabel_ then
        if pendingOfflineCoin_ > 0 then
            offlineLabel_:SetText("本次离线收益 +" .. FormatNumber(pendingOfflineCoin_))
        else
            offlineLabel_:SetText("当前可以领取 12.35万")
        end
    end
end

local function SetLoginStatus(text)
    if loginStatusLabel_ then
        loginStatusLabel_:SetText(text)
    end
end

local function ShowRoot(root)
    uiRoot_ = root
    UI.SetRoot(uiRoot_, true)
end

local function LabelText(text, size, color)
    return UI.Label {
        text = text,
        fontSize = size,
        fontWeight = "bold",
        fontColor = color or { 255, 255, 255, 255 },
        textAlign = "center",
        textStroke = { width = 2, color = { 50, 34, 20, 220 } },
    }
end

local function CreateResourcePill(id, title, value, color)
    return UI.Panel {
        id = id,
        width = 174,
        height = 34,
        flexDirection = "row",
        alignItems = "center",
        backgroundColor = { 18, 16, 14, 220 },
        borderColor = { 220, 200, 160, 90 },
        borderWidth = 1,
        borderRadius = 8,
        paddingLeft = 8,
        paddingRight = 10,
        gap = 8,
        children = {
            UI.Panel {
                width = 24,
                height = 24,
                borderRadius = 12,
                backgroundColor = color,
                borderWidth = 2,
                borderColor = { 255, 255, 255, 160 },
            },
            UI.Label {
                text = title,
                width = 28,
                fontSize = 14,
                fontColor = { 245, 230, 190, 255 },
                textAlign = "left",
            },
            UI.Label {
                id = id .. "Value",
                text = value,
                flexGrow = 1,
                flexShrink = 1,
                fontSize = 18,
                fontColor = { 255, 245, 220, 255 },
                textAlign = "right",
                textStroke = { width = 1, color = { 0, 0, 0, 220 } },
            },
        },
    }
end

local function CreateTopMenuButton(label)
    return UI.Panel {
        width = 82,
        height = 78,
        alignItems = "center",
        justifyContent = "center",
        gap = 3,
        backgroundColor = { 222, 214, 194, 115 },
        borderColor = { 80, 58, 36, 120 },
        borderWidth = 2,
        borderRadius = 12,
        onClick = function()
            print("[Home] Menu clicked: " .. label)
        end,
        children = {
            UI.Label {
                text = "★",
                fontSize = 30,
                fontWeight = "bold",
                fontColor = { 55, 42, 28, 255 },
                textAlign = "center",
            },
            UI.Label {
                text = label,
                fontSize = 18,
                fontWeight = "bold",
                fontColor = { 46, 34, 24, 255 },
                textAlign = "center",
                textStroke = { width = 1, color = { 255, 245, 220, 180 } },
            },
        },
    }
end

local function CreateModeBadge(title, color)
    return UI.Panel {
        width = 66,
        height = 70,
        alignItems = "center",
        justifyContent = "center",
        backgroundColor = { 236, 230, 212, 200 },
        borderColor = color,
        borderWidth = 3,
        borderRadius = 10,
        children = {
            UI.Label {
                text = title,
                fontSize = 18,
                fontWeight = "bold",
                fontColor = { 58, 44, 32, 255 },
                textAlign = "center",
                textStroke = { width = 1, color = { 255, 255, 255, 200 } },
            },
        },
    }
end

local function CreateCircleFeature(label, side)
    local left = side == "left" and 24 or nil
    local right = side == "right" and 24 or nil
    return UI.Panel {
        width = 120,
        height = 120,
        borderRadius = 60,
        backgroundColor = { 230, 224, 210, 205 },
        borderWidth = 5,
        borderColor = { 255, 255, 255, 180 },
        alignItems = "center",
        justifyContent = "center",
        position = "absolute",
        left = left,
        right = right,
        onClick = function()
            print("[Home] Feature clicked: " .. label)
        end,
        children = {
            UI.Label {
                text = label,
                fontSize = 28,
                fontWeight = "bold",
                fontColor = { 50, 38, 26, 255 },
                textAlign = "center",
                whiteSpace = "normal",
                textStroke = { width = 2, color = { 255, 255, 255, 220 } },
            },
        },
    }
end

local function CreateBottomNav(label)
    return UI.Panel {
        flexGrow = 1,
        flexShrink = 1,
        height = 126,
        alignItems = "center",
        justifyContent = "center",
        backgroundColor = { 38, 30, 22, 225 },
        borderColor = { 181, 160, 116, 160 },
        borderWidth = 1,
        gap = 6,
        onClick = function()
            print("[Home] Bottom tab clicked: " .. label)
        end,
        children = {
            UI.Label {
                text = "◆",
                fontSize = 34,
                fontWeight = "bold",
                fontColor = { 240, 230, 205, 255 },
                textAlign = "center",
                textStroke = { width = 2, color = { 0, 0, 0, 180 } },
            },
            UI.Label {
                text = label,
                fontSize = 28,
                fontWeight = "bold",
                fontColor = { 255, 248, 226, 255 },
                textAlign = "center",
                textStroke = { width = 2, color = { 0, 0, 0, 220 } },
            },
        },
    }
end

local function CreateTopHud()
    return UI.Panel {
        position = "absolute",
        top = 10,
        left = 12,
        right = 12,
        gap = 8,
        children = {
            UI.Panel {
                width = "100%",
                height = 38,
                flexDirection = "row",
                alignItems = "center",
                gap = 10,
                children = {
                    UI.Panel {
                        width = 104,
                        height = 34,
                        borderRadius = 8,
                        backgroundColor = { 18, 16, 14, 220 },
                        alignItems = "center",
                        justifyContent = "center",
                        children = { UI.Label { text = "23:00", fontSize = 18, fontColor = { 255, 255, 255, 255 } } },
                    },
                    CreateResourcePill("coin", "金", FormatNumber(playerSave_.coin), { 255, 213, 55, 255 }),
                    CreateResourcePill("diamond", "蓝", FormatNumber(playerSave_.diamond), { 45, 205, 255, 255 }),
                    CreateResourcePill("crystal", "晶", FormatNumber(playerSave_.crystal), { 215, 220, 255, 255 }),
                    UI.Button {
                        text = "+",
                        width = 44,
                        height = 44,
                        fontSize = 30,
                        backgroundColor = { 210, 78, 28, 255 },
                        pressedBackgroundColor = { 170, 50, 18, 255 },
                        textColor = { 255, 245, 210, 255 },
                        borderRadius = 9,
                        onClick = function()
                            print("[Home] Add resource clicked")
                        end,
                    },
                },
            },
            UI.Panel {
                width = "100%",
                height = 38,
                flexDirection = "row",
                alignItems = "center",
                justifyContent = "space-between",
                children = {
                    UI.Panel {
                        width = 190,
                        height = 34,
                        flexDirection = "row",
                        alignItems = "center",
                        paddingHorizontal = 8,
                        gap = 6,
                        backgroundColor = { 238, 230, 204, 190 },
                        borderRadius = 8,
                        children = {
                            UI.Label { text = "玩家名字", fontSize = 18, fontColor = { 65, 45, 34, 255 } },
                            UI.Label { text = "#75874", fontSize = 14, fontColor = { 196, 82, 42, 255 } },
                        },
                    },
                    UI.Label {
                        text = "1234567890",
                        fontSize = 26,
                        fontColor = { 255, 203, 74, 255 },
                        textStroke = { width = 2, color = { 95, 54, 25, 255 } },
                    },
                },
            },
        },
    }
end

local function CreateHomeScreen()
    coinLabel_ = nil
    offlineLabel_ = nil

    local root = UI.Panel {
        id = "homeScreen",
        width = DESIGN_WIDTH,
        height = DESIGN_HEIGHT,
        backgroundImage = MAIN_REFERENCE_IMAGE,
        backgroundFit = "cover",
        overflow = "hidden",
        children = {
            UI.Panel {
                width = "100%",
                height = "100%",
                backgroundColor = { 0, 0, 0, 52 },
                pointerEvents = "box-none",
            },

            CreateTopHud(),

            UI.Panel {
                position = "absolute",
                top = 92,
                left = 16,
                right = 16,
                height = 84,
                flexDirection = "row",
                justifyContent = "space-between",
                alignItems = "center",
                children = {
                    CreateTopMenuButton("签到"),
                    CreateTopMenuButton("商城"),
                    CreateTopMenuButton("邮件"),
                    CreateTopMenuButton("成就"),
                    CreateTopMenuButton("设置"),
                },
            },

            UI.Panel {
                position = "absolute",
                top = 176,
                left = 0,
                right = 0,
                height = 48,
                backgroundColor = { 245, 236, 218, 215 },
                alignItems = "center",
                justifyContent = "center",
                children = {
                    UI.Label {
                        text = "第一章  迷失森林",
                        fontSize = 28,
                        fontColor = { 52, 36, 24, 255 },
                        textAlign = "center",
                    },
                },
            },

            UI.Panel {
                position = "absolute",
                top = 236,
                left = 42,
                right = 42,
                height = 292,
                children = {
                    UI.Panel {
                        position = "absolute",
                        top = 8,
                        left = 0,
                        width = 116,
                        height = 116,
                        borderRadius = 58,
                        backgroundColor = { 236, 228, 208, 190 },
                        alignItems = "center",
                        justifyContent = "center",
                        children = { LabelText("玩家\n挑战", 22, { 72, 52, 35, 255 }) },
                    },
                    UI.Panel {
                        position = "absolute",
                        top = 8,
                        right = 0,
                        width = 116,
                        height = 116,
                        borderRadius = 58,
                        backgroundColor = { 236, 228, 208, 190 },
                        alignItems = "center",
                        justifyContent = "center",
                        children = { LabelText("玩家\n养成", 22, { 72, 52, 35, 255 }) },
                    },
                    UI.Label {
                        text = "伙伴 Lv." .. tostring(playerSave_.partner.level),
                        position = "absolute",
                        left = 56,
                        bottom = 12,
                        fontSize = 22,
                        fontColor = { 255, 255, 255, 255 },
                        textStroke = { width = 2, color = { 0, 0, 0, 220 } },
                    },
                },
            },

            UI.Panel {
                position = "absolute",
                top = 535,
                left = 18,
                right = 18,
                height = 76,
                flexDirection = "row",
                justifyContent = "space-between",
                alignItems = "center",
                children = {
                    CreateModeBadge("普通", { 150, 155, 150, 255 }),
                    CreateModeBadge("精英", { 90, 120, 180, 255 }),
                    CreateModeBadge("传说", { 207, 146, 48, 255 }),
                    CreateModeBadge("普通", { 110, 130, 110, 255 }),
                    CreateModeBadge("精英", { 90, 120, 180, 255 }),
                    CreateModeBadge("传说", { 207, 146, 48, 255 }),
                    CreateModeBadge("剧情", { 140, 116, 96, 255 }),
                    CreateModeBadge("奇遇", { 215, 105, 60, 255 }),
                    CreateModeBadge("BOSS", { 190, 45, 45, 255 }),
                    CreateModeBadge("地图", { 78, 144, 210, 255 }),
                },
            },

            UI.Panel {
                position = "absolute",
                top = 602,
                left = 0,
                right = 0,
                height = 46,
                flexDirection = "row",
                alignItems = "center",
                justifyContent = "center",
                gap = 18,
                backgroundColor = { 238, 228, 205, 235 },
                children = {
                    UI.Label {
                        id = "offlineRewardLabel",
                        text = pendingOfflineCoin_ > 0 and ("本次离线收益 +" .. FormatNumber(pendingOfflineCoin_)) or "当前可以领取 12.35万",
                        fontSize = 22,
                        fontColor = { 65, 50, 40, 255 },
                        textAlign = "center",
                    },
                    UI.Button {
                        text = "领取",
                        width = 92,
                        height = 36,
                        fontSize = 22,
                        backgroundColor = { 158, 48, 30, 255 },
                        pressedBackgroundColor = { 120, 32, 22, 255 },
                        textColor = { 255, 245, 220, 255 },
                        borderRadius = 18,
                        onClick = function()
                            playerSave_.coin = playerSave_.coin + 123500
                            playerSave_.idle.lastCollectTime = Now()
                            pendingOfflineCoin_ = 0
                            RequestUpdateSave("领取挂机收益", function()
                                UpdateHomeLabels()
                            end)
                        end,
                    },
                },
            },

            UI.Panel {
                position = "absolute",
                top = 660,
                left = 0,
                right = 0,
                bottom = 126,
                children = {
                    UI.Panel {
                        position = "absolute",
                        top = 166,
                        left = 240,
                        right = 240,
                        height = 72,
                        borderRadius = 36,
                        backgroundColor = { 73, 225, 255, 230 },
                        borderWidth = 4,
                        borderColor = { 31, 138, 180, 255 },
                        alignItems = "center",
                        justifyContent = "center",
                        onClick = function()
                            print("[Home] Secret challenge clicked")
                        end,
                        children = {
                            UI.Label {
                                text = "秘境挑战",
                                fontSize = 30,
                                fontWeight = "bold",
                                fontColor = { 255, 255, 255, 255 },
                                textStroke = { width = 3, color = { 40, 120, 160, 255 } },
                            },
                        },
                    },
                    UI.Panel { position = "absolute", top = 0, left = 0, right = 0, height = 150, pointerEvents = "box-none", children = {
                        CreateCircleFeature("勇者", "left"),
                        CreateCircleFeature("福利", "right"),
                    } },
                    UI.Panel { position = "absolute", top = 294, left = 0, right = 0, height = 150, pointerEvents = "box-none", children = {
                        CreateCircleFeature("召唤", "left"),
                        CreateCircleFeature("宝物", "right"),
                    } },
                },
            },

            UI.Panel {
                position = "absolute",
                left = 0,
                right = 0,
                bottom = 0,
                height = 126,
                flexDirection = "row",
                children = {
                    CreateBottomNav("背包"),
                    CreateBottomNav("阵型"),
                    CreateBottomNav("冒险"),
                    CreateBottomNav("任务"),
                    CreateBottomNav("图鉴"),
                },
            },
        },
    }

    coinLabel_ = root:FindById("coinValue")
    offlineLabel_ = root:FindById("offlineRewardLabel")
    return root
end

local function EnterHomeScreen()
    ShowRoot(CreateHomeScreen())
    UpdateHomeLabels()
    print("[Main] Entered home screen")
end

local function CompleteLoginWithSave(rawSave)
    local now = Now()
    playerSave_ = NormalizeSave(rawSave, now)
    ApplyOfflineSettlement(now)

    RequestUpdateSave("登录离线收益结算", function()
        EnterHomeScreen()
    end, function(reason)
        isLoggingIn_ = false
        if loginButton_ then
            loginButton_:SetDisabled(false)
            loginButton_:SetText("登录")
        end
        SetLoginStatus("保存失败：" .. tostring(reason))
    end)
end

local function HandleLogin()
    if isLoggingIn_ then return end
    isLoggingIn_ = true

    if loginButton_ then
        loginButton_:SetDisabled(true)
        loginButton_:SetText("读档中")
    end
    SetLoginStatus("正在请求存档...")

    RequestPlayerSave(function(rawSave)
        SetLoginStatus("正在结算离线收益...")
        CompleteLoginWithSave(rawSave)
    end, function(reason)
        isLoggingIn_ = false
        if loginButton_ then
            loginButton_:SetDisabled(false)
            loginButton_:SetText("重试")
        end
        SetLoginStatus("读档失败：" .. tostring(reason))
    end)
end

local function CreateLoginButton()
    loginButton_ = UI.Button {
        id = "loginButton",
        text = "登录",
        width = 260,
        height = 76,
        fontSize = 30,
        fontWeight = "bold",
        backgroundColor = { 255, 202, 84, 255 },
        hoverBackgroundColor = { 255, 218, 112, 255 },
        pressedBackgroundColor = { 222, 156, 44, 255 },
        textColor = { 92, 48, 20, 255 },
        borderRadius = 38,
        borderWidth = 3,
        borderColor = { 255, 245, 180, 230 },
        boxShadow = {
            { x = 0, y = 8, blur = 18, spread = 0, color = { 60, 32, 12, 120 } },
        },
        transition = "scale 0.12s easeOut, backgroundColor 0.12s easeOut",
        onClick = function()
            HandleLogin()
        end,
    }
    return loginButton_
end

local function CreateLoginScreen()
    loginStatusLabel_ = UI.Label {
        id = "loginStatusLabel",
        text = "登录后读取存档并结算离线收益",
        fontSize = 18,
        fontColor = { 255, 248, 220, 230 },
        textAlign = "center",
        textStroke = { width = 2, color = { 0, 0, 0, 180 } },
    }

    return UI.Panel {
        id = "loginScreen",
        width = DESIGN_WIDTH,
        height = DESIGN_HEIGHT,
        backgroundImage = LOGIN_BACKGROUND_IMAGE,
        backgroundFit = "cover",
        justifyContent = "center",
        alignItems = "center",
        overflow = "hidden",
        children = {
            UI.Panel {
                id = "centerLayer",
                width = "100%",
                height = "100%",
                justifyContent = "center",
                alignItems = "center",
                pointerEvents = "box-none",
                gap = 16,
                children = {
                    CreateLoginButton(),
                    loginStatusLabel_,
                },
            },
        },
    }
end

function Start()
    graphics.windowTitle = "伙伴挂机"

    UI.Init({
        theme = "default-dark",
        scale = UI.Scale.DESIGN_RESOLUTION(DESIGN_WIDTH, DESIGN_HEIGHT),
    })

    ShowRoot(CreateLoginScreen())

    print("[Main] Login screen initialized at 720x1280 design resolution")
end

function Stop()
    UI.Shutdown()
    uiRoot_ = nil
    loginButton_ = nil
    loginStatusLabel_ = nil
    coinLabel_ = nil
    offlineLabel_ = nil
end
