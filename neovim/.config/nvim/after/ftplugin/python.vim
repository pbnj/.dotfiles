let &l:expandtab = 1
let &l:formatprg = 'ruff format'
let &l:shiftwidth = 4
let &l:softtabstop = -1 " use shiftwidth value
let &l:tabstop = 4

let b:undo_ftplugin = 'setlocal formatprg< expandtab< shiftwidth< softtabstop< tabstop<'
