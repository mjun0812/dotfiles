return {
    "folke/snacks.nvim",
    ---@type snacks.Config
    opts = {
        indent = {
            enabled = true,
            animate = {
                enabled = false,
            },
        },
        win = { enabled = true },
        words = { enabled = true },
    },
    config = function()
        local Snacks = require("snacks")
        Snacks.toggle.zoom():map("<leader>wm")
    end,
}
