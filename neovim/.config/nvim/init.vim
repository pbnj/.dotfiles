nnoremap <silent><nowait><space> <nop>
let g:mapleader = ' '
let g:maplocalleader = ' '

" Plugins

" Filter quickfix list. See :h :Cfilter
packadd! cfilter

" Editorconfig. See :h editorconfig
let g:editorconfig = v:false

" Download plug.vim if it doesn't exist yet
let data_dir = has('nvim') ? stdpath('data') . '/site' : '~/.vim'
if empty(glob(data_dir . '/autoload/plug.vim'))
  silent execute '!curl -fLo '.data_dir.'/autoload/plug.vim --create-dirs  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
endif

call plug#begin()

" misc
Plug 'https://github.com/airblade/vim-rooter'
Plug 'https://github.com/dstein64/vim-startuptime', { 'on': ['StartupTime'] }
Plug 'https://github.com/nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}

" tpope plugins
Plug 'https://github.com/tpope/vim-dadbod', { 'on': ['DB'] }
Plug 'https://github.com/tpope/vim-endwise'
Plug 'https://github.com/tpope/vim-eunuch'
Plug 'https://github.com/tpope/vim-fugitive'
Plug 'https://github.com/tpope/vim-rhubarb'
Plug 'https://github.com/tpope/vim-rsi'
Plug 'https://github.com/tpope/vim-sleuth'
Plug 'https://github.com/tpope/vim-surround'
Plug 'https://github.com/tpope/vim-unimpaired'

" junegunn plugins
Plug 'https://github.com/junegunn/fzf', { 'dir': '~/.fzf', 'do': { -> fzf#install() } }
Plug 'https://github.com/junegunn/fzf.vim'

Plug 'https://github.com/folke/tokyonight.nvim'

call plug#end()

filetype plugin indent on
syntax on

" Options
let &autoindent = 1
let &autoread = 1
let &backspace = 'indent,eol,start'
let &belloff = 'all'
let &breakindent = 1
let &clipboard = 'unnamedplus'
let &complete = '.,w,b,u,t'
let &completeopt = 'menuone'
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
let &number = 1
let &pumheight = 50
let &ruler = 0
let &scrolloff = 0
let &shortmess = 'filnxtocTOCI'
let &showmode = 1
let &signcolumn = 'number'
let &smartcase = 1
let &smarttab = 1
let &statusline = ' %f:%l:%c %m%r%h%w%q%y %{FugitiveStatusline()}'
let &swapfile = 0
let &ttimeout = 1
let &ttimeoutlen = 50
let &ttyfast = 1
let &undofile = 1
let &wildignorecase = 1
let &wildmenu = 1
let &wrap = 0

" disable syntax if file is larger than 10MB (performance improvement)
augroup LARGEFILE
  autocmd!
  autocmd BufReadPost * if line2byte(line("$") + 1) > 1000000 | syntax clear | echo 'Syntax disabled on large files' | endif
augroup END

" automatically re-balance window sizes
augroup RESIZE
  autocmd!
  autocmd VimResized * wincmd =
augroup END

" Neovim
augroup TERMINAL
  autocmd!
  autocmd TermOpen * startinsert | setlocal nonumber
  autocmd TermClose * stopinser  | setlocal number
augroup END

augroup YANK
  autocmd!
  autocmd TextYankPost * silent! lua vim.highlight.on_yank {higroup='Visual', timeout=300}
augroup END

" Mappings
cnoremap <c-n> <c-Down>
cnoremap <c-p> <c-Up>
nnoremap j gj
nnoremap k gk

" Abbreviations
inoreabbrev isod <c-r>=strftime('%Y-%m-%d')<cr>
inoreabbrev isodt <c-r>=strftime('%Y-%m-%dT%H:%M:%S')<cr>
inoreabbrev teh the

colorscheme tokyonight-night
