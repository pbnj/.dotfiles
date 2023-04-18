let b:ale_fixers = [ 'remove_trailing_lines', 'trim_whitespace', 'goimports' ]
let &l:keywordprg = ':!ddgr golang'
let &l:formatprg = 'goimports'

command! Format normal! mfgggqG`f
nnoremap <leader>af <cmd>Format<cr>

" Install additional Go tooling
command! GoInstallTools
      \   call term_start('go install golang.org/x/tools/...@latest', #{ term_finish: 'close' })
      \ | call term_start('go install github.com/cweill/gotests/...@latest', #{ term_finish: 'close' })
