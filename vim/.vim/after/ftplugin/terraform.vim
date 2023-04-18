let g:ale_fixers = [ 'remove_trailing_lines', 'trim_whitespace', 'terraform' ]
let &l:keywordprg = ':!ddgr terraform'
let &l:formatprg = 'terraform fmt -'

iabbrev  tfdaip   <c-o>:read ~/.vim/templates/terraform/aws/data-aws-iam-policy.tf<cr><esc>
iabbrev  tfdaipd  <c-o>:read ~/.vim/templates/terraform/aws/data-aws-iam-policy-document.tf<cr><esc>
iabbrev  tfraip   <c-o>:read ~/.vim/templates/terraform/aws/aws-iam-policy.tf<cr><esc>
iabbrev  tfrair   <c-o>:read ~/.vim/templates/terraform/aws/aws-iam-role.tf<cr><esc>
iabbrev  tfraiu   <c-o>:read ~/.vim/templates/terraform/aws/aws-iam-user.tf<cr><esc>
iabbrev  tfi      terraform import

command! Format !terraform fmt %
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
