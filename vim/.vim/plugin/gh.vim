if exists('g:loaded_gh') | finish | endif
let g:loaded_gh = 1

" Custom Vim command for `gh` tool with completion for subcommand names
function! s:gh_completion(A,L,P) abort
  return filter(
        \ [
        \   'alias',
        \   'api',
        \   'auth',
        \   'browse',
        \   'codespace',
        \   'config',
        \   'extension',
        \   'gist',
        \   'gpg-key',
        \   'issue',
        \   'label',
        \   'org',
        \   'pr',
        \   'project',
        \   'release',
        \   'repo',
        \   'run',
        \   'search',
        \   'secret',
        \   'ssh-key',
        \   'status',
        \   'variable',
        \   'workflow',
        \   '--help',
        \ ],
        \ 'v:val =~ a:A' )
endfunction

command! -nargs=* -complete=customlist,s:gh_completion GH
      \ terminal gh <args>

" REPO subcommand
function! s:gh_repo_completion(A,L,P) abort
  let l:org_repo = split(a:A, '/')
  let l:org = l:org_repo[0]
  let l:repo = ""
  if len(l:org_repo) == 2
    let l:repo = l:org_repo[1]
  endif
  return filter(systemlist(printf('gh repo list --json=nameWithOwner --jq .[].nameWithOwner %s', l:org)) ,'v:val =~ l:repo' )
endfunction

" REPO VIEW
command! -nargs=1 -complete=customlist,s:gh_repo_completion GHRepoView
      \ terminal gh repo view <args>

" REPO CLONE
command! -nargs=1 -complete=customlist,s:gh_repo_completion GHRepoClone
      \ exe 'terminal gh repo clone <args> ' . expand('~/Projects/github.com/<args>')

" PR subcommand
function! s:gh_pr_completion(A,L,P) abort
  return filter(
        \ [
        \   'create',
        \   'list',
        \   'status',
        \   'checkout',
        \   'checks',
        \   'close',
        \   'comment',
        \   'diff',
        \   'edit',
        \   'lock',
        \   'merge',
        \   'ready',
        \   'reopen',
        \   'review',
        \   'unlock',
        \   'view',
        \   '-R', '--repo',
        \   '--help',
        \ ], 'v:val =~ a:A')
endfunction

command! -nargs=* -complete=customlist,s:gh_pr_completion GHPR
      \ terminal gh pr <args>

" RUN subcommand
function! s:gh_run_completion(A,L,P) abort
  return filter(
        \ [
        \   'cancel',
        \   'delete',
        \   'download',
        \   'list',
        \   'rerun',
        \   'view',
        \   'watch',
        \   '-R', '--repo',
        \   '--help',
        \ ], 'v:val =~ a:A')
endfunction

command! -nargs=* -complete=customlist,s:gh_run_completion GHRun
      \ terminal gh run <args>

function! s:gh_run_view_completion(A,L,P) abort
  return filter(systemlist('gh run list --json=databaseId --jq .[].databaseId'), 'v:val =~ a:A')
endfunction

command! -nargs=* -complete=customlist,s:gh_run_view_completion GHRunView
      \ terminal gh run view <args>
command! -nargs=* -complete=customlist,s:gh_run_view_completion GHRunLog
      \ terminal gh run view --log <args>
command! -nargs=* GHRunWatch
      \ terminal gh run watch <args>

" WORKFLOW
function! s:gh_workflow_completion(A,L,P) abort
  return filter(systemlist('gh workflow list --json=name --jq .[].name'), 'v:val =~ a:A')
endfunction
command! -nargs=1 -complete=customlist,s:gh_workflow_completion GHWorkflowRun
      \ exe 'terminal gh workflow run ' .. shellescape('<args>')

" SEARCH
function! s:gh_search_completion(A, L, P) abort
  return [
        \ '--extension=',
        \ '--filename=',
        \ '--jq=',
        \ '--json=',
        \ '--language=',
        \ '--limit=30',
        \ '--owner=',
        \ '--repo=',
        \ '--web',
        \ ]->filter('v:val =~ a:A')
endfunction
command! -nargs=* -complete=customlist,s:gh_search_completion GHSearchCode
      \ terminal gh search code <args>
