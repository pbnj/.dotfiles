let b:ale_linters = ['analyzer', 'cargo']

let &l:keywordprg=':!ddgr rust'

command! -bar WatchCargoCheck
                  \ <mods> call term_start('watchexec --clear cargo check')

command! -bar WatchCargoTest
                  \ <mods> call term_start('watchexec --clear cargo test')

command! -bar WatchCargoCheckTest WatchCargoCheck | vert WatchCargoTest
