return {
    'neoclide/coc.nvim',
    branch = 'release',
    config = function()
      -- coc.nvimに関する設定は、元のcoc.rc.vimを読み込む形で維持
      vim.cmd('source ~/.config/nvim/coc.rc.vim')
    end
}