" vim:ts=2:sts=2:sw=2:et:
nnoremap <silent><nowait><space> <nop>
let g:mapleader = ' '

"-------------------------------------------------------------------------------
" Plugins
"-------------------------------------------------------------------------------

" https://github.com/junegunn/vim-plug/wiki/tips
let data_dir = has('nvim') ? stdpath('data') . '/site' : '~/.vim'
if empty(glob(data_dir . '/autoload/plug.vim'))
  silent execute '!curl -fLo '.data_dir.'/autoload/plug.vim --create-dirs  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

" Enable built-in plugin to filter quickfix list. See :h :Cfilter
packadd cfilter

" vim-signify
let g:signify_sign_add               = '+'
let g:signify_sign_delete            = '-'
let g:signify_sign_delete_first_line = '-'
let g:signify_sign_change            = '•'
let g:signify_sign_change_delete     = g:signify_sign_change

call plug#begin()

Plug 'https://github.com/airblade/vim-rooter'
Plug 'https://github.com/editorconfig/editorconfig-vim'
Plug 'https://github.com/godlygeek/tabular'
Plug 'https://github.com/junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'https://github.com/junegunn/fzf.vim'
Plug 'https://github.com/machakann/vim-highlightedyank'
Plug 'https://github.com/mhinz/vim-signify'
Plug 'https://github.com/pbnj/pbnj.vim'
Plug 'https://github.com/pbnj/terradoc.vim'
Plug 'https://github.com/pbnj/vim-britive'
Plug 'https://github.com/pbnj/vim-ddgr'
Plug 'https://github.com/sheerun/vim-polyglot'
Plug 'https://github.com/tpope/vim-abolish'
Plug 'https://github.com/tpope/vim-commentary'
Plug 'https://github.com/tpope/vim-eunuch'
Plug 'https://github.com/tpope/vim-fugitive'
Plug 'https://github.com/tpope/vim-rsi'
Plug 'https://github.com/tpope/vim-surround'
Plug 'https://github.com/tpope/vim-unimpaired'
Plug 'https://github.com/tpope/vim-vinegar'

if has('nvim')
  Plug 'neovim/nvim-lspconfig'
  Plug 'williamboman/mason.nvim'
  Plug 'williamboman/mason-lspconfig.nvim'
  Plug 'hrsh7th/nvim-cmp'
  Plug 'hrsh7th/cmp-nvim-lsp'
  Plug 'hrsh7th/cmp-buffer'
  Plug 'hrsh7th/cmp-path'
  Plug 'saadparwaiz1/cmp_luasnip'
  Plug 'hrsh7th/cmp-nvim-lua'
  Plug 'L3MON4D3/LuaSnip'
  Plug 'rafamadriz/friendly-snippets'
  Plug 'VonHeikemen/lsp-zero.nvim', {'branch': 'v1.x'}
endif

call plug#end()

filetype plugin indent on

lua require('lsp-zero').preset({ name = 'minimal', set_lsp_keymaps = true, manage_nvim_cmp = true, suggest_lsp_servers = false }).setup()

"-------------------------------------------------------------------------------
" Options
"-------------------------------------------------------------------------------

let &autoindent=1
let &autoread=1
let &backspace='indent,eol,start'
let &backup=0
let &breakindent=1
let &clipboard='unnamed,unnamedplus'
let &completeopt='menu'
let &cursorline=1
let &encoding='utf-8'
let &errorformat='%f:%l:%m,%f:%l:%c:%m'
let &fillchars='vert:|,fold:-,eob: '
let &foldenable=0
let &grepformat='%f:%l:%c:%m'
let &hidden=1
let &hlsearch=1
let &ignorecase=1
let &incsearch=1
let &infercase=1
let &keywordprg=':!ddgr'
let &laststatus=2
let &lazyredraw=1
let &linebreak=1
let &list=1
let &listchars='tab:| ,trail:·'
let &modeline=1
let &mouse='a'
let &number=1
let &omnifunc='ale#completion#OmniFunc'
let &relativenumber=0
let &ruler=0
let &secure=1
let &shortmess='filnxtToOc'
let &showmode=1
let &signcolumn='yes'
let &smartcase=1
let &smarttab=1
let &swapfile=0
let &ttimeout=1
let &ttimeoutlen=50
let &ttyfast=1
let &undofile=1
let &wildignorecase=1
let &wildmenu=1
let &wildmode='longest:full,full'
let &wrap=0

