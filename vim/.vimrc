" set mapleader to space
nnoremap <silent><nowait><space> <nop>
let g:mapleader = ' '

let g:netrw_liststyle = 3

filetype plugin indent on

" plugins

let g:fzf_layout = { 'down': '40%' }

let g:ale_completion_enabled = 1
let g:ale_fix_on_save        = 1
let g:ale_fixers             = { '*': ['remove_trailing_lines', 'trim_whitespace'] }
let g:ale_floating_preview   = 1

if filereadable(glob('~/.vim/work.vim'))
  source ~/.vim/work.vim
endif

call plug#begin()

Plug 'https://gist.github.com/PeterRincker/582ea9be24a69e6dd8e237eb877b8978.git', { 'as': 'SortGroup', 'do': 'mkdir plugin; mv -f *.vim plugin/', 'on': 'SortGroup' }
Plug 'https://github.com/arthurxavierx/vim-caser'
Plug 'https://github.com/dense-analysis/ale'
Plug 'https://github.com/editorconfig/editorconfig-vim'
Plug 'https://github.com/junegunn/fzf'
Plug 'https://github.com/junegunn/fzf.vim'
Plug 'https://github.com/junegunn/vim-easy-align'
Plug 'https://github.com/kana/vim-textobj-entire'
Plug 'https://github.com/kana/vim-textobj-indent'
Plug 'https://github.com/kana/vim-textobj-user'
Plug 'https://github.com/ludovicchabant/vim-gutentags'
Plug 'https://github.com/machakann/vim-highlightedyank'
Plug 'https://github.com/mhinz/vim-signify'
Plug 'https://github.com/romainl/vim-qf'
Plug 'https://github.com/sheerun/vim-polyglot'
Plug 'https://github.com/tpope/vim-abolish'
Plug 'https://github.com/tpope/vim-commentary'
Plug 'https://github.com/tpope/vim-dispatch'
Plug 'https://github.com/tpope/vim-eunuch'
Plug 'https://github.com/tpope/vim-fugitive'
Plug 'https://github.com/tpope/vim-rhubarb'
Plug 'https://github.com/tpope/vim-rsi'
Plug 'https://github.com/tpope/vim-surround'
Plug 'https://github.com/tpope/vim-unimpaired'
Plug 'https://github.com/tpope/vim-vinegar'
Plug 'https://github.com/vim-scripts/ReplaceWithRegister'
Plug 'https://github.com/vim-test/vim-test'

call plug#end()

" options

if !isdirectory(expand('~/.vim/undo/'))
  mkdir(expand('~/.vim/undo/'))
endif

let &autoindent     = 1
let &autoread       = 1
let &background     = 'dark'
let &backspace      = 'indent,eol,start'
let &backup         = 0
let &breakindent    = 1
let &clipboard      = 'unnamed,unnamedplus'
let &cmdheight      = 2
let &completeopt    = 'menuone'
let &conceallevel   = 0
let &cursorcolumn   = 0
let &cursorline     = 0
let &display        = 'lastline'
let &encoding       = 'utf-8' | scriptencoding utf-8
let &errorformat    = '%f|%l| %m,%f:%l:%m,%f:%l:%c:%m'
let &fillchars      = 'vert:|,fold:-,eob:~'
let &formatoptions  = 'tcqjno'
let &grepprg        = 'grep -HI --line-number'
let &hidden         = 1
let &hlsearch       = 1
let &ignorecase     = 1
let &incsearch      = 1
let &infercase      = 1
let &laststatus     = 2
let &lazyredraw     = 1
let &linebreak      = 1
let &list           = 1
let &listchars      = 'tab:| ,nbsp:·,trail:·,eol:¬,'
let &modeline       = 1
let &mouse          = ''
let &number         = 0
let &omnifunc       = 'ale#completion#OmniFunc'
let &relativenumber = 0
let &ruler          = 1
let &scrolloff      = 10
let &secure         = 1
let &shortmess      = 'filnxtToOc'
let &showbreak      = '> '
let &sidescrolloff  = 20
let &signcolumn     = 'yes'
let &smartcase      = 1
let &smarttab       = 1
let &swapfile       = 0
let &t_Co           = 16
let &termguicolors  = 0
let &ttimeout       = 1
let &ttimeoutlen    = 50
let &ttyfast        = 1
let &undodir        = expand('~/.vim/undo/')
let &undofile       = 1
let &updatetime     = 100
let &wildignore     = '*.o,*.obj,*.bin,*.dll,*.exe,*.DS_Store,*.pdf,*/.ssh/*,*.pub,*.crt,*.key,*/cache/*,*/dist/*,*/node_modules/*,*/tmp/*,*/vendor/*,*/__pycache__/*,*/build/*,*/.git/*'
let &wildignorecase = 1
let &wildmenu       = 1
let &wrap           = 0
let &wrapscan       = 0

if v:version >= 900
  let &listchars .= 'multispace:·,leadmultispace:·,'
  let &wildoptions = 'fuzzy,pum'
endif

let &statusline = '%<%f %h%m%r'
if exists('*FugitiveStatusline')
  let &statusline .= '%{FugitiveStatusline()}'
endif
let &statusline .= ' %y %l:%c/%L'

augroup ToggleCursorLine
  autocmd!
  autocmd InsertEnter * setlocal cursorline
  autocmd InsertLeave * setlocal nocursorline
augroup END

function! CopyPath(type) abort
  if a:type ==# 'file'
    let l:value=expand('%:p')
  elseif a:type ==# 'filename'
    let l:value=expand('%:p')->split('/')[-1]
  elseif a:type ==# 'dir'
    let l:value=expand('%:p:h')
  elseif a:type ==# 'dirname'
    let l:value=expand('%:p:h')->split('/')[-1]
  endif
  let @+=l:value
  echom 'Copied: ' . l:value
endfunction
command! CopyFilePath call CopyPath('file')
command! CopyFileName call CopyPath('filename')
command! CopyDirPath call CopyPath('dir')
command! CopyDirName call CopyPath('dirname')

command! -nargs=* Terminal topleft terminal ++shell <args>
command! -nargs=* STerminal topleft terminal ++shell <args>
command! -nargs=* VTerminal topleft vertical terminal ++shell <args>

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

command! BO :%bdelete | edit# | normal `#
command! -range GB call GitBrowse({
      \ 'branch': trim(system('git rev-parse --abbrev-ref HEAD 2>/dev/null')),
      \ 'filename': trim(system('git ls-files --full-name ' . expand('%'))),
      \ 'range': <range>,
      \ 'line1': <line1>,
      \ 'line2': <line2>,
      \ })
command! GC Git commit
command! GD Gdiffsplit
command! GP Git push
command! GPull Git pull
command! GRoot execute 'lcd ' . finddir('.git/..', expand('%:p:h').';')
command! GW Gwrite

command! -nargs=* Grep cexpr system('rg ' . <q-args>)
command! -nargs=* DD Terminal ddgr --expand <args>
command! -nargs=* DHere :Dispatch -dir=%:p:h <args>
command! TmuxHere call system('tmux split-window -c ' . expand('%:p:h'))
command! TermHere call term_start($SHELL, {'cwd': expand('%:p:h')})

nmap <C-j> <Plug>(ale_next_wrap)
nmap <C-k> <Plug>(ale_previous_wrap)
nnoremap <leader>bb <cmd>b#<cr>
nnoremap <leader>cd <cmd>GRoot<cr>
nnoremap <leader>ee :e **/*
nnoremap <leader>es :sp **/*
nnoremap <leader>ev :vsp **/*
nnoremap <leader>ff <cmd>Files<cr>
nnoremap <leader>fb <cmd>Buffers<cr>
nnoremap <leader>fg <cmd>GFiles<cr>
nnoremap <leader>gd <cmd>ALEGoToDefinition<cr>
nnoremap <leader>gK <cmd>ALEDocumentation<cr>
nnoremap <leader>gk <cmd>ALEHover<cr>
nnoremap <leader>gm <cmd>ALEGoToImplementation<cr>
nnoremap <leader>gq mzgggqG`z
nnoremap <leader>gr <cmd>ALEFindReferences<cr>
nnoremap <leader>gs <cmd>SignifyHunkDiff<cr>
nnoremap <leader>gy <cmd>ALEGoToTypeDefinition<cr>
nnoremap <leader>lcd <cmd>lcd %:p:h<cr>
nnoremap <leader>rn <cmd>ALERename<cr>
nnoremap C "_C
nnoremap c "_c
nnoremap cc "_cc
nnoremap x "_x
nnoremap Y y$
tnoremap <esc> <c-\><c-n>
tnoremap <s-space> <space>

try
  colorscheme pbnj
catch
endtry

" vim:ts=2:sts=2:sw=2:et:
