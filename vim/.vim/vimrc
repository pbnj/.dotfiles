nnoremap <silent><nowait><space> <nop>
let g:mapleader = ' '
let g:maplocalleader = ' '

""""""""""""""""""""""""""""""""""""""""
" Built-in Plugins
""""""""""""""""""""""""""""""""""""""""

" vim-only plugins
runtime ftplugin/man.vim

" Filter quickfix list. See :h :Cfilter
packadd! cfilter

" enable built-in editorconfig
packadd! editorconfig

" tree view
let g:netrw_liststyle = 3
let g:netrw_keepdir = 0
let g:netrw_keepj = ""

""""""""""""""""""""""""""""""""""""""""
" External Pulgins
""""""""""""""""""""""""""""""""""""""""

" Download plug.vim if it doesn't exist yet
if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
        \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
endif

call plug#begin()

" misc
Plug 'https://github.com/airblade/vim-rooter'
Plug 'https://github.com/dstein64/vim-startuptime', { 'on': ['StartupTime'] }
Plug 'https://github.com/ervandew/supertab'
Plug 'https://github.com/junegunn/fzf', { 'dir': '~/.fzf', 'do': { -> fzf#install() } }
Plug 'https://github.com/junegunn/fzf.vim'
Plug 'https://github.com/machakann/vim-highlightedyank'
Plug 'https://github.com/markonm/traces.vim'
Plug 'https://github.com/sheerun/vim-polyglot'
Plug 'https://github.com/wellle/targets.vim'

" tpope plugins
Plug 'https://github.com/tpope/vim-commentary'
Plug 'https://github.com/tpope/vim-dadbod', { 'on': ['DB'] }
Plug 'https://github.com/tpope/vim-endwise'
Plug 'https://github.com/tpope/vim-eunuch'
Plug 'https://github.com/tpope/vim-fugitive'
Plug 'https://github.com/tpope/vim-rhubarb'
Plug 'https://github.com/tpope/vim-rsi'
Plug 'https://github.com/tpope/vim-sleuth'
Plug 'https://github.com/tpope/vim-surround'
Plug 'https://github.com/tpope/vim-unimpaired'

call plug#end()

filetype plugin indent on

""""""""""""""""""""""""""""""""""""""""
" Options
""""""""""""""""""""""""""""""""""""""""

let &autoindent = 1
let &autoread = 1
let &background = 'dark'
let &backspace = 'indent,eol,start'
let &belloff = 'all'
let &breakindent = 1
let &clipboard = 'unnamed'
let &complete = '.,w,b,u,t'
let &completeopt = 'menuone,longest,fuzzy'
let &cursorline = 0
let &expandtab = 1
let &fillchars = 'vert:│,fold:-,eob:~,lastline:@'
let &foldenable = 0
let &grepformat = '%f:%l:%c:%m,%f:%l:%m'
let &grepprg = executable('rg') ? 'rg --vimgrep --smart-case $*' : 'git grep $*'
let &hidden = 1
let &hlsearch = 1
let &ignorecase = 1
let &incsearch = 1
let &infercase = 1
let &iskeyword = '@,48-57,_,192-255,-,#'
let &laststatus = 2
let &lazyredraw = 1
let &list = 1
let &listchars = 'tab:│⋅,trail:⋅,nbsp:␣'
let &modeline = 1
let &modelines = 5
let &mouse = 'a'
let &number = 0
let &pumheight = 50
let &ruler = 0
let &scrolloff = 0
let &shortmess = 'filnxtocTOCI'
let &showmode = 1
let &signcolumn = 'no'
let &smartcase = 1
let &smarttab = 1
let &statusline = ' %f:%l:%c %m%r%h%w%q%y%{FugitiveStatusline()} '
let &swapfile = 0
let &ttimeout = 1
let &ttimeoutlen = 100
let &ttyfast = 1
let &undodir = expand('~/.vim/undo/')
let &undofile = 1
let &viminfofile = '$HOME/.vim/.viminfo'
let &wildignorecase = 1
let &wildmenu = 1
let &wildoptions = 'pum'
let &wrap = 0
let &wrapscan = 0

if &term =~# 'xterm'
  " change cursor shape from block to beam when in INSERT or REPLACE mode
  let &t_SI = "\e[6 q"
  let &t_SR = "\e[4 q"
  let &t_EI = "\e[2 q"
  " set terminal colors
  let &t_Co          = 256
  let &termguicolors = 0
endif

""""""""""""""""""""""""""""""""""""""""
" Mappings
""""""""""""""""""""""""""""""""""""""""

" General
cnoremap <C-N> <c-Down>
cnoremap <C-P> <c-Up>
inoremap <C-U> <C-G>u<C-U>
nnoremap j gj
nnoremap k gk

""""""""""""""""""""""""""""""""""""""""
" Abbreviations
""""""""""""""""""""""""""""""""""""""""

" date & time shortcuts
inoreabbrev isod <c-r>=strftime('%Y-%m-%d')<cr>
inoreabbrev isodt <c-r>=strftime('%Y-%m-%dT%H:%M:%S')<cr>
inoreabbrev teh the

""""""""""""""""""""""""""""""""""""""""
" Colors
""""""""""""""""""""""""""""""""""""""""

colorscheme pbnj
