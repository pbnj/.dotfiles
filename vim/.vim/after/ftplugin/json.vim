let b:ale_fixers = ['prettier']

setlocal expandtab
setlocal shiftwidth=2
setlocal softtabstop=2
setlocal formatprg=prettier\ --parser=json

" Sort json file
" Requires: jq
" Examples:
"	:JSONSort % " sort current json file
command! JSONSort
			\ execute '%! dasel --parser=json'

" Convert YAML to JSON or JSON to YAML
" Requires: yq
" Examples:
"	:JY % " convert current json file to yaml
command! JSONtoYAML execute 'silent !yq eval --prettyPrint % > %:r.yaml' | checktime | split %:r.yaml | redraw!
command! JY execute 'silent !yq eval --prettyPrint % > %:r.yaml' | checktime | split %:r.yaml | redraw!

" Formatter
command! FMT execute '! npx prettier --write %'
