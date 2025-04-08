if exists('g:loaded_precommit') | finish | endif
let g:loaded_precommit = 1

function! s:precommit_completion(A, L, P) abort
  return [
        \ 'autoupdate',
        \ 'clean',
        \ 'gc',
        \ 'init-templatedir',
        \ 'install',
        \ 'install-hooks',
        \ 'migrate-config',
        \ 'run',
        \ 'sample-config',
        \ 'try-repo',
        \ 'uninstall',
        \ 'validate-config',
        \ 'validate-manifest',
        \ 'help',
        \ ]->filter('v:val =~ a:A')
endfunction

command! -nargs=* -complete=customlist,s:precommit_completion Precommit
      \ <mods> terminal pre-commit <args>

command! -nargs=1 -complete=file_in_path PrecommitRun
      \ <mods> terminal pre-commit run --files <args>
