" Install additional Go tooling
command! GoInstallTools call term_start('go install golang.org/x/tools/...@latest', #{ term_finish: 'close' })
			\ | call term_start('go install github.com/cweill/gotests/...@latest', #{ term_finish: 'close' })

command! FMT execute '! goimports -w %'

let b:ale_fixers = ['goimports']
