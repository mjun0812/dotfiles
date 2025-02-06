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

-- Use some simple heuristics to determine if we should open it
-- with a text editor in the terminal.
-- Take note! The code in this file runs on your local machine,
-- but a URI can appear for a remote, multiplexed session.
-- WezTerm can spawn the editor in that remote session, but doesn't
-- have access to the file locally, so we can't probe inside the
-- file itself, so we are limited to simple heuristics based on
-- the filename appearance.
function editable(filename)
  -- "foo.bar" -> ".bar"
  local extension = filename:match("^.+(%..+)$")
  if extension then
    -- ".bar" -> "bar"
    extension = extension:sub(2)
    wezterm.log_info(string.format("extension is [%s]", extension))
    local binary_extensions = {
      jpg = true,
      jpeg = true,
      -- and so on
    }
    if binary_extensions[extension] then
      -- can't edit binary files
      return false
    end
  end

  -- if there is no, or an unknown, extension, then assume
  -- that our trusty editor will do something reasonable

  return true
end

function extract_filename(uri)
  local start, match_end = uri:find("$EDITOR:");
  if start == 1 then
    -- skip past the colon
    return uri:sub(match_end+1)
  end

  -- `file://hostname/path/to/file`
  local start, match_end = uri:find("file:");
  if start == 1 then
    -- skip "file://", -> `hostname/path/to/file`
    local host_and_path = uri:sub(match_end+3)
    local start, match_end = host_and_path:find("/")
    if start then
      -- -> `/path/to/file`
      return host_and_path:sub(match_end)
    end
  end

  return nil
end

wezterm.on("open-uri", function(window, pane, uri)
  local name = extract_filename(uri)
  if name and editable(name) then
    -- Note: if you change your VISUAL or EDITOR environment,
    -- you will need to restart wezterm for this to take effect,
    -- as there isn't a way for wezterm to "see into" your shell
    -- environment and capture it.
    local editor = os.getenv("VISUAL") or os.getenv("EDITOR") or "open"

    -- To open a new window:
    local action = wezterm.action{SpawnCommandInNewWindow={
        args={editor, name}
      }};

    -- and spawn it!
    window:perform_action(action, pane);

    -- prevent the default action from opening in a browser
    return false
  end
end)

config.hyperlink_rules = {
  -- Matches: a URL in parens: (URL)
  {
    regex = '\\((\\w+://\\S+)\\)',
    format = '$1',
    highlight = 1,
  },
  -- Matches: a URL in brackets: [URL]
  {
    regex = '\\[(\\w+://\\S+)\\]',
    format = '$1',
    highlight = 1,
  },
  -- Matches: a URL in curly braces: {URL}
  {
    regex = '\\{(\\w+://\\S+)\\}',
    format = '$1',
    highlight = 1,
  },
  -- Matches: a URL in angle brackets: <URL>
  {
    regex = '<(\\w+://\\S+)>',
    format = '$1',
    highlight = 1,
  },
  -- Then handle URLs not wrapped in brackets
  {
    regex = '\\b\\w+://\\S+[)/a-zA-Z0-9-]+',
    format = '$0',
  },
  -- implicit mailto link
  {
    regex = '\\b\\w+@[\\w-]+(\\.[\\w-]+)+\\b',
    format = 'mailto:$0',
  },
  -- new in nightly builds; automatically highly file:// URIs.
  {
      regex = "\\bfile://\\S*\\b",
      format = "$0"
  },
  -- Now add a new item at the bottom to match things that are
  -- probably filenames
  {
    regex = "\\b\\S*\\b",
    format = "$EDITOR:$0"
  }
}
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
