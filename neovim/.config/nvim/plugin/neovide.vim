if exists('g:loaded_neovide_custom') && exists('g:neovide') | finish | endif
let g:loaded_neovide_custom = 1

" Neovide specifics
cnoremap <D-v> <C-R>+
inoremap <D-v> <C-R>+
nnoremap <D-s> :w<cr>
nnoremap <D-v> "+P
vnoremap <D-c> "+y
vnoremap <D-v> "+P
let g:neovide_window_blurred = v:true
