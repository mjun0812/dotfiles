require('config.lazy')
require('config.lsp')

vim.cmd [[colorscheme tokyonight-night]]

local opt = vim.opt

opt.encoding = 'utf-8'
opt.fileencodings = { 'utf-8', 'cp932' }

-- menuoneで、対象が1件しかなくても常に補完ウィンドウを表示
-- noinsertで補完ウィンドウを表示時に挿入しない
opt.completeopt = { 'menuone', 'noinsert' }

-- カーソル行をハイライト
opt.cursorline = true
-- True Colorを有効化
opt.termguicolors = true
-- 行番号を表示
opt.number = true
-- サインカラムを常に表示（LSPエラー等で画面が動かないように）
opt.signcolumn = 'yes'

-- 行末でのカーソル移動
opt.whichwrap:append('<,>,[,],h,l,b,s')
-- バックスペースで削除できる範囲を設定
opt.backspace = { 'start', 'eol', 'indent' }

-- マウスを有効化
opt.mouse = 'a'
-- OSのクリップボードとの連携
opt.clipboard = "unnamedplus"

-- ステータスラインを常に表示 (globalstatus)
-- Splitした時にステータスバーはSplitしないようにする
opt.laststatus = 3
-- モード表示を無効化 (lightline/lualineのため)
opt.showmode = false

-- ######## インデント ########
-- タブをスペースに展開
opt.expandtab = true
-- スマートインデント
opt.smartindent = true
-- 自動インデントの幅
opt.shiftwidth = 4
-- タブキーで挿入されるスペースの数
opt.softtabstop = 4

-- ######## Backup ########
-- バックアップ、スワップファイルを作成しない
opt.backup = false
opt.writebackup = false
opt.swapfile = false

-- ######## 検索 ########
-- 検索結果をハイライト
opt.hlsearch = true
-- 大文字無視
opt.ignorecase = true
-- 大文字で検索したら区別をつける
opt.smartcase = true
-- 検索が末尾までいったら先頭から検索
opt.wrapscan = true

-- カーソル位置を記憶
vim.api.nvim_create_autocmd('BufReadPost', {
    pattern = '*',
    callback = function()
        local line = vim.fn.line("'\"")
        if line > 0 and line <= vim.fn.line('$') then
            vim.cmd("normal! g'\"")
        end
    end,
})

-- ########## Terminal ########
-- ターミナルモードで <Esc> を押したらノーマルモードに戻る
vim.keymap.set('t', '<Esc>', [[<C-\><C-n>]], { noremap = true, silent = true })

-- :T コマンドで水平分割＋下部に高さ20行のターミナルを開く
vim.api.nvim_create_user_command('T', function(opts)
    vim.cmd('split')
    vim.cmd('wincmd j')
    vim.cmd('resize 20')
    vim.cmd('terminal ' .. opts.args)
end, { nargs = '*' })

-- ターミナルが開いたら自動でインサートモードに入る
vim.api.nvim_create_autocmd('TermOpen', {
    pattern = '*',
    command = 'startinsert',
})

-- ########## Keys ########
-- Resize window using <ctrl> arrow keys
vim.keymap.set("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "Increase Window Height" })
vim.keymap.set("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = "Decrease Window Height" })
vim.keymap.set("n", "<C-Left>", "<cmd>vertical resize -2<cr>", { desc = "Decrease Window Width" })
vim.keymap.set("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Increase Window Width" })
