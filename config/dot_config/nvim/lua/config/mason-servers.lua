-- 事前installするLSP serverの一覧 (lspconfig名)
-- plugins/mason.lua (起動時の自動install) と config/mason-preinstall.lua (headlessでの事前install) の両方から参照される
-- シェルやpre-commitでも使うtoolはmiseで入れ、ここには書かない (config/mise-servers.lua)
return {
  "copilot",
  "lua_ls",
}
