-- コマンドライン(`hs` CLI)からHammerspoonを操作できるようにIPCを有効化する。
-- これによりターミナルから `hs -c "hs.reload()"` 等でリロードや実行が可能になる。
require("hs.ipc")

-- Claude Codeの通知クリックから、セッション開始時のWezTerm windowとpaneへ戻る。
local claudeWeztermSessions = {}

local function isWeztermWindow(window)
    if not window then return false end

    local app = window:application()
    if not app then return false end

    return app:name() == "WezTerm" or app:bundleID() == "com.github.wez.wezterm"
end

local function currentWeztermWindow()
    local app = hs.application.get("WezTerm")
    local window = app and app:focusedWindow()
    if isWeztermWindow(window) then return window end

    window = hs.window.focusedWindow()
    if isWeztermWindow(window) then return window end

    return nil
end

local function weztermBinary()
    local candidates = {
        "/opt/homebrew/bin/wezterm",
        "/usr/local/bin/wezterm",
        "/Applications/WezTerm.app/Contents/MacOS/wezterm",
    }

    for _, candidate in ipairs(candidates) do
        if hs.fs.attributes(candidate) then return candidate end
    end

    return nil
end

local function activateWeztermPane(paneId)
    local binary = weztermBinary()
    if not binary then return end

    hs.task.new(binary, function() end, {
        "cli",
        "activate-pane",
        "--pane-id",
        tostring(paneId),
    }):start()
end

hs.urlevent.bind("claude-wezterm-capture", function(_, params)
    local sessionId = params and params.session
    local paneId = params and params.pane
    if not sessionId or not sessionId:match("^[%w%-_]+$") then return end
    if not paneId or not paneId:match("^%d+$") then return end
    if claudeWeztermSessions[sessionId] then return end

    local window = currentWeztermWindow()
    if not window then
        hs.printf("Claude Code WezTerm capture skipped: no focused WezTerm window")
        return
    end

    claudeWeztermSessions[sessionId] = {
        paneId = paneId,
        window = window,
        capturedAt = os.time(),
    }
    hs.printf(
        "Claude Code WezTerm captured: session=%s pane=%s window=%s",
        sessionId,
        paneId,
        window:id()
    )
end)

hs.urlevent.bind("claude-wezterm-focus", function(_, params)
    local sessionId = params and params.session
    local paneId = params and params.pane
    if not sessionId or not sessionId:match("^[%w%-_]+$") then return end
    if paneId and not paneId:match("^%d+$") then return end

    local session = claudeWeztermSessions[sessionId]
    if not session then
        hs.printf("Claude Code WezTerm focus skipped: session not captured: %s", sessionId)
        return
    end

    paneId = session.paneId
    local window = session.window
    local app = window:application()
    if not app then
        hs.printf("Claude Code WezTerm focus skipped: window is unavailable")
        return
    end

    app:activate(false)
    window:raise()
    window:focus()

    hs.timer.doAfter(0.05, function()
        window:raise()
        window:focus()
        activateWeztermPane(paneId)
    end)
end)

-- URLで呼べる「中央寄せ」
hs.urlevent.bind("center", function()
    local win = hs.window.focusedWindow()
    if not win then return end
    win:centerOnScreen(nil, true) -- trueで画面外(ドック下など)に行きにくくする
end)

-- AeroSpace workspace HUD
-- フォーカス中のAeroSpaceワークスペース番号を画面中央下部に一時表示する。
local aerospaceWorkspaceCanvas = nil
local aerospaceWorkspaceHideTimer = nil

local function showAeroSpaceWorkspaceHUD(workspace)
    workspace = tostring(workspace or "?")

    if aerospaceWorkspaceHideTimer then
        aerospaceWorkspaceHideTimer:stop()
        aerospaceWorkspaceHideTimer = nil
    end

    if aerospaceWorkspaceCanvas then
        aerospaceWorkspaceCanvas:delete()
        aerospaceWorkspaceCanvas = nil
    end

    local screen = hs.screen.mainScreen()
    if not screen then return end

    local frame = screen:frame()

    local hudWidth = 96
    local hudHeight = 72
    local bottomMargin = 56

    local x = frame.x + (frame.w - hudWidth) / 2
    local y = frame.y + frame.h - hudHeight - bottomMargin

    aerospaceWorkspaceCanvas = hs.canvas.new({
        x = x,
        y = y,
        w = hudWidth,
        h = hudHeight,
    })

    aerospaceWorkspaceCanvas:appendElements({
        {
            type = "rectangle",
            action = "fill",
            frame = { x = 0, y = 0, w = hudWidth, h = hudHeight },
            roundedRectRadii = { xRadius = 18, yRadius = 18 },
            fillColor = { white = 0, alpha = 0.72 },
        },
        {
            type = "text",
            text = workspace,
            frame = { x = 0, y = 8, w = hudWidth, h = hudHeight },
            textSize = 42,
            textAlignment = "center",
            textColor = { white = 1, alpha = 1 },
        },
    })

    aerospaceWorkspaceCanvas:level(hs.canvas.windowLevels.overlay)
    aerospaceWorkspaceCanvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces)

    aerospaceWorkspaceCanvas:show(0.03)

    aerospaceWorkspaceHideTimer = hs.timer.doAfter(0.7, function()
        if aerospaceWorkspaceCanvas then
            aerospaceWorkspaceCanvas:delete(0.15)
            aerospaceWorkspaceCanvas = nil
        end
        aerospaceWorkspaceHideTimer = nil
    end)
end

hs.urlevent.bind("aerospace-workspace", function(_, params)
    showAeroSpaceWorkspaceHUD(params and params["ws"])
end)

-- chrome-vertical-tab-toggle (installed by install.sh on 20260621-114452)
require("chrome-vertical-tab-toggle")
