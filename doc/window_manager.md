# Window Managers

This document describes the two tiling window managers configured in this repository, [Rift](https://github.com/acsandmann/rift) and [AeroSpace](https://github.com/nikitabobko/AeroSpace), and their keyboard shortcuts.

Rift is the window manager in use. AeroSpace stays installed so that you can switch back to it, but it turns its own window management off at startup. Both are configured with the same keys, workspace layout, and floating apps, so switching between them does not change how you work.

## Overview

| Item           | Rift                                                                                 | AeroSpace                                                                              |
| -------------- | ------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------- |
| Config         | `config/dot_config/rift/config.toml` → `~/.config/rift`                              | `config/dot_config/aerospace/aerospace.toml` → `~/.config/aerospace`                   |
| Install        | `brew:acsandmann/tap/rift` in `[bootstrap.packages]` of `config.macos.toml`          | `brew-cask:nikitabobko/tap/aerospace` in `[bootstrap.packages]` of `config.macos.toml` |
| Start at login | The `rift` user service (`[bootstrap.services.rift]`) runs `script/services/rift.sh` | `start-at-login = true`                                                                |
| State          | Manages windows                                                                      | `after-startup-command = ['enable off']` turns window management off                   |
| Config reload  | `hot_reload = true`                                                                  | `auto-reload-config = true`                                                            |

Both config directories are linked by `mise dot apply` from the `[dotfiles]` entries in `config/dot_config/mise/conf.d/dotfiles.toml`.

## Shared Behavior

### Workspaces

Both use nine workspaces, named 1-9.

- Workspaces 1-5 are on the main (left) display.
- Workspaces 6-9 are on the secondary (right) display. With a single display, they fall back to that display.

Rift numbers workspaces from 0 internally, so its config refers to workspace 1 as `0` and workspace 9 as `8`.

### Floating Apps

The following apps open in floating mode by default:

| App                | Bundle ID                       |
| ------------------ | ------------------------------- |
| Finder             | com.apple.finder                |
| LINE               | jp.naver.line.mac               |
| Mattermost         | Mattermost.Desktop              |
| DeepL              | com.linguee.DeepLCopyTranslator |
| Nani               | jp.kiok.nani                    |
| System Preferences | com.apple.systempreferences     |

Ghostty (`com.mitchellh.ghostty`) is set to tiling explicitly.

### Gaps

All inner and outer gaps are 0 in both.

### Hammerspoon Workspace HUD

On every workspace change, both open `hammerspoon://aerospace-workspace?ws=<num>`, and Hammerspoon shows the workspace number in a HUD. AeroSpace does this with `exec-on-workspace-change`, and Rift with a `rift-cli subscribe` command in `run_on_start`. See [doc/hammerspoon.md](hammerspoon.md).

## Keyboard Shortcuts

The keys are the same in both. Where the two behave differently, the table says so.

### Main Mode

| Key                                 | Rift                                                 | AeroSpace                                        |
| ----------------------------------- | ---------------------------------------------------- | ------------------------------------------------ |
| `Alt + Ctrl + H` / `Alt + Ctrl + ←` | Focus window to the left                             | Same                                             |
| `Alt + Ctrl + J` / `Alt + Ctrl + ↓` | Focus window below                                   | Same                                             |
| `Alt + Ctrl + K` / `Alt + Ctrl + ↑` | Focus window above                                   | Same                                             |
| `Alt + Ctrl + L` / `Alt + Ctrl + →` | Focus window to the right                            | Same                                             |
| `Alt + Shift + H/J/K/L`             | Move window left / down / up / right                 | Same                                             |
| `Alt + /`                           | Toggle the split orientation                         | Toggle between horizontal and vertical tiles     |
| `Alt + ,`                           | Toggle stacking                                      | Toggle between horizontal and vertical accordion |
| `Alt + -`                           | Shrink the window (smart resize)                     | Resize smaller (-50)                             |
| `Alt + =`                           | Grow the window (smart resize)                       | Resize larger (+50)                              |
| `Alt + 1-9`                         | Switch to workspace 1-9                              | Same                                             |
| `Alt + Shift + 1-9`                 | Move window to workspace 1-9 and follow              | Same                                             |
| `Alt + Shift + Tab`                 | Move window to the next display and focus it         | Same                                             |
| `Alt + Ctrl + Shift + ←/↓/↑/→`      | Focus the display in that direction, even if empty   | Not bound                                        |
| `Alt + Z`                           | Turn management of the current macOS Space on or off | Not bound                                        |
| `Alt + Shift + ;`                   | Enter service mode                                   | Same                                             |

In Rift, `Alt + Shift + Tab` runs `config/dot_config/rift/move-next-display.sh`, which picks the next display by its position with `next-display.jq`.

### Service Mode

Enter service mode with `Alt + Shift + ;`. Every command returns to main mode after it runs.

| Key                     | Rift                                                     | AeroSpace                             |
| ----------------------- | -------------------------------------------------------- | ------------------------------------- |
| `Esc`                   | Reload config and exit                                   | Same                                  |
| `R`                     | Unjoin the selected windows and balance their sizes      | Reset layout (flatten workspace tree) |
| `F`                     | Toggle floating/tiling                                   | Same                                  |
| `Alt + Shift + H/J/K/L` | Join with the window to the left / below / above / right | Same                                  |

## Rift Settings

| Setting                                              | Value                                                                     |
| ---------------------------------------------------- | ------------------------------------------------------------------------- |
| Layout mode                                          | `traditional` (new windows go next to the selection, nodes are equalized) |
| Virtual workspaces                                   | Enabled, `global` mode, 9 workspaces                                      |
| Animation                                            | On, 0.15 s at 100 fps                                                     |
| Focus follows mouse                                  | No                                                                        |
| Mouse follows focus                                  | No                                                                        |
| Menu bar                                             | Shows the workspace index, hides empty workspaces                         |
| Mission Control, stack line, gestures, drag and drop | Disabled                                                                  |

Notes:

- Keep `animation_fps` above 0. Rift computes `1.0 / animation_fps` at startup even when `animate = false`, and crashes when it is 0.
- Homebrew re-signs Rift (ad hoc) on every install, so after Rift is upgraded you have to grant it Accessibility permission again.
- The user service writes Rift's output to `/tmp/rift_<user>.out.log` and `/tmp/rift_<user>.err.log`. It restarts Rift only when it fails, so quitting Rift from its menu leaves it stopped.

## AeroSpace Settings

| Setting                               | Value |
| ------------------------------------- | ----- |
| Config version                        | 2     |
| Accordion padding                     | 30    |
| Default layout                        | tiles |
| Default orientation                   | auto  |
| Normalization (flatten containers)    | Yes   |
| Normalization (opposite orientation)  | Yes   |
| Mouse follows focus on monitor change | Yes   |
| Auto-unhide hidden apps               | No    |
| Persistent workspaces                 | 1-9   |

To turn AeroSpace's window management back on, run `aerospace enable on` or the `toggle_aerospace.sh` Raycast script. Quit Rift first, because both use the same keys. The Raycast scripts for AeroSpace are listed in [doc/macOS.md](macOS.md#raycast).
