if exists('g:loaded_gitvscodeweb') | finish | endif
let g:loaded_gitvscodeweb = 1

" GitBrowse takes a dictionary and opens files on remote git repo websites.
function! s:GitVSCodeWeb(args) abort
  let l:branch = len(a:args.branch) ? a:args.branch : 'origin'
  let l:remote = trim(system('git config branch.'.l:branch.'.remote'))
  let l:cmd = 'git vscodeweb ' . ((a:args.range) ? printf('%s %s %s %s',l:remote, a:args.filename, a:args.line1, a:args.line2) : printf('%s %s', l:remote, a:args.filename))
  echom l:cmd
  execute 'silent ! ' . l:cmd | redraw!
endfunction

" Launch project in VSCode Web instance
command! -range GitVSCodeWeb
      \ call s:GitVSCodeWeb({
      \   'branch': trim(system('git rev-parse --abbrev-ref HEAD 2>/dev/null')),
      \   'filename': trim(system('git ls-files --full-name ' .. expand('%'))),
      \   'range': <range>,
      \   'line1': <line1>,
      \   'line2': <line2>,
      \ })
