function! TerraformStateCompletion(A,L,P) abort
    return filter(systemlist('terraform state list'),'v:val =~ a:A')
endfunction

command! -nargs=? -complete=customlist,TerraformStateCompletion TFstate
            \ Terminal terraform state show <args>

let b:ale_fixers  = [ 'terraform', 'remove_trailing_lines', 'trim_whitespace']
let b:ale_linters = [ 'terraform', 'terraform_ls', 'tflint' ]
