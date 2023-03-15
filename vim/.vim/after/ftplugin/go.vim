let b:ale_fixers = ['goimports', 'remove_trailing_lines', 'trim_whitespace']

let &l:keywordprg=':!ddgr golang'

" Install additional Go tooling
command! GoInstallTools
      \ call term_start('go install golang.org/x/tools/...@latest', #{ term_finish: 'close' })
      \ | call term_start('go install github.com/cweill/gotests/...@latest', #{ term_finish: 'close' })
