let b:ale_fixers = ['prettier', 'remove_trailing_lines', 'trim_whitespace']

setlocal formatprg=prettier\ --parser=markdown

" TOC generates table of contents
command! TOC
                  \ terminal npx -y doctoc --notitle --update-only %:p:h

" Mermaid
command! -nargs=+ MMDC
                  \ terminal npx -p @mermaid-js/mermaid-cli mmdc <args>
