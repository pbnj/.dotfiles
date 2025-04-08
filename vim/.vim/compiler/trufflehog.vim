" Compiler: trufflehog
" Maintainer: Peter Benjamin
" Last Modified: September 08, 2023

if exists('current_compiler') | finish | endif
let current_compiler = 'trufflehog'

if exists(':CompilerSet') != 2
  command -nargs=* CompilerSet setlocal <args>
endif

let s:save_cpo = &cpo
set cpo-=C

let &l:makeprg = 'trufflehog filesystem --only-verified --json . 2>/dev/null | jq -rc ''. | @text "\(.SourceMetadata.Data.Filesystem.file):\(.SourceMetadata.Data.Filesystem.line) \(.DetectorName) - \(.Raw)"'''
let &l:errorformat = '%f:%l %m'

silent CompilerSet makeprg
silent CompilerSet errorformat

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: sw=2 sts=2 ts=2 et
