let b:ale_fixers = ['terraform', 'remove_trailing_lines', 'trim_whitespace']
let &l:keywordprg = ':!ddgr terraform'
let &l:formatprg = 'terraform fmt -'

" code expansions
iabbrev  tfdaip   <c-o>:read ~/.vim/templates/terraform/aws/data-aws-iam-policy.tf<cr><esc>
iabbrev  tfdaipd  <c-o>:read ~/.vim/templates/terraform/aws/data-aws-iam-policy-document.tf<cr><esc>
iabbrev  tfi      terraform import
iabbrev  tfr      resource "" "" {<cr>}<esc>3B
iabbrev  tfraip   <c-o>:read ~/.vim/templates/terraform/aws/aws-iam-policy.tf<cr><esc>
iabbrev  tfrair   <c-o>:read ~/.vim/templates/terraform/aws/aws-iam-role.tf<cr><esc>
iabbrev  tfraiu   <c-o>:read ~/.vim/templates/terraform/aws/aws-iam-user.tf<cr><esc>

function! TerraformStateCompletion(A,L,P) abort
    return filter(systemlist('terraform state list'),'v:val =~ a:A')
endfunction
function! TerraformStateShow(args) abort
    if empty(a:args)
        execute 'terminal ++shell terraform state list | fzf --reverse --multi --prompt ''Terraform State Show> '' | xargs -L1 terraform state show -no-color'
    else
        execute 'terminal terraform state show ' .. a:args
    endif
endfunction
command! -nargs=? -complete=customlist,TerraformStateCompletion TerraformStateShow call TerraformStateShow(<q-args>)

" call ale#linter#Define('terraform', {
"       \ 'name': 'tfsec',
"       \ 'executable': 'tfsec',
"       \ 'command': '%e -f csv %s | awk -F, ''{print $1":"$2":"$5" "$6}''',
"       \ 'language': 'terraform',
"       \ 'project_root': { _ -> expand('%p:h') },
"       \ 'callback': '',
"       \ })
