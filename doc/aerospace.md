# AeroSpace Configuration

This document describes the AeroSpace window manager configuration and keyboard shortcuts.

[AeroSpace](https://github.com/nikitabobko/AeroSpace) is a tiling window manager for macOS.

## Settings

| Setting | Value |
| ------- | ----- |
| Start at login | Yes |
| Accordion padding | 30 |
| Default layout | tiles |
| Default orientation | auto |
| Key preset | qwerty |

## Workspaces

- Workspaces 1-5: Main monitor
- Workspaces 6-9: Secondary monitor (fallback to main)

## Keyboard Shortcuts

### Main Mode

#### Layout

| Key | Description |
| --- | ----------- |
| `Alt + /` | Toggle between horizontal and vertical tiles |
| `Alt + ,` | Toggle between horizontal and vertical accordion |

#### Focus

| Key | Description |
| --- | ----------- |
| `Alt + ←` | Focus window to the left |
| `Alt + ↓` | Focus window below |
| `Alt + ↑` | Focus window above |
| `Alt + →` | Focus window to the right |

#### Move Window

| Key | Description |
| --- | ----------- |
| `Alt + Shift + H` | Move window left |
| `Alt + Shift + J` | Move window down |
| `Alt + Shift + K` | Move window up |
| `Alt + Shift + L` | Move window right |

#### Resize

| Key | Description |
| --- | ----------- |
| `Alt + -` | Resize smaller (-50) |
| `Alt + =` | Resize larger (+50) |

#### Workspace

| Key | Description |
| --- | ----------- |
| `Alt + 1-9` | Switch to workspace 1-9 |
| `Alt + Shift + 1-9` | Move window to workspace 1-9 and follow |

#### Other

| Key | Description |
| --- | ----------- |
| `Alt + Shift + Tab` | Move window to next monitor and focus |
| `Alt + Shift + ;` | Enter service mode |

### Service Mode

Enter service mode with `Alt + Shift + ;`. All commands return to main mode after execution.

| Key | Description |
| --- | ----------- |
| `Esc` | Reload config and exit |
| `R` | Reset layout (flatten workspace tree) |
| `F` | Toggle floating/tiling layout (centers window when floating via Hammerspoon) |
| `Alt + Shift + H` | Join with window to the left |
| `Alt + Shift + J` | Join with window below |
| `Alt + Shift + K` | Join with window above |
| `Alt + Shift + L` | Join with window to the right |

## Floating Apps

The following apps are configured to open in floating mode by default:

| App | Bundle ID |
| --- | --------- |
| Finder | com.apple.finder |
| LINE | jp.naver.line.mac |
| Mattermost | Mattermost.Desktop |
| Slack | com.tinyspeck.slackmacgap |
| DeepL | com.linguee.DeepLCopyTranslator |
| 何 (Nani) | jp.kiok.nani |
| System Preferences | com.apple.systempreferences |
| X.com (Chrome App) | com.google.Chrome.app.lodlkdfmihgonocnmddehnfgiljnadcf |

## Hammerspoon Integration

When toggling floating layout with `F` in service mode, AeroSpace calls Hammerspoon to center the window on screen.

Hammerspoon configuration (`~/.hammerspoon/init.lua`):

```lua
-- Center window via URL scheme
hs.urlevent.bind("center", function()
    local win = hs.window.focusedWindow()
    if not win then return end
    win:centerOnScreen(nil, true)
end)
```

## Raycast Scripts

The following Raycast scripts are available for AeroSpace management:

| Script | Description |
| ------ | ----------- |
| `toggle_aerospace.sh` | Toggle AeroSpace ON/OFF |
| `toggle_aerospace_float.sh` | Toggle floating layout and center window |
| `new_chrome.sh` | Open new Chrome window in current space |
| `new_safari.sh` | Open new Safari window in current space |
