let &l:formatprg = 'prettier --stdin-filepath %:t'

command! Format normal! mfgggqG`f
nnoremap <leader>af <cmd>Format<cr>
