let &l:formatprg = 'npx prettier --stdin-filepath=%'
let b:undo_ftplugin = 'setlocal formatprg<'

" Initialize Table of Contents
command! -buffer -nargs=0 TocInit
      \ call append(4, ['<!-- START doctoc generated TOC please keep comment here to allow auto update -->', '<!-- DON''T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->', '', '<!-- END doctoc generated TOC please keep comment here to allow auto update -->', ''])

" Generate Table of Contents
command! -buffer -nargs=0 TocUpdate
      \ !npx doctoc --no-title %
