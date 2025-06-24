return {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
        require('nvim-treesitter.configs').setup {
          sync_install = true,
          auto_install = true,
          highlight = { enable = true },
        }
    end,
}