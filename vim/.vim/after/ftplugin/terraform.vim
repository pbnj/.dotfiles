setlocal formatprg=terraform\ fmt\ -

function! TerraformStateCompletion(A,L,P) abort
    return filter(systemlist('terraform state list'),'v:val =~ a:A')
endfunction

command! -nargs=? -complete=customlist,TerraformStateCompletion TerraformStateShow
            \ <mods> terminal terraform state show <args>

command! -bar TFWatchValidate
            \ <mods> terminal watchexec -c terraform validate

command! -bar TFWatchLint
            \ <mods> terminal watchexec -c tflint

command! -bar TFWatchSec
            \ <mods> terminal watchexec -c tfsec

command! -bar TFWatchAll
            \ <mods> TFWatchLint | <mods> TFWatchSec

augroup fixer_terraform
    autocmd! * <buffer>
    autocmd BufWritePre,FileWritePre <buffer> TerraformFmt
augroup END
