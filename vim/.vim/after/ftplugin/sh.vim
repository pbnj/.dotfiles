setlocal formatprg=shfmt\ -ln\ posix\ -sr\ -ci\ -s

let b:ale_fixers = ['shfmt']

command! Lint cexpr system('shellcheck --format=gcc ' . expand('%'))
command! Format execute '! shfmt -ln posix -sr -ci -s -w ' . expand('%')
