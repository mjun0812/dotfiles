return {
    "folke/snacks.nvim",
    lazy = false,
    opts = {
        indent = {
            enabled = true,
            animate = {
                enabled = false,
            },
        },
        terminal = { enabled = true },
        win = { enabled = true },
        words = { enabled = true },
    },
    config = function(_, opts)
        local Snacks = require("snacks")
        Snacks.setup(opts)

        -- maximize current window toggle
        Snacks.toggle.zoom():map("<leader>wm")

        vim.keymap.set({ "n", "t" }, "<C-`>", function()
            Snacks.terminal(nil, {
                -- bottom と float を別IDにしたいので env で分ける
                -- terminal id は cmd/cwd/env/vim.v.count1 から決まる
                env = { SNACKS_TERM = "bottom" },
                win = {
                    position = "bottom",
                    height = 0.25,
                },
            })
        end, { silent = true, desc = "Terminal (bottom)" })

        vim.keymap.set({ "n", "t" }, "<M-`>", function()
            Snacks.terminal(nil, {
                env = { SNACKS_TERM = "float" },
                win = {
                    position = "float",
                    width = 0.9,
                    height = 0.9,
                    backdrop = 60,
                },
            })
        end, { silent = true, desc = "Terminal (float)" })
    end,
}
