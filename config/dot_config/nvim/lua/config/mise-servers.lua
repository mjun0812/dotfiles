-- miseで入れるLSP serverのlspconfig名と実行ファイル名
-- config/lsp.lua (有効化) とscript/ci/check_nvim.lua (CIでの存在確認) の両方から参照される
return {
  copilot = "copilot-language-server",
  lua_ls = "lua-language-server",
  oxfmt = "oxfmt",
  ruff = "ruff",
  taplo = "taplo",
  ty = "ty",
}
