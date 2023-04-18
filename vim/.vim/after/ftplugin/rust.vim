let b:ale_fixers = [ 'remove_trailing_lines', 'trim_whitespace', 'analyzer', 'cargo' ]
let &l:keywordprg = ':!ddgr rustlang'
let &l:formatprg = 'cargo fmt'

command! Format normal! mfgggqG`f
nnoremap <leader>af <cmd>Format<cr>

command! -bar WatchCargoCheck
                  \ <mods> call term_start('watchexec --clear cargo check')

command! -bar WatchCargoTest
                  \ <mods> call term_start('watchexec --clear cargo test')

command! -bar WatchCargoCheckTest WatchCargoCheck | vert WatchCargoTest
