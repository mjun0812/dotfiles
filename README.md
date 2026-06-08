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

| Tool        | Description                            |
| ----------- | -------------------------------------- |
| actionlint  | GitHub Actions workflow linter         |
| aqua        | Declarative CLI version manager        |
| aws-cli     | AWS command-line interface             |
| bat         | Modern `cat` with syntax highlighting  |
| chezmoi     | Dotfiles manager                       |
| delta       | Git diff pager                         |
| eza         | Modern `ls`                            |
| fd          | Modern `find`                          |
| gh          | GitHub CLI                             |
| ghq         | Repository management                  |
| git-lfs     | Git Large File Storage                 |
| gwq         | Git worktree management                |
| jq          | JSON processor                         |
| kubectl     | Kubernetes CLI                         |
| lazygit     | Git TUI                                |
| ripgrep     | Modern `grep`                          |
| ripgrep-all | `ripgrep` for PDFs, archives, and docs |
| sheldon     | Zsh plugin manager                     |
| shfmt       | Shell script formatter                 |
| starship    | Cross-shell prompt                     |
| tex-fmt     | LaTeX formatter                        |
| tmux        | Terminal multiplexer                   |
| tree-sitter | Parser generator tool                  |
| yazi        | Terminal file manager                  |
| yq          | YAML processor                         |
| zoxide      | Smart `cd` command                     |

### AI Agents

| Agent           | Description       |
| --------------- | ----------------- |
| Claude Code     | AI agent for code |
| Codex           | AI agent for code |
| Gemini-cli      | AI agent for code |
| Antigravity-cli | AI agent for code |
| Copilot-cli     | AI agent for code |
| OpenCode        | AI agent for code |

Agent skills (shared across Claude Code / Codex / Gemini / Antigravity) are documented in [doc/skills.md](doc/skills.md).

### macOS Only

Apps installed via Homebrew Cask.

| App                | Description                       |
| ------------------ | --------------------------------- |
| AeroSpace          | Tiling window manager             |
| Alt-Tab            | Windows-style window switcher     |
| azooKey            | Japanese input method             |
| balenaEtcher       | USB flash tool                    |
| BetterTouchTool    | Input device customization        |
| ChatGPT            | OpenAI desktop client             |
| Claude             | Anthropic desktop client          |
| Clipy              | Clipboard manager                 |
| cmux               | Terminal emulator                 |
| Cursor             | AI-powered IDE                    |
| DeepL              | Translator                        |
| Ghostty            | Terminal emulator                 |
| Hammerspoon        | macOS automation                  |
| Homerow            | Keyboard-driven mouse replacement |
| Inkscape           | Vector graphics editor            |
| iTerm2             | Terminal emulator                 |
| Karabiner-Elements | Keyboard customization            |
| Nani               | macOS utility                     |
| Notion             | Notes and knowledge base          |
| Obsidian           | Markdown knowledge base           |
| Ollama             | Local LLM runtime                 |
| Raycast            | Launcher                          |
| Visual Studio Code | Code editor                       |
| WezTerm            | Terminal emulator                 |
| XQuartz            | X11 for macOS                     |

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

# Copilot-cli
copilot-commit # AIが生成したコミットメッセージでコミットする
copilot-commit-ja # AIが生成した日本語のコミットメッセージでコミットする

# Antigravity-cli
agy-commit # AIが生成したコミットメッセージでコミットする
agy-commit-ja # AIが生成した日本語のコミットメッセージでコミットする

# Alias
aicommit # = cc-commit
aicommit-ja # = cc-commit-ja

# zoxide + fzf
# zoxideの履歴をfzfで選択してcdする
# Ctrl+f でも同様の操作が可能
fzf-zoxide-cd

# ghq + fzf
# ghqで管理しているリポジトリをfzfで選択してcdする
# cd for ghq repository
cd_repo
# Ctrl+j でも同様の操作が可能

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

## mise

This dotfiles uses [mise](https://github.com/jdx/mise) as a package manager for CLI tools.  
If you want to search and add a new tool, you can use below commands.

```bash
# Search for a tool in the mise registry
mise registry | grep <tool-name>
# Search for a tool in aqua registry
aqua g
mise use aqua:google-antigravity/antigravity-cli@latest
```

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
