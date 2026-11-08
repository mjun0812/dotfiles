return {
  "windwp/nvim-autopairs",
  event = "InsertEnter",
  opts = {
    -- treesitterのnodeでpairを足さない場所を判定する
    -- (既定のts_config: luaのstring、javascriptのtemplate_string)
    check_ts = true,
  },
}
