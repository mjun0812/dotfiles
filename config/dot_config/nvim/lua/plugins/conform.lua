return {
    {
        "stevearc/conform.nvim",
        event = { "BufWritePre" },
        opts = {
            formatters_by_ft = {
                bash = { "shfmt" },
                css = { "oxfmt" },
                html = { "oxfmt" },
                javascript = { "oxfmt" },
                javascriptreact = { "oxfmt" },
                json = { "oxfmt" },
                jsonc = { "oxfmt" },
                lua = { "stylua" },
                markdown = { "oxfmt" },
                python = { "ruff_format" },
                scss = { "oxfmt" },
                sh = { "shfmt" },
                toml = { "taplo" },
                typescript = { "oxfmt" },
                typescriptreact = { "oxfmt" },
                yaml = { "oxfmt" },
            },
            format_on_save = {
                lsp_format = "fallback",
                timeout_ms = 1000,
            },
        },
    },
}
