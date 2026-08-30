return {
  "windwp/nvim-autopairs",
  event = "InsertEnter",
  opts = {
    -- treesitter の node で pair を足さない場所を判定する
    -- (既定の ts_config: lua の string、javascript の template_string)
    check_ts = true,
  },
}
