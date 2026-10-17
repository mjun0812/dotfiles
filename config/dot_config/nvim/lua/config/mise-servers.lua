-- miseで入れたtoolを起動するLSP serverの一覧 (lspconfig名。実行ファイル名と同じ)
-- masonで入れるとnvimの中だけmason版が使われ、シェルやpre-commitとバージョンがずれるため、miseに揃える
-- config/lsp.lua (有効化) と script/ci/check_nvim.lua (CIでの存在確認) の両方から参照される
return {
  "oxfmt",
  "ruff",
  "taplo",
  "ty",
}
