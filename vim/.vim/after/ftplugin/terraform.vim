let b:ale_fixers  = [ 'terraform', 'remove_trailing_lines', 'trim_whitespace']
let b:ale_linters = [ 'terraform', 'terraform_ls', 'tflint' ]

setlocal keywordprg=:!ddgr\ terraform
setlocal formatprg=terraform\ fmt\ -

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
