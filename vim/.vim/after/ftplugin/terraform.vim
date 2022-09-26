setlocal formatprg=terraform\ fmt\ \-no-color\ \-
setlocal commentstring=#\ %s

function! TerraformStateCompletion(A,L,P) abort
    return filter(systemlist('terraform state list'),'v:val =~ a:A')
endfunction

command! -nargs=1 -complete=customlist,TerraformStateCompletion TFstate
            \ Terminal terraform state show <args>

let b:ale_fixers  = [ 'terraform', 'remove_trailing_lines', 'trim_whitespace']
let b:ale_linters = [ 'terraform', 'terraform_ls', 'tflint' ]

" make sure to: `stow ctags`
let g:tagbar_type_terraform = {
            \ 'ctagstype' : 'terraform',
            \ 'kinds' : [ 'r:Resources', 'd:Datas', 'v:Variables', 'p:Providers', 'o:Outputs', 'm:Modules', 'f:TFVars' ],
            \ 'sort': 1,
            \ 'deffile': expand('~') . '/.ctags.d/terraform.ctags',
            \ }
