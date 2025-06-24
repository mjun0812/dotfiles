return {
    'lambdalisue/fern.vim',
    dependencies = {
      'lambdalisue/fern-git-status.vim',
      'lambdalisue/nerdfont.vim',
      'lambdalisue/fern-renderer-nerdfont.vim',
    },
    config = function()
      -- # はLuaのコメント文字なので、Vim scriptの変数を設定する際は[]で囲む
      vim.g['fern#renderer'] = 'nerdfont'
      vim.g['fern#default_hidden'] = 1

      -- <C-e>でFernを開く
      vim.keymap.set('n', '<C-e>', ':Fern . -reveal=% -drawer -toggle<CR>', { silent = true, noremap = true })

      -- FernのバッファでVを押したら縦分割でファイルを開く
      vim.api.nvim_create_autocmd('FileType', {
        pattern = 'fern',
        callback = function()
          vim.keymap.set('n', 'V', '<Plug>(fern-action-open:split)', { buffer = true, noremap = true })
        end,
      })
    end
}