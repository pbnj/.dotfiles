setlocal formatprg=terraform\ fmt\ -

function! TerraformStateCompletion(A,L,P) abort
    return filter(systemlist('terraform state list'),'v:val =~ a:A')
endfunction

command! -bar WatchTFAll
            \ WatchTFValidate | vert WatchTFLint | vert WatchTFSec

command! -bar VWatchTFAll
            \ vert WatchTFValidate | WatchTFLint | WatchTFSec

command! -nargs=? -complete=customlist,TerraformStateCompletion TerraformStateShow
            \ <mods> terminal terraform state show <args>

command! -bar WatchTFValidate
            \ <mods> terminal watchexec -c terraform validate

command! -bar WatchTFLint
            \ <mods> terminal watchexec -c tflint

command! -bar WatchTFSec
            \ <mods> terminal watchexec -c tfsec

augroup fixer_terraform
    autocmd! * <buffer>
    autocmd BufWritePre,FileWritePre <buffer> TerraformFmt
augroup END
