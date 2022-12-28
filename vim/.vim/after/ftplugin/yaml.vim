let b:ale_fixers  = [ 'prettier', 'remove_trailing_lines', 'trim_whitespace']

setlocal comments=:#
setlocal commentstring=#\ %s
setlocal expandtab
setlocal formatoptions-=t
setlocal formatoptions+=croql
setlocal shiftwidth=2
setlocal softtabstop=2
setlocal formatprg=prettier\ --parser=yaml

" Convert YAML to JSON or JSON to YAML
" Requires: yq
command! YJ terminal yq eval --tojson % > %:r.json
command! YAMLtoJSON terminal yq eval --tojson % > %:r.json
