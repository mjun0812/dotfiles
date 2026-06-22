# Hammerspoon Configuration

This document describes the Hammerspoon configuration and URL schemes.

[Hammerspoon](https://www.hammerspoon.org/) is a macOS automation tool that bridges the operating system and a Lua scripting engine. In this dotfiles setup, Hammerspoon supplements [AeroSpace](https://github.com/nikitabobko/AeroSpace) with window management features that AeroSpace cannot handle natively (centering floating windows, displaying a workspace HUD), and adds a toggle for Chrome's native vertical-tab sidebar.

## Configuration Location

| Path                                                    | Description                                                     |
| ------------------------------------------------------- | --------------------------------------------------------------- |
| `config/dot/hammerspoon/init.lua` (source)              | Entry point. Registers URL handlers and loads sub-modules       |
| `config/dot/hammerspoon/chrome-vertical-tab-toggle.lua` | Chrome vertical tab sidebar toggle (`require`d from `init.lua`) |
| `~/.hammerspoon/` (deployed)                            | Symlinked from `config/dot/hammerspoon/` by `install.sh`        |

Edit files under `config/dot/hammerspoon/` directly. Since `~/.hammerspoon` is a symlink to the source directory, changes are picked up without re-running `install.sh` — just reload the config from the Hammerspoon menu bar (or `hs.reload()` in the console).

## URL Schemes

Hammerspoon registers URL handlers via `hs.urlevent.bind`. They can be invoked from any process with `open -g "hammerspoon://<handler>"`.

| URL                                          | Description                                              |
| -------------------------------------------- | -------------------------------------------------------- |
| `hammerspoon://center`                       | Center the focused window on the current screen          |
| `hammerspoon://aerospace-workspace?ws=<num>` | Show a transient HUD with the AeroSpace workspace number |

### `hammerspoon://center`

Centers the focused window with `hs.window.focusedWindow():centerOnScreen(nil, true)`. The second argument (`true`) keeps the window from being placed under the Dock or off-screen.

Example:

```bash
open -g "hammerspoon://center"
```

### `hammerspoon://aerospace-workspace`

Displays the workspace number passed via the `ws` query parameter as an overlay HUD near the bottom-center of the main screen. The HUD auto-hides after about 0.7 seconds.

Example:

```bash
open -g "hammerspoon://aerospace-workspace?ws=3"
```

## AeroSpace Integration

The AeroSpace configuration (`config/dot_config/aerospace/aerospace.toml`) calls into Hammerspoon at two points:

| Trigger                                | URL invoked                                  | Purpose                                                     |
| -------------------------------------- | -------------------------------------------- | ----------------------------------------------------------- |
| `exec-on-workspace-change`             | `hammerspoon://aerospace-workspace?ws=<num>` | Display workspace HUD on every workspace switch             |
| Service mode `F` key (toggle floating) | `hammerspoon://center`                       | Re-center the window when it transitions to floating layout |

The Raycast script `config/mac/raycast/toggle_aerospace_float.sh` also calls `hammerspoon://center` after switching the focused window to the floating layout.

## Workspace HUD Customization

The workspace HUD is rendered with `hs.canvas`. Adjust the following local values inside `showAeroSpaceWorkspaceHUD` in `config/dot/hammerspoon/init.lua` to tweak its appearance:

| Variable                             | Default                        | Description                                      |
| ------------------------------------ | ------------------------------ | ------------------------------------------------ |
| `hudWidth`                           | `96`                           | HUD width in pixels                              |
| `hudHeight`                          | `72`                           | HUD height in pixels                             |
| `bottomMargin`                       | `56`                           | Distance from the bottom edge of the main screen |
| `roundedRectRadii`                   | `xRadius = 18`, `yRadius = 18` | Corner radius of the background rectangle        |
| `fillColor`                          | `{ white = 0, alpha = 0.72 }`  | Background color and opacity                     |
| `textSize`                           | `42`                           | Font size of the workspace number                |
| `textColor`                          | `{ white = 1, alpha = 1 }`     | Text color                                       |
| Show fade-in (`canvas:show`)         | `0.03` seconds                 | HUD fade-in duration                             |
| Auto-hide delay (`hs.timer.doAfter`) | `0.7` seconds                  | Time before the HUD starts fading out            |
| Hide fade-out (`canvas:delete`)      | `0.15` seconds                 | HUD fade-out duration                            |

The HUD is placed on the overlay window level (`hs.canvas.windowLevels.overlay`) and joins all spaces (`canJoinAllSpaces`) so it stays visible across AeroSpace workspace transitions.

## Chrome Vertical Tab Sidebar Toggle

`config/dot/hammerspoon/chrome-vertical-tab-toggle.lua` toggles Chrome's native vertical-tab sidebar from the keyboard or by hovering the screen's left edge. The script uses the macOS Accessibility API to locate the sidebar's expand/collapse button (matched against Chromium's localized `IDS_EXPAND_VERTICAL_TABS` / `IDS_COLLAPSE_VERTICAL_TABS` strings) and presses it via `AXPress`.

### Triggers

| Trigger               | Default       | Description                                                                              |
| --------------------- | ------------- | ---------------------------------------------------------------------------------------- |
| Keyboard hotkey       | `Cmd+Shift+B` | Toggle the sidebar while Chrome is frontmost                                             |
| Mouse left-edge hover | enabled       | Expand when the cursor reaches the left edge; collapse when it leaves the sidebar bounds |

Both triggers only fire when the frontmost app is in `TARGET_APPS` (Google Chrome and its Beta / Canary / Dev / Chromium variants by default).

### Configuration

All tunables live as `local` tables at the top of the script. Edit and reload Hammerspoon to apply.

| Table            | Notable keys                                                                  | Purpose                                                                                                   |
| ---------------- | ----------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| `FEATURES`       | `keyboardToggle`, `mouseEdgeToggle`                                           | Disable a trigger entirely. The corresponding `hs.eventtap`/`hs.timer` is never created when set to false |
| `TARGET_APPS`    | application name → `true`                                                     | Allow-list of frontmost app names treated as "Chrome"                                                     |
| `TOGGLE_MODS`    | `cmd`, `ctrl`, `alt`, `shift`                                                 | Modifier mask required for the hotkey (matched exactly)                                                   |
| `TOGGLE_KEY`     | e.g. `"b"`, `"tab"`                                                           | Main key for the hotkey                                                                                   |
| `SIDEBAR_LABELS` | `collapsed`, `expanded` arrays                                                | Localized button labels. Add the exact AXTitle/AXDescription string if your locale is missing             |
| `AX.maxDepth`    | `15`                                                                          | Maximum recursion depth when walking Chrome's AX tree                                                     |
| `EDGE`           | `enterPx`, `exitMarginPx`, `waitSeconds`, `pollSeconds`, …                    | Hover-trigger geometry and timing                                                                         |
| `WATCHDOG`       | `intervalSeconds`, `heartbeatTimeout`                                         | Revives the mouse poller if it stops emitting heartbeats (e.g. after sleep/wake)                          |
| `GRACE`          | `onActivate`, `onDeactivate`, `onLaunch`, `onWake`, `onInit`                  | Suppression windows that ignore triggers during noisy transitions                                         |
| `DELAY`          | `startAfterActivate`, `stopAfterDeactivate`, `restartAfterWake`, `restartGap` | Spacing for asynchronous start/stop/restart of the trigger services                                       |

### Troubleshooting

- **Sidebar not toggled** — Chrome may show the button under a locale not in `SIDEBAR_LABELS`. Inspect the button's AXTitle/AXDescription with Hammerspoon's `hs.axuielement` and append the exact string (matching is case-insensitive but requires a full-string match, not substring).
- **Hotkey doesn't fire** — `TOGGLE_MODS` is matched exactly; e.g. with `cmd = true` and `shift = true` set, pressing `Cmd+B` will NOT trigger.
- **Edge hover stops working after sleep** — the watchdog should revive it within `WATCHDOG.intervalSeconds + WATCHDOG.heartbeatTimeout` seconds; check `Console.app` for `chrome-sidebar` log entries.

## Adding New URL Handlers

To expose a new automation as a URL scheme, register it with `hs.urlevent.bind` in `config/dot/hammerspoon/init.lua`:

```lua
hs.urlevent.bind("my-action", function(_, params)
    -- params is a table populated from the query string
    hs.alert.show("Hello from " .. (params and params.name or "Hammerspoon"))
end)
```

Trigger it with:

```bash
open -g "hammerspoon://my-action?name=world"
```

After editing, reload Hammerspoon from the menu bar so the new handler is registered.
