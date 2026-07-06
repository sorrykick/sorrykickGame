local UI = require("urhox-libs/UI")
local NormalizedSprite = require("UI.NormalizedSprite")
local SaveManager = require("Save.SaveManager")
local GridBattleScene = require("Battle.GridBattleScene")
local FormationScene = require("Formation.FormationScene")
local InventoryScene = require("Inventory.InventoryScene")
local HeroGrowthScene = require("Hero.HeroGrowthScene")
local HeroSkillScene = require("Hero.HeroSkillScene")
local HeroCodexScene = require("Hero.HeroCodexScene")
local LevelManager = require("Level.LevelManager")
local SecretRealmDialog = require("Level.SecretRealmDialog")

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
local HERO1_CLIP_DIR = "image/npcClip/0001"
local HOME_HERO_SWITCH_MIN_SECONDS = 3.0
local HOME_HERO_SWITCH_MAX_SECONDS = 5.0
local HOME_HERO_MAX_DISPLAY = 5
local HOME_HERO_WIDTH = 150
local HOME_HERO_HEIGHT = 120
local HOME_HERO_SLOT_LEFTS = { 2, 142, 282, 422, 562 }

local HERO1_ANIMATIONS = {
    idle = { label = "待机", frames = { 1, 2, 3, 4 }, fps = 5, loop = true, width = HOME_HERO_WIDTH, height = HOME_HERO_HEIGHT },
    move = { label = "移动", frames = { 6, 7, 8, 9 }, fps = 8, loop = true, width = HOME_HERO_WIDTH, height = HOME_HERO_HEIGHT },
    attack = { label = "攻击", frames = { 10, 11, 12, 13, 14 }, fps = 10, loop = false, returnTo = "move", width = HOME_HERO_WIDTH, height = HOME_HERO_HEIGHT },
}
local HERO1_ACTION_ORDER = { "move", "attack" }

---@type Widget|nil
local uiRoot_ = nil
---@type Widget|nil
local loginButton_ = nil
---@type Widget|nil
local loginStatusLabel_ = nil
---@type Widget|nil
local coinLabel_ = nil
---@type Widget|nil
local diamondLabel_ = nil
---@type Widget|nil
local crystalLabel_ = nil
---@type Widget|nil
local timeLabel_ = nil
---@type Widget|nil
local offlineLabel_ = nil
---@type Widget|nil
local stageTitleLabel_ = nil
---@type Widget|nil
local stageForestLayerA_ = nil
---@type Widget|nil
local stageForestLayerB_ = nil
---@type table
local homeHeroSprites_ = {}
---@type table|nil
local battleScene_ = nil
---@type table|nil
local formationScene_ = nil
---@type table|nil
local inventoryScene_ = nil
---@type table|nil
local heroGrowthScene_ = nil
---@type table|nil
local heroSkillScene_ = nil
---@type table|nil
local heroCodexScene_ = nil
---@type table|nil
local secretRealmDialog_ = nil

local ClearCloudSaveAndRestart = nil
local CreateLoginScreen = nil

local STAGE_FOREST_WIDTH = 1024
local STAGE_FOREST_HEIGHT = 309
local STAGE_FOREST_SPEED = 28

local isLoggingIn_ = false
local isClearingCloudSave_ = false
local pendingLoginStatusText_ = nil
local stageForestOffset_ = 0
local topResourceRefreshTimer_ = 0
local homeDisplayedHeroes_ = {}
local hero1CurrentHeroId_ = nil
local hero1SwitchTimer_ = 0
local hero1SwitchInterval_ = HOME_HERO_SWITCH_MIN_SECONDS
local hero1AnimName_ = "move"
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
    ["冒险"] = "image/edited_nav_skill_20260706082834.png",
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

local function FormatClockTime()
    return os.date("%H:%M", os.time())
end

