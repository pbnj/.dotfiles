" vim:ts=2:sts=2:sw=2:et:
nnoremap <silent><nowait><space> <nop>
let g:mapleader = ' '

" plugins
packadd cfilter
let g:netrw_keepdir = 0
let g:netrw_altfile = 0

if filereadable(glob('~/.vim/work.vim'))
  source ~/.vim/work.vim
endif

let g:ale_completion_enabled = 1
let g:ale_lint_on_text_changed = 1
let g:ale_fix_on_save = 1
let g:ale_fixers = {'*': ['remove_trailing_lines', 'trim_whitespace']}
let g:ale_floating_preview = 1
let g:ale_hover_cursor = 0
let g:ale_sign_error = 'x'
let g:ale_sign_info = 'i'
let g:ale_sign_style_error = 'x'
let g:ale_sign_style_warning = '!'
let g:ale_sign_warning = '!'

nnoremap <leader>K <cmd>ALEHover<cr>

let g:signify_sign_add = '│'
let g:signify_sign_delete = '│'
let g:signify_sign_delete_first_line = '│'
let g:signify_sign_change = '│'
let g:signify_sign_change_delete = g:signify_sign_change

let g:fzf_layout = {'down': '40%'}

call plug#begin()
Plug 'https://github.com/christoomey/vim-tmux-navigator'
Plug 'https://github.com/dense-analysis/ale'
Plug 'https://github.com/editorconfig/editorconfig-vim'
Plug 'https://github.com/junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'https://github.com/junegunn/fzf.vim'
Plug 'https://github.com/ludovicchabant/vim-gutentags'
Plug 'https://github.com/machakann/vim-highlightedyank'
Plug 'https://github.com/mhinz/vim-signify'
Plug 'https://github.com/pbnj/pbnj.vim'
Plug 'https://github.com/sheerun/vim-polyglot'
Plug 'https://github.com/tpope/vim-commentary'
Plug 'https://github.com/tpope/vim-eunuch'
Plug 'https://github.com/tpope/vim-fugitive'
Plug 'https://github.com/tpope/vim-rsi'
Plug 'https://github.com/tpope/vim-surround'
Plug 'https://github.com/tpope/vim-unimpaired'
Plug 'https://github.com/tpope/vim-vinegar'
call plug#end()

" language servers, linters, fixers
  " bash-language-server
  " commitlint
  " dockerfile-language-server
  " goimports
  " golangci-lint
  " golangci-lint-langserver
  " gopls
  " gotests
  " hadolint
  " json-lsp
  " jsonlint
  " markdownlint
  " prettier
  " rust-analyzer
  " rustfmt
  " shellcheck
  " shfmt
  " terraform-ls
  " tflint
  " yaml-language-server
  " yamllint

filetype plugin indent on

" options

if system("defaults read -g AppleInterfaceStyle") =~ '^Dark'
  set background=dark
else
  set background=light
endif

colorscheme pbnj

if !isdirectory(expand('~/.vim/undo/'))
  mkdir(expand('~/.vim/undo/'))
endif

if has('nvim')
  set inccommand=split
  set termguicolors
else
  set ttyfast
  set undodir=~/.vim/undo/
endif

