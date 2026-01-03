return {
    'akinsho/toggleterm.nvim',
    version = "*",
    config = function()
        vim.opt.guicursor = "a:blinkon0"
        require("toggleterm").setup{
            open_mapping = [[<c-`>]],
            direction = 'horizontal',
        }
        -- <Alt + `>でFloatを開く
        vim.keymap.set(
            {'n', 't'},
            '<M-`>',
            '<cmd>ToggleTerm direction=float<cr>',
            { noremap = true, silent = true }
        )
    end
}
