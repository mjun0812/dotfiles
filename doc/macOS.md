# macOS

## AeroSpace

See [doc/aerospace.md](aerospace.md) for AeroSpace window manager configuration and keyboard shortcuts.

## Hammerspoon

See [doc/hammerspoon.md](hammerspoon.md) for Hammerspoon configuration and URL schemes.

Hammerspoon is used for window management features that AeroSpace cannot handle natively.

Currently configured features:

- Center window on screen via URL scheme (`hammerspoon://center`)
- AeroSpace workspace HUD via URL scheme (`hammerspoon://aerospace-workspace?ws=<num>`)
- Toggle Chrome's native vertical tab sidebar via `Cmd+Shift+B` and left-edge hover

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

| Script                      | Description                                |
| --------------------------- | ------------------------------------------ |
| `toggle_aerospace.sh`       | Toggle AeroSpace ON/OFF                    |
| `toggle_aerospace_float.sh` | Make focused window floating and center it |
| `new_chrome.sh`             | Open new Chrome window in current space    |
| `new_safari.sh`             | Open new Safari window in current space    |
| `new_wezterm.sh`            | Open new WezTerm window                    |

## launchd

User-level launchd agents are declared in `config/dot_config/mise/config.toml` and managed by mise. mise generates the plist files under `~/Library/LaunchAgents/` and loads them with `launchctl`.

### Installation

```sh
mise bootstrap macos launchd-agents apply --yes
```

`install.sh` runs this command automatically on macOS after installing Headroom.

### Managed Agents

| Label                     | Purpose                                           |
| ------------------------- | ------------------------------------------------- |
| `dev.mise.headroom-proxy` | Run `headroom proxy` on `127.0.0.1:8787` at login |
| `dev.mise.cli-proxy-api`  | Run CLIProxyAPI on `127.0.0.1:8317` at login      |

The generated plists are `~/Library/LaunchAgents/<label>.plist`.

### CLIProxyAPI configuration

The config is tracked at `config/dot_config/cli-proxy-api/config.yaml` and linked to `~/.config/cli-proxy-api/config.yaml` by `install.sh`. Only the file is linked (like herdr) because the app downloads runtime assets (`static/`) next to it; the directory itself stays real.

Tracking it is safe only while the config holds no secrets: credentials live in `auth-dir` (`~/.cli-proxy-api/`, outside the repo). Keep it that way — do not add client `api-keys` values or a `remote-management.secret-key` (the management API rewrites the config in place, which would dirty the repo through the symlink). If either becomes necessary, move the config out of the repo first.

The full option reference is `~/.local/share/mise/installs/github-router-for-me-cli-proxy-api/latest/config.example.yaml`.

The agent resolves the config via its `working_directory`, but interactive logins run from your shell's cwd, so pass `-config` explicitly:

```sh
cli-proxy-api -config ~/.config/cli-proxy-api/config.yaml -codex-login
mise run cli-proxy-api-restart # reload the agent after logging in
```

Note: the config symlink must exist before `mise bootstrap macos launchd-agents apply`; without a config the binary exits immediately and `KeepAlive` respawns it in a loop. `install.sh` runs the steps in that order.

### Manual Operations

```sh
# Status
mise bootstrap macos launchd-agents status
launchctl print gui/$(id -u)/dev.mise.headroom-proxy

# Apply changes
mise bootstrap macos launchd-agents apply --yes

# Stop / Start
launchctl bootout gui/$(id -u)/dev.mise.headroom-proxy
mise bootstrap macos launchd-agents apply --yes
```

### Viewing Logs

stdout/stderr are routed to the macOS unified logging system (no log files are written, so disk usage stays bounded).

```sh
# Tail logs live
log stream --predicate 'process == "headroom"' --info

# Show the last hour
log show --predicate 'process == "headroom"' --info --last 1h

# CLIProxyAPI
log show --predicate 'process == "cli-proxy-api"' --info --last 1h

# Include debug-level entries
log stream --predicate 'process == "headroom"' --debug --info
```

If a process exits immediately and `process == "headroom"` returns nothing, search by launchd label instead:

```sh
log show --predicate 'subsystem == "com.apple.xpc.launchd" AND eventMessage CONTAINS "dev.mise.headroom-proxy"' --last 1h
```
