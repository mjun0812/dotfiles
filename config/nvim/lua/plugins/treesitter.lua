return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  lazy = false,
  build = ":TSUpdate",
  config = function()
    vim.api.nvim_create_autocmd("FileType", {
      pattern = { "*" },
      group = vim.api.nvim_create_augroup("vim-treesitter-start", {}),
      callback = function()
        -- syntax highlighting, provided by Neovim
        pcall(vim.treesitter.start)
        -- folds, provided by Neovim
        vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
        -- indentation, provided by nvim-treesitter
        vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end,
    })
  end
}