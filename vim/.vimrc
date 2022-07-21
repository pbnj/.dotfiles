" set mapleader to space
nnoremap <silent><nowait><space> <nop>
let g:mapleader = ' '

let g:netrw_keepdir = 0

filetype plugin indent on

" plugins

" :help cfilter
packadd! cfilter

if filereadable(glob('~/.vim/work.vim'))
  source ~/.vim/work.vim
endif

let g:fzf_layout = { 'down': '40%' }
let g:fzf_colors = {
      \ 'hl':      [ 'fg', 'Exception'  ] ,
      \ 'hl+':     [ 'fg', 'Exception'  ] ,
      \ 'border':  [ 'fg', 'NonText'    ] ,
      \ 'pointer': [ 'fg', 'DiffAdd'    ] ,
      \ 'marker':  [ 'fg', 'DiffDelete' ] ,
      \ 'info':    [ 'fg', 'PreProc'    ] ,
      \ 'query':   [ 'fg', 'PreProc'    ] ,
      \ }

let g:ale_completion_enabled = 1
let g:ale_fix_on_save        = 1
let g:ale_fixers             = { '*': ['remove_trailing_lines', 'trim_whitespace'] }
let g:ale_floating_preview   = 1

function! ALELSPMappings() abort
  setlocal omnifunc=ale#completion#OmniFunc

  nnoremap <buffer> <leader>gd <cmd>ALEGoToDefinition<cr>
  nnoremap <buffer> <leader>gk <cmd>ALEDocumentation<cr>
  nnoremap <buffer> <leader>gm <cmd>ALEGoToImplementation<cr>
  nnoremap <buffer> <leader>gr <cmd>ALEFindReferences<cr>
  nnoremap <buffer> <leader>gy <cmd>ALEGoToTypeDefinition<cr>
  nnoremap <buffer> <leader>K  <cmd>ALEHover<cr>
  nnoremap <buffer> <leader>rn <cmd>ALERename<cr>

endfunction

augroup ALEMappings
  autocmd!
  autocmd User ALELSPStarted call ALELSPMappings()
augroup END

let g:plugin_dir = '~/.vim/pack/pbnj/start'
let g:plugins = [
      \ 'https://github.com/dense-analysis/ale',
      \ 'https://github.com/editorconfig/editorconfig-vim',
      \ 'https://github.com/godlygeek/tabular',
      \ 'https://github.com/junegunn/fzf',
      \ 'https://github.com/junegunn/fzf.vim',
      \ 'https://github.com/kana/vim-textobj-entire',
      \ 'https://github.com/kana/vim-textobj-user',
      \ 'https://github.com/ludovicchabant/vim-gutentags',
      \ 'https://github.com/machakann/vim-highlightedyank',
      \ 'https://github.com/mhinz/vim-signify',
      \ 'https://github.com/preservim/tagbar',
      \ 'https://github.com/sheerun/vim-polyglot',
      \ 'https://github.com/tpope/vim-commentary',
      \ 'https://github.com/tpope/vim-dispatch',
      \ 'https://github.com/tpope/vim-eunuch',
      \ 'https://github.com/tpope/vim-fugitive',
      \ 'https://github.com/tpope/vim-rhubarb',
      \ 'https://github.com/tpope/vim-surround',
      \ 'https://github.com/tpope/vim-unimpaired',
      \ 'https://github.com/tpope/vim-vinegar',
      \ 'https://github.com/vim-test/vim-test',
      \ 'https://github.com/lifepillar/vim-mucomplete',
      \ ]

function! PackInstall() abort
  for l:plugin_url in g:plugins
    let l:plugin_path = g:plugin_dir . '/' . join(split(l:plugin_url, '/')[-1 : ], '/')
    execute 'Terminal git clone ' . l:plugin_url . ' ' . l:plugin_path . ' 2>/dev/null || git -C ' . l:plugin_path . ' pull '
  endfor
endfunction

command! PackUp call PackInstall()

packloadall
helptags ALL

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
let &fillchars      = 'vert:|,fold:-,eob:~'
let &formatoptions  = 'tcqjno'
let &grepprg        = 'grep -HIn'
let &hidden         = 1
let &hlsearch       = 1
let &ignorecase     = 1
let &incsearch      = 1
let &infercase      = 1
let &laststatus     = 2
let &lazyredraw     = 1
let &linebreak      = 1
let &list           = 1
let &listchars      = 'tab:| ,nbsp:·,trail:·,'
let &modeline       = 1
let &mouse          = 'a'
let &number         = 1
let &relativenumber = 0
let &ruler          = 1
let &scrolloff      = 10
let &secure         = 1
let &shortmess      = 'filnxtToOSc'
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

command! CD :lcd %:p:h
command! BO :%bdelete | edit# | normal `#
command! Cclear call setqflist([])
command! GC Git commit
command! GD Gdiffsplit
command! GP Git push
command! GPull Git pull
command! GW Gwrite
command! -range GBrowse call GitBrowse({
      \ 'branch': trim(system('git rev-parse --abbrev-ref HEAD 2>/dev/null')),
      \ 'filename': trim(system('git ls-files --full-name ' . expand('%'))),
      \ 'range': <range>,
      \ 'line1': <line1>,
      \ 'line2': <line2>,
      \ })

if executable('brew')
  command! BUpdate
        \ VTerminal brew update && arch -arm64 brew upgrade && brew upgrade --casks && brew cleanup --prune 0
else
  echoerr 'brew cli is not in $PATH'
endif

if executable('ddgr')
  command! -nargs=* DD
        \ VTerminal ddgr --expand <args>
else
  echoerr 'ddgr cli is not in $PATH'
endif

imap <C-f> <plug>(fzf-complete-path)
inoremap <expr> <C-d> fzf#vim#complete(fzf#wrap({
      \ 'source': uniq(sort(split(join(getline(1,'$'),"\n"),'\W\+'))),
      \ }))
imap <C-l> <plug>(fzf-complete-line)
inoremap <silent> <C-U> <C-G>u<C-U>
inoremap <silent> <C-W> <C-G>u<C-W>
nmap <C-j> <Plug>(ale_next_wrap)
nmap <C-k> <Plug>(ale_previous_wrap)
nnoremap <leader>bb <cmd>b#<cr>
nnoremap <leader>bs :b <C-d>
nnoremap <leader>cd <cmd>CD<cr>
nnoremap <leader>gq mzgggqG`z
nnoremap <leader>tt <cmd>TagbarToggle<cr>
nnoremap C "_C
nnoremap Y y$
nnoremap c "_c
nnoremap cc "_cc
nnoremap gs <cmd>SignifyHunkDiff<cr>
tnoremap <esc> <c-\><c-n>
tnoremap <s-space> <space>

try
  colorscheme pbnj
catch
endtry

" vim:ts=2:sts=2:sw=2:et:
