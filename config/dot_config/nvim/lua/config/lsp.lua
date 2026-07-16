vim.lsp.config("lua_ls", {
  settings = {
    Lua = {
      diagnostics = {
        globals = { "vim" },
      },
    },
  },
})

-- 言語サーバーがアタッチされた時に呼ばれる
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("my.lsp", {}),
  callback = function(args)
    local client = assert(vim.lsp.get_client_by_id(args.data.client_id))
    local buf = args.buf

    -- デフォルトで設定されている言語サーバー用キーバインドに設定を追加する
    -- See https://neovim.io/doc/user/lsp.html#lsp-defaults
    -- 言語サーバーのクライアントがLSPで定められた機能を実装していたら設定を追加するという流れ

    if client:supports_method("textDocument/definition") then
      vim.keymap.set("n", "gd", vim.lsp.buf.definition, { buffer = buf, desc = "Go to definition" })
    end

    if client:supports_method("textDocument/hover") then
      vim.keymap.set("n", "<leader>k",
        function() vim.lsp.buf.hover({ border = "single" }) end,
        { buffer = buf, desc = "Show hover documentation" })
    end

    -- Copilot等のinline completion (ghost text)
    -- ポップアップ補完はblink.cmpが担うため vim.lsp.completion は有効化しない
    if client:supports_method("textDocument/inlineCompletion") then
      vim.lsp.inline_completion.enable(true, { bufnr = buf })
      vim.keymap.set("i", "<Tab>", function()
        if vim.lsp.inline_completion.get() then
          return
        end
        if require("blink.cmp").snippet_forward() then
          return
        end
        return "<Tab>"
      end, { buffer = buf, expr = true, desc = "Accept inline completion" })
    end
  end,
})