local function GetHeroFramePath(clipDir, frameNumber)
    local dir = tostring(clipDir or HERO1_CLIP_DIR)
    local path = string.format("%s/%02d.png", dir, frameNumber)
    if cache and not cache:Exists(path) then
        return string.format("%s/%02d.png", HERO1_CLIP_DIR, frameNumber)
    end
    return path
end

local function GetHeroId(hero)
    return tostring(hero and (hero.id or hero.npcId or hero.configId) or "")
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

    for index, sprite in ipairs(homeHeroSprites_) do
        local hero = homeDisplayedHeroes_[index]
        if sprite and hero then
            sprite:SetStyle({
                visible = true,
                width = anim.width,
                height = anim.height,
                backgroundImage = GetHeroFramePath(hero.clipDir, anim.frames[hero1FrameIndex_]),
            })
        end
    end

    print("[Hero1] Play animation: " .. anim.label)
end

local function PlayNextHero1Action()
    hero1ActionOrderIndex_ = hero1ActionOrderIndex_ % #HERO1_ACTION_ORDER + 1
    SetHero1Animation(HERO1_ACTION_ORDER[hero1ActionOrderIndex_])
end

local function UpdateHero1Animation(timeStep)
    if #homeHeroSprites_ == 0 then return end

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
            SetHero1Animation(anim.returnTo or "move")
            return
        end
    end

    for index, sprite in ipairs(homeHeroSprites_) do
        local hero = homeDisplayedHeroes_[index]
        if sprite and hero then
            sprite:SetBackgroundImage(GetHeroFramePath(hero.clipDir, anim.frames[hero1FrameIndex_]))
        end
    end
end

local function ScheduleNextHomeHeroSwitch()
    hero1SwitchTimer_ = 0
    hero1SwitchInterval_ = HOME_HERO_SWITCH_MIN_SECONDS + math.random() * (HOME_HERO_SWITCH_MAX_SECONDS - HOME_HERO_SWITCH_MIN_SECONDS)
end

