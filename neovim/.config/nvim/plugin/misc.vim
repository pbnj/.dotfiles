if exists('g:loaded_misc') | finish | endif
let g:loaded_misc = 1

command! BrewUp terminal brew update && brew outdated && brew upgrade && brew cleanup
command! Btm terminal btm
