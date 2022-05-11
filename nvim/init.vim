"dein Scripts-----------------------------
if &compatible
  set nocompatible               " Be iMproved
endif

" Required:
set runtimepath+=~/.cache/dein/repos/github.com/Shougo/dein.vim

" Required:
if dein#load_state('~/.cache/dein')
  call dein#begin('~/.cache/dein')

  " Let dein manage dein
  " Required:
  call dein#add('~/.cache/dein/repos/github.com/Shougo/dein.vim')
  
  " Add or remove your plugins here like this:
  
  " themes
  call dein#add('rakr/vim-one')
  
  " status bar
  call dein#add('vim-airline/vim-airline')
  
  " syntax
  "call dein#add('vim-python/python-syntax')
  call dein#add('sheerun/vim-polyglot')
  
  " 補完
  call dein#add('neoclide/coc.nvim', { 'merged': 0, 'rev': 'release' })

  " file tree
  call dein#add('lambdalisue/fern.vim')
  call dein#add('lambdalisue/fern-git-status.vim')
  call dein#add('lambdalisue/nerdfont.vim')
  call dein#add('lambdalisue/fern-renderer-nerdfont.vim')
  
  " 括弧補完
  call dein#add('cohama/lexima.vim')

  "() 色付け:
  call dein#add('itchyny/lightline.vim') 

  "markdown preview
  call dein#add('iamcco/markdown-preview.nvim', 
              \ {'on_ft': ['markdown', 'pandoc.markdown', 'rmd'], 
              \ 'build': 'sh -c "cd app && yarn install"' })

  " Required:
  call dein#end()
  call dein#save_state()
endif

" Required:
filetype plugin indent on
syntax enable

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
" 補完表示時のEnterで改行をしない
inoremap <expr><CR>  pumvisible() ? "<C-y>" : "<CR>"
" 補完で選択したものを即時に挿入しない
inoremap <expr><C-n> pumvisible() ? "<Down>" : "<C-n>"
inoremap <expr><C-p> pumvisible() ? "<Up>" : "<C-p>"

" 行を強調表示
set cursorline

" NERDTreeToggle
nnoremap <silent><C-e> :Fern . -reveal=% -drawer -toggle<CR>

" theme
if (has("nvim"))
  let $NVIM_TUI_ENABLE_TRUE_COLOR=1
endif
set termguicolors
set background=dark
colorscheme one
let g:airline_theme='one'

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

" カッコ保管のルール(lexima)
let g:lexima_enable_basic_rules=1

" vim-python
"let g:python_highlight_all=1

" fern
let g:fern#renderer='nerdfont'

" coc-pydocstring
nmap <silent> ga <Plug>(coc-codeaction-line)
xmap <silent> ga <Plug>(coc-codeaction-selected)
nmap <silent> gA <Plug>(coc-codeaction)

" coc.nvim config
source ~/.config/nvim/coc.rc.vim

