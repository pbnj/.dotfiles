if exists('g:loaded_cheat') | finish | endif
let g:loaded_cheat = 1

command! -nargs=? Cheat
      \ <mods> terminal curl https://cheat.sh/<args>
