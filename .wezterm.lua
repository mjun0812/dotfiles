local wezterm = require 'wezterm'

local config = wezterm.config_builder()
config.automatically_reload_config = true

-- Font
-- config.font = wezterm.font("RobotoMonoJP", { weight="Regular" })
config.font = wezterm.font_with_fallback({
  "RobotoMonoJP",
  "Roboto Mono",
  "Noto Color Emoji",
  "Noto Sans CJK JP",
})

config.font_size = 12.0

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
