if exists('g:loaded_win_resize') | finish | endif
let g:loaded_win_resize = 1

" automatically re-balance window sizes
augroup RESIZE
  autocmd!
  autocmd VimResized * wincmd =
augroup END
