" Compiler: actionlint
" Maintainer: Peter Benjamin
" Modified: 2025-03-19

if exists('current_compiler') | finish | endif
let current_compiler = 'actionlint'

if exists(':CompilerSet') != 2
  command -nargs=* CompilerSet setlocal <args>
endif

let s:save_cpo = &cpo
set cpo-=C

let &l:makeprg = 'actionlint %'
let &l:errorformat = '%f:%l:%c: %m'

silent CompilerSet makeprg
silent CompilerSet errorformat

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: sw=2 sts=2 et
