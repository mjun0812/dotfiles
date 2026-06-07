# dotfiles

My Linux/macOS dotfiles.

## Install

require git, zsh, curl

```bash
git clone git@github.com:mjun0812/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

## Tools

| Tool   | Description     |
| ------ | --------------- |
| zsh    | Shell           |
| mise   | Package manager |
| Neovim | editor          |
| VSCode | IDE             |
| Cursor | IDE             |

### CLI

| Tool        | Description                           |
| ----------- | ------------------------------------- |
| aws-cli     | AWS command-line interface            |
| bat         | Modern `cat` with syntax highlighting |
| delta       | Git diff pager                        |
| eza         | Modern `ls`                           |
| fd          | Modern `find`                         |
| gh          | GitHub CLI                            |
| ghq         | Repository management                 |
| git-lfs     | Git Large File Storage                |
| gwq         | Git worktree management               |
| jq          | JSON processor                        |
| lazygit     | Git TUI                               |
| ripgrep     | Modern `grep`                         |
| starship    | Cross-shell prompt                    |
| tree-sitter | Parser generator tool                 |
| yazi        | Terminal file manager                 |
| yq          | YAML processor                        |
| zoxide      | Smart `cd` command                    |

### AI Agents

| Agent       | Description       |
| ----------- | ----------------- |
| Claude Code | AI agent for code |
| Gemini-cli  | AI agent for code |
| Codex       | AI agent for code |
| Copilot-cli | AI agent for code |

### macOS Only

Apps installed via Homebrew Cask.

| App                | Description                   |
| ------------------ | ----------------------------- |
| AeroSpace          | Tiling window manager         |
| Alt-Tab            | Windows-style window switcher |
| balenaEtcher       | USB flash tool                |
| BetterTouchTool    | Input device customization    |
| Clipy              | Clipboard manager             |
| cmux               | Terminal emulator             |
| Ghostty            | Terminal emulator             |
| Hammerspoon        | macOS automation              |
| Inkscape           | Vector graphics editor        |
| iTerm2             | Terminal emulator             |
| Karabiner-Elements | Keyboard customization        |
| Raycast            | Launcher                      |
| WezTerm            | Terminal emulator             |
| XQuartz            | X11 for macOS                 |

## Alias

```bash
# Show NVIDIA GPUs that are not used by Xorg or gnome
nvs

# Claude Code
cc-commit # AIが生成したコミットメッセージでコミットする
cc-commit-ja # AIが生成した日本語のコミットメッセージでコミットする

# Gemini-cli
gemini-commit # AIが生成したコミットメッセージでコミットする
gemini-commit-ja # AIが生成した日本語のコミットメッセージでコミットする

# Codex
codex-commit # AIが生成したコミットメッセージでコミットする
codex-commit-ja # AIが生成した日本語のコミットメッセージでコミットする

# Alias
aicommit # = cc-commit
aicommit-ja # = cc-commit-ja

# ghq + fzf
# ghqで管理しているリポジトリをfzfで選択してcdする
# cd for ghq repository
cd_repo
# Ctrl+f でも同様の操作が可能

# gwq + fzf
# gwqで管理しているワークツリーをfzfで選択してcdする
# cd git worktree with gwq
# cd for git worktree
cd_gwq
```

## Git Commands

```bash
# Delete local branches that are deleted and merged
git prune-branch

# commit with AI generated commit message
git aicommit
# commit with AI generated commit message in Japanese
git aicommit-ja
```

## ANSI 16 Color

For terminal color schemes.

### sRGB

| Color         | Hex     |
| ------------- | ------- |
| Black         | #000000 |
| Red           | #FE533E |
| Green         | #57DC76 |
| Yellow        | #FECB00 |
| Blue          | #00A7FF |
| Magenta       | #FF4867 |
| Cyan          | #69D1FA |
| White         | #EAEAEA |
| Gray          | #7B7B7B |
| Light Red     | #FE533E |
| Light Green   | #57DC76 |
| Light Yellow  | #FECB00 |
| Light Blue    | #00A7FF |
| Light Magenta | #FF4867 |
| Light Cyan    | #69D1FA |
| Light White   | #EAEAEA |

### Display-P3 (only supported on macOS)

| Color         | Hex     |
| ------------- | ------- |
| Black         | #000000 |
| Red           | #EB6049 |
| Green         | #7DD981 |
| Yellow        | #F6CD45 |
| Blue          | #4AA5F8 |
| Magenta       | #EB576A |
| Cyan          | #84CFF6 |
| White         | #EAEAEA |
| Gray          | #7B7B7B |
| Light Red     | #EB6049 |
| Light Green   | #7DD981 |
| Light Yellow  | #F6CD45 |
| Light Blue    | #4AA5F8 |
| Light Magenta | #EB576A |
| Light Cyan    | #84CFF6 |
| Light White   | #EAEAEA |

## Neovim

See [doc/nvim.md](doc/nvim.md) for Neovim configuration and keyboard shortcuts.

## VSCode

VS Code extensions are managed in `config/vscode/extensions.txt`.

`install.sh` runs `script/install-vscode-extensions.sh`, which installs missing extensions only and does not uninstall local extensions.

To synchronize the installed extensions exactly with `config/vscode/extensions.txt`, run:

```bash
script/sync-vscode-extensions.sh
```

You can pass another extension list:

```bash
script/sync-vscode-extensions.sh path/to/extensions.txt
```

Use `--dry-run` to preview installs and uninstalls without changing VS Code:

```bash
script/sync-vscode-extensions.sh --dry-run
script/sync-vscode-extensions.sh --dry-run path/to/extensions.txt
```

## AeroSpace

See [doc/aerospace.md](doc/aerospace.md) for AeroSpace window manager configuration and keyboard shortcuts.

## Hammerspoon

See [doc/hammerspoon.md](doc/hammerspoon.md) for Hammerspoon configuration and URL schemes.

Hammerspoon is used for window management features that AeroSpace cannot handle natively.

Currently configured features:

- Center window on screen via URL scheme (`hammerspoon://center`)
- AeroSpace workspace HUD via URL scheme (`hammerspoon://aerospace-workspace?ws=<num>`)
- Toggle Chrome's native vertical tab sidebar via `Cmd+B` and left-edge hover

## Raycast Scripts

Custom Raycast scripts are available in `script/raycast/`:

| Script                      | Description                              |
| --------------------------- | ---------------------------------------- |
| `toggle_aerospace.sh`       | Toggle AeroSpace ON/OFF                  |
| `toggle_aerospace_float.sh` | Toggle floating layout and center window |
| `new_chrome.sh`             | Open new Chrome window in current space  |
| `new_safari.sh`             | Open new Safari window in current space  |
| `new_wezterm.sh`            | Open new WezTerm window                  |
