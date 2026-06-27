local UI = require("urhox-libs/UI")

local DESIGN_WIDTH = 720
local DESIGN_HEIGHT = 1280
local BACKGROUND_IMAGE = "image/login_background.png"

---@type Widget|nil
local uiRoot_ = nil

local function CreateLoginButton()
    return UI.Button {
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
            print("[Login] Login button clicked")
        end,
    }
end

local function CreateLoginScreen()
    return UI.Panel {
        id = "loginScreen",
        width = DESIGN_WIDTH,
        height = DESIGN_HEIGHT,
        backgroundImage = BACKGROUND_IMAGE,
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
                children = {
                    CreateLoginButton(),
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

    uiRoot_ = CreateLoginScreen()
    UI.SetRoot(uiRoot_)

    print("[Main] Login screen initialized at 720x1280 design resolution")
end

function Stop()
    UI.Shutdown()
    uiRoot_ = nil
end
