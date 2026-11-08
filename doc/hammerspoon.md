# Hammerspoon Configuration

This document describes the Hammerspoon configuration and URL schemes.

[Hammerspoon](https://www.hammerspoon.org/) is a macOS automation tool that bridges the operating system and a Lua scripting engine. In this dotfiles setup, Hammerspoon supplements the window managers [AeroSpace](https://github.com/nikitabobko/AeroSpace) and [Rift](https://github.com/acsandmann/rift) with a feature they cannot handle natively (displaying a workspace HUD).

## Configuration Location

| Path                                                 | Description                                                        |
| ---------------------------------------------------- | ------------------------------------------------------------------ |
| `config/dot/hammerspoon/init.lua` (source)           | Entry point. Enables IPC and `require`s the feature modules below  |
| `config/dot/hammerspoon/wezterm-focus.lua`           | Return to the WezTerm window/pane from a coding agent notification |
| `config/dot/hammerspoon/aerospace-workspace-hud.lua` | AeroSpace workspace number HUD                                     |
| `~/.hammerspoon/` (deployed)                         | Symlinked from `config/dot/hammerspoon/` by `mise dot apply`       |

Edit files under `config/dot/hammerspoon/` directly. Since `~/.hammerspoon` is a symlink to the source directory, changes are picked up without re-running `install.sh` — just reload the config from the Hammerspoon menu bar (or `hs.reload()` in the console).

## URL Schemes

Hammerspoon registers URL handlers via `hs.urlevent.bind`. They can be invoked from any process with `open -g "hammerspoon://<handler>"`.

| URL                                                    | Description                                                             |
| ------------------------------------------------------ | ----------------------------------------------------------------------- |
| `hammerspoon://aerospace-workspace?ws=<num>`           | Show a transient HUD with the workspace number (AeroSpace and Rift)     |
| `hammerspoon://wezterm-capture?session=<id>&pane=<id>` | Remember the focused WezTerm window and pane for a coding agent session |
| `hammerspoon://wezterm-focus?session=<id>&pane=<id>`   | Bring back the WezTerm window and pane recorded for that session        |

### `hammerspoon://aerospace-workspace`

Displays the workspace number passed via the `ws` query parameter as an overlay HUD near the bottom-center of the main screen. The HUD auto-hides after about 0.7 seconds.

Example:

```bash
open -g "hammerspoon://aerospace-workspace?ws=3"
```

### `hammerspoon://wezterm-capture` / `hammerspoon://wezterm-focus`

`wezterm-capture` records the currently focused WezTerm window together with the `pane` id under the `session` key (re-captured when the recorded window is gone). `wezterm-focus` activates the recorded window and pane. Both are called from the Claude Code and Codex hook scripts under `config/ai-agents/hooks/` and `script/notify/`, not by hand.

## Window Manager Integration

The AeroSpace configuration (`config/dot_config/aerospace/aerospace.toml`) and the Rift configuration (`config/dot_config/rift/config.toml`) each call into Hammerspoon at one point:

| Config                     | Trigger                                                                | URL invoked                                  | Purpose                                         |
| -------------------------- | ---------------------------------------------------------------------- | -------------------------------------------- | ----------------------------------------------- |
| `aerospace/aerospace.toml` | `exec-on-workspace-change`                                             | `hammerspoon://aerospace-workspace?ws=<num>` | Display workspace HUD on every workspace switch |
| `rift/config.toml`         | `run_on_start` (`rift-cli subscribe` to the `workspace_changed` event) | `hammerspoon://aerospace-workspace?ws=<num>` | Display workspace HUD on every workspace switch |

## Workspace HUD Customization

The workspace HUD is rendered with `hs.canvas`. Adjust the following local values inside `showAeroSpaceWorkspaceHUD` in `config/dot/hammerspoon/aerospace-workspace-hud.lua` to tweak its appearance:

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

The HUD is placed on the overlay window level (`hs.canvas.windowLevels.overlay`) and joins all spaces (`canJoinAllSpaces`) so it stays visible across workspace transitions.

## Adding New URL Handlers

To expose a new automation as a URL scheme, create a new module under `config/dot/hammerspoon/` that registers the handler with `hs.urlevent.bind`, then `require` it from `init.lua`:

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
