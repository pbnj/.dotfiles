let b:ale_fixers = [ 'remove_trailing_lines', 'trim_whitespace', 'jq' ]
let &l:formatprg = 'prettier --stdin-filepath %:t'

command! Format normal! mfgggqG`f
nnoremap <leader>af <cmd>Format<cr>
