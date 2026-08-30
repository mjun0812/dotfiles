return {
  {
    "mason-org/mason.nvim",
    build = ":MasonUpdate",
    cmd = { "Mason", "MasonUpdate", "MasonLog", "MasonInstall", "MasonUninstall", "MasonUninstallAll" },
    config = function()
      -- ~/.npmrc の min-release-age=7 はmasonがpinする新しいLSP server
      -- (copilot-language-server等) のinstallをブロックするため、mason経由のnpm installでは無効化する
      vim.env.npm_config_min_release_age = "0"
      require("mason").setup()
    end,
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
      ensure_installed = require("config.mason-servers"),
    },
    keys = {
      { "gh", "<cmd>lua vim.lsp.buf.hover()       <CR>" },
      { "gD", "<cmd>lua vim.lsp.buf.declaration() <CR>" },
    },
  },
}
