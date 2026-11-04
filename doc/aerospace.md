# AeroSpace Configuration

This document describes the AeroSpace window manager configuration and keyboard shortcuts.

[AeroSpace](https://github.com/nikitabobko/AeroSpace) is a tiling window manager for macOS.

## Settings

| Setting                               | Value                                                        |
| ------------------------------------- | ------------------------------------------------------------ |
| Config version                        | 2                                                            |
| Start at login                        | Yes                                                          |
| After startup                         | `enable off` (window management is disabled until turned on) |
| Auto reload config                    | Yes                                                          |
| Accordion padding                     | 30                                                           |
| Default layout                        | tiles                                                        |
| Default orientation                   | auto                                                         |
| Key preset                            | qwerty                                                       |
| Normalization (flatten containers)    | Yes                                                          |
| Normalization (opposite orientation)  | Yes                                                          |
| Mouse follows focus on monitor change | Yes                                                          |
| Auto-unhide hidden apps               | No                                                           |
| Persistent workspaces                 | 1-9                                                          |
| Gaps                                  | All 0                                                        |

## Workspaces

- Workspaces 1-5: Main monitor
- Workspaces 6-9: Secondary monitor (fallback to main)

## Keyboard Shortcuts

### Main Mode

#### Layout

| Key       | Description                                      |
| --------- | ------------------------------------------------ |
| `Alt + /` | Toggle between horizontal and vertical tiles     |
| `Alt + ,` | Toggle between horizontal and vertical accordion |

#### Focus

| Key                                 | Description               |
| ----------------------------------- | ------------------------- |
| `Alt + Ctrl + H` / `Alt + Ctrl + ←` | Focus window to the left  |
| `Alt + Ctrl + J` / `Alt + Ctrl + ↓` | Focus window below        |
| `Alt + Ctrl + K` / `Alt + Ctrl + ↑` | Focus window above        |
| `Alt + Ctrl + L` / `Alt + Ctrl + →` | Focus window to the right |

#### Move Window

| Key               | Description       |
| ----------------- | ----------------- |
| `Alt + Shift + H` | Move window left  |
| `Alt + Shift + J` | Move window down  |
| `Alt + Shift + K` | Move window up    |
| `Alt + Shift + L` | Move window right |

#### Resize

| Key       | Description          |
| --------- | -------------------- |
| `Alt + -` | Resize smaller (-50) |
| `Alt + =` | Resize larger (+50)  |

#### Workspace

| Key                 | Description                             |
| ------------------- | --------------------------------------- |
| `Alt + 1-9`         | Switch to workspace 1-9                 |
| `Alt + Shift + 1-9` | Move window to workspace 1-9 and follow |

#### Other

| Key                 | Description                           |
| ------------------- | ------------------------------------- |
| `Alt + Shift + Tab` | Move window to next monitor and focus |
| `Alt + Shift + ;`   | Enter service mode                    |

### Service Mode

Enter service mode with `Alt + Shift + ;`. All commands return to main mode after execution.

| Key               | Description                           |
| ----------------- | ------------------------------------- |
| `Esc`             | Reload config and exit                |
| `R`               | Reset layout (flatten workspace tree) |
| `F`               | Toggle floating/tiling layout         |
| `Alt + Shift + H` | Join with window to the left          |
| `Alt + Shift + J` | Join with window below                |
| `Alt + Shift + K` | Join with window above                |
| `Alt + Shift + L` | Join with window to the right         |

## Floating Apps

The following apps are configured to open in floating mode by default:

| App                | Bundle ID                       |
| ------------------ | ------------------------------- |
| Finder             | com.apple.finder                |
| LINE               | jp.naver.line.mac               |
| Mattermost         | Mattermost.Desktop              |
| DeepL              | com.linguee.DeepLCopyTranslator |
| Nani               | jp.kiok.nani                    |
| System Preferences | com.apple.systempreferences     |

Ghostty (`com.mitchellh.ghostty`) is set to tiling layout explicitly.

## Hammerspoon Integration

On every workspace change (`exec-on-workspace-change`), AeroSpace opens `hammerspoon://aerospace-workspace?ws=<num>` so that Hammerspoon shows the workspace number HUD. See [doc/hammerspoon.md](hammerspoon.md).

## Raycast Scripts

The following Raycast scripts are available for AeroSpace management:

| Script                      | Description                             |
| --------------------------- | --------------------------------------- |
| `toggle_aerospace.sh`       | Toggle AeroSpace ON/OFF                 |
| `toggle_aerospace_float.sh` | Make focused window floating            |
| `new_chrome.sh`             | Open new Chrome window in current space |
| `new_safari.sh`             | Open new Safari window in current space |
