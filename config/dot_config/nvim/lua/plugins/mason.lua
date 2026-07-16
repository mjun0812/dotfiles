return {
    {
        "mason-org/mason.nvim",
        build = ":MasonUpdate",
        cmd = { "Mason", "MasonUpdate", "MasonLog", "MasonInstall", "MasonUninstall", "MasonUninstallAll" },
        config = true,
    },
    {
        "mason-org/mason-lspconfig.nvim",
        dependencies = {
            { "mason-org/mason.nvim" },
            { "neovim/nvim-lspconfig" },
        },
        event = { "BufReadPre", "BufNewFile" },
        config = true,
        opts = {
            ensure_installed = { "copilot", "lua_ls", "ruff", "ty", "oxfmt", "taplo" },
        },
        keys = {
            { "gh", "<cmd>lua vim.lsp.buf.hover()       <CR>" },
            { "gD", "<cmd>lua vim.lsp.buf.declaration() <CR>" },
        },
    },
}
