setlocal comments=:#
setlocal commentstring=#\ %s
setlocal formatoptions-=t
setlocal formatoptions+=croql

" Convert YAML to JSON or JSON to YAML
" Requires: yq
command! YJ terminal yq eval --tojson % > %:r.json
command! YAMLtoJSON terminal yq eval --tojson % > %:r.json
