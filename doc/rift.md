# Rift Traditional

[Rift](https://github.com/acsandmann/rift) is an optional alternative to AeroSpace for comparing window-management responsiveness on macOS. This configuration targets **v0.7.1 or later** and was checked against the [v0.7.1 example configuration](https://github.com/acsandmann/rift/blob/v0.7.1/rift.default.toml). It does not claim a measured speed improvement or complete AeroSpace compatibility.

## Configuration

`config/dot_config/rift/` is linked to `~/.config/rift` by `mise dot apply`, as declared in `config/dot_config/mise/conf.d/dotfiles.toml`.

- Traditional layout, zero gaps, and independent workspaces named 1–9 on each display.
- AeroSpace-style focus, move, workspace, resize, and service-mode bindings.
- Animations, gestures, drag-and-drop, and external HUD hooks disabled for the initial comparison.
- Finder, LINE, Mattermost, Mail, DeepL, Nani, and System Settings float; Ghostty tiles.
- Rift manages windows immediately when launched (`default_disable = false`). Installing or linking the configuration does **not** start it.

AeroSpace's package, configuration, Raycast scripts, and Hammerspoon integration are retained. Neither window manager's service or login settings are changed automatically.

## Install and link

Rift, its Homebrew tap, and `jq` are declared in the macOS mise bootstrap configuration. The normal dotfiles installation therefore installs them without enabling Rift's service. For a targeted trial without rerunning the full installer:

```sh
brew update
brew install acsandmann/tap/rift jq
rift-cli --version
```

The sequence bindings require Rift 0.7.1 or later. Use `brew upgrade acsandmann/tap/rift` if necessary; do not use `--HEAD` for this comparison.

From `~/.dotfiles`, apply the declared links:

```sh
mise dot status
mise dot apply
```

Review the status first: `mise dot apply` applies all declared links, not only Rift. If `~/.config/rift` already contains a real directory from a manual installation, move that directory to a dated backup before applying the link. Do not delete local settings or force an overwrite. The full `install.sh` has its own backup handling, but rerunning it also applies other tools and settings.

For multiple monitors, enable **System Settings → Desktop & Dock → Mission Control → Displays have separate Spaces**, logging out if requested. No SIP change is required. Leave the current physical monitor arrangement intact.

## First launch

Do not let AeroSpace and Rift manage windows at the same time. Disable AeroSpace, then quit it from its menu-bar menu:

```sh
aerospace enable off
```

Start Rift in a terminal for the first test:

```sh
rift
```

Grant the `rift` binary Accessibility permission in **System Settings → Privacy & Security → Accessibility**. Its path is printed by:

```sh
echo "$(brew --prefix rift)/bin/rift"
```

Restart the foreground process after granting permission. `rift-cli` is only the command client; the permission is for `rift`. The custom Mission Control preview is disabled in this configuration.

After testing, stop the foreground process with `Ctrl+C`, then opt in to login startup:

```sh
brew services start acsandmann/tap/rift
```

Use **Homebrew services only** for this setup; do not also register `rift service install` / `rift service start`. Before enabling automatic startup, set `start-at-login = false` in AeroSpace's configuration so it does not compete for shortcuts after login. This change is deliberately left to the user during the trial.

## Shortcuts

| Shortcut                         | Action                                                        |
| -------------------------------- | ------------------------------------------------------------- |
| `Alt + Ctrl + H/J/K/L` or arrows | Focus a window in that direction                              |
| `Alt + Shift + H/J/K/L`          | Move the selected tile                                        |
| `Alt + /`                        | Toggle split orientation                                      |
| `Alt + ,`                        | Toggle stacking (not AeroSpace's accordion orientation cycle) |
| `Alt + -` / `Alt + =`            | Smart shrink / grow                                           |
| `Alt + 1–9`                      | Select a workspace on the current display                     |
| `Alt + Shift + 1–9`              | Move the window to that workspace and follow                  |
| `Alt + Shift + Tab`              | Move to the next managed display and follow                   |
| `Alt + Ctrl + Shift + arrows`    | Focus another display, including an empty one                 |
| `Alt + Z`                        | Toggle management of the current macOS Space                  |
| `Alt + Shift + ;`                | Enter service mode                                            |

Service mode exits after each operation: `Escape` reloads the config, `F` toggles floating, `R` unjoins the selected group and balances sizes, and `Alt + Shift + H/J/K/L` joins with a neighbor.

Rift's internal workspace indices are 0–8; the visible names and number keys are 1–9. Unlike the old main/secondary assignment, each display has its own workspace 1, 2, and so on. Smart resize is ratio-based, not AeroSpace's 50-point increment. Service-mode `R` is **not** `flatten-workspace-tree`, and `Alt + /` does not force a stacked container back to tiles. Mouse-follow behavior also differs: automatic pointer movement is disabled for the initial comparison.

### Next-display helper

`move-next-display.sh` uses Rift's CLI and `next-display.jq` to cycle managed displays by macOS X coordinate, then Y coordinate, then UUID. It wraps at the last display and does nothing with fewer than two managed displays. It rejects an ambiguous active display or malformed response and does not focus the destination if the move command fails. This is a custom helper, not a built-in Rift `next` command, and its order may differ from AeroSpace.

The helper uses zsh, which ships with macOS. `jq` is installed through Homebrew so it remains available to the Homebrew service without depending on interactive shell activation. Other everyday focus/workspace bindings use Rift's native commands, not a spawned shell.

## Check and tune

```sh
rift-cli query displays
rift-cli query workspaces
rift-cli query workspace-layout
rift-cli execute config reload
```

Start with animations and external HUD hooks disabled. Compare repeated focus changes, window creation, workspace switches, cross-display moves, sleep/wake, and external-monitor disconnect/reconnect with the same apps as AeroSpace. macOS GUI behavior and latency still require an actual multi-monitor test; the automated tests below do not establish those results.

To add visual animation after checking responsiveness, edit the existing `[settings]` values in `~/.config/rift/config.toml`:

```toml
animate = true
animation_duration = 0.15
animation_fps = 0.0
```

Zero FPS means the display refresh rate, not disabled rendering. Hot reload is enabled. Editing the linked file changes the repository, so review the diff before committing personal changes. Leave the Hammerspoon workspace HUD disconnected until the baseline comparison is complete.

For manual activation on each display instead of managing immediately at launch, change the existing `default_disable` to `true`, restart Rift, and use `Alt + Z` on each display. This toggle is scoped to the current macOS Space, not all displays. Existing AeroSpace Raycast scripts do not control Rift; the equivalent current-Space toggle is:

```sh
rift-cli execute space toggle-activated
```

Logs and recovery from a stuck service binding mode:

```sh
tail -n 80 "/tmp/rift_$(id -un).err.log"
rift-cli execute binding-mode default
```

## Return to AeroSpace

Stop Rift before restarting AeroSpace:

```sh
brew services stop acsandmann/tap/rift
open -a AeroSpace
```

If Rift was started in a terminal, stop that process with `Ctrl+C` instead. Once AeroSpace has started, enable it explicitly because its existing startup configuration disables management:

```sh
aerospace enable on
```

Restore AeroSpace's `start-at-login = true` if it was changed for the trial. No uninstallation is necessary.

## Tests

Python 3.11+, jq, and zsh are sufficient; Rift and macOS GUI access are not needed:

```sh
zsh -n config/dot_config/rift/move-next-display.sh
RIFT_TEST_SHELL=/bin/zsh python3 -m unittest discover -s tests -p 'test_rift.py' -v
```

The tests check TOML, key mappings, package/link declarations, and the real helper/filter with a mocked `rift-cli`. CI runs them on Linux and macOS with zsh. In a development container without zsh, the tests can exercise the helper's portable shell subset with Bash; that is not a substitute for the zsh CI or real multi-monitor testing.