let &wildignore='*.o,*.obj,*.bin,*.dll,*.exe,*.DS_Store,'
let &wildignore..='*.pdf,*/.ssh/*,*.pub,*.crt,*.key,*/cache/*,'
let &wildignore..='*/dist/*,*/node_modules/*,*/vendor/*,*/__pycache__/*,*/build/*,*/.git/*,*/.terraform/*'

" Better grep
if executable('rg')
  let &grepprg='rg --vimgrep --line-number --column $*'
elseif executable('git')
  let &grepprg='git grep --line-number --column $*'
else
  let &grepprg='grep -HIn --line-buffered $*'
endif

augroup quickfix
  autocmd QuickFixCmdPost [^l]* nested cwindow
  autocmd QuickFixCmdPost    l* nested lwindow
augroup END

"----------------------------------------
" Statusline
"----------------------------------------

let statusline=' %f'
let statusline..=' %#Error#%m%*%r%h%w%q'
let statusline..=' %#ALEInfoSign#%{ale#engine#IsCheckingBuffer(bufnr())?"checking...":""}%*'
let statusline..=' %#ALEErrorSign#%{(ale#statusline#Count(bufnr()).error)?"x".ale#statusline#Count(bufnr()).error:""}%*'
let statusline..=' %#ALEWarningSign#%{(ale#statusline#Count(bufnr()).warning)?"w".ale#statusline#Count(bufnr()).warning:""}%*'

"-------------------------------------------------------------------------------
" Functions & Commands
"-------------------------------------------------------------------------------

"----------------------------------------
" General
"----------------------------------------

" Completion function for `make`
function! MakeCompletion(A,L,P) abort
    let l:targets = systemlist('make -qp | awk -F'':'' ''/^[a-zA-Z0-9][^$#\/\t=]*:([^=]|$)/ {split($1,A,/ /);for(i in A)print A[i]}'' | grep -v Makefile | sort -u')
    return filter(l:targets, 'v:val =~ "^' . a:A . '"')
endfunction
command! -nargs=* -complete=customlist,MakeCompletion Make
      \ terminal make -C %:p:h <args>
nnoremap <leader>mm :Make<space><c-d>

function! StripTrailingSpaces() abort
  %s/\s\+$//e
endfunction
command! StripTrailingSpaces call StripTrailingSpaces()

function! StripTrailingNewLines() abort
  %s/\($\n\s*\)\+\%$//e
endfunction
command! StripTrailingNewLines call StripTrailingNewLines()

function! StripNewLines() abort
  g/^$/d
endfunction
command! StripNewLines call StripNewLines()

augroup fixer_general
  autocmd!
  autocmd BufWritePre,FileWritePre * call StripTrailingSpaces() | call StripTrailingNewLines()
augroup END

function! Open(...) abort
  if executable('xdg-open')
    silent call system('xdg-open ' . join(a:000, ' '))
  elseif executable('open')
    silent call system('open ' . join(a:000, ' '))
  elseif executable('open-cli')
    silent call system('open-cli ' . join(a:000, ' '))
  elseif executable('lynx')
    for url in a:000
      silent call term_start(['lynx', url])
    endfor
  elseif executable('w3m')
    for url in a:000
      silent call term_start(['w3m', url])
    endfor
  else
    echoerr "TODO: support more programs"
  endif
endfunction
command! -nargs=* Open
      \ call Open(<q-args>)

" :Projects[!] is a custom Project Manager
if executable('fd')
  let project_finder = 'fd . ~/Projects --type d'
else
  let project_finder = 'find ~/Projects -type d -not \( -path *.git* -prune \) -not \( -path *.terraform* -prune \)'
