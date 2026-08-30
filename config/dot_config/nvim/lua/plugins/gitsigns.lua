return {
  "lewis6991/gitsigns.nvim",
  event = "BufRead",
  opts = {
    on_attach = function(bufnr)
      local profile = vim.env.NVIM_NOTEBOOK or "none"
      local filename = vim.api.nvim_buf_get_name(bufnr)

      if (profile == "molten" or profile == "all") and filename:match("%.ipynb$") then
        return false
      end
    end,
  },
}
