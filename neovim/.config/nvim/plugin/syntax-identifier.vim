if exists('g:loaded_syntax_identifier') | finish | endif
let g:loaded_syntax_identifier = 1

command! SynID echo synIDattr(synID(line("."), col("."), 1), "name")
