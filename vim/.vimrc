" vim:ts=2:sts=2:sw=2:et:
" set mapleader to space
nnoremap <silent><nowait><space> <nop>
let g:mapleader = ' '

let g:netrw_keepdir = 0

" plugins

packadd cfilter
runtime ftplugin/man.vim

if filereadable(glob('~/.vim/work.vim'))
  source ~/.vim/work.vim
endif

let g:ale_completion_enabled = 1
let g:ale_fix_on_save = 1
let g:ale_fixers = {'*': ['remove_trailing_lines', 'trim_whitespace']}
let g:ale_floating_preview = 1
let g:ale_sign_error = 'x'
let g:ale_sign_info = 'i'
let g:ale_sign_style_error = 'x'
let g:ale_sign_style_warning = '!'
let g:ale_sign_warning = '!'
nmap <C-j> <Plug>(ale_next_wrap)
nmap <C-k> <Plug>(ale_previous_wrap)

let g:signify_sign_add = '+'
let g:signify_sign_delete = '_'
let g:signify_sign_delete_first_line = '‾'
let g:signify_sign_change = '~'
let g:signify_sign_change_delete = g:signify_sign_change . g:signify_sign_delete_first_line

let g:fzf_layout = {'down': '20%'}

call plug#begin()
Plug 'https://github.com/dense-analysis/ale'
Plug 'https://github.com/editorconfig/editorconfig-vim'
Plug 'https://github.com/junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'https://github.com/junegunn/fzf.vim'
Plug 'https://github.com/machakann/vim-highlightedyank'
Plug 'https://github.com/mhinz/vim-signify'
Plug 'https://github.com/pbnj/pbnj.vim'
Plug 'https://github.com/sheerun/vim-polyglot'
Plug 'https://github.com/tpope/vim-commentary'
Plug 'https://github.com/tpope/vim-dispatch'
Plug 'https://github.com/tpope/vim-eunuch'
Plug 'https://github.com/tpope/vim-fugitive'
Plug 'https://github.com/tpope/vim-surround'
Plug 'https://github.com/arcticicestudio/nord-vim'
call plug#end()

filetype plugin indent on

" options

if !isdirectory(expand('~/.vim/undo/'))
  mkdir(expand('~/.vim/undo/'))
endif

