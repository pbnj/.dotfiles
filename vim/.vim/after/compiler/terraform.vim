if exists("current_compiler")
  finish
endif
let current_compiler = "terraform"

if exists(":CompilerSet") != 2
	command -nargs=* CompilerSet setlocal <args>
endif

let s:cpo_save = &cpo
set cpo&vim

CompilerSet makeprg=terraform\ $*\ -no-color
" CompilerSet errorformat=%f:%l:%c:\ [%trror]\ %m,

let &cpo = s:cpo_save
unlet s:cpo_save
