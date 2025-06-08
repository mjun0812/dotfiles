local wezterm = require 'wezterm'

local config = wezterm.config_builder()
config.automatically_reload_config = true

-- Font
config.font = wezterm.font_with_fallback({
  "RobotoMonoJP",
  "Roboto Mono",
  "Noto Color Emoji",
  "Noto Sans CJK JP",
})
config.font_size = 12.0

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
  return path:gsub(":%d+:%d+$", "")  -- :行:列
             :gsub(":%d+$", "")      -- :行
end

-- open-uri ハンドラ -----------------------------------------------------------
wezterm.on("open-uri", function(window, pane, uri)
  local raw_path = extract_path(uri)
  if not raw_path then return end               -- URL などは既定動作
  local clean_path = strip_line_numbers(raw_path)

  -- OS 既定アプリで開く
  wezterm.open_with(clean_path)

  return false  -- ブラウザで開く等の既定アクションを抑制
end)

-- 既定ルールをベースにする
local hyperlink_rules = wezterm.default_hyperlink_rules()

-- ファイルパス検出用ルールを追加
table.insert(hyperlink_rules, {
  --   ~ / ./ ../ C:\     で始まり、空白や<>\"' を除く任意文字列
  --   オプションで :行 または :行:列 を繰り返し許可
  regex = [[(?:~|/|\.{1,2}/|\w:[\\/])[^[:space:]'"<>]+(?::\d+(?::\d+)*)?]],
  format = '$0',      -- ← `$EDITOR:` は付けない
  highlight = 0,      -- 色を変えたいときは 1
})

config.hyperlink_rules = hyperlink_rules

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

-- 日本語入力
config.use_ime = true
-- 透過
config.window_background_opacity = 0.85
-- ぼかし
config.macos_window_background_blur = 20
-- タブバーの+ボタンを消す
config.show_new_tab_button_in_tab_bar = false
-- Windowの余白
config.window_padding = {
  left = '0.5cell',
  right = '0.5cell',
  top = 0,
  bottom = '0.2cell',
}
-- タブの最大幅
config.tab_max_width = 20
-- window size
config.initial_rows = 30
config.initial_cols = 110

-- タブ上のタイトルを消す
if wezterm.target_triple == 'aarch64-apple-darwin' then
  config.window_decorations = "INTEGRATED_BUTTONS | RESIZE"
elseif wezterm.target_triple == 'x86_64-unknown-linux-gnu' then
  config.window_decorations = "RESIZE"
end

config.use_fancy_tab_bar = true
config.window_frame = {
  font = wezterm.font({ family = "RobotoMonoJP"}),
  font_size = 13.0,
  inactive_titlebar_bg = "none",
  active_titlebar_bg = "none",
}
config.window_background_gradient = {
  colors = { "#000000" },
}
config.colors = {
  -- ターミナルの文字色
  foreground = "#c7c7c7",
  -- ターミナルの背景色
  background = "#000000",

  -- カーソル
  cursor_bg = "#4aa5f8",
  cursor_border = "#4aa5f8",

  tab_bar = {
    background = "#000000",
    -- タブの境界線を削除
    inactive_tab_edge = "none",
    active_tab = {
      bg_color = "rgba(0,0,0,0.85)",
      fg_color = "#c7c7c7",
      intensity = "Bold",
    },
    inactive_tab = {
      bg_color = "rgba(0,0,0,0.85)",
      fg_color = "#7b7b7b",
      intensity = "Normal",
    },
  },

  ansi = {
    "#000000", -- black
    "#eb6049", -- red
    "#7dd981", -- green
    "#f6cd45", -- yellow
    "#4aa5f8", -- blue
    "#eb576a", -- magenta
    "#84cff6", -- cyan
    "#eaeaea", -- white
  },
  brights = {
    "#7b7b7b", -- gray
    "#eb6049", -- red
    "#7dd981", -- green
    "#f6cd45", -- yellow
    "#4aa5f8", -- blue
    "#eb576a", -- magenta
    "#84cff6", -- cyan
    "#eaeaea", -- white
  },
}

return config
