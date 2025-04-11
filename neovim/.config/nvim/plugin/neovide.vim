if exists('g:loaded_neovide_custom') && exists('g:neovide') | finish | endif
let g:loaded_neovide_custom = 1

" https://neovide.dev/faq.html#how-can-i-use-cmd-ccmd-v-to-copy-and-paste
cnoremap <D-v> <C-R>+
inoremap <D-v> <C-R>+
nnoremap <D-s> :w<cr>
nnoremap <D-v> "+P
vnoremap <D-c> "+y
vnoremap <D-v> "+P

let &title = 1
let &titlestring = '%F'

let g:neovide_opacity = 0.9
let g:neovide_window_blurred = v:true

" https://neovide.dev/faq.html#how-can-i-dynamically-change-the-scale-at-runtime
let g:neovide_scale_factor=1.0
function! ChangeScaleFactor(delta)
  let g:neovide_scale_factor = g:neovide_scale_factor * a:delta
endfunction
function! ResetScaleFactor()
  let g:neovide_scale_factor=1.0
endfunction
nnoremap <expr><D-=> ChangeScaleFactor(1.25)
nnoremap <expr><D--> ChangeScaleFactor(1/1.25)
nnoremap <expr><D-0> ResetScaleFactor()
