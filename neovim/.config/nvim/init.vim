nnoremap <silent><nowait><space> <nop>
let g:mapleader = ' '

" netrw
let g:netrw_keepdir = 0
let g:netrw_fastbrowse = 0

" Enable built-in plugin to filter quickfix list. See :h :Cfilter
packadd cfilter

filetype plugin indent on
syntax on

lua require('plugins')
lua require('lsp')

" vim options
let &autoindent = 1
let &autoread = 1
let &background = system('defaults read -g AppleInterfaceStyle') =~ '^Dark' ? 'dark' : 'light'
let &backspace = 'indent,eol,start'
let &breakindent = 1
let &clipboard = 'unnamed,unnamedplus'
let &completeopt = 'menu'
let &cursorline = 0
let &encoding = 'utf-8'
let &errorformat = '%f:%l:%m,%f:%l:%c:%m'
let &fillchars = 'vert:│,foldclose:⎯,fold:⎯,diff:⎯,eob: '
let &grepformat = '%f:%l:%c:%m'
let &grepprg = executable('rg') ? 'rg --vimgrep --line-number --column $*' : executable('git') ? 'git grep --line-number --column $*' : 'grep -HIn --line-buffered $*'
let &hidden = 1
let &hlsearch = 1
let &ignorecase = 1
let &incsearch = 1
let &infercase = 1
let &laststatus = 2
let &lazyredraw = 1
let &linebreak = 1
let &list = 1
let &listchars = 'tab:│ ,trail:·'
let &modeline = 1
let &mouse = 'a'
let &number = 1
let &secure = 1
let &shortmess = 'filnxtToOc'
let &showmode = 1
let &signcolumn = 'yes'
let &smartcase = 1
let &smarttab = 1
let &statusline = ' %f %#Error#%m%*%r%h%w%q'
let &swapfile = 0
let &termguicolors = 0
let &ttimeout = 1
let &ttimeoutlen = 50
let &ttyfast = 1
let &undofile = 1
let &wildignorecase = 1
let &wildmenu = 1
let &wildmode = 'longest:full,full'
let &wrap = 0

let &wildignore   = '*.o,*.obj,*.bin,*.dll,*.exe,*.DS_Store,'
let &wildignore ..= '*.pdf,*/.ssh/*,*.pub,*.crt,*.key,*/cache/*,'
let &wildignore ..= '*/dist/*,*/node_modules/*,*/vendor/*,*/__pycache__/*,*/build/*,*/.git/*,*/.terraform/*'

augroup cursorline_toggle
	autocmd!
	autocmd InsertEnter,InsertLeave * setlocal cursorline!
augroup end

augroup highlight_yanks
	autocmd!
	autocmd TextYankPost * silent! lua vim.highlight.on_yank()
augroup end

" Completion function for `make`
function! MakeCompletion(A,L,P) abort
	let l:targets = systemlist('make -qp | awk -F'':'' ''/^[a-zA-Z0-9][^$#\/\t=]*:([^=]|$)/ {split($1,A,/ /);for(i in A)print A[i]}'' | grep -v Makefile | sort -u')
	return filter(l:targets, 'v:val =~ "^' .. a:A .. '"')
endfunction
command! -nargs=* -complete=customlist,MakeCompletion Make
			\ ! make -C %:p:h <args>
nnoremap <leader>mm :Make<space><c-d>

if !empty($TMUX)
	command! Terminal silent
				\ ! tmux split-window -c %:p:h | redraw!
else
	if has('nvim')
		command! Terminal
					\ call termopen([&shell,'-l'],{'cwd':expand('%:p:h')})
	else
		command! Terminal
					\ call term_start([&shell,'-l'],{'cwd':expand('%:p:h')})
	endif
endif

" GitBrowse takes a dictionary and opens files on remote git repo websites.
function! GitBrowse(args) abort
	let l:branch = len(a:args.branch) ? a:args.branch : 'origin'
	let l:remote = trim(system('git config branch.'..l:branch..'.remote'))
	let l:cmd = 'git browse ' .. ((a:args.range) ? printf("%s %s %s %s",l:remote, a:args.filename, a:args.line1, a:args.line2) : printf("%s %s", l:remote, a:args.filename))
	echom l:cmd
	execute 'silent ! '..l:cmd | redraw!
endfunction
" View git repo, branch, & file in the browser
command! -range GB
			\ call GitBrowse({
			\   'branch': trim(system('git rev-parse --abbrev-ref HEAD 2>/dev/null')),
			\   'filename': trim(system('git ls-files --full-name ' .. expand('%'))),
			\   'range': <range>,
			\   'line1': <line1>,
			\   'line2': <line2>,
			\ })
command! GW Gwrite
command! GR execute 'lcd '..finddir('.git/..', expand('%:p:h')..';')
command! GC Git commit
nnoremap <leader>gg <cmd>G<cr>
nnoremap <leader>gr <cmd>execute 'lcd '..finddir('.git/..', expand('%:p:h')..';')<cr>
nnoremap <leader>gw <cmd>Gwrite<cr>

" FZF commands & bindings
command! URLs call fzf#run(fzf#wrap({'source': map(filter(uniq(split(join(getline(1,'$'),' '),' ')), 'v:val =~ "http"'), {k,v->substitute(v,'\(''\|)\|"\|,\)','','g')}), 'sink': executable('open') ? '!open' : '!xdg-open', 'options': '--multi --prompt=URLs\>\ '}))
command! F Files
command! FF Files %:p:h
nnoremap <leader>bb <cmd>Buffers<cr>
nnoremap <leader>ff <cmd>GFiles<cr>
nnoremap <leader>FF <cmd>FF<cr>
nnoremap <leader>uu <cmd>URLs<cr>

" General purpose bindings
cnoremap <c-n> <c-Down>
cnoremap <c-p> <c-Up>
nnoremap <leader>cd <cmd>lcd %:p:h<cr>
nnoremap <leader>ee :ed **/*
nnoremap <leader>sp :sp **/*
nnoremap <leader>vs :vs **/*
nnoremap <leader>tt <cmd>call term_start([&shell,'-l'],{'cwd':expand('%:p:h')})<cr>
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
