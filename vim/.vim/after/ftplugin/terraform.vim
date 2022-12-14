setlocal formatprg=terraform\ fmt\ -

function! TerraformStateCompletion(A,L,P) abort
    return filter(systemlist('terraform state list'),'v:val =~ a:A')
endfunction

command! -nargs=? -complete=customlist,TerraformStateCompletion TerraformStateShow
            \ terminal terraform state show <args>

augroup fixer_terraform
    autocmd! * <buffer>
    autocmd BufWritePre,FileWritePre <buffer> TerraformFmt
augroup END
