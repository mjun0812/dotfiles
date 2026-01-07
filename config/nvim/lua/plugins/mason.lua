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
            ensure_installed = { "copilot-language-server", "lua_ls", "ruff", "ty" },
        },
        keys = {
            { "<C-space>", "<cmd>lua vim.lsp.completion.get()  <CR>", mode = "i" },
            { "gh",        "<cmd>lua vim.lsp.buf.hover()       <CR>" },
            { "gd",        "<cmd>lua vim.lsp.buf.definition()  <CR>" },
            { "gD",        "<cmd>lua vim.lsp.buf.declaration() <CR>" },
        },
    },
}
