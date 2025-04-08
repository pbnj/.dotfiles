if exists('g:visual_selection_search') | finish | endif
let g:visual_selection_search = 1

xnoremap * :<C-u>call <SID>visual_selection_search()<CR>/<C-R>=@/<CR><CR>
xnoremap # :<C-u>call <SID>visual_selection_search()<CR>?<C-R>=@/<CR><CR>

function! s:visual_selection_search()
    let temp = @s
    norm! gv"sy
    let @/ = '\V' . substitute(escape(@s, '/\'), '\n', '\\n','g')
    let @s = temp
endfunction
