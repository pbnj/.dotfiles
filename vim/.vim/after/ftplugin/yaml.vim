let &l:comments = '#'
let &l:commentstring = '# %s'
let &l:formatprg = 'prettier --stdin-filepath %:t'
setlocal formatoptions-=t
setlocal formatoptions+=croql

command! Format normal! mfgggqG`f
nnoremap <leader>af <cmd>Format<cr>

" Convert YAML to JSON or JSON to YAML
" Requires: yq
command! YJ terminal yq eval --tojson % > %:r.json
command! YAMLtoJSON terminal yq eval --tojson % > %:r.json
