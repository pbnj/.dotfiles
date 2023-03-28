let &l:keywordprg = ':!ddgr open policy agent'
let &l:formatprg = 'opa fmt'

command! Format normal! mfgggqG`f
nnoremap <leader>af <cmd>Format<cr>

" https://github.com/tsandall/vim-rego/blob/master/ftdetect/rego.vim
setlocal comments=b:#,fb:-
setlocal commentstring=#\ %s
