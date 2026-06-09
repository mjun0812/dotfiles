# dotfiles

My Linux/macOS dotfiles.

[![CI macOS](https://img.shields.io/github/actions/workflow/status/mjun0812/dotfiles/ci-macos.yml?style=flat-square&logo=githubactions&logoColor=white&label=CI%20macOS)](https://github.com/mjun0812/dotfiles/actions/workflows/ci-macos.yml)
[![CI Ubuntu](https://img.shields.io/github/actions/workflow/status/mjun0812/dotfiles/ci-ubuntu.yml?style=flat-square&logo=githubactions&logoColor=white&label=CI%20Ubuntu)](https://github.com/mjun0812/dotfiles/actions/workflows/ci-ubuntu.yml)
![macOS](https://img.shields.io/badge/macOS-000000?style=flat-square&logo=apple&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?style=flat-square&logo=linux&logoColor=black)
![Zsh](https://img.shields.io/badge/Zsh-F15A24?style=flat-square&logo=zsh&logoColor=white)
![tmux](https://img.shields.io/badge/tmux-1BB91F?style=flat-square&logo=tmux&logoColor=white)
![Starship](https://img.shields.io/badge/Starship-DD0B78?style=flat-square&logo=starship&logoColor=white)
![mise](https://img.shields.io/badge/mise-258577?style=flat-square)
![Neovim](https://img.shields.io/badge/Neovim-57A143?style=flat-square&logo=neovim&logoColor=white)
![VS Code](https://img.shields.io/badge/VS%20Code-0078d7?style=flat-square&logo=vscodium&logoColor=white)
![Cursor](https://img.shields.io/badge/Cursor-000000?style=flat-square&logo=cursor&logoColor=white)
![Ghostty](https://img.shields.io/badge/Ghostty-1D2021?style=flat-square&logo=ghostty&logoColor=white)
![WezTerm](https://img.shields.io/badge/WezTerm-4E49EE?style=flat-square&logo=wezterm&logoColor=white)
![iTerm2](https://img.shields.io/badge/iTerm2-000000?style=flat-square&logo=iterm2&logoColor=white)
![Claude Code](https://img.shields.io/badge/Claude%20Code-D97757?style=flat-square&logo=claude&logoColor=white)
![Codex](https://img.shields.io/badge/Codex-000000?style=flat-square&logo=openai&logoColor=white)
![Gemini](https://img.shields.io/badge/Gemini-8E75B2?style=flat-square&logo=googlegemini&logoColor=white)
![GitHub Copilot](https://img.shields.io/badge/Copilot-000000?style=flat-square&logo=githubcopilot&logoColor=white)
![Git](https://img.shields.io/badge/Git-F05032?style=flat-square&logo=git&logoColor=white)
![GitHub CLI](https://img.shields.io/badge/gh-181717?style=flat-square&logo=github&logoColor=white)
![License](https://img.shields.io/github/license/mjun0812/dotfiles?style=flat-square)
![Last Commit](https://img.shields.io/github/last-commit/mjun0812/dotfiles?style=flat-square)

### Shieldcn

[![CI macOS](https://shieldcn.dev/github/ci/mjun0812/dotfiles.png?size=sm&logo=githubactions&logoColor=white&label=CI%20macOS)](https://github.com/mjun0812/dotfiles/actions/workflows/ci-macos.yml)
[![CI Ubuntu](https://shieldcn.dev/github/ci/mjun0812/dotfiles.png?size=sm&logo=githubactions&logoColor=white&label=CI%20Ubuntu)](https://github.com/mjun0812/dotfiles/actions/workflows/ci-ubuntu.yml)
![macOS](https://shieldcn.dev/badge/macOS-000000.png?size=sm&logo=apple&logoColor=white)
![Linux](https://shieldcn.dev/badge/Linux-FCC624.png?size=sm&logo=linux&logoColor=black)
![Zsh](https://shieldcn.dev/badge/Zsh-F15A24.png?size=sm&logo=zsh&logoColor=white)
![tmux](https://shieldcn.dev/badge/tmux-1BB91F.png?size=sm&logo=tmux&logoColor=white)
![Starship](https://shieldcn.dev/badge/Starship-DD0B78.png?size=sm&logo=starship&logoColor=white)
![mise](https://shieldcn.dev/badge/mise-258577.png?size=sm)
![Neovim](https://shieldcn.dev/badge/Neovim-57A143.png?size=sm&logo=neovim&logoColor=white)
![VS Code](https://shieldcn.dev/badge/VS%20Code-0078d7.png?size=sm&logo=vscodium&logoColor=white)
![Cursor](https://shieldcn.dev/badge/Cursor-000000.png?size=sm&logo=cursor&logoColor=white)
![Ghostty](https://shieldcn.dev/badge/Ghostty-1D2021.png?size=sm&logo=ghostty&logoColor=white)
![WezTerm](https://shieldcn.dev/badge/WezTerm-4E49EE.png?size=sm&logo=wezterm&logoColor=white)
![iTerm2](https://shieldcn.dev/badge/iTerm2-000000.png?size=sm&logo=iterm2&logoColor=white)
![Claude Code](https://shieldcn.dev/badge/Claude%20Code-D97757.png?size=sm&logo=claude&logoColor=white)
![Codex](https://shieldcn.dev/badge/Codex-000000.png?size=sm&logo=openai&logoColor=white)
![Gemini](https://shieldcn.dev/badge/Gemini-8E75B2.png?size=sm&logo=googlegemini&logoColor=white)
![GitHub Copilot](https://shieldcn.dev/badge/Copilot-000000.png?size=sm&logo=githubcopilot&logoColor=white)
![Git](https://shieldcn.dev/badge/Git-F05032.png?size=sm&logo=git&logoColor=white)
![GitHub CLI](https://shieldcn.dev/badge/gh-181717.png?size=sm&logo=github&logoColor=white)
![License](https://shieldcn.dev/github/license/mjun0812/dotfiles.png?size=sm)
![Last Commit](https://shieldcn.dev/github/commits/mjun0812/dotfiles.png?size=sm)

## Install

require git, zsh, curl

```bash
git clone git@github.com:mjun0812/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh

# First Install Only: Install VS Code extensions
./script/install_vscode_extensions.sh
# First Install Only: For macOS
./script/install_macOS.sh

# Optional: Login to GitHub CLI
gh auth login
```

## Tools

| Name   | Description     |
| ------ | --------------- |
| zsh    | Shell           |
| mise   | Package manager |
| Neovim | Editor          |
| VSCode | IDE             |
| Cursor | IDE             |

### CLI

| Name        | Description                            |
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
| pre-commit  | Git commit hooks manager               |
| prek        | pre-commit runner in Rust              |
| ripgrep     | Modern `grep`                          |
| ripgrep-all | `ripgrep` for PDFs, archives, and docs |
| sheldon     | Zsh plugin manager                     |
| shellcheck  | Shell script linter                    |
| shfmt       | Shell script formatter                 |
| starship    | Cross-shell prompt                     |
| tex-fmt     | LaTeX formatter                        |
| tmux        | Terminal multiplexer                   |
| tree-sitter | Parser generator tool                  |
| uv          | Python package and tool manager        |
| vp          | Vite Plus CLI                          |
| yazi        | Terminal file manager                  |
| yq          | YAML processor                         |
| zoxide      | Smart `cd` command                     |

### AI Agents

| Name            | Description                           |
| --------------- | ------------------------------------- |
| Claude Code     | AI agent for daily use                |
| Codex           | AI agent for daily use                |
| Gemini-cli      | AI agent for generate commit messages |
| Antigravity-cli | AI agent for generate commit messages |
| Copilot-cli     | AI agent for code                     |
| OpenCode        | AI agent for code                     |

Agent skills (shared across Claude Code / Codex / Gemini / Antigravity) are documented in [doc/skills.md](doc/skills.md).

### macOS Apps

Apps installed via Homebrew Cask.
Details of configuration and keyboard shortcuts are documented in [doc/macOS.md](doc/macOS.md).

| Name               | Description                       |
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
| Nani               | Translator                        |
| Notion             | Notes and knowledge base          |
| Obsidian           | Markdown knowledge base           |
| Ollama             | Local LLM runtime                 |
| Raycast            | Launcher                          |
| Visual Studio Code | Code editor                       |
| WezTerm            | Terminal emulator                 |
| XQuartz            | X11 for macOS                     |

## Design

I prefer [Tokyo Night](https://github.com/tokyo-night) color scheme.
It is used in Neovim, VS Code, Cursor.

### Terminal color schemes

| Color         | sRGB    | Display-P3 |
| ------------- | ------- | ---------- |
| Foreground    | #EAEAEA | #EAEAEA    |
| Background    | #000000 | #000000    |
| Black         | #000000 | #000000    |
| Red           | #FE533E | #EB6049    |
| Green         | #57DC76 | #7DD981    |
| Yellow        | #FECB00 | #F6CD45    |
| Blue          | #00A7FF | #4AA5F8    |
| Magenta       | #FF4867 | #EB576A    |
| Cyan          | #69D1FA | #84CFF6    |
| White         | #EAEAEA | #EAEAEA    |
| Gray          | #7B7B7B | #7B7B7B    |
| Light Red     | #FE533E | #EB6049    |
| Light Green   | #57DC76 | #7DD981    |
| Light Yellow  | #FECB00 | #F6CD45    |
| Light Blue    | #00A7FF | #4AA5F8    |
| Light Magenta | #FF4867 | #EB576A    |
| Light Cyan    | #69D1FA | #84CFF6    |
| Light White   | #EAEAEA | #EAEAEA    |

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

### Git Commands

```bash
# Delete local branches that are deleted and merged
git prune-branch

# commit with AI generated commit message
git aicommit
# commit with AI generated commit message in Japanese
git aicommit-ja
```

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

`install.sh` runs `script/install_vscode_extensions.sh`, which installs missing extensions only and does not uninstall local extensions.

To synchronize the installed extensions exactly with `config/vscode/extensions.txt`, run:

```bash
script/sync_vscode_extensions.sh
```

You can pass another extension list:

```bash
script/sync_vscode_extensions.sh path/to/extensions.txt
```

Use `--dry-run` to preview installs and uninstalls without changing VS Code:

```bash
script/sync_vscode_extensions.sh --dry-run
script/sync_vscode_extensions.sh --dry-run path/to/extensions.txt
```
