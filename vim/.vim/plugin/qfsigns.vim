if exists('g:loaded_qfsigns')
  finish
endif
let g:loaded_qfsigns=1

sign define QFErr texthl=QFErrMarker text=E
sign define QFWarn texthl=QFWarnMarker text=W
sign define QFInfo texthl=QFInfoMarker text=I

augroup qfsigns
  autocmd!
  autocmd QuickFixCmdPre * call s:clear_signs()
  autocmd QuickFixCmdPost [^l]* call s:place_signs('qf')
  autocmd QuickFixCmdPost l* call s:place_signs('ll')
augroup END

nnoremap <Plug>(QfSignsPlace) :silent call <SID>place_signs()<CR>
nnoremap <Plug>(QfSignsClear) :silent call <SID>clear_signs()<CR>

let s:sign_count = 0

" Surface counts to .vimrc
let g:qfsigns_error = 0
let g:qfsigns_warn = 0
let g:qfsigns_info = 0

function! s:place_signs(list_type) abort
  let l:qfsigns_error = 0
  let l:qfsigns_warn = 0
  let l:qfsigns_info = 0

  if a:list_type == 'qf'
    let l:errors = getqflist()
  elseif a:list_type == 'll'
    let l:errors = getloclist(winnr())
  endif

  for l:error in l:errors
    if l:error.bufnr <= 0
      continue
    endif
    let s:sign_count = s:sign_count + 1
    if l:error.type ==# 'E'
      let l:qfsigns_error = l:qfsigns_error + 1
      let l:qf_sign = 'sign place ' . s:sign_count
            \ . ' priority=99'
            \ . ' line=' . l:error.lnum
            \ . ' name=QFErr'
            \ . ' buffer=' . l:error.bufnr
    elseif l:error.type ==# 'W'
      let l:qfsigns_warn = l:qfsigns_warn + 1
      let l:qf_sign = 'sign place ' . s:sign_count
            \ . ' priority=98'
            \ . ' line=' . l:error.lnum
            \ . ' name=QFWarn'
            \ . ' buffer=' . l:error.bufnr
    else
      let l:qfsigns_info = l:qfsigns_info + 1
      let l:qf_sign = 'sign place ' . s:sign_count
            \ . ' priority=97'
            \ . ' line=' . l:error.lnum
            \ . ' name=QFInfo'
            \ . ' buffer=' . l:error.bufnr
    endif
    silent! execute l:qf_sign
  endfor

  let g:qfsigns_error = l:qfsigns_error
  let g:qfsigns_warn = l:qfsigns_warn
  let g:qfsigns_info = l:qfsigns_info

endfunction

function! s:clear_signs() abort
  while s:sign_count > 0
    execute 'sign unplace ' . s:sign_count
    let s:sign_count = s:sign_count - 1
  endwhile
  redraw!
endfunction
