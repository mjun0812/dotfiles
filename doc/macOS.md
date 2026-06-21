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

## launchd

User-level launchd agents are managed under `config/mac/launchd/`. Each `*.plist` is symlinked to `~/Library/LaunchAgents/` and loaded automatically.

### Installation

```sh
./script/install/install_launchd.sh
```

The script:

- Symlinks every `config/mac/launchd/*.plist` into `~/Library/LaunchAgents/`.
- Backs up any pre-existing file at the target to `.backup/LaunchAgents/`.
- Unloads the previous agent (if loaded) and re-loads the new plist with `launchctl load`.

### Managed Agents

| Label                | Purpose                                           |
| -------------------- | ------------------------------------------------- |
| `com.headroom.proxy` | Run `headroom proxy` on `127.0.0.1:8787` at login |

### Manual Operations

```sh
# Status
launchctl list | grep com.headroom.proxy

# Stop / Start
launchctl unload ~/Library/LaunchAgents/com.headroom.proxy.plist
launchctl load   ~/Library/LaunchAgents/com.headroom.proxy.plist

# Restart (after editing the plist in this repo, just re-run the installer)
./script/install/install_launchd.sh
```

### Viewing Logs

stdout/stderr are routed to the macOS unified logging system (no log files are written, so disk usage stays bounded).

```sh
# Tail logs live
log stream --predicate 'process == "headroom"' --info

# Show the last hour
log show --predicate 'process == "headroom"' --info --last 1h

# Include debug-level entries
log stream --predicate 'process == "headroom"' --debug --info
```

If a process exits immediately and `process == "headroom"` returns nothing, search by launchd label instead:

```sh
log show --predicate 'subsystem == "com.apple.xpc.launchd" AND eventMessage CONTAINS "com.headroom.proxy"' --last 1h
```
