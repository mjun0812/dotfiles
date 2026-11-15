return {
  {
    "neovim/nvim-lspconfig",
    lazy = false,
    keys = {
      { "gh", "<cmd>lua vim.lsp.buf.hover()       <CR>" },
      { "gD", "<cmd>lua vim.lsp.buf.declaration() <CR>" },
    },
  },
}
