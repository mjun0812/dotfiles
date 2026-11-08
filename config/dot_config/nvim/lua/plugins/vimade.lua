return {
  "tadaa/vimade",
  opts = {
    recipe = { "default", { animate = true } },
    fadelevel = 0.5,
    blocklist = {
      -- デフォルトは非アクティブなfloatを全て除外する。
      -- snacks explorerのツリーはfloatなので、これだけfade対象に含める
      block_inactive_floats = function(win, active)
        if vim.bo[win.bufnr].filetype == "snacks_picker_list" then
          return false
        end
        return win.win_config.relative ~= "" and (win ~= active or win.buf_opts.buftype == "terminal") and true or false
      end,
    },
  },
}
