# Neovim Configuration

This document describes the Neovim configuration and keyboard shortcuts.

## Plugins

The configuration uses [lazy.nvim](https://github.com/folke/lazy.nvim) as the plugin manager.

| Plugin                                                                                        | Description                                         |
| --------------------------------------------------------------------------------------------- | --------------------------------------------------- |
| [tokyonight.nvim](https://github.com/folke/tokyonight.nvim)                                   | Color scheme                                        |
| [snacks.nvim](https://github.com/folke/snacks.nvim)                                           | Terminal, indent guides, window zoom, file explorer |
| [blink.cmp](https://github.com/saghen/blink.cmp)                                              | Completion engine                                   |
| [nvim-autopairs](https://github.com/windwp/nvim-autopairs)                                    | Auto pairs (incl. `"""` and ` ``` `)                |
| [rainbow-delimiters.nvim](https://github.com/HiPhish/rainbow-delimiters.nvim)                 | Rainbow delimiters                                  |
| [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)                            | Fuzzy finder                                        |
| [gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim)                                   | Git signs in gutter                                 |
| [trouble.nvim](https://github.com/folke/trouble.nvim)                                         | Diagnostics and quickfix list                       |
| [which-key.nvim](https://github.com/folke/which-key.nvim)                                     | Keybinding help                                     |
| [mason.nvim](https://github.com/mason-org/mason.nvim)                                         | LSP server installation                             |
| [mason-lspconfig.nvim](https://github.com/mason-org/mason-lspconfig.nvim)                     | Bridge between Mason and nvim-lspconfig             |
| [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig)                                    | LSP server configuration                            |
| [conform.nvim](https://github.com/stevearc/conform.nvim)                                      | Formatter                                           |
| [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)                         | Syntax highlighting                                 |
| [nvim-treesitter-textobjects](https://github.com/nvim-treesitter/nvim-treesitter-textobjects) | Treesitter text objects                             |
| [lualine.nvim](https://github.com/nvim-lualine/lualine.nvim)                                  | Status line                                         |
| [colorful-winsep.nvim](https://github.com/nvim-zh/colorful-winsep.nvim)                       | Highlight the borders of the active window          |
| [vimade](https://github.com/tadaa/vimade)                                                     | Fade inactive windows                               |
| [image.nvim](https://github.com/3rd/image.nvim)                                               | Inline images in Markdown and notebooks             |
| [diagram.nvim](https://github.com/3rd/diagram.nvim)                                           | Render Mermaid diagrams in Markdown                 |
| [ipynb.nvim](https://github.com/ajbucci/ipynb.nvim)                                           | Direct `.ipynb` notebook editor                     |
| [molten-nvim](https://github.com/benlubas/molten-nvim)                                        | Jupyter kernel runner                               |
| [jupytext.nvim](https://github.com/goerz/jupytext.nvim)                                       | Notebook/plaintext conversion                       |

## Keyboard Shortcuts

Leader key: `<Space>`, Local leader: `\`

### General

| Key         | Mode     | Description                            |
| ----------- | -------- | -------------------------------------- |
| `<Esc>`     | Terminal | Exit terminal mode to normal mode      |
| `:T [args]` | Command  | Open terminal at bottom with height 20 |

### Window Resize

| Key     | Mode   | Description            |
| ------- | ------ | ---------------------- |
| `<A-j>` | Normal | Increase window height |
| `<A-k>` | Normal | Decrease window height |
| `<A-h>` | Normal | Decrease window width  |
| `<A-l>` | Normal | Increase window width  |

### Terminal (snacks.nvim)

| Key          | Mode            | Description                         |
| ------------ | --------------- | ----------------------------------- |
| `<C-`>`      | Normal/Terminal | Toggle bottom terminal (25% height) |
| `<M-`>`      | Normal/Terminal | Toggle floating terminal (90% size) |
| `<leader>wm` | Normal          | Toggle window maximize (zoom)       |

### File Explorer (snacks.nvim explorer)

The explorer is configured in `lua/plugins/snacks-explorer.lua` with fern.vim-style keymaps.
It watches the file system and refreshes automatically; the search input is hidden until `/` is pressed.

| Key                     | Mode         | Description                                                  |
| ----------------------- | ------------ | ------------------------------------------------------------ |
| `<C-e>`                 | Normal       | Toggle file tree (reveals the current file)                  |
| `l` / `h`               | Explorer     | Expand or open / collapse                                    |
| `<CR>`                  | Explorer     | Open file, or make the directory the root                    |
| `<C-h>` / `<BS>`        | Explorer     | Go to the parent directory                                   |
| `i`                     | Explorer     | Reveal the file of the current buffer                        |
| `!` / `H` / `I`         | Explorer     | Toggle hidden files / hidden files / git-ignored files       |
| `e` / `E` / `V` / `t`   | Explorer     | Open / open in vertical split / horizontal split / tab       |
| `x`                     | Explorer     | Open with the system application                             |
| `-` / `<C-j>` / `<C-k>` | Explorer     | Toggle selection / select and move down / move up and select |
| `N` / `K`               | Explorer     | Create a file or directory (end with `/` for a directory)    |
| `D` / `R` / `m` / `c`   | Explorer     | Trash / rename / move / copy                                 |
| `y` / `C` / `P`         | Explorer     | Yank path / yank path / paste (copy) into the directory      |
| `r` / `<C-l>`           | Explorer     | Refresh                                                      |
| `/`                     | Explorer     | Show the search input and search recursively                 |
| `<CR>`                  | Search input | Reveal the match in the tree and hide the input              |
| `<Esc>`                 | Search input | Leave the search and hide the input                          |
| `?`                     | Explorer     | Show help                                                    |

### Fuzzy Finder (Telescope)

| Key          | Mode   | Description             |
| ------------ | ------ | ----------------------- |
| `<leader>ff` | Normal | Find files              |
| `<leader>fg` | Normal | Live grep (search text) |
| `<leader>fb` | Normal | List buffers            |
| `<leader>fh` | Normal | Search help tags        |

### Completion (blink.cmp)

Preset: `enter`

| Key                | Mode   | Description                           |
| ------------------ | ------ | ------------------------------------- |
| `<CR>`             | Insert | Accept completion                     |
| `<C-Space>`        | Insert | Open menu / open docs if menu is open |
| `<C-n>` / `<Down>` | Insert | Select next item                      |
| `<C-p>` / `<Up>`   | Insert | Select previous item                  |
| `<C-e>`            | Insert | Hide menu                             |
| `<C-k>`            | Insert | Toggle signature help                 |

### LSP / Code Intelligence

| Key         | Mode   | Description                                                                        |
| ----------- | ------ | ---------------------------------------------------------------------------------- |
| `gd`        | Normal | Go to definition                                                                   |
| `<leader>k` | Normal | Show hover documentation                                                           |
| `<Tab>`     | Insert | Accept inline completion (Copilot), otherwise jump to the next snippet placeholder |

Auto-format on save is enabled when the language server supports formatting.

GitHub Copilot is not a plugin here: the `copilot` language server is installed through Mason
(`lua/config/mason-servers.lua`) and its suggestions are shown as ghost text via `vim.lsp.inline_completion`.

### Diagnostics (Trouble)

| Key          | Mode   | Description                       |
| ------------ | ------ | --------------------------------- |
| `<leader>xx` | Normal | Toggle diagnostics                |
| `<leader>xX` | Normal | Toggle buffer diagnostics         |
| `<leader>cs` | Normal | Toggle symbols                    |
| `<leader>cl` | Normal | Toggle LSP definitions/references |
| `<leader>xL` | Normal | Toggle location list              |
| `<leader>xQ` | Normal | Toggle quickfix list              |

### Which Key

| Key         | Mode   | Description               |
| ----------- | ------ | ------------------------- |
| `<leader>?` | Normal | Show buffer local keymaps |

## Jupyter Notebooks

Euporie, ipynb.nvim, and Jupytext + Molten are documented in
[notebooks.md](notebooks.md). Use the dedicated launch commands so the two
Neovim `.ipynb` handlers are never enabled together:

```bash
euporie-nb notebook.ipynb
nvim-ipynb notebook.ipynb
nvim-molten notebook.ipynb
```

## Commands

| Command     | Description                            |
| ----------- | -------------------------------------- |
| `:T [args]` | Open terminal at bottom with height 20 |
| `:Trouble`  | Open Trouble diagnostics               |
| `:Mason`    | Open Mason (LSP server management)     |
| `:Lazy`     | Open lazy.nvim plugin manager          |
