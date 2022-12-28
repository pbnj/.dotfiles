let b:ale_fixers = ['prettier', 'remove_trailing_lines', 'trim_whitespace']

setlocal formatprg=prettier\ --parser=markdown

" TOC generator
command! TOC
                  \ terminal npx doctoc --notitle --update-only %:p:h

" Mermaid
command! -nargs=+ MMDC
                  \ terminal npx -p @mermaid-js/mermaid-cli mmdc <args>