local function GetOwnedDisplayHeroes()
    local saveData = SaveManager.GetSaveData()
    local result = {}
    for _, hero in ipairs(saveData and saveData.heroes or {}) do
        if type(hero) == "table" and hero.clipDir and hero.clipDir ~= "" then
            result[#result + 1] = hero
        end
    end
    return result
end

local function GetDefaultHeroGrowthHeroId()
    local saveData = SaveManager.GetSaveData()
    local heroes = saveData and saveData.heroes or {}
    for _, hero in ipairs(heroes) do
        if type(hero) == "table" and hero.id then
            return hero.id
        end
    end
    return nil
end

local function PickInitialHomeHeroes(heroes)
    local pool = {}
    for _, hero in ipairs(heroes or {}) do
        pool[#pool + 1] = hero
    end

    homeDisplayedHeroes_ = {}
    local count = math.min(HOME_HERO_MAX_DISPLAY, #pool)
    for index = 1, count do
        local pickIndex = math.random(1, #pool)
        homeDisplayedHeroes_[index] = table.remove(pool, pickIndex)
    end
end

local function RefreshHomeHeroSprites()
    local anim = HERO1_ANIMATIONS[hero1AnimName_] or HERO1_ANIMATIONS.move
    local frame = anim.frames[hero1FrameIndex_] or anim.frames[1]
    for index, sprite in ipairs(homeHeroSprites_) do
        local hero = homeDisplayedHeroes_[index]
        if sprite then
            sprite:SetStyle({
                visible = hero ~= nil,
                backgroundImage = hero and GetHeroFramePath(hero.clipDir, frame) or GetHeroFramePath(HERO1_CLIP_DIR, frame),
            })
        end
    end
end

local function SelectHomeHeroes()
    local heroes = GetOwnedDisplayHeroes()
    if #heroes == 0 then
        homeDisplayedHeroes_ = {}
        RefreshHomeHeroSprites()
        ScheduleNextHomeHeroSwitch()
        print("[HomeHero] Display hero count: 0")
        return
    else
        PickInitialHomeHeroes(heroes)
    end

    hero1CurrentHeroId_ = homeDisplayedHeroes_[1] and GetHeroId(homeDisplayedHeroes_[1]) or nil
    SetHero1Animation("move")
    ScheduleNextHomeHeroSwitch()
    print("[HomeHero] Display hero count: " .. tostring(#homeDisplayedHeroes_))
end

local function ReplaceOneHomeHero()
    local heroes = GetOwnedDisplayHeroes()
    if #heroes <= #homeDisplayedHeroes_ or #homeDisplayedHeroes_ == 0 then
        ScheduleNextHomeHeroSwitch()
        return
    end

    local displayed = {}
    for _, hero in ipairs(homeDisplayedHeroes_) do
        displayed[GetHeroId(hero)] = true
    end

    local candidates = {}
    for _, hero in ipairs(heroes) do
        if not displayed[GetHeroId(hero)] then
            candidates[#candidates + 1] = hero
        end
    end

    if #candidates == 0 then
        ScheduleNextHomeHeroSwitch()
        return
    end

    local slotIndex = math.random(1, #homeDisplayedHeroes_)
    local selected = candidates[math.random(1, #candidates)]
    homeDisplayedHeroes_[slotIndex] = selected
    hero1CurrentHeroId_ = GetHeroId(selected)
    RefreshHomeHeroSprites()
    ScheduleNextHomeHeroSwitch()
    print("[HomeHero] Replace display hero: " .. tostring(selected.name or hero1CurrentHeroId_))
end

local function UpdateHomeHeroSwitch(timeStep)
    if #homeHeroSprites_ == 0 then return end

    hero1SwitchTimer_ = hero1SwitchTimer_ + timeStep
    if hero1SwitchTimer_ >= hero1SwitchInterval_ then
        ReplaceOneHomeHero()
    end
end

local function UpdateTopResourceLabels()
    local saveData = SaveManager.GetSaveData()
    if timeLabel_ then
        timeLabel_:SetText(FormatClockTime())
    end
    if not saveData then return end
    if coinLabel_ then
        coinLabel_:SetText(FormatNumber(saveData.coin))
    end
    if diamondLabel_ then
        diamondLabel_:SetText(FormatNumber(saveData.diamond))
    end
    if crystalLabel_ then
        crystalLabel_:SetText(FormatNumber(saveData.crystal))
    end
end

local function UpdateHomeLabels()
    local saveData = SaveManager.GetSaveData()
    if not saveData then return end

    UpdateTopResourceLabels()
    if offlineLabel_ then
        local pendingOfflineCoin = SaveManager.GetPendingOfflineCoin()
        if pendingOfflineCoin > 0 then
            offlineLabel_:SetText("本次离线收益 +" .. FormatNumber(pendingOfflineCoin))
        else
            offlineLabel_:SetText("暂无可领取收益")
        end
    end
    if stageTitleLabel_ then
        stageTitleLabel_:SetText(LevelManager.GetCurrentStageTitle(saveData))
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

local function DestroyBattleScene()
    if battleScene_ then
        battleScene_:Destroy()
        battleScene_ = nil
    end
end

local function DestroyFormationScene()
    if formationScene_ then
        formationScene_:Destroy()
        formationScene_ = nil
    end
end

local function DestroyInventoryScene()
    if inventoryScene_ then
        inventoryScene_:Destroy()
        inventoryScene_ = nil
    end
end

local function DestroyHeroGrowthScene()
    if heroGrowthScene_ then
        heroGrowthScene_:Destroy()
        heroGrowthScene_ = nil
    end
end

local function DestroyHeroSkillScene()
    if heroSkillScene_ then
        heroSkillScene_:Destroy()
        heroSkillScene_ = nil
    end
end

local function DestroyHeroCodexScene()
    if heroCodexScene_ then
        heroCodexScene_:Destroy()
        heroCodexScene_ = nil
    end
end

local function DestroySecretRealmDialog()
    if secretRealmDialog_ then
        secretRealmDialog_:Destroy()
        secretRealmDialog_ = nil
    end
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
    if battleScene_ then
        battleScene_:Update(timeStep)
        return
    end
    if stageForestLayerA_ and stageForestLayerB_ then
        stageForestOffset_ = (stageForestOffset_ + STAGE_FOREST_SPEED * timeStep) % STAGE_FOREST_WIDTH
        UpdateStageForestLayers()
    end
    topResourceRefreshTimer_ = topResourceRefreshTimer_ + timeStep
    if topResourceRefreshTimer_ >= 1.0 then
        topResourceRefreshTimer_ = 0
        UpdateTopResourceLabels()
    end
    UpdateHero1Animation(timeStep)
    UpdateHomeHeroSwitch(timeStep)
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
            if label == "设置" and ClearCloudSaveAndRestart then
                ClearCloudSaveAndRestart()
            end
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

local EnterHomeScreen
local EnterBattleScreen
local EnterFormationScreen
local EnterInventoryScreen
local EnterHeroGrowthScreen
local EnterHeroSkillScreen
local EnterHeroCodexScreen
local ShowSecretRealmDialog

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
        onClick = function(_, event)
            if event then
                event:StopPropagation()
            end
            print("[Home] Feature clicked: " .. label)
            if label == "勇者" and EnterHeroGrowthScreen then
                EnterHeroGrowthScreen(GetDefaultHeroGrowthHeroId())
            end
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
            if label == "背包" then
                EnterInventoryScreen()
            elseif label == "阵型" then
                EnterFormationScreen()
            elseif label == "图鉴" and EnterHeroCodexScreen then
                EnterHeroCodexScreen()
            end
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

local function OpenHomeDisplayedHero(hero)
    if hero and EnterHeroGrowthScreen then
        print("[HomeHero] Open growth: " .. tostring(hero.name or hero.id))
        EnterHeroGrowthScreen(hero.id)
        return
    end
    PlayNextHero1Action()
end

local function CreateHero1Actor()
    homeDisplayedHeroes_ = {}
    homeHeroSprites_ = {}
    hero1CurrentHeroId_ = nil
    hero1SwitchTimer_ = 0
    hero1SwitchInterval_ = HOME_HERO_SWITCH_MIN_SECONDS
    hero1AnimName_ = "move"
    hero1FrameIndex_ = 1
    hero1FrameTimer_ = 0
    hero1ActionOrderIndex_ = 1

    local children = {}
    for index = 1, HOME_HERO_MAX_DISPLAY do
        local sprite = NormalizedSprite {
            width = HOME_HERO_WIDTH,
            height = HOME_HERO_HEIGHT,
            position = "absolute",
            left = HOME_HERO_SLOT_LEFTS[index] or ((index - 1) * 140 + 2),
            top = 0,
            visible = false,
            backgroundImage = GetHeroFramePath(HERO1_CLIP_DIR, HERO1_ANIMATIONS.move.frames[1]),
            backgroundFit = "contain",
            imageTint = { 255, 255, 255, 255 },
            transition = "scale 0.12s easeOut",
            onClick = function(_, event)
                if event then
                    event:StopPropagation()
                end
                OpenHomeDisplayedHero(homeDisplayedHeroes_[index])
            end,
        }
        homeHeroSprites_[index] = sprite
        children[index] = sprite
    end

    return UI.Panel {
        id = "Hanginglist",
        position = "absolute",
        top = 159,
        left = 0,
        width = 720,
        height = 148,
        backgroundColor = { 255, 255, 255, 0 },
        onClick = function()
            PlayNextHero1Action()
        end,
        children = children,
    }
end

local function CreateTopResourceRow(saveData)
    return UI.Panel {
        id = "顶级",
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
                children = { UI.Label { id = "time", text = FormatClockTime(), fontSize = 18, fontColor = { 255, 255, 255, 255 } } },
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
            CreateTopResourceRow(saveData),
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
        },
    }
end

local function ClearHomeRuntimeLabels()
    timeLabel_ = nil
    coinLabel_ = nil
    diamondLabel_ = nil
    crystalLabel_ = nil
    offlineLabel_ = nil
    stageTitleLabel_ = nil
end

local function BindTopResourceLabels(root)
    timeLabel_ = root and root:FindById("time") or nil
    coinLabel_ = root and root:FindById("coinValue") or nil
    diamondLabel_ = root and root:FindById("diamondValue") or nil
    crystalLabel_ = root and root:FindById("crystalValue") or nil
    UpdateTopResourceLabels()
end

local function CreateHomeScreen()
    ClearHomeRuntimeLabels()
    homeHeroSprites_ = {}

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
                        id = "stageTitleLabel",
                        text = LevelManager.GetCurrentStageTitle(SaveManager.GetSaveData()),
                        width = 420,
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
                top = 530,
                left = 0,
                right = 6,
                width = 720,
                height = 50,
                borderRadius = 0,
                flexDirection = "row",
                alignItems = "center",
                justifyContent = "center",
                gap = 18,
                backgroundImage = REWARD_BAR_IMAGE,
                backgroundFit = "fill",
                children = {
                    UI.Label {
                        id = "offlineRewardLabel",
                        text = SaveManager.GetPendingOfflineCoin() > 0 and ("本次离线收益 +" .. FormatNumber(SaveManager.GetPendingOfflineCoin())) or "暂无可领取收益",
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
                            SaveManager.CollectIdleReward(SaveManager.GetPendingOfflineCoin(), function()
                                UpdateHomeLabels()
                            end, function(reason)
                                print("[Home] Collect idle reward failed: " .. tostring(reason))
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
                            if ShowSecretRealmDialog then
                                ShowSecretRealmDialog()
                            end
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

    BindTopResourceLabels(root)
    offlineLabel_ = root:FindById("offlineRewardLabel")
    stageTitleLabel_ = root:FindById("stageTitleLabel")
    SelectHomeHeroes()
    return root
end

EnterHomeScreen = function()
    DestroyBattleScene()
    DestroyFormationScene()
    DestroyInventoryScene()
    DestroyHeroGrowthScene()
    DestroyHeroSkillScene()
    DestroyHeroCodexScene()
    DestroySecretRealmDialog()
    ShowRoot(CreateHomeScreen())
    UpdateHomeLabels()
    print("[Main] Entered home screen")
end

ShowSecretRealmDialog = function()
    DestroyHeroGrowthScene()
    DestroyHeroSkillScene()
    DestroyHeroCodexScene()
    DestroySecretRealmDialog()
    secretRealmDialog_ = SecretRealmDialog:new({
        saveDataProvider = function()
            return SaveManager.GetSaveData()
        end,
        createTopResourceRow = function()
            return CreateTopResourceRow(SaveManager.GetSaveData())
        end,
        onRootChanged = function(root)
            BindTopResourceLabels(root)
        end,
        onClose = function()
            DestroySecretRealmDialog()
            EnterHomeScreen()
        end,
        onChallenge = function()
            DestroySecretRealmDialog()
            EnterBattleScreen()
        end,
    })
    local root = secretRealmDialog_:CreateRoot()
    ShowRoot(root)
    BindTopResourceLabels(root)
    print("[Main] Opened secret realm dialog")
end

EnterBattleScreen = function()
    DestroyFormationScene()
    DestroyInventoryScene()
    DestroyHeroGrowthScene()
    DestroyHeroSkillScene()
    DestroyHeroCodexScene()
    DestroySecretRealmDialog()
    stageForestLayerA_ = nil
    stageForestLayerB_ = nil
    ClearHomeRuntimeLabels()
    homeHeroSprites_ = {}

    battleScene_ = GridBattleScene:new({
        onExit = function()
            EnterHomeScreen()
        end,
    })
    ShowRoot(battleScene_:CreateRoot())
    print("[Main] Entered battle screen")
end

EnterFormationScreen = function()
    DestroyBattleScene()
    DestroyInventoryScene()
    DestroyHeroGrowthScene()
    DestroyHeroSkillScene()
    DestroyHeroCodexScene()
    DestroySecretRealmDialog()
    stageForestLayerA_ = nil
    stageForestLayerB_ = nil
    ClearHomeRuntimeLabels()
    homeHeroSprites_ = {}

    formationScene_ = FormationScene:new({
        onExit = function()
            EnterHomeScreen()
        end,
        createTopResourceRow = function()
            return CreateTopResourceRow(SaveManager.GetSaveData())
        end,
        onRootChanged = function(root)
            BindTopResourceLabels(root)
        end,
    })
    local root = formationScene_:CreateRoot()
    ShowRoot(root)
    BindTopResourceLabels(root)
    print("[Main] Entered formation screen")
end

EnterInventoryScreen = function()
    DestroyBattleScene()
    DestroyFormationScene()
    DestroyHeroGrowthScene()
    DestroyHeroSkillScene()
    DestroyHeroCodexScene()
    DestroySecretRealmDialog()
    stageForestLayerA_ = nil
    stageForestLayerB_ = nil
    ClearHomeRuntimeLabels()
    homeHeroSprites_ = {}

    inventoryScene_ = InventoryScene:new({
        onExit = function()
            EnterHomeScreen()
        end,
        createTopResourceRow = function()
            return CreateTopResourceRow(SaveManager.GetSaveData())
        end,
        onRootChanged = function(root)
            BindTopResourceLabels(root)
        end,
    })
    local root = inventoryScene_:CreateRoot()
    ShowRoot(root)
    BindTopResourceLabels(root)
    print("[Main] Entered inventory screen")
end

EnterHeroGrowthScreen = function(heroId)
    DestroyBattleScene()
    DestroyFormationScene()
    DestroyInventoryScene()
    DestroyHeroGrowthScene()
    DestroyHeroSkillScene()
    DestroyHeroCodexScene()
    DestroySecretRealmDialog()
    stageForestLayerA_ = nil
    stageForestLayerB_ = nil
    ClearHomeRuntimeLabels()
    homeHeroSprites_ = {}

    heroGrowthScene_ = HeroGrowthScene:new({
        selectedHeroId = heroId,
        onExit = function()
            EnterHomeScreen()
        end,
        onOpenSkill = function(selectedHeroId)
            EnterHeroSkillScreen(selectedHeroId)
        end,
        createTopResourceRow = function()
            return CreateTopResourceRow(SaveManager.GetSaveData())
        end,
        onRootChanged = function(root)
            BindTopResourceLabels(root)
        end,
    })
    local root = heroGrowthScene_:CreateRoot()
    ShowRoot(root)
    BindTopResourceLabels(root)
    print("[Main] Entered hero growth screen: " .. tostring(heroId))
end

EnterHeroSkillScreen = function(heroId)
    DestroyBattleScene()
    DestroyFormationScene()
    DestroyInventoryScene()
    DestroyHeroGrowthScene()
    DestroyHeroSkillScene()
    DestroyHeroCodexScene()
    DestroySecretRealmDialog()
    stageForestLayerA_ = nil
    stageForestLayerB_ = nil
    ClearHomeRuntimeLabels()
    homeHeroSprites_ = {}

    heroSkillScene_ = HeroSkillScene:new({
        selectedHeroId = heroId,
        onExit = function(selectedHeroId)
            EnterHeroGrowthScreen(selectedHeroId or heroId)
        end,
        createTopResourceRow = function()
            return CreateTopResourceRow(SaveManager.GetSaveData())
        end,
        onRootChanged = function(root)
            BindTopResourceLabels(root)
        end,
    })
    local root = heroSkillScene_:CreateRoot()
    ShowRoot(root)
    BindTopResourceLabels(root)
    print("[Main] Entered hero skill screen: " .. tostring(heroId))
end

EnterHeroCodexScreen = function()
    DestroyBattleScene()
    DestroyFormationScene()
    DestroyInventoryScene()
    DestroyHeroGrowthScene()
    DestroyHeroSkillScene()
    DestroyHeroCodexScene()
    DestroySecretRealmDialog()
    stageForestLayerA_ = nil
    stageForestLayerB_ = nil
    ClearHomeRuntimeLabels()
    homeHeroSprites_ = {}

    heroCodexScene_ = HeroCodexScene:new({
        onExit = function()
            EnterHomeScreen()
        end,
        createTopResourceRow = function()
            return CreateTopResourceRow(SaveManager.GetSaveData())
        end,
        onRootChanged = function(root)
            BindTopResourceLabels(root)
        end,
    })
    local root = heroCodexScene_:CreateRoot()
    ShowRoot(root)
    BindTopResourceLabels(root)
    print("[Main] Entered hero codex screen")
end

local function ReturnToLoginScreen(statusText)
    DestroyBattleScene()
    DestroyFormationScene()
    DestroyInventoryScene()
    DestroyHeroGrowthScene()
    DestroyHeroSkillScene()
    DestroyHeroCodexScene()
    DestroySecretRealmDialog()
    ClearHomeRuntimeLabels()
    stageForestLayerA_ = nil
    stageForestLayerB_ = nil
    homeHeroSprites_ = {}
    homeDisplayedHeroes_ = {}
    pendingLoginStatusText_ = statusText
    isLoggingIn_ = false
    ShowRoot(CreateLoginScreen())
    if pendingLoginStatusText_ then
        SetLoginStatus(pendingLoginStatusText_)
        pendingLoginStatusText_ = nil
    end
end

ClearCloudSaveAndRestart = function()
    if isClearingCloudSave_ then
        print("[Home] Clear cloud save ignored, already clearing")
        return
    end

    isClearingCloudSave_ = true
    print("[Home] Start clear cloud save")
    SaveManager.ClearCloudSave(function()
        isClearingCloudSave_ = false
        ReturnToLoginScreen("云存档已清除，请重新登录开始新游戏")
    end, function(reason)
        isClearingCloudSave_ = false
        print("[Home] Clear cloud save failed: " .. tostring(reason))
    end, function(statusText)
        print("[Home] " .. tostring(statusText))
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
    end, function(statusText)
        SetLoginStatus(statusText)
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

CreateLoginScreen = function()
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
    math.randomseed(os.time())

    UI.Init({
        theme = "default-dark",
        scale = UI.Scale.DESIGN_RESOLUTION(DESIGN_WIDTH, DESIGN_HEIGHT),
    })

    ShowRoot(CreateLoginScreen())
    SubscribeToEvent("Update", "HandleUpdate")

    print("[Main] Login screen initialized at 720x1280 design resolution")
end

function Stop()
    DestroyBattleScene()
    DestroyFormationScene()
    DestroyInventoryScene()
    DestroyHeroGrowthScene()
    DestroyHeroSkillScene()
    DestroyHeroCodexScene()
    DestroySecretRealmDialog()
    UI.Shutdown()
    uiRoot_ = nil
    loginButton_ = nil
    loginStatusLabel_ = nil
    coinLabel_ = nil
    diamondLabel_ = nil
    crystalLabel_ = nil
    timeLabel_ = nil
    offlineLabel_ = nil
    stageForestLayerA_ = nil
    stageForestLayerB_ = nil
    ClearHomeRuntimeLabels()
    homeHeroSprites_ = {}
end
