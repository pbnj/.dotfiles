if exists("current_compiler")
  finish
endif
let current_compiler = "shellcheck"

if exists(":CompilerSet") != 2
	command -nargs=* CompilerSet setlocal <args>
endif

let s:cpo_save = &cpo
set cpo&vim

CompilerSet makeprg=yamllint\ --format=parsable
CompilerSet errorformat=%f:%l:%c:\ [%trror]\ %m,
		       \%f:%l:%c:\ [%tarning]\ %m

let &cpo = s:cpo_save
unlet s:cpo_save
