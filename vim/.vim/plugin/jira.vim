if exists('g:loaded_jira') | finish | endif
let g:loaded_jira = 1

" Installer function
function! s:jira_install() abort
  if !executable('jira')
    if executable('brew')
      terminal brew install ankitpokhrel/jira-cli/jira-cli
    endif
  endif
endfunction
command! JiraInstall call s:jira_install()

" General Jira completion & command
function! s:jira_completion(A, L, P) abort
  return [
        \ 'board',
        \ 'completion',
        \ 'epic',
        \ 'help',
        \ 'init',
        \ 'issue',
        \ 'man',
        \ 'me',
        \ 'open',
        \ 'project',
        \ 'serverinfo',
        \ 'sprint',
        \ 'version',
        \ ]->filter('v:val =~ a:A')
endfunction
command! -nargs=* -complete=customlist,s:jira_completion Jira
      \ terminal jira <args>

" Jira Issue completion and command
function! s:jira_issue_completion(A, L, P) abort
  return [
        \ 'assign',
        \ 'clone',
        \ 'comment',
        \ 'create',
        \ 'delete',
        \ 'edit',
        \ 'link',
        \ 'list',
        \ 'move',
        \ 'unlink',
        \ 'view',
        \ 'watch',
        \ 'worklog',
        \ ]->filter('v:val =~ a:A')
endfunction
command! -nargs=* -complete=customlist,s:jira_issue_completion JiraIssue
      \ terminal jira issue <args>

" Open Jira issues in the browser
" If no Jira Key provided, then use current WORD under cursor
function! s:jira_open(jira_key) abort
  if empty(a:jira_key)
    call system(printf('jira open %s', expand('<cword>')))
    return
  endif
  call system(printf('jira open %s', a:jira_key))
  return
endfunction
command! -nargs=? -complete=customlist,s:jira_issue_completion JiraOpen
      \ call s:jira_open(<q-args>)
