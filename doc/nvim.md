# Neovim Configuration

This document describes the Neovim configuration and keyboard shortcuts.

## Plugins

The configuration uses [lazy.nvim](https://github.com/folke/lazy.nvim) as the plugin manager.

| Plugin                                                                | Description                          |
|-----------------------------------------------------------------------|--------------------------------------|
| [tokyonight.nvim](https://github.com/folke/tokyonight.nvim)           | Color scheme                         |
| [snacks.nvim](https://github.com/folke/snacks.nvim)                   | Terminal, indent guides, window zoom |
| [blink.cmp](https://github.com/saghen/blink.cmp)                      | Completion engine                    |
| [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)    | Fuzzy finder                         |
| [fern.vim](https://github.com/lambdalisue/fern.vim)                   | File explorer                        |
| [gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim)           | Git signs in gutter                  |
| [trouble.nvim](https://github.com/folke/trouble.nvim)                 | Diagnostics and quickfix list        |
| [which-key.nvim](https://github.com/folke/which-key.nvim)             | Keybinding help                      |
| [mini.pairs](https://github.com/echasnovski/mini.pairs)               | Auto pairs                           |
| [sidekick.nvim](https://github.com/folke/sidekick.nvim)               | AI CLI integration                   |
| [mason.nvim](https://github.com/williamboman/mason.nvim)              | LSP server management                |
| [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) | Syntax highlighting                  |
| [copilot.vim](https://github.com/github/copilot.vim)                  | GitHub Copilot                       |
| [lualine.nvim](https://github.com/nvim-lualine/lualine.nvim)          | Status line                          |

## Keyboard Shortcuts

Leader key: `<Space>`, Local leader: `\`

### General

| Key         | Mode     | Description                            |
|-------------|----------|----------------------------------------|
| `<Esc>`     | Terminal | Exit terminal mode to normal mode      |
| `:T [args]` | Command  | Open terminal at bottom with height 20 |

### Window Resize

| Key     | Mode   | Description            |
|---------|--------|------------------------|
| `<A-j>` | Normal | Increase window height |
| `<A-k>` | Normal | Decrease window height |
| `<A-h>` | Normal | Decrease window width  |
| `<A-l>` | Normal | Increase window width  |

### Terminal (snacks.nvim)

| Key | Mode | Description |
| --- | ---- | ----------- |
| `<C-`>` | Normal/Terminal | Toggle bottom terminal (25% height) |
| `<M-`>` | Normal/Terminal | Toggle floating terminal (90% size) |
| `<leader>wm` | Normal | Toggle window maximize (zoom) |

### File Explorer (Fern)

| Key     | Mode        | Description                 |
|---------|-------------|-----------------------------|
| `<C-e>` | Normal      | Toggle file tree            |
| `V`     | Fern buffer | Open file in vertical split |

### Fuzzy Finder (Telescope)

| Key          | Mode   | Description             |
|--------------|--------|-------------------------|
| `<leader>ff` | Normal | Find files              |
| `<leader>fg` | Normal | Live grep (search text) |
| `<leader>fb` | Normal | List buffers            |
| `<leader>fh` | Normal | Search help tags        |

### Completion (blink.cmp)

Preset: `enter`

| Key                | Mode   | Description                           |
|--------------------|--------|---------------------------------------|
| `<CR>`             | Insert | Accept completion                     |
| `<C-Space>`        | Insert | Open menu / open docs if menu is open |
| `<C-n>` / `<Down>` | Insert | Select next item                      |
| `<C-p>` / `<Up>`   | Insert | Select previous item                  |
| `<C-e>`            | Insert | Hide menu                             |
| `<C-k>`            | Insert | Toggle signature help                 |

### LSP / Code Intelligence

| Key         | Mode   | Description              |
|-------------|--------|--------------------------|
| `gd`        | Normal | Go to definition         |
| `<leader>k` | Normal | Show hover documentation |

Auto-format on save is enabled when the language server supports formatting.

### Diagnostics (Trouble)

| Key          | Mode   | Description                       |
|--------------|--------|-----------------------------------|
| `<leader>xx` | Normal | Toggle diagnostics                |
| `<leader>xX` | Normal | Toggle buffer diagnostics         |
| `<leader>cs` | Normal | Toggle symbols                    |
| `<leader>cl` | Normal | Toggle LSP definitions/references |
| `<leader>xL` | Normal | Toggle location list              |
| `<leader>xQ` | Normal | Toggle quickfix list              |

### Which Key

| Key         | Mode   | Description               |
|-------------|--------|---------------------------|
| `<leader>?` | Normal | Show buffer local keymaps |

### AI Integration (Sidekick)

| Key          | Mode                          | Description                           |
|--------------|-------------------------------|---------------------------------------|
| `<Tab>`      | Normal                        | Jump to / apply next edit suggestion  |
| `<C-.>`      | Normal/Terminal/Insert/Visual | Toggle Sidekick                       |
| `<leader>aa` | Normal                        | Toggle Sidekick CLI                   |
| `<leader>as` | Normal                        | Select CLI tool                       |
| `<leader>ad` | Normal                        | Detach CLI session                    |
| `<leader>at` | Normal/Visual                 | Send current code (`{this}`)          |
| `<leader>af` | Normal                        | Send current file (`{file}`)          |
| `<leader>av` | Visual                        | Send visual selection (`{selection}`) |
| `<leader>ap` | Normal/Visual                 | Select prompt                         |
| `<leader>ac` | Normal                        | Toggle Claude CLI                     |

## Commands

| Command     | Description                            |
|-------------|----------------------------------------|
| `:T [args]` | Open terminal at bottom with height 20 |
| `:Trouble`  | Open Trouble diagnostics               |
| `:Mason`    | Open Mason (LSP server management)     |
| `:Lazy`     | Open lazy.nvim plugin manager          |
