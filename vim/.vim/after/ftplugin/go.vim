" vim:ts=2:sts=2:sw=2:et:
" Install additional Go tooling
command! GoInstallTools
      \ call term_start('go install golang.org/x/tools/...@latest', #{ term_finish: 'close' })
      \ | call term_start('go install github.com/cweill/gotests/...@latest', #{ term_finish: 'close' })
