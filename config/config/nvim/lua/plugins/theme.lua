return {
    {
        "folke/tokyonight.nvim",
        lazy = false,
        priority = 1000,
        opts = {},
    },
    {
        'navarasu/onedark.nvim',
        config = function()
          vim.g.onedark_config = { style = 'darker' }
        end
    },
}