setlocal formatprg=terraform\ fmt\ \-no-color\ \-

command! -nargs=* TF Terminal terraform -chdir=%:p:h <args>
command! TFfmt Terminal terraform fmt -recursive
command! TFplan Terminal terraform -chdir=%:p:h plan
command! TFapply
            \ Terminal terraform -chdir=%:p:h fmt && terraform -chdir=%:p:h validate && terraform -chdir=%:p:h apply
command! TFsec cexpr system('tfsec --format csv | grep -v ''file,start_line,'' | awk -F'','' ''{print $1":"$2": ["$5"] "$6}'' | sort')

function! TerraformStateCompletion(A,L,P) abort
    return filter(systemlist('terraform state list'),'v:val =~ a:A')
endfunction

command! -nargs=1 -complete=customlist,TerraformStateCompletion TFstate
            \ Terminal terraform state show <args>

let b:ale_fixers = [ 'terraform' ]

" make sure to: `stow ctags`
let g:tagbar_type_terraform = {
            \ 'ctagstype' : 'terraform',
            \ 'kinds' : [
                \ 'r:Resources',
                \ 'd:Datas',
                \ 'v:Variables',
                \ 'p:Providers',
                \ 'o:Outputs',
                \ 'm:Modules',
                \ 'f:TFVars'
                \ ],
            \ 'sort': 1,
            \ 'deffile': expand('~') . '/.ctags.d/terraform.ctags',
            \ }
