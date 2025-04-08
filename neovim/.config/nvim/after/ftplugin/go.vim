" go install golang.org/x/tools/cmd/goimports@latest
if executable('goimports')
  let &l:formatprg = 'goimports'
else
  let &l:formatprg = 'gofmt'
endif

let b:undo_ftplugin = 'setlocal formatprg<'

" TODO: command to generate go tests
