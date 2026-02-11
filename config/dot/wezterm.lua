local wezterm = require 'wezterm'

local config = wezterm.config_builder()
config.automatically_reload_config = true

-- ベル無効化
config.audible_bell = "Disabled"
-- 通知設定
config.notification_handling = "AlwaysShow"
-- 日本語入力
config.use_ime = true
-- Windowを閉じた時にWeztermを終了しない
config.quit_when_all_windows_are_closed = false
-- Windowを閉じるときの確認を無効
config.window_close_confirmation = "NeverPrompt"
-- 透過
config.window_background_opacity = 0.70
-- ぼかし
config.macos_window_background_blur = 30

-- Font
config.font = wezterm.font_with_fallback({
    "RobotoMonoJP",
    "Roboto Mono",
    "Noto Color Emoji",
    "Noto Sans CJK JP",
})
config.font_size = 12.0

-- Window Settings
-- size
config.initial_rows = 30
config.initial_cols = 110
-- titlebar
config.window_frame = {
    font = wezterm.font({ family = "RobotoMonoJP", weight = "Bold" }),
    font_size = 12.0,
    inactive_titlebar_bg = "none",
    active_titlebar_bg = "none",
}
-- 背景グラデーション
config.window_background_gradient = {
    colors = { "#000000" },
}
-- Windowの余白
config.window_padding = {
    left = '0.5cell',
    right = '0.5cell',
    top = '0.1cell',
    bottom = '0',
}

-- タブの最大幅
config.tab_max_width = 10
-- タブ上のタイトルを消す
if wezterm.target_triple == 'aarch64-apple-darwin' then
    config.window_decorations = "INTEGRATED_BUTTONS | RESIZE"
    -- config.window_decorations = "RESIZE"
elseif wezterm.target_triple == 'x86_64-unknown-linux-gnu' then
    config.window_decorations = "RESIZE"
end
-- タブが一つのときタブバーを隠す
config.hide_tab_bar_if_only_one_tab = false
-- タブの閉じるボタンを消す
config.show_close_tab_button_in_tabs = false
-- タブバーの+ボタンを消す
config.show_new_tab_button_in_tab_bar = false
-- タブ番号を消す
config.show_tab_index_in_tab_bar = false
-- rendered in a native style with proportional fonts
config.use_fancy_tab_bar = true
wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
    local title = tab.active_pane.title or ""
    if title == "" then
        local cwd = tab.active_pane.current_working_dir
        if cwd then
            local path = cwd.file_path or tostring(cwd)
            title = path:match("([^/]+)/?$") or path
        else
            title = "untitled"
        end
    end
    title = wezterm.truncate_right(title, max_width)
    local space_after = string.rep(' ', math.max(0, max_width - #title - 1))
    return {
        { Text = " " .. title .. space_after },
    }
end)

config.colors = {
    -- ターミナルの文字色
    foreground = "#EAEAEA",
    -- ターミナルの背景色
    background = "#000000",
    -- カーソル
    cursor_bg = "#00A7FF",
    cursor_border = "#00A7FF",
    -- tab bar
    tab_bar = {
        background = "#000000",
        -- タブの境界線を削除
        inactive_tab_edge = "none",
        active_tab = {
            bg_color = "rgba(0,0,0,0.0)",
            fg_color = "#EAEAEA",
            intensity = "Bold",
        },
        inactive_tab = {
            bg_color = "rgba(0,0,0,0.0)",
            fg_color = "#7b7b7b",
            intensity = "Half",
        },
    },
    -- colors
    ansi = {
        "#000000", -- black
        "#FE533E", -- red
        "#57DC76", -- green
        "#FECB00", -- yellow
        "#00A7FF", -- blue
        "#FF4867", -- magenta
        "#69D1FA", -- cyan
        "#EAEAEA", -- white
    },
    brights = {
        "#7B7B7B", -- gray
        "#FE533E", -- red
        "#57DC76", -- green
        "#FECB00", -- yellow
        "#00A7FF", -- blue
        "#FF4867", -- magenta
        "#69D1FA", -- cyan
        "#EAEAEA", -- white
    },
}

-- mouse bindings
config.mouse_bindings = {
    -- Ctrl-click will open the link under the mouse cursor
    {
        event = { Up = { streak = 1, button = 'Left' } },
        mods = 'CTRL',
        action = wezterm.action.OpenLinkAtMouseCursor,
    },
    {
        event = { Up = { streak = 1, button = 'Left' } },
        mods = 'CMD',
        action = wezterm.action.OpenLinkAtMouseCursor,
    },
}

config.keys = {
    {
        key = 'Enter',
        mods = 'SHIFT',
        action = wezterm.action.SendString('\n')
    },
}

-- Hyperlink 抽出と処理
local function extract_path(uri)
    -- `$EDITOR:/path/to/file` → `/path/to/file`
    local s, e = uri:find("^$EDITOR:")
    if s then return uri:sub(e + 1) end

    -- `file://hostname/path` → `/path`
    s, e = uri:find("^file:")
    if s then
        local host_path = uri:sub(e + 3)
        local slash = host_path:find("/")
        return slash and host_path:sub(slash) or host_path
    end

    -- `http://` 等はスキップ
    if uri:match("^[%w%+%-%.]+://") then return nil end

    -- それ以外はそのままパスとみなす
    return uri
end

-- 行番号 (例: :42:7 や :128) を削除して OS が理解できる形に ---------------
local function strip_line_numbers(path)
    return path:gsub(":%d+:%d+$", "") -- :行:列
        :gsub(":%d+$", "")            -- :行
end

-- open-uri ハンドラ
wezterm.on("open-uri", function(window, pane, uri)
    local raw_path = extract_path(uri)
    if not raw_path then return end -- URL などは既定動作
    local clean_path = strip_line_numbers(raw_path)

    -- OS 既定アプリで開く
    wezterm.open_with(clean_path)

    return false -- ブラウザで開く等の既定アクションを抑制
end)

-- 既定ルールをベースにする
local hyperlink_rules = wezterm.default_hyperlink_rules()

-- ファイルパス検出用ルールを追加
table.insert(hyperlink_rules, {
    --  ~ / ./ ../ C:\     で始まり、空白や<>\"' を除く任意文字列
    --  オプションで :行 または :行:列 を繰り返し許可
    regex = [[(?:~|/|\.{1,2}/|\w:[\\/])[^[:space:]'"<>]+(?::\d+(?::\d+)*)?]],
    format = '$0', -- ← `$EDITOR:` は付けない
    highlight = 0, -- 色を変えたいときは 1
})

config.hyperlink_rules = hyperlink_rules

return config
