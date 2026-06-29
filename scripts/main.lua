local UI = require("urhox-libs/UI")
local SaveManager = require("Save.SaveManager")

local DESIGN_WIDTH = 720
local DESIGN_HEIGHT = 1280
local LOGIN_BACKGROUND_IMAGE = "image/login_background.png"
local MAIN_BACKGROUND_IMAGE = "image/main_bg_blur.png"
local STAGE_FOREST_IMAGE = "image/stage_forest_bg.png"
local REWARD_BAR_IMAGE = "image/reward_bar.png"
local BOTTOM_NAV_BG_IMAGE = "image/bottom_nav_bg.png"
local SECRET_REALM_BG_IMAGE = "image/secret_realm_bg.png"
local SECRET_BUTTON_IMAGE = "image/btn_secret_challenge.png"
local CHALLENGE_BADGE_LEFT_IMAGE = "image/challenge_badge_left.png"
local CHALLENGE_BADGE_RIGHT_IMAGE = "image/challenge_badge_right.png"
local TITLE_TOP_IMAGE = "image/P-标题-上.png"
local HERO1_CLIP_DIR = "image/npcClip/1"

local HERO1_ANIMATIONS = {
    idle = { label = "待机", frames = { 1, 2, 3, 4 }, fps = 5, loop = true, width = 300, height = 240 },
    move = { label = "移动", frames = { 6, 7, 8, 9 }, fps = 8, loop = true, width = 300, height = 240 },
    attack = { label = "攻击", frames = { 10, 11, 12, 13, 14 }, fps = 10, loop = false, returnTo = "idle", width = 360, height = 240 },
}
local HERO1_ACTION_ORDER = { "idle", "move", "attack" }

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
---@type Widget|nil
local stageForestLayerA_ = nil
---@type Widget|nil
local stageForestLayerB_ = nil
---@type Widget|nil
local hero1Sprite_ = nil
---@type Widget|nil
local hero1ActionLabel_ = nil

local STAGE_FOREST_WIDTH = 1024
local STAGE_FOREST_HEIGHT = 309
local STAGE_FOREST_SPEED = 28

local isLoggingIn_ = false
local stageForestOffset_ = 0
local hero1AnimName_ = "idle"
local hero1FrameIndex_ = 1
local hero1FrameTimer_ = 0
local hero1ActionOrderIndex_ = 1

local RESOURCE_ICONS = {
    coin = "image/icon_gold.png",
    diamond = "image/icon_gem_blue.png",
    crystal = "image/icon_gem_white.png",
}

local TOP_MENU_ICONS = {
    ["签到"] = "image/icon_signin.png",
    ["商城"] = "image/icon_shop.png",
    ["邮件"] = "image/icon_mail.png",
    ["成就"] = "image/icon_achievement.png",
    ["设置"] = "image/icon_settings.png",
}

local FEATURE_ICONS = {
    ["勇者"] = "image/icon_hero.png",
    ["福利"] = "image/icon_welfare.png",
    ["召唤"] = "image/icon_summon.png",
    ["宝物"] = "image/icon_treasure.png",
}

local BOTTOM_NAV_ICONS = {
    ["背包"] = "image/nav_bag.png",
    ["阵型"] = "image/nav_formation.png",
    ["冒险"] = "image/nav_adventure.png",
    ["任务"] = "image/nav_adventure.png",
    ["图鉴"] = "image/nav_codex.png",
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

local function GetHero1FramePath(frameNumber)
    return string.format("%s/%02d.png", HERO1_CLIP_DIR, frameNumber)
end

local function SetHero1Animation(name)
    local anim = HERO1_ANIMATIONS[name]
    if not anim then
        print("[Hero1] Unknown animation: " .. tostring(name))
        return
    end

    hero1AnimName_ = name
    hero1FrameIndex_ = 1
    hero1FrameTimer_ = 0

    if hero1Sprite_ then
        hero1Sprite_:SetStyle({
            width = anim.width,
            height = anim.height,
            backgroundImage = GetHero1FramePath(anim.frames[hero1FrameIndex_]),
        })
    end
    if hero1ActionLabel_ then
        hero1ActionLabel_:SetText("勇者1 · " .. anim.label)
    end

    print("[Hero1] Play animation: " .. anim.label)
end

local function PlayNextHero1Action()
    hero1ActionOrderIndex_ = hero1ActionOrderIndex_ % #HERO1_ACTION_ORDER + 1
    SetHero1Animation(HERO1_ACTION_ORDER[hero1ActionOrderIndex_])
end

local function UpdateHero1Animation(timeStep)
    if not hero1Sprite_ then return end

    local anim = HERO1_ANIMATIONS[hero1AnimName_]
    if not anim then return end

    hero1FrameTimer_ = hero1FrameTimer_ + timeStep
    local frameDuration = 1 / anim.fps
    if hero1FrameTimer_ < frameDuration then return end

    hero1FrameTimer_ = hero1FrameTimer_ - frameDuration
    hero1FrameIndex_ = hero1FrameIndex_ + 1
    if hero1FrameIndex_ > #anim.frames then
        if anim.loop then
            hero1FrameIndex_ = 1
        else
            SetHero1Animation(anim.returnTo or "idle")
            return
        end
    end

    hero1Sprite_:SetBackgroundImage(GetHero1FramePath(anim.frames[hero1FrameIndex_]))
end

local function UpdateHomeLabels()
    local saveData = SaveManager.GetSaveData()
    if not saveData then return end

    if coinLabel_ then
        coinLabel_:SetText(FormatNumber(saveData.coin))
    end
    if offlineLabel_ then
        local pendingOfflineCoin = SaveManager.GetPendingOfflineCoin()
        if pendingOfflineCoin > 0 then
            offlineLabel_:SetText("本次离线收益 +" .. FormatNumber(pendingOfflineCoin))
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

local function UpdateStageForestLayers()
    if not stageForestLayerA_ or not stageForestLayerB_ then
        return
    end

    local x = -stageForestOffset_
    stageForestLayerA_:SetStyle({ left = x })
    stageForestLayerB_:SetStyle({ left = x + STAGE_FOREST_WIDTH })
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local timeStep = eventData["TimeStep"]:GetFloat()
    if stageForestLayerA_ and stageForestLayerB_ then
        stageForestOffset_ = (stageForestOffset_ + STAGE_FOREST_SPEED * timeStep) % STAGE_FOREST_WIDTH
        UpdateStageForestLayers()
    end
    UpdateHero1Animation(timeStep)
end

local function CreateResourcePill(id, value)
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
        paddingLeft = 5,
        paddingRight = 10,
        gap = 6,
        children = {
            UI.Panel {
                width = 30,
                height = 30,
                backgroundImage = RESOURCE_ICONS[id],
                backgroundFit = "contain",
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
        width = 96,
        height = 96,
        alignItems = "center",
        justifyContent = "flex-end",
        gap = 0,
        backgroundColor = { 255, 255, 255, 0 },
        onClick = function()
            print("[Home] Menu clicked: " .. label)
        end,
        children = {
            UI.Panel {
                width = 96,
                height = 96,
                left = 0,
                top = 0,
                backgroundImage = TOP_MENU_ICONS[label],
                backgroundFit = "contain",
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
    local left = side == "left" and 20 or nil
    local right = side == "right" and 20 or nil
    return UI.Panel {
        width = 160,
        height = 160,
        backgroundImage = FEATURE_ICONS[label],
        backgroundFit = "contain",
        alignItems = "center",
        justifyContent = "flex-end",
        position = "absolute",
        left = left,
        right = right,
        paddingBottom = 12,
        onClick = function()
            print("[Home] Feature clicked: " .. label)
        end,
    }
end

local function CreateBottomNav(label, index)
    local leftOffsets = { 0, 2, 4, 4, 2 }
    local itemHeight = index == 1 and 128 or 126
    return UI.Panel {
        flexGrow = 1,
        flexShrink = 1,
        width = 52,
        height = itemHeight,
        left = leftOffsets[index] or 0,
        top = index == 2 and 0 or nil,
        alignItems = "center",
        justifyContent = "center",
        backgroundColor = { 255, 255, 255, 0 },
        gap = 2,
        onClick = function()
            print("[Home] Bottom tab clicked: " .. label)
        end,
        children = {
            UI.Panel {
                width = 96,
                height = 96,
                left = index == 1 and 0 or nil,
                top = index == 1 and 0 or nil,
                backgroundImage = BOTTOM_NAV_ICONS[label],
                backgroundFit = "contain",
            },
            UI.Label {
                visible = false,
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

local function CreateHero1Actor()
    hero1AnimName_ = "idle"
    hero1FrameIndex_ = 1
    hero1FrameTimer_ = 0
    hero1ActionOrderIndex_ = 1

    hero1Sprite_ = UI.Panel {
        width = 300,
        height = 240,
        backgroundImage = GetHero1FramePath(1),
        backgroundFit = "contain",
        imageTint = { 255, 255, 255, 255 },
        transition = "scale 0.12s easeOut",
    }
    hero1ActionLabel_ = UI.Label {
        text = "勇者1 · 待机",
        height = 28,
        fontSize = 20,
        fontWeight = "bold",
        fontColor = { 255, 248, 214, 255 },
        textAlign = "center",
        textStroke = { width = 2, color = { 36, 28, 18, 230 } },
    }

    return UI.Panel {
        position = "absolute",
        top = 54,
        left = 180,
        width = 360,
        height = 246,
        alignItems = "center",
        justifyContent = "flex-end",
        backgroundColor = { 255, 255, 255, 0 },
        onClick = function()
            PlayNextHero1Action()
        end,
        children = {
            hero1Sprite_,
            hero1ActionLabel_,
        },
    }
end

local function CreateTopHud()
    local saveData = SaveManager.GetSaveData()
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
                    CreateResourcePill("coin", FormatNumber(saveData.coin)),
                    CreateResourcePill("diamond", FormatNumber(saveData.diamond)),
                    CreateResourcePill("crystal", FormatNumber(saveData.crystal)),
                    UI.Panel {
                        width = 44,
                        height = 44,
                        backgroundImage = "image/icon_add.png",
                        backgroundFit = "contain",
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
                },
            },
        },
    }
end

local function CreateStageForestPanel()
    local saveData = SaveManager.GetSaveData()
    stageForestOffset_ = 0
    stageForestLayerA_ = UI.Panel {
        position = "absolute",
        top = 0,
        left = 0,
        width = STAGE_FOREST_WIDTH,
        height = STAGE_FOREST_HEIGHT,
        backgroundImage = STAGE_FOREST_IMAGE,
        backgroundFit = "fill",
    }
    stageForestLayerB_ = UI.Panel {
        position = "absolute",
        top = 0,
        left = STAGE_FOREST_WIDTH,
        width = STAGE_FOREST_WIDTH,
        height = STAGE_FOREST_HEIGHT,
        backgroundImage = STAGE_FOREST_IMAGE,
        backgroundFit = "fill",
    }

    return UI.Panel {
        position = "absolute",
        top = 224,
        left = 0,
        right = 0,
        height = 310,
        overflow = "hidden",
        children = {
            stageForestLayerA_,
            stageForestLayerB_,
            UI.Panel {
                position = "absolute",
                top = 0,
                left = 0,
                right = 0,
                bottom = 0,
                backgroundColor = { 0, 0, 0, 22 },
                pointerEvents = "box-none",
            },
            UI.Panel {
                position = "absolute",
                top = 2,
                left = -1,
                width = 128,
                height = 136,
                backgroundImage = CHALLENGE_BADGE_LEFT_IMAGE,
                backgroundFit = "contain",
                onClick = function()
                    print("[Home] Player challenge clicked")
                    SetHero1Animation("attack")
                end,
            },
            UI.Panel {
                position = "absolute",
                top = 7,
                right = -9,
                width = 128,
                height = 136,
                backgroundImage = CHALLENGE_BADGE_RIGHT_IMAGE,
                backgroundFit = "contain",
                onClick = function()
                    print("[Home] Player growth clicked")
                    SetHero1Animation("move")
                end,
            },
            CreateHero1Actor(),
            UI.Label {
                text = "伙伴 Lv." .. tostring(saveData.partner.level),
                position = "absolute",
                left = 64,
                bottom = 18,
                fontSize = 22,
                fontColor = { 255, 255, 255, 255 },
                textStroke = { width = 2, color = { 0, 0, 0, 220 } },
            },
        },
    }
end

local function CreateHomeScreen()
    coinLabel_ = nil
    offlineLabel_ = nil
    hero1Sprite_ = nil
    hero1ActionLabel_ = nil

    local root = UI.Panel {
        id = "homeScreen",
        width = DESIGN_WIDTH,
        height = DESIGN_HEIGHT,
        backgroundImage = MAIN_BACKGROUND_IMAGE,
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
                top = 100,
                left = 19,
                right = 13,
                height = 96,
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
                top = 194,
                left = -2,
                right = 2,
                height = 56,
                zIndex = 10,
                backgroundImage = TITLE_TOP_IMAGE,
                backgroundFit = "fill",
                alignItems = "center",
                justifyContent = "center",
                children = {
                    UI.Label {
                        text = "第一章  迷失森林",
                        width = 388,
                        height = 41,
                        left = -3,
                        top = -2,
                        fontSize = 20,
                        fontColor = { 52, 36, 24, 255 },
                        textAlign = "center",
                    },
                },
            },

            CreateStageForestPanel(),

            UI.Panel {
                position = "absolute",
                top = 514,
                left = 5,
                right = 20,
                width = 712,
                height = 110,
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
                top = 614,
                left = 0,
                right = 6,
                width = 720,
                height = 50,
                flexDirection = "row",
                alignItems = "center",
                justifyContent = "center",
                gap = 18,
                backgroundImage = REWARD_BAR_IMAGE,
                backgroundFit = "fill",
                children = {
                    UI.Label {
                        id = "offlineRewardLabel",
                        text = SaveManager.GetPendingOfflineCoin() > 0 and ("本次离线收益 +" .. FormatNumber(SaveManager.GetPendingOfflineCoin())) or "当前可以领取 12.35万",
                        left = -78,
                        top = -2,
                        fontSize = 22,
                        fontColor = { 65, 50, 40, 255 },
                        textAlign = "center",
                    },
                    UI.Button {
                        text = "领取",
                        width = 115,
                        height = 39,
                        left = 114,
                        top = -2,
                        variant = "outline",
                        paddingTop = 0,
                        paddingRight = 16,
                        paddingBottom = 4,
                        paddingLeft = 16,
                        fontSize = 22,
                        backgroundColor = { 158, 48, 30, 255 },
                        pressedBackgroundColor = { 120, 32, 22, 255 },
                        textColor = { 255, 245, 220, 255 },
                        borderColor = { 0, 0, 0, 255 },
                        borderWidth = 1,
                        borderRadius = 30,
                        onClick = function()
                            SaveManager.CollectIdleReward(123500, function()
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
                        top = 54,
                        left = 190,
                        width = 339,
                        height = 242,
                        backgroundImage = SECRET_REALM_BG_IMAGE,
                        backgroundFit = "contain",
                        pointerEvents = "none",
                    },
                    UI.Panel {
                        position = "absolute",
                        top = 297,
                        left = 238,
                        width = 240,
                        height = 72,
                        backgroundImage = SECRET_BUTTON_IMAGE,
                        backgroundFit = "contain",
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
                                textAlign = "center",
                                textStroke = { width = 3, color = { 40, 120, 160, 255 } },
                            },
                        },
                    },
                    UI.Panel { position = "absolute", top = 0, left = 0, right = 0, height = 160, pointerEvents = "box-none", children = {
                        CreateCircleFeature("勇者", "left"),
                        CreateCircleFeature("福利", "right"),
                    } },
                    UI.Panel { position = "absolute", top = 294, left = 0, right = 0, height = 160, pointerEvents = "box-none", children = {
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
                height = 131,
                backgroundImage = BOTTOM_NAV_BG_IMAGE,
                backgroundFit = "fill",
                flexDirection = "row",
                children = {
                    CreateBottomNav("背包", 1),
                    CreateBottomNav("阵型", 2),
                    CreateBottomNav("冒险", 3),
                    CreateBottomNav("任务", 4),
                    CreateBottomNav("图鉴", 5),
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

local function HandleLogin()
    if isLoggingIn_ then return end
    isLoggingIn_ = true

    if loginButton_ then
        loginButton_:SetDisabled(true)
        loginButton_:SetText("读档中")
    end
    SetLoginStatus("正在请求存档...")

    SaveManager.LoginSyncPlayerSave(function()
        SetLoginStatus("正在进入主界面...")
        EnterHomeScreen()
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
    SubscribeToEvent("Update", "HandleUpdate")

    print("[Main] Login screen initialized at 720x1280 design resolution")
end

function Stop()
    UI.Shutdown()
    uiRoot_ = nil
    loginButton_ = nil
    loginStatusLabel_ = nil
    coinLabel_ = nil
    offlineLabel_ = nil
    stageForestLayerA_ = nil
    stageForestLayerB_ = nil
    hero1Sprite_ = nil
    hero1ActionLabel_ = nil
end