endif
command! -bang Projects
      \ call fzf#run(fzf#wrap({'source': project_finder},<bang>0))

command! URLs
      \ call fzf#run(fzf#wrap({'source': map(filter(uniq(split(join(getline(1,'$'),' '),' ')), 'v:val =~ "http"'), {k,v->substitute(v,'\(''\|)\|"\|,\)','','g')}), 'sink': 'Open', 'options': '--multi'}))
nnoremap <leader>uu <cmd>URLs<cr>

"---------------------------------------
" Git
"---------------------------------------
" GitBrowse takes a dictionary and opens files on remote git repo websites.
function! GitBrowse(args) abort
  let l:cmd = 'git browse '
  let l:remote = trim(system('git config branch.'.a:args.branch.'.remote || echo "origin" '))
  if a:args.range == 0
    let l:cmd ..= l:remote . ' ' . a:args.filename
  else
    echo a:args.range
    let l:cmd ..= l:remote . ' ' . a:args.filename . ' ' . a:args.line1 . ' ' . a:args.line2
  endif
  execute 'silent ! ' . l:cmd | redraw!
endfunction
" View git repo, branch, & file in the browser
command! -range GB
      \ call GitBrowse({
      \ 'branch': trim(system('git rev-parse --abbrev-ref HEAD 2>/dev/null')),
      \ 'filename': trim(system('git ls-files --full-name ' . expand('%'))),
      \ 'range': <range>,
      \ 'line1': <line1>,
      \ 'line2': <line2>,
      \ })
command! GC Git commit
command! GP Git! push
command! GR execute 'lcd ' . finddir('.git/..', expand('%:p:h').';')
command! GS Git! status %:h

"-------------------------------------------------------------------------------
" Mappings
"-------------------------------------------------------------------------------

cnoremap <c-n> <c-Down>
cnoremap <c-p> <c-Up>
inoremap <c-f> <c-x><c-f>
inoremap <c-l> <c-x><c-l>
inoremap <c-o> <c-x><c-o>
inoremap <c-u> <c-x><c-u>
nnoremap <expr> <leader>ss '/\<'.expand('<cword>').'\><cr>'
nnoremap <leader>bb <cmd>b#<cr>
nnoremap <leader>br <cmd>FZFBritiveConsole<cr>
nnoremap <leader>cc <cmd>cc<cr>
nnoremap <leader>cd <cmd>lcd %:p:h<cr>
nnoremap <leader>ee :ed **/*
nnoremap <leader>es :sp **/*
nnoremap <leader>ev :vs **/*
nnoremap <leader>fb <cmd>Buffers<cr>
nnoremap <leader>ff <cmd>Files<cr>
nnoremap <leader>FF <cmd>Files %:p:h<cr>
nnoremap <leader>fg <cmd>GFiles<cr>
nnoremap <leader>fG <cmd>GFiles?<cr>
nnoremap <leader>fs <cmd>Rg<cr>
nnoremap <leader>gc <cmd>G commit<cr>
nnoremap <leader>gd <cmd>ALEGoToDefinition<cr>
nnoremap <leader>gg <cmd>G<cr>
nnoremap <leader>gp <cmd>G! push<cr>
nnoremap <leader>gr <cmd>GR<cr>
nnoremap <leader>gs <cmd>G<cr>
nnoremap <leader>gw <cmd>Gwrite<cr>
nnoremap <leader>ll <cmd>ll<cr>
nnoremap <leader>tt <cmd>terminal<cr>
nnoremap <leader>ww <cmd>write<cr>
nnoremap <leader>xx <cmd>20Lexplore<cr>
nnoremap <leader>ya <cmd>%y+<cr>
nnoremap C "_C
nnoremap Y y$
nnoremap c "_c
nnoremap cc "_cc
nnoremap q <Nop>
nnoremap x "_x
noremap <expr> N 'nN'[v:searchforward]
noremap <expr> n 'Nn'[v:searchforward]
tnoremap <esc> <c-\><c-n>
tnoremap <s-space> <space>

colorscheme pbnj
