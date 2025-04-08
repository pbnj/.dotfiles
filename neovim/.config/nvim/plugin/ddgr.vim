if !executable('ddgr') || exists('g:loaded_ddgr') | finish | endif
let g:loaded_ddgr = 1

function! s:ddgr_bang_completion(A,L,P) abort
  return filter(
        \ [ 'bangs'
        \ , 'archiveweb', 'archiveis'
        \ , 'aws', 'cloudformation', 'gcp', 'azure'
        \ , 'devdocs'
        \ , 'dictionary', 'mw', 'mwd', 'dmw', 'd'
        \ , 'dockerhub','dhdocs', 'kubernetes'
        \ , 'gh', 'ghcode', 'ghio', 'ghrepo', 'ght', 'ghtopic', 'ghuser', 'gist'
        \ , 'godoc', 'gopkg'
        \ , 'google', 'g', 'gdocs', 'gsheets', 'gslides', 'gmaps', 'amaps', 'gmail', 'gdefine', 'translate'
        \ , 'ker'
        \ , 'man', 'tldr', 'chtsh'
        \ , 'mysql', 'postgres'
        \ , 'node', 'npm', 'typescript', 'mdn'
        \ , 'python', 'py3'
        \ , 'rust', 'rustdoc', 'rce', 'rclippy', 'crates', 'docs.rs'
        \ , 'stackoverflow'
        \ , 'tmg'
        \ , 'vimw'
        \ , 'yt', 'reddit', 'twitch', 'devto', 'spotify'
        \ ], 'v:val =~ a:A')
endfunction

function! s:ddgr(args) range
  let args = a:args
  if empty(args)
    " Get the start and end positions of the visual selection
    let [line_start, column_start] = getpos("'<")[1:2]
    let [line_end, column_end] = getpos("'>")[1:2]
    " Get the selected text
    let lines = getline(line_start, line_end)
    " Handle single line selection
    if line_start == line_end
      let lines[0] = lines[0][column_start - 1 : column_end - 1]
    else
      " Handle multi-line selection
      let lines[0] = lines[0][column_start - 1 :]
      let lines[-1] = lines[-1][: column_end - 1]
    endif
    let args = join(lines, " ")
  endif
  let cmd = printf('! ddgr --expand %s', shellescape(args))
  execute cmd
endfunction

" function! s:ddgr(args) range
"   let l:args = a:args
"   if empty(l:args)
"     let l:args = join(getline(a:firstline, a:lastline), ' ')
"   endif
"   let l:cmd = printf('! ddgr --expand "%s"', l:args)
"   execute l:cmd
" endfunction
" command! -nargs=? -range -complete=customlist,s:ddgr_bang_completion DDGR <line1>,<line2>call s:ddgr(<q-args>)
command! -nargs=? -range -complete=customlist,s:ddgr_bang_completion DDGR call s:ddgr(<q-args>)
