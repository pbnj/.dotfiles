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
command! YJ Dispatch yq eval --tojson % > %:r.json
command! YAMLtoJSON Dispatch yq eval --tojson % > %:r.json

" Formatter
command! FMT Dispatch npx prettier --write %

let b:ale_fixers = ['prettier']
