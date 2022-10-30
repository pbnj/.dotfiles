let b:ale_fixers = ['prettier', 'remove_trailing_lines', 'trim_whitespace']

" TOC generator
command! TOC
			\ Terminal npx doctoc --notitle --update-only %:p:h

" Mermaid
command! -nargs=+ MMDC
			\ Terminal npx -p @mermaid-js/mermaid-cli mmdc <args>
