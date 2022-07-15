setlocal expandtab
setlocal shiftwidth=2
setlocal softtabstop=2
setlocal textwidth=79
setlocal formatprg=prettier\ --parser=markdown

let b:ale_fixers = ['prettier']

" TOC generator
command! TOC
			\ Terminal npx doctoc --notitle --update-only %:p:h

" Mermaid
command! -nargs=+ MMDC
			\ Terminal npx -p @mermaid-js/mermaid-cli mmdc <args>
