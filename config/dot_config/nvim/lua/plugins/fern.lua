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
      -- 隠しファイルを表示
      vim.g['fern#default_hidden'] = true
      -- カーソルを非表示
      vim.g['fern#hide_cursor'] = true

      -- <C-e>でFernを開く
      vim.keymap.set(
          'n',
          '<C-e>',
          ':Fern . -reveal=% -drawer -toggle<CR>',
          { silent = true, noremap = true }
      )

      vim.api.nvim_create_autocmd('FileType', {
        pattern = 'fern',
        callback = function()
          -- Fernのバッファでrを押したら再読み込み
          vim.keymap.set(
              'n',
              'r',
              '<Plug>(fern-action-reload)',
              { buffer = true, remap = true, desc = 'Reload Fern' }
          )

          -- FernのバッファでVを押したら縦分割でファイルを開く
          vim.keymap.set(
              'n',
              'V',
              '<Plug>(fern-action-open:split)',
              { buffer = true, noremap = true }
          )

          -- 相対と絶対の両方の行番号をオフにする
          vim.opt_local.relativenumber = false
          vim.opt_local.number = false
          vim.opt_local.signcolumn = 'no'
          vim.opt_local.foldcolumn = "0"

        end,
      })

      vim.api.nvim_create_autocmd('FocusGained', {
        group = vim.api.nvim_create_augroup('my.fern', {}),
        callback = function()
          vim.cmd([[FernDo normal <F5> -drawer -stay]])
        end,
      })
    end
}
