# Hammerspoon Configuration

This document describes the Hammerspoon configuration and URL schemes.

[Hammerspoon](https://www.hammerspoon.org/) is a macOS automation tool that bridges the operating system and a Lua scripting engine. In this dotfiles setup, Hammerspoon supplements [AeroSpace](https://github.com/nikitabobko/AeroSpace) with window management features that AeroSpace cannot handle natively (centering floating windows, displaying a workspace HUD).

## Configuration Location

| Path                                       | Description                            |
| ------------------------------------------ | -------------------------------------- |
| `config/dot/hammerspoon/init.lua` (source) | Managed in this repository via chezmoi |
| `~/.hammerspoon/init.lua` (deployed)       | Loaded by Hammerspoon at startup       |

Edit `config/dot/hammerspoon/init.lua` and run `chezmoi apply` to deploy. After deploying, reload the config from the Hammerspoon menu bar (or `hs.reload()` in the console).

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

The Raycast script `script/raycast/toggle_aerospace_float.sh` also calls `hammerspoon://center` after switching the focused window to the floating layout.

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
