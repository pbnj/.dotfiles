if exists('g:loaded_bufonly') | finish | endif
let g:loaded_bufonly = 1

command! BufOnly silent! execute '%bd | e# | bd#'
command! BOnly silent! execute '%bd | e# | bd#'
