" Install VimPlug if nothing
let data_dir = has('nvim') ? stdpath('data') . '/site' : '~/.vim'
if empty(glob(data_dir . '/autoload/plug.vim'))
  silent execute '!curl -fLo '.data_dir.'/autoload/plug.vim --create-dirs  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
endif

" Run PlugInstall if there are missing plugins
autocmd VimEnter * if len(filter(values(g:plugs), '!isdirectory(v:val.dir)'))
  \| PlugInstall --sync | source $MYVIMRC
\| endif

call plug#begin()
  " themes
  Plug 'navarasu/onedark.nvim'
  
  " status bar
  Plug 'itchyny/lightline.vim'
  
  " syntax
  Plug 'sheerun/vim-polyglot'
  Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
  
  " 補完
  Plug 'neoclide/coc.nvim', {'branch': 'release'}
  "Plug 'cohama/lexima.vim'

  " file tree
  Plug 'lambdalisue/fern.vim'
  Plug 'lambdalisue/fern-git-status.vim'
  Plug 'lambdalisue/nerdfont.vim'
  Plug 'lambdalisue/fern-renderer-nerdfont.vim'

  " Top Tab
  " OPTIONAL: for file icons
  Plug 'nvim-tree/nvim-web-devicons' 
  " OPTIONAL: for git status
  Plug 'lewis6991/gitsigns.nvim'
  Plug 'romgrk/barbar.nvim'

  " Search
  Plug 'nvim-lua/plenary.nvim'
  Plug 'nvim-telescope/telescope.nvim', { 'tag': '0.1.8' }

call plug#end()

set nocompatible
set encoding=UTF-8

" Enable syntax highlighting
if has('syntax')
  syntax on
  syntax enable
endif

" menuoneで、対象が1件しかなくても常に補完ウィンドウを表示
" noinsertで補完ウィンドウを表示時に挿入しない
set completeopt=menuone,noinsert

" 行を強調表示
set cursorline

" theme
if (has("nvim"))
  let $NVIM_TUI_ENABLE_TRUE_COLOR=1
endif
set termguicolors
let g:onedark_config = {
    \ 'style': 'darker',
\}
colorscheme onedark

" 行番号
set number

" タブ文字をスペースに
set expandtab

" プログラミング言語に合わせて適切にインデントを自動挿入(切り替え)
set smartindent

" 各コマンドやsmartindentで挿入する空白の量(数値)
set shiftwidth=4

" Tabキーで挿入するスペースの数(数値)
set softtabstop=4

" バッファ内で扱う文字コード(文字列)
set encoding=utf-8

" 書き込む文字コード(文字列) : この場合encodingと同じなので省略可
set fileencoding=utf-8

" 読み込む文字コード(文字列のリスト) : この場合UTF-8を試し、だめならShift_JIS
set fileencodings=utf-8,cp932

" 検索した文字をハイライトする
set hls

" マウスの利用
set mouse=a

" カーソルを行頭，行末で止まらないようにする
set whichwrap=b,s,h,l,<,>,[,]

" BSで削除できるものを指定する
"   indent  : 行頭の空白
"   eol     : 改行
"   start   : 挿入モード開始位置より手前の文字
set backspace=indent,eol,start

" yank した文字列をクリップボードにコピー
set clipboard+=unnamed

" ターミナルを開いたらに常にinsertモードに入る
autocmd TermOpen * :startinsert

" ターミナルモードで行番号を非表示
autocmd TermOpen * setlocal norelativenumber
autocmd TermOpen * setlocal nonumber

" Terminalのインサートモードからの離脱をESCにする
:tnoremap <Esc> <C-\><C-n>

" :Tコマンドで下にターミナルを表示する
command! -nargs=* T split | wincmd j | terminal <args>

" カーソル記憶
if has("autocmd")
  augroup redhat
    " In text files, always limit the width of text to 78 characters
    autocmd BufRead *.txt set tw=78
    " When editing a file, always jump to the last cursor position
    autocmd BufReadPost *
    \ if line("'\"") > 0 && line ("'\"") <= line("$") |
    \   exe "normal! g'\"" |
    \ endif
  augroup END
endif

" fern
let g:fern#renderer='nerdfont'
let g:fern#default_hidden=1
" Fern NERDTreeToggle
nnoremap <silent><C-e> :Fern . -reveal=% -drawer -toggle<CR>

function! s:init_fern() abort
    nmap <buffer> V <Plug>(fern-action-open:split)
endfunction
augroup fern-custom
  autocmd! *
  autocmd FileType fern call s:init_fern()
augroup END

lua <<EOF
require'nvim-treesitter.configs'.setup {
  -- A list of parser names, or "all"
  ensure_installed = { "c", "markdown", "lua", "markdown_inline", "python"},

  -- Install parsers synchronously (only applied to `ensure_installed`)
  sync_install = true,

  -- Automatically install missing parsers when entering buffer
  -- Recommendation: set to false if you don't have `tree-sitter` CLI installed locally
  auto_install = true,

  highlight = {
      enable = true,
      disable = { "latex" },
  }
}
EOF

" Splitした時にステータスバーはSplitしない
set laststatus=3

" ############### For barbar.nvim ###############
" Move to previous/next
nnoremap <silent>    <A-,> <Cmd>BufferPrevious<CR>
nnoremap <silent>    <A-.> <Cmd>BufferNext<CR>
" Re-order to previous/next
nnoremap <silent>    <A-<> <Cmd>BufferMovePrevious<CR>
nnoremap <silent>    <A->> <Cmd>BufferMoveNext<CR>
" Goto buffer in position...
nnoremap <silent>    <A-1> <Cmd>BufferGoto 1<CR>
nnoremap <silent>    <A-2> <Cmd>BufferGoto 2<CR>
nnoremap <silent>    <A-3> <Cmd>BufferGoto 3<CR>
nnoremap <silent>    <A-4> <Cmd>BufferGoto 4<CR>
nnoremap <silent>    <A-5> <Cmd>BufferGoto 5<CR>
nnoremap <silent>    <A-6> <Cmd>BufferGoto 6<CR>
nnoremap <silent>    <A-7> <Cmd>BufferGoto 7<CR>
nnoremap <silent>    <A-8> <Cmd>BufferGoto 8<CR>
nnoremap <silent>    <A-9> <Cmd>BufferGoto 9<CR>
nnoremap <silent>    <A-0> <Cmd>BufferLast<CR>
" Pin/unpin buffer
nnoremap <silent>    <A-p> <Cmd>BufferPin<CR>
" Close buffer
nnoremap <silent>    <A-c> <Cmd>BufferClose<CR>
" Restore buffer
nnoremap <silent>    <A-s-c> <Cmd>BufferRestore<CR>


" ############### For telescope.nvim ###############
nnoremap <leader>ff <cmd>Telescope find_files<cr>
nnoremap <C-p> <cmd>Telescope find_files<cr>
nnoremap <leader>fg <cmd>Telescope live_grep<cr>
nnoremap <C-g> <cmd>Telescope live_grep<cr>
nnoremap <leader>fb <cmd>Telescope buffers<cr>
nnoremap <leader>fh <cmd>Telescope help_tags<cr>

" coc.nvim config
source ~/.config/nvim/coc.rc.vim


