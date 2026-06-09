# macOS

## AeroSpace

See [doc/aerospace.md](aerospace.md) for AeroSpace window manager configuration and keyboard shortcuts.

## Hammerspoon

See [doc/hammerspoon.md](hammerspoon.md) for Hammerspoon configuration and URL schemes.

Hammerspoon is used for window management features that AeroSpace cannot handle natively.

Currently configured features:

- Center window on screen via URL scheme (`hammerspoon://center`)
- AeroSpace workspace HUD via URL scheme (`hammerspoon://aerospace-workspace?ws=<num>`)
- Toggle Chrome's native vertical tab sidebar via `Cmd+B` and left-edge hover

## Raycast

Custom Raycast scripts are available in `config/mac/raycast/`.

### Script Commands Setup

Add the script directory in Raycast:

1. Open Raycast Settings.
2. Open `Script Commands`.
3. Click `Add Script Directory`.
4. Select `~/.dotfiles/config/mac/raycast`.

Raycast indexes scripts in the directory as commands. Metadata changes in script headers are picked up automatically.

See [Raycast Script Commands](https://manual.raycast.com/script-commands) for the official setup flow and metadata reference.

### Available Scripts

| Script                      | Description                              |
| --------------------------- | ---------------------------------------- |
| `toggle_aerospace.sh`       | Toggle AeroSpace ON/OFF                  |
| `toggle_aerospace_float.sh` | Toggle floating layout and center window |
| `new_chrome.sh`             | Open new Chrome window in current space  |
| `new_safari.sh`             | Open new Safari window in current space  |
| `new_wezterm.sh`            | Open new WezTerm window                  |
