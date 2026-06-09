# dotfiles

My Linux/macOS dotfiles.

<p align="center">
  <!-- CI / Repository -->
  <img alt="badge" src="https://shieldcn.dev/github/ci/mjun0812/dotfiles.svg?workflow=ci-macos.yml&variant=secondary&size=xs">
  <img alt="badge" src="https://shieldcn.dev/github/ci/mjun0812/dotfiles.svg?workflow=ci-ubuntu.yml&variant=secondary&size=xs">
  <img alt="badge" src="https://shieldcn.dev/github/commits/mjun0812/dotfiles.svg?variant=secondary&size=xs">
  <img alt="badge" src="https://shieldcn.dev/github/last-commit/mjun0812/dotfiles.svg?variant=secondary&size=xs">
  <br>
  <!-- OS -->
  <img src="https://shieldcn.dev/badge/macOS-000000.svg?size=xs&logo=apple&logoColor=white" alt="macOS">
  <img src="https://shieldcn.dev/badge/Linux-FCC624.svg?size=xs&logo=linux&logoColor=black" alt="Linux">
  <br>
  <!-- Shell -->
  <img src="https://shieldcn.dev/badge/Zsh-F15A24.svg?size=xs&logo=zsh&logoColor=white" alt="Zsh">
  <img src="https://shieldcn.dev/badge/Powerlevel10k-000000.svg?size=xs&logo=zsh&logoColor=white" alt="Powerlevel10k">
  <img src="https://shieldcn.dev/badge/tmux-1BB91F.svg?size=xs&logo=tmux&logoColor=white" alt="tmux">
  <img src="https://shieldcn.dev/badge/mise-258577.svg?size=xs&logo=ri:RiTerminalBoxFill&logoColor=white" alt="mise">
  <br>
  <!-- Languages / Package Managers -->
  <img src="https://shieldcn.dev/badge/Python-3776AB.svg?size=xs&logo=python&logoColor=white" alt="Python">
  <img src="https://shieldcn.dev/badge/uv-DE5FE9.svg?size=xs&logo=uv&logoColor=white" alt="uv">
  <img src="https://shieldcn.dev/badge/Go-00ADD8.svg?size=xs&logo=go&logoColor=white" alt="Go">
  <img src="https://shieldcn.dev/badge/Vite%20Plus-646CFF.svg?size=xs&logo=vite&logoColor=white" alt="Vite Plus">
  <img src="https://shieldcn.dev/badge/pnpm-F69220.svg?size=xs&logo=pnpm&logoColor=white" alt="pnpm">
  <br>
  <!-- Editor -->
  <img src="https://shieldcn.dev/badge/Neovim-57A143.svg?size=xs&logo=neovim&logoColor=white" alt="Neovim">
  <img src="https://shieldcn.dev/badge/VS%20Code-0078d7.svg?size=xs&logo=vscodium&logoColor=white" alt="VS Code">
  <img src="https://shieldcn.dev/badge/Cursor-000000.svg?size=xs&logo=cursor&logoColor=white" alt="Cursor">
  <br>
  <!-- Terminal -->
  <img src="https://shieldcn.dev/badge/Ghostty-1D2021.svg?size=xs&logo=ghostty&logoColor=white" alt="Ghostty">
  <img src="https://shieldcn.dev/badge/WezTerm-4E49EE.svg?size=xs&logo=wezterm&logoColor=white" alt="WezTerm">
  <img src="https://shieldcn.dev/badge/iTerm2-000000.svg?size=xs&logo=iterm2&logoColor=white" alt="iTerm2">
  <br>
  <!-- AI Agents -->
  <img src="https://shieldcn.dev/badge/Claude%20Code-D97757.svg?size=xs&logo=claude&logoColor=white" alt="Claude Code">
  <img src="https://shieldcn.dev/badge/Codex-000000.svg?size=xs&logo=ri:RiOpenaiFill&logoColor=white" alt="Codex">
  <img src="https://shieldcn.dev/badge/Gemini-8E75B2.svg?size=xs&logo=googlegemini&logoColor=white" alt="Gemini">
  <img src="https://shieldcn.dev/badge/Antigravity-000000.svg?size=xs&logo=google&logoColor=white" alt="Antigravity">
  <img src="https://shieldcn.dev/badge/Copilot-000000.svg?size=xs&logo=githubcopilot&logoColor=white" alt="GitHub Copilot">
</p>

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
