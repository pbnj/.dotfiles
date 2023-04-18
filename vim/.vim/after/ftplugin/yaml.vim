let b:ale_fixers = [ 'remove_trailing_lines', 'trim_whitespace', 'prettier' ]
let b:ale_yaml_ls_config = {
                  \   'yaml': {
                  \     'schemaStore': {
                  \         'enable': v:true,
                  \     },
                  \   },
                  \ }

let &l:formatprg = 'prettier --stdin-filepath %:t'
setlocal formatoptions-=t
setlocal formatoptions+=croql

command! Format normal! mfgggqG`f
nnoremap <leader>af <cmd>Format<cr>

" Convert YAML to JSON or JSON to YAML
" Requires: yq
command! YJ terminal yq eval --tojson % > %:r.json
command! YAMLtoJSON terminal yq eval --tojson % > %:r.json
