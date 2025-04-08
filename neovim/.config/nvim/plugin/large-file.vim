if exists('g:loaded_large_file') | finish | endif
let g:loaded_large_file = 1

" disable syntax if file is larger than 10MB (performance improvement)
augroup LARGEFILE
  autocmd!
  autocmd BufReadPost * if line2byte(line("$") + 1) > 1000000 | syntax clear | echo 'Syntax disabled on large files' | endif
augroup END

