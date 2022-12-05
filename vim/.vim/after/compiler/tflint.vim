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
" data.tf:22:1: Warning - Missing version constraint for provider "1" in "required_providers" (terraform_required_providers)
" data.tf:22:1: Warning - data "1" "2" is declared but not used (terraform_unused_declarations)

let &cpo = s:cpo_save
unlet s:cpo_save
