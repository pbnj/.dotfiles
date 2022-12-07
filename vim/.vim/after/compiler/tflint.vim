if exists("current_compiler")
  finish
endif
let current_compiler = "tflint"

if exists(":CompilerSet") != 2
	command -nargs=* CompilerSet setlocal <args>
endif

let s:cpo_save = &cpo
set cpo&vim

CompilerSet makeprg=tflint\ --format=compact\ $*
CompilerSet errorformat=%f:%l:%c:\ %trror\ -\ %m,%f:%l:%c:\ %tarning\ -\ %m,%f:%l:%c:\ -\ %totice\ %m

let &cpo = s:cpo_save
unlet s:cpo_save
