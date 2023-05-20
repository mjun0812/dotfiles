"dein Scripts-----------------------------
" Install Dein
let $CACHE = expand('~/.cache')
if !isdirectory($CACHE)
  call mkdir($CACHE, 'p')
endif
if &runtimepath !~# '/dein.vim'
  let s:dein_dir = fnamemodify('dein.vim', ':p')
  if !isdirectory(s:dein_dir)
    let s:dein_dir = $CACHE . '/dein/repos/github.com/Shougo/dein.vim'
    if !isdirectory(s:dein_dir)
      execute '!git clone https://github.com/Shougo/dein.vim' s:dein_dir
    endif
  endif
  execute 'set runtimepath^=' . substitute(
        \ fnamemodify(s:dein_dir, ':p') , '[/\\]$', '', '')
endif

set nocompatible

" Set dein base path (required)
let s:dein_base = '~/.cache/dein/'

" Set dein source path (required)
let s:dein_src = '~/.cache/dein/repos/github.com/Shougo/dein.vim'

" Set dein runtime path (required)
execute 'set runtimepath+=' . s:dein_src

if dein#load_state('~/.cache/dein')
  call dein#begin(s:dein_base)
  call dein#add(s:dein_src)

  " Add or remove your plugins here like this:

  " themes
  "call dein#add('rakr/vim-one')
  call dein#add('navarasu/onedark.nvim')
  
  " status bar
  "call dein#add('vim-airline/vim-airline')
  call dein#add('itchyny/lightline.vim') 
  
  " syntax
  "call dein#add('vim-python/python-syntax')
  call dein#add('sheerun/vim-polyglot')
  call dein#add('nvim-treesitter/nvim-treesitter', {'hook_post_update': 'TSUpdate'})
  
  " 補完
  call dein#add('neoclide/coc.nvim', { 'merged': 0, 'rev': 'release' })

  " file tree
  call dein#add('lambdalisue/fern.vim')
  call dein#add('lambdalisue/fern-git-status.vim')
  call dein#add('lambdalisue/nerdfont.vim')
  call dein#add('lambdalisue/fern-renderer-nerdfont.vim')
  
  "markdown preview
  call dein#add('iamcco/markdown-preview.nvim', 
              \ {'on_ft': ['markdown', 'pandoc.markdown', 'rmd'], 
              \ 'build': 'sh -c "cd app && yarn install"' })

  " Required:
  call dein#end()
  call dein#save_state()
endif

" Attempt to determine the type of a file based on its name and possibly its
" contents. Use this to allow intelligent auto-indenting for each filetype,
" and for plugins that are filetype specific.
if has('filetype')
  filetype indent plugin on
endif
" Enable syntax highlighting
if has('syntax')
  syntax on
  syntax enable
endif

" If you want to install not installed plugins on startup.
if dein#check_install()
  call dein#install()
endif

" check dein deleted plugin
if len(dein#check_clean()) != 0
  call map(dein#check_clean(), "delete(v:val, 'rf')")
endif

"End dein Scripts-------------------------

set encoding=UTF-8

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

"set background=dark
"colorscheme one
"let g:airline_theme='one'
"
let g:onedark_config = {
    \ 'style': 'darker',
\}
colorscheme onedark
let g:airline_theme='onedark'

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

" 新規タブでターミナルモードを起動
" nnoremap <silent> tt <cmd>terminal<CR>
" 下分割でターミナルモードを起動
" nnoremap <silent> tx <cmd>belowright new<CR><cmd>terminal<CR>

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
  ensure_installed = { "c", "markdown", "lua", "markdown_inline", "python" },

  -- Install parsers synchronously (only applied to `ensure_installed`)
  sync_install = true,

  -- Automatically install missing parsers when entering buffer
  -- Recommendation: set to false if you don't have `tree-sitter` CLI installed locally
  auto_install = true,

  highlight = {
      enable = true,
  }
}
EOF

" Splitした時にステータスバーはSplitしない
set laststatus=3

" coc.nvim config
source ~/.config/nvim/coc.rc.vim


