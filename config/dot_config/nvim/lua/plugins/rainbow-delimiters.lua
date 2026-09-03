return {
  -- 括弧をネストの深さごとに色分けする (treesitter parser がある filetype で自動的に有効)
  "HiPhish/rainbow-delimiters.nvim",
  -- submodule はテスト用 (.luals/addons, test/bin) のみ。Ubuntu 22.04 の git 2.34 では
  -- lazy.nvim の partial clone と組み合わさると submodule checkout に失敗するため取得しない
  submodules = false,
}