set autoindent
set autoread
set backspace=indent,eol,start
set breakindent
set clipboard=unnamed,unnamedplus
set completeopt=menuone,longest,noinsert
set encoding=utf-8
set fillchars=vert:\│,fold:-,eob:~
set formatoptions=tcqjno
set hidden
set hlsearch
set ignorecase
set incsearch
set infercase
set laststatus=2
set lazyredraw
set linebreak
set list
set listchars=tab:\│\ ,trail:·
set modeline
set mouse=a
set nobackup
set norelativenumber
set noswapfile
set nowrap
set number
set omnifunc=ale#completion#OmniFunc
set ruler
set secure
set shortmess=filnxtToOc
set showmode
set smartcase
set smarttab
set statusline=%f\ %{FugitiveStatusline()}\ %m%r%h%w%y%q\ %-3l,%-3c\ %P
set ttimeout
set ttimeoutlen=50
set undofile
set updatetime=100
set wildignore=*.o,*.obj,*.bin,*.dll,*.exe,*.DS_Store,*.pdf,*/.ssh/*,*.pub,*.crt,*.key,*/cache/*,*/dist/*,*/node_modules/*,*/tmp/*,*/vendor/*,*/__pycache__/*,*/build/*,*/.git/*
set wildignorecase
set wildmenu
set wildmode=longest:full,full
set wildoptions=pum

if executable('rg')
  let &grepprg = 'rg --vimgrep --hidden --smart-case'
else
  let &grepprg = 'grep -HI --line-number $* -r .'
endif

let &errorformat='%f|%l| %m,%f:%l:%m,%f:%l:%c:%m'

" GitBrowse takes a dictionary and opens files on remote git repo websites.
function! GitBrowse(args) abort
  if a:args.filename ==# ''
    return
  endif
  let l:remote = trim(system('git config branch.'.a:args.branch.'.remote || echo "origin" '))
  if a:args.range == 0
    let l:cmd = 'git browse ' . l:remote . ' ' . a:args.filename
  else
    let l:cmd = 'git browse ' . l:remote . ' ' . a:args.filename . ' ' . a:args.line1 . ' ' . a:args.line2
  endif
  execute 'silent ! ' . l:cmd | redraw!
endfunction
command! -range GB call GitBrowse({
      \ 'branch': trim(system('git rev-parse --abbrev-ref HEAD 2>/dev/null')),
      \ 'filename': trim(system('git ls-files --full-name ' . expand('%'))),
      \ 'range': <range>,
      \ 'line1': <line1>,
      \ 'line2': <line2>,
      \ })

command! -nargs=* Gpull Git! pull <args>
command! -nargs=* Gpush Git! push <args>
command! Gcommit Git commit
command! Groot execute 'lcd ' . finddir('.git/..', expand('%:p:h').';')
command! Gstatus Git! status %:h

function! Terminal(...) abort
  if has('nvim')
    if a:0 >= 1
      new
      call termopen(split(&shell) + split(&shellcmdflag) + [join(a:000,' ')], {'cwd': expand('%:p:h')})
    else
      new
      call termopen(split(&shell), {'cwd': expand('%:p:h')})
    endif
  else
    if a:0 >= 1
      call term_start(split(&shell) + split(&shellcmdflag) + [join(a:000,' ')], {'cwd': expand('%:p:h')})
    else
      call term_start(split(&shell), {'cwd': expand('%:p:h')})
    endif
  endif
endfunction
command! -nargs=* -complete=shellcmd Terminal call Terminal(<f-args>)

function! MakeCompletion(A,L,P) abort
    let l:targets = systemlist('make -qp | awk -F'':'' ''/^[a-zA-Z0-9][^$#\/\t=]*:([^=]|$)/ {split($1,A,/ /);for(i in A)print A[i]}'' | grep -v Makefile | sort -u')
    return filter(l:targets, 'v:val =~ "^' . a:A . '"')
endfunction
command! -nargs=* -complete=customlist,MakeCompletion Make terminal make <args>
nnoremap m<space> :Make<space><c-d>

nnoremap <leader>bb <cmd>Buffers<cr>
nnoremap <leader>bd <cmd>bd!<cr>
nnoremap <leader>cd <cmd>lcd %:p:h<cr>
nnoremap <leader>ee :ed **/*
nnoremap <leader>es :sp **/*
nnoremap <leader>ev :vs **/*
nnoremap <leader>ff <cmd>Files!<cr>
nnoremap <leader>fg <cmd>GFiles!<cr>
nnoremap <leader>fG <cmd>GFiles!?<cr>
nnoremap <leader>fs <cmd>Rg!<cr>
nnoremap <leader>fl <cmd>Lines!<cr>
nnoremap <leader>fb <cmd>Buffers<cr>
nnoremap <leader>gd <cmd>ALEGoToDefinition<cr>
nnoremap <leader>gg <cmd>Git<cr>
nnoremap <leader>gK <cmd>ALEDocumentation<cr>
nnoremap <leader>gk <cmd>ALEHover<cr>
nnoremap <leader>gm <cmd>ALEGoToImplementation<cr>
nnoremap <leader>gq mzgggqG`z
nnoremap <leader>gr <cmd>ALEFindReferences<cr>
nnoremap <leader>gy <cmd>ALEGoToTypeDefinition<cr>
nnoremap <leader>tt :terminal<space>
nnoremap <leader>w <cmd>write<cr>
nnoremap <leader>ya <cmd>%y+<cr>
nnoremap C "_C
nnoremap c "_c
nnoremap cc "_cc
nnoremap x "_x
nnoremap Y y$
tnoremap <esc> <c-\><c-n>
tnoremap <s-space> <space>

if has('gui_running') || exists('g:neovide')
  let g:neovide_input_use_logo=v:true
  vnoremap <D-c> "+y
  nnoremap <D-v> "+p
  inoremap <D-v> <Esc>"+pa
  cnoremap <D-v> <c-r>+
  tnoremap <D-v> <C-\><C-n>"+pa
  set guioptions+=k
  set guioptions-=L
  set guioptions-=l
  set guioptions-=R
  set guioptions-=r
endif
