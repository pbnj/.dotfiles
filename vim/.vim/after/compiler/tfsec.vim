if exists("current_compiler")
  finish
endif
let current_compiler = "tfsec"

if exists(":CompilerSet") != 2
	command -nargs=* CompilerSet setlocal <args>
endif

let s:cpo_save = &cpo
set cpo&vim

CompilerSet makeprg=tfsec\ --format=csv\ --force-all-dirs\ --exclude-downloaded-modules
CompilerSet errorformat=%f\\,%l\\,%e\\,%m

let &cpo = s:cpo_save
unlet s:cpo_save
