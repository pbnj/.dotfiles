let &l:keywordprg = ':!ddgr bash'
let &l:formatprg = 'shfmt --posix'

command! Format normal! mfgggqG`f
nnoremap <leader>af <cmd>Format<cr>
