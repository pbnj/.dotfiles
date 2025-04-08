let &l:formatprg = 'terraform fmt -no-color -'
let &l:keywordprg = 'ddgr terraform'
let b:undo_ftplugin = 'setlocal formatprg< keywordprg<'

function! s:tfenv_completion(A, L, P)
  return filter([
        \ 'install',
        \ 'use',
        \ 'uninstall',
        \ 'list',
        \ 'list-remote',
        \ 'version-name',
        \ 'init',
        \ 'pin',
        \ ],
        \ 'v:val =~ a:A')
endfunction
command! -buffer -nargs=? -complete=customlist,s:tfenv_completion TFenv ! tfenv <args>

" TerraformStateCompletion provides terraform resource address suggestions to
" :TerraformStateShow command
function! s:terraform_state_completion(A, L, P) abort
  return systemlist(printf('terraform -chdir=%s state list', fnamemodify(expand('%'), ':h')))->filter('v:val =~ a:A')
endfunction
command! -buffer -nargs=? -complete=customlist,s:terraform_state_completion TerraformStateShow terminal terraform -chdir=%:h state show <args>

function! s:terraform_doc_completion(A, L, P) abort
  let l:cmd = 'terraform -chdir=' . fnamemodify(expand('%'), ':h') . ' show -json 2>/dev/null | jq -rc .values.root_module.resources[].provider_name'
  return systemlist(l:cmd)->uniq()->filter('v:val =~ a:A')
endfunction
" function! s:TerraformDocs(args) abort
" endfunction
command! -buffer -nargs=? -complete=customlist,s:terraform_doc_completion TerraformDocs
      \ ! carbonyl https://<args>