set autoindent
set autoread
set background=dark
set backspace=indent,eol,start
set breakindent
set clipboard=unnamed,unnamedplus
set completeopt=menuone,longest,noinsert
set encoding=utf-8
set formatoptions=tcqjno
set hidden
set hlsearch
set ignorecase
set incsearch
set infercase
set lazyredraw
set linebreak
set list
set listchars=tab:\|\ ,trail:·
set modeline
set mouse=
set nobackup
set norelativenumber
set noshowmode
set noswapfile
set nowrap
set nowrapscan
set number
set omnifunc=ale#completion#OmniFunc
set ruler
set secure
set shortmess=filnxtToOc
set smartcase
set smarttab
set ttimeout
set ttimeoutlen=50
set ttyfast
set undodir=~/.vim/undo/
set undofile
set updatetime=100
set wildignore=*.o,*.obj,*.bin,*.dll,*.exe,*.DS_Store,*.pdf,*/.ssh/*,*.pub,*.crt,*.key,*/cache/*,*/dist/*,*/node_modules/*,*/tmp/*,*/vendor/*,*/__pycache__/*,*/build/*,*/.git/*
set wildignorecase
set wildmenu
set wildmode=longest:full,full

if executable('rg')
  let &grepprg = 'rg --vimgrep --hidden --smart-case'
else
  let &grepprg = 'grep -HI --line-number $* -r .'
endif

let &errorformat='%f|%l| %m,%f:%l:%m,%f:%l:%c:%m'

" augroup ToggleCursorLine
"   autocmd!
"   autocmd InsertEnter * setlocal cursorline
"   autocmd InsertLeave * setlocal nocursorline
" augroup END

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
command! GCommit Git commit
command! GDiff Gdiffsplit
command! GPush Git! push
command! GPull Git! pull
command! GRoot execute 'lcd ' . finddir('.git/..', expand('%:p:h').';')
command! GWrite Gwrite
command! GStatus G status %:h

function! Terminal(...) abort
  if a:0 >= 1
    call term_start([$SHELL, '-lc', join(a:000,' ')], {'cwd': expand('%:p:h')})
  else
    call term_start($SHELL, {'cwd': expand('%:p:h')})
  endif
endfunction
command! -nargs=* Terminal call Terminal(<f-args>)

nnoremap <c-a> ^
nnoremap <c-e> $
vnoremap <c-a> ^
vnoremap <c-e> $
inoremap <c-a> <esc>^i
inoremap <c-e> <esc>$a
cnoremap <c-a> <c-b>
nnoremap <expr>yob &background ==# 'dark' ? ':let &background="light"<cr>' : ':let &background="dark"<cr>'
nnoremap <expr>yoh &hlsearch == 1 ? ':let &hlsearch=0<cr>' : ':let &hlsearch=1<cr>'
nnoremap <expr>yol &list == 1 ? ':let &list=0<cr>' : ':let &list=1<cr>'
nnoremap <leader>bb <cmd>Buffers<cr>
nnoremap <leader>cd <cmd>lcd %:p:h<cr>
nnoremap <leader>ee :ed **/*
nnoremap <leader>es :sp **/*
nnoremap <leader>ev :vs **/*
nnoremap <leader>ff <cmd>Files<cr>
nnoremap <leader>fg <cmd>GFiles<cr>
nnoremap <leader>fG <cmd>GFiles?<cr>
nnoremap <leader>fs <cmd>Rg<cr>
nnoremap <leader>fl <cmd>Lines<cr>
nnoremap <leader>fb <cmd>Buffers<cr>
nnoremap <leader>gd <cmd>ALEGoToDefinition<cr>
nnoremap <leader>gg <cmd>Git<cr>
nnoremap <leader>gK <cmd>ALEDocumentation<cr>
nnoremap <leader>gk <cmd>ALEHover<cr>
nnoremap <leader>gm <cmd>ALEGoToImplementation<cr>
nnoremap <leader>gq mzgggqG`z
nnoremap <leader>gr <cmd>ALEFindReferences<cr>
nnoremap <leader>gy <cmd>ALEGoToTypeDefinition<cr>
nnoremap <leader>tt :terminal
nnoremap <leader>w <cmd>write<cr>
nnoremap <leader>ya <cmd>%y+<cr>
nnoremap C "_C
nnoremap c "_c
nnoremap cc "_cc
nnoremap x "_x
nnoremap Y y$
tnoremap <esc> <c-\><c-n>
tnoremap <s-space> <space>

nnoremap [a <cmd>previous<cr>
nnoremap ]a <cmd>next<cr>
nnoremap [A <cmd>first<cr>
nnoremap ]A <cmd>last<cr>
nnoremap [b <cmd>bprevious<cr>
nnoremap ]b <cmd>bnext<cr>
nnoremap [B <cmd>bfirst<cr>
nnoremap ]B <cmd>blast<cr>
nnoremap [e <cmd>move -2<cr>
nnoremap ]e <cmd>move +1<cr>
nnoremap [l <cmd>lprevious<cr>
nnoremap ]l <cmd>lnext<cr>
nnoremap [L <cmd>lfirst<cr>
nnoremap ]L <cmd>llast<cr>
nnoremap [q <cmd>cprevious<cr>
nnoremap ]q <cmd>cnext<cr>
nnoremap [Q <cmd>cfirst<cr>
nnoremap ]Q <cmd>clast<cr>
nnoremap [t <cmd>tprevious<cr>
nnoremap ]t <cmd>tnext<cr>
nnoremap [T <cmd>tfirst<cr>
nnoremap ]T <cmd>tlast<cr>

try
  colorscheme nord
catch
endtry
