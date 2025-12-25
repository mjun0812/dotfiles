# dotfiles

## Install

require git, zsh

```bash
git clone --recursive git@github.com:mjun0812/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

## Git Commands

```bash
# Delete local branches that are deleted and merged
# すでにremoteでマージされて，削除されたブランチをローカルでも削除する
git prune-branch

# commit with AI generated commit message
# AIが生成したコミットメッセージでコミットする
git aicommit
# commit with AI generated commit message in Japanese
# AIが生成した日本語のコミットメッセージでコミットする
git aicommit-ja

# generate pull request with AI generated title and description
# AIが生成したタイトルと説明でプルリクエストを作成する
git aipr
# generate pull request with AI generated title and description in Japanese
# AIが生成した日本語のタイトルと説明でプルリクエストを作成する
git aipr-ja
```

## Alias

```bash
# Show NVIDIA GPUs that are not used by Xorg or gnome
nvs

# Claude Code
cc-commit # AIが生成したコミットメッセージでコミットする
cc-commit-ja # AIが生成した日本語のコミットメッセージでコミットする
cc-pr # AIが生成したタイトルと説明でプルリクエストを作成する
cc-pr-ja # AIが生成した日本語のタイトルと説明でプルリクエストを作成する

# Gemini-cli
gemini-commit # AIが生成したコミットメッセージでコミットする
gemini-commit-ja # AIが生成した日本語のコミットメッセージでコミットする

# Codex
codex-commit # AIが生成したコミットメッセージでコミットする
codex-commit-ja # AIが生成した日本語のコミットメッセージでコミットする

# Copilot-cli
copilot-commit # AIが生成したコミットメッセージでコミットする
copilot-commit-ja # AIが生成した日本語のコミットメッセージでコミットする
copilot-pr # AIが生成したタイトルと説明でプルリクエストを作成する
copilot-pr-ja # AIが生成した日本語のタイトルと説明でプルリクエストを作成する

# Alias
aicommit # = cc-commit
aicommit-ja # = cc-commit-ja
aipr # = cc-pr
aipr-ja # = cc-pr-ja

# ghq + fzf
cd_repo # ghqで管理しているリポジトリをfzfで選択してcdする
# Ctrl+f でも同様の操作が可能
```

## Neovim Keyboard Shortcuts

Leader key: `<Space>`, Local leader: `\`

### General

| Key | Mode | Description |
|-----|------|-------------|
| `<Esc>` | Terminal | Exit terminal mode to normal mode |
| `:T [args]` | Command | Open terminal at bottom with height 20 |

### File Explorer (Fern)

| Key | Mode | Description |
|-----|------|-------------|
| `<C-e>` | Normal | Toggle file tree |
| `V` | Fern buffer | Open file in vertical split |

### Fuzzy Finder (Telescope)

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>ff` | Normal | Find files |
| `<leader>fg` | Normal | Live grep (search text) |
| `<leader>fb` | Normal | List buffers |
| `<leader>fh` | Normal | Search help tags |

### LSP / Code Intelligence (CoC)

#### Completion (Insert mode)

| Key | Mode | Description |
|-----|------|-------------|
| `<Tab>` | Insert | Next completion item / trigger completion |
| `<S-Tab>` | Insert | Previous completion item |
| `<CR>` | Insert | Confirm completion |
| `<C-Space>` | Insert | Trigger completion |
| `<C-n>` | Insert | Next completion item |
| `<C-p>` | Insert | Previous completion item |

#### Navigation

| Key | Mode | Description |
|-----|------|-------------|
| `gd` | Normal | Go to definition |
| `gy` | Normal | Go to type definition |
| `gi` | Normal | Go to implementation |
| `gr` | Normal | Show references |
| `K` | Normal | Show documentation |
| `[g` | Normal | Previous diagnostic |
| `]g` | Normal | Next diagnostic |

#### Code Actions

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>rn` | Normal | Rename symbol |
| `<leader>f` | Normal/Visual | Format selected code |
| `<leader>a` | Normal/Visual | Code action on selected |
| `<leader>ac` | Normal | Code action at cursor |
| `<leader>as` | Normal | Code action for buffer |
| `<leader>qf` | Normal | Quick fix current line |
| `<leader>re` | Normal | Refactor |
| `<leader>r` | Normal/Visual | Refactor selected |
| `<leader>cl` | Normal | Code Lens action |
| `ga` | Normal | Code action for line |
| `gA` | Normal | Code action |

#### Text Objects

| Key | Mode | Description |
|-----|------|-------------|
| `if` / `af` | Visual/Operator | Inner/around function |
| `ic` / `ac` | Visual/Operator | Inner/around class |

#### Scroll & Selection

| Key | Mode | Description |
|-----|------|-------------|
| `<C-f>` | Normal/Insert/Visual | Scroll float window down |
| `<C-b>` | Normal/Insert/Visual | Scroll float window up |
| `<C-s>` | Normal/Visual | Range select |

#### CocList

| Key | Mode | Description |
|-----|------|-------------|
| `<Space>a` | Normal | Show all diagnostics |
| `<Space>e` | Normal | Manage extensions |
| `<Space>c` | Normal | Show commands |
| `<Space>o` | Normal | Show outline |
| `<Space>s` | Normal | Search workspace symbols |
| `<Space>j` | Normal | Next item |
| `<Space>k` | Normal | Previous item |
| `<Space>p` | Normal | Resume last list |

### Commands

| Command | Description |
|---------|-------------|
| `:Format` | Format current buffer |
| `:Fold` | Fold current buffer |
| `:OR` | Organize imports |
