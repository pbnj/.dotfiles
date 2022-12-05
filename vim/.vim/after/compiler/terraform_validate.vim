if exists("current_compiler")
  finish
endif
let current_compiler = "terraform_validate"

if exists(":CompilerSet") != 2
	command -nargs=* CompilerSet setlocal <args>
endif

let s:cpo_save = &cpo
set cpo&vim

CompilerSet makeprg=terraform\ validate\ -no-color
" CompilerSet errorformat=%f:%l:%c:\ [%trror]\ %m,

let &cpo = s:cpo_save
unlet s:cpo_save
