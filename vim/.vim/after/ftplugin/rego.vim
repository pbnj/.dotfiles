let b:ale_fixers = ['opa', 'remove_trailing_lines', 'trim_whitespace']

" https://github.com/tsandall/vim-rego/blob/master/ftdetect/rego.vim
setlocal comments=b:#,fb:-
setlocal commentstring=#\ %s

setlocal formatprg=opa\ fmt
