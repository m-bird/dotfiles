set number
syntax on
" 括弧の対応を確認
set showmatch

"
" - 検索設定
"
" インクリメンタル検索
set incsearch
" 検索で小文字大文字区別しない
set noignorecase
" 検索文字列が大文字含んでいたら、:set ignorecase(大文字小文字区別)
set smartcase
" 検索ハイライト削除
nmap <Esc><Esc> :noh<CR><Esc>

"
" - ファイラ設定
"
" 縦に分割、右に起動させる
if maparg('<C-W><C-V>', 'n') == ''
  map <C-W><C-V> :Vexplore!<CR>
endif
" 横にに分割、下に起動させる
if maparg('<C-W><C-H>', 'n') == ''
  map <C-W><C-H> :Hexplore!<CR>
endif

"
" - vim表示設定
"
" ルーラ表示オン(右下の行、列の番号表示)
set ruler
" カーソルライン表示
set cursorline
" 行数表示
set number
