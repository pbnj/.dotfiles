setlocal formatprg=terraform\ fmt\ -
compiler tflint

function! TerraformStateCompletion(A,L,P) abort
    return filter(systemlist('terraform state list'),'v:val =~ a:A')
endfunction

command! -nargs=? -complete=customlist,TerraformStateCompletion TFstate
            \ Terminal terraform state show <args>
