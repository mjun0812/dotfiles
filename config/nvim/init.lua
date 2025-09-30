-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Make sure to setup `mapleader` and `maplocalleader` before
-- loading lazy.nvim so that mappings are correct.
-- This is also a good place to setup other settings (vim.opt)
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Setup lazy.nvim
require("lazy").setup({
  spec = {
    { import = "plugins.theme" },
    { import = "plugins.treesitter" },
    { import = "plugins.telescope" },
    { import = "plugins.fern" },
    { import = "plugins.lualine" },
    { import = "plugins.coc" },
    { import = "plugins.copilot" },
  },
  -- Configure any other settings here. See the documentation for more details.
  -- colorscheme that will be used when installing plugins.
  install = { colorscheme = { "tokyonight-night" } },
  -- automatically check for plugin updates
  checker = { enabled = true, notify = false },
})

vim.cmd[[colorscheme tokyonight-night]]

local opt = vim.opt

opt.encoding = 'utf-8'
opt.fileencodings = {'utf-8', 'cp932'}

-- menuoneで、対象が1件しかなくても常に補完ウィンドウを表示
-- noinsertで補完ウィンドウを表示時に挿入しない
opt.completeopt = {'menuone', 'noinsert'}

-- カーソル行をハイライト
opt.cursorline = true
-- True Colorを有効化
opt.termguicolors = true
-- 行番号を表示
opt.number = true

-- 行末でのカーソル移動
opt.whichwrap:append('<,>,[,],h,l,b,s')
-- バックスペースで削除できる範囲を設定
opt.backspace = {'start', 'eol', 'indent'}

-- マウスを有効化
opt.mouse = 'a'
-- OSのクリップボードとの連携
opt.clipboard:append({unnamedeplus = true})

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
