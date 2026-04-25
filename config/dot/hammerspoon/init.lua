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