# macOS

## App Settings

GUI app settings are managed as config files when the app reads one, and as mise defaults otherwise. Nothing is kept as a `defaults` plist dump.

1. **Config files**: the app reads a text file from the repo. `install.sh` links them.
   - **iTerm2 profiles**: `config/mac/iterm2/DynamicProfiles/dotfiles.json` is a [Dynamic Profile](https://iterm2.com/documentation-dynamic-profiles.html), linked into `~/Library/Application Support/iTerm2/DynamicProfiles/`. iTerm2 reloads it when the file changes. Changes made in the Settings UI are not written back: use _Other Actions > Save Profile as JSON_ and copy the keys into the file.
   - **Karabiner-Elements**: `config/mac/karabiner/` is linked to `~/.config/karabiner`, so UI changes land in the repo directly.
2. **mise defaults**: preferences declared in `[bootstrap.macos.defaults]` of `config/dot_config/mise/config.macos.toml` (AltTab, BetterDisplay, Clipy, Homerow, and the iTerm2 global settings). `install.sh` applies them with `mise bootstrap macos defaults apply`; apps read them on their next launch.
   - Only settings are declared. Keys that record app state (update checks, window frames, launch counts, `NoSync*` in iTerm2) and per-device values (BetterDisplay's `key@Display:N`) are left out, so BetterDisplay declares only its menu layout (`menuLevel*`).
   - Values stored as binary data cannot be declared (Clipy's shortcuts, which are not used). Clipy snippets live in a Realm DB and are not covered.
   - `./update.sh` reports settings that drifted from the declarations (`script/tools/mac_defaults.py`): `[differs]` for declared values changed in the UI, `[undeclared]` for keys set in the UI but not declared. Update the TOML by hand.

## System Settings

macOS's own preferences that were changed from the defaults (Dock, Finder, keyboard, trackpad, hot corners, menu bar clock, screenshots, Stage Manager, ...) are declared in `config/dot_config/mise/config.macos.toml`, with the named sections (`[bootstrap.macos.dock]`, `finder`, `keyboard`, `trackpad`) where they fit and `[bootstrap.macos.defaults]` otherwise. `install.sh` applies them together with the app settings.

- Things that change as the machine is used are not declared: the apps pinned in the Dock, the login items, recent items, and other state that macOS records. Language and region, input sources, and text replacements are left to the macOS setup assistant and iCloud.
- Values that System Settings stores as reals (`KeyRepeat`, `InitialKeyRepeat`, Dock `tilesize`, `largesize`) are declared as raw defaults with float values; the named sections write integers, which would never match.
- mise does not restart Dock, Finder, or the menu bar. Changes show after they relaunch or on the next login.
- `./update.sh` reports only `[differs]` for these domains (`NSGlobalDomain` and `com.apple.*`); they hold too much state for `[undeclared]` to be useful. A declared value changed in System Settings must be copied into the TOML, or the next `install.sh` reverts it.
- To find the keys of a setting you are about to change, take a snapshot of every defaults domain first, change the setting, then list what changed as TOML tables to paste into `config.macos.toml`:

  ```sh
  python3 script/tools/mac_defaults.py snapshot   # saved to ~/.cache/dotfiles/mac_defaults_snapshot.plist
  # change the setting in System Settings or the app
  python3 script/tools/mac_defaults.py changes
  ```

  `changes` skips date values and app-state keys, and marks values that cannot be declared (binary data, dates inside a value) and removed keys as comments. Keys that macOS or apps changed in the background between the two commands show up too, so keep only the ones that belong to the setting.

## AeroSpace

See [doc/aerospace.md](aerospace.md) for AeroSpace window manager configuration and keyboard shortcuts.

## Hammerspoon

See [doc/hammerspoon.md](hammerspoon.md) for Hammerspoon configuration and URL schemes.

Hammerspoon is used for window management features that AeroSpace cannot handle natively.

Currently configured features:

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

| Script                      | Description                             |
| --------------------------- | --------------------------------------- |
| `toggle_aerospace.sh`       | Toggle AeroSpace ON/OFF                 |
| `toggle_aerospace_float.sh` | Make focused window floating            |
| `new_chrome.sh`             | Open new Chrome window in current space |
| `new_safari.sh`             | Open new Safari window in current space |
| `new_wezterm.sh`            | Open new WezTerm window                 |

## launchd

User-level launchd agents are declared as user services (`[bootstrap.services]`) in `config/dot_config/mise/config.toml` and managed by mise. On macOS, mise generates the plist files under `~/Library/LaunchAgents/` and loads them with `launchctl`; on Linux, the same declarations become systemd user services.

### Installation

```sh
mise bootstrap services apply --yes
```

`install.sh` runs this command automatically after installing Headroom.

### Managed Agents

| Label                              | Purpose                                           |
| ---------------------------------- | ------------------------------------------------- |
| `dev.mise.headroom-proxy`          | Run `headroom proxy` on `127.0.0.1:8787` at login |
| `dev.mise.cli-proxy-api`           | Run CLIProxyAPI on `127.0.0.1:8317` at login      |
| `dev.mise.codex-app-server-daemon` | Start the Codex app-server daemon at login        |

The generated plists are `~/Library/LaunchAgents/<label>.plist`.

### CLIProxyAPI configuration

The config is tracked at `config/dot_config/cli-proxy-api/config.yaml` and linked to `~/.config/cli-proxy-api/config.yaml` by `install.sh`. Only the file is linked (like herdr) because the app downloads runtime assets (`static/`) next to it; the directory itself stays real.

Tracking it is safe only while the config holds no secrets: credentials live in `auth-dir` (`~/.cli-proxy-api/`, outside the repo). Keep it that way — do not add client `api-keys` values or a `remote-management.secret-key` (the management API rewrites the config in place, which would dirty the repo through the symlink). If either becomes necessary, move the config out of the repo first.

The full option reference is `~/.local/share/mise/installs/github-router-for-me-cli-proxy-api/latest/config.example.yaml`.

The agent resolves the config via its `working_directory`, but interactive logins run from your shell's cwd, so pass `-config` explicitly:

```sh
cli-proxy-api -config ~/.config/cli-proxy-api/config.yaml -codex-login
launchctl kickstart -k gui/$(id -u)/dev.mise.cli-proxy-api # reload the agent after logging in
```

Note: the config symlink must exist before `mise bootstrap services apply`; without a config the binary exits immediately and `KeepAlive` respawns it in a loop. `install.sh` runs the steps in that order.

### Manual Operations

```sh
# Status
mise bootstrap services status
launchctl print gui/$(id -u)/dev.mise.headroom-proxy

# Apply changes
mise bootstrap services apply --yes

# Stop / Start
launchctl bootout gui/$(id -u)/dev.mise.headroom-proxy
mise bootstrap services apply --yes
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

## Codex Remote Control

Codex is installed by mise through the Aqua backend on macOS and Linux. The Remote Control server runs as the Codex-managed daemon (`codex app-server daemon`), and mise stays the only version authority:

```text
mise/Aqua Codex package
  -> codex app-server daemon update --from-cli   (copy and pin)
  -> ~/.codex/packages/app-server-daemon/current
  -> Codex Remote Control daemon
```

`script/setup/setup_codex_daemon.sh` drives the lifecycle:

| Subcommand | Called from                          | Action                                                                                                  |
| ---------- | ------------------------------------ | ------------------------------------------------------------------------------------------------------- |
| `pin`      | Codex postinstall, `install.sh`      | Enable Remote Control, start the daemon, and pin the mise-installed package (restarts a running daemon) |
| `run`      | `codex-app-server-daemon` service    | Start the daemon at login, then idle so the service manager does not reap it                            |
| `migrate`  | `install.sh` (before `mise install`) | Remove the old `codex-remote-control` service and the `~/.codex/packages/standalone/current` link       |

The daemon is a pidfile-backed detached process and does not survive a reboot, so the `codex-app-server-daemon` mise user service (LaunchAgent on macOS, systemd user service on Linux) starts it at login. Pinning disables the daemon's own updater; `mise upgrade` runs the postinstall, which pins the new version and restarts the daemon. Run it when no active Codex turn should be interrupted.

Do not run `codex app-server daemon update` without `--from-cli`, `codex app-server daemon bootstrap`, or `codex remote-control start`; they return the daemon to Codex's own update channel and create a second version authority.

```sh
codex app-server daemon version   # status and versions as JSON
codex app-server daemon stop
codex app-server daemon start
```

Migrating an existing machine: rerun `./install.sh`. `migrate` removes the old service (`mise bootstrap services remove codex-remote-control`), so the old definition is not restored by `mise bootstrap services apply`, and the legacy `standalone/current` link, so only one daemon runs.

Start a new Remote Control session with `codex --remote unix://`. Add `resume` or `fork` to the command to resume or fork a stored session.
