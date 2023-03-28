let &l:keywordprg = ':!ddgr terraform'
let &l:formatprg = 'terraform fmt -'

command! Format normal! mfgggqG`f
nnoremap <leader>af <cmd>Format<cr>

function! TerraformStateCompletion(A,L,P) abort
    return filter(systemlist('terraform state list'),'v:val =~ a:A')
endfunction

command! -nargs=? -complete=customlist,TerraformStateCompletion TerraformStateShow
            \ <mods> terminal terraform state show <args>

command! -bar WatchAll
            \ WatchTest | vert WatchLint | vert WatchSec

command! -bar VWatchAll
            \ vert WatchTest | WatchLint | WatchSec

command! -bar WatchTest
            \ <mods> terminal watchexec -c terraform validate

command! -bar WatchLint
            \ <mods> terminal watchexec -c tflint

command! -bar WatchSec
            \ <mods> terminal watchexec -c tfsec
