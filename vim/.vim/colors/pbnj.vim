" vim:et:sw=2:sts=2:ts=2:
"         _            _
"   _ __ | |__  _ __  (_)
"  | '_ \| '_ \| '_ \ | |
"  | |_) | |_) | | | || |
"  | .__/|_.__/|_| |_|/ |
"  |_|              |__/
"
" Author:      Peter Benjamin
" Description: Slightly modified/improved version of default Vim colorscheme

" :help cterm-colors

" NR-16 NR-8 COLOR-NAME
" 0     0    Black
" 1     4    DarkBlue
" 2     2    DarkGreen
" 3     6    DarkCyan
" 4     1    DarkRed
" 5     5    DarkMagenta
" 6     3    Brown,     DarkYellow
" 7     7    LightGray, LightGrey, Gray, Grey
" 8     0*   DarkGray,  DarkGrey
" 9     4*   Blue,      LightBlue
" 10    2*   Green,     LightGreen
" 11    6*   Cyan,      LightCyan
" 12    1*   Red,       LightRed
" 13    5*   Magenta,   LightMagenta
" 14    3*   Yellow,    LightYellow
" 15    7*   White

highlight! clear
if exists("g:syntax_on") | syntax reset | endif
let g:colors_name='pbnj'

highlight!  Comment      cterm=none          ctermfg=DarkGray    ctermbg=none
highlight!  CurSearch    cterm=reverse       ctermfg=DarkRed     ctermbg=none
highlight!  DiffAdd      cterm=reverse       ctermfg=DarkGreen   ctermbg=none
highlight!  diffAdded    cterm=none          ctermfg=DarkGreen   ctermbg=none
highlight!  DiffChange   cterm=reverse       ctermfg=DarkYellow  ctermbg=none
highlight!  DiffDelete   cterm=reverse       ctermfg=DarkRed     ctermbg=none
highlight!  diffDiffer   cterm=none          ctermfg=DarkYellow  ctermbg=none
highlight!  diffRemoved  cterm=none          ctermfg=DarkRed     ctermbg=none
highlight!  DiffText     cterm=bold,reverse  ctermfg=DarkYellow  ctermbg=none
highlight!  LineNr       cterm=none          ctermfg=DarkGray    ctermbg=none
highlight!  MatchParen   cterm=bold          ctermfg=none        ctermbg=none
highlight!  NonText      cterm=none          ctermfg=DarkGray    ctermbg=none
highlight!  Pmenu        cterm=none          ctermfg=Black       ctermbg=Magenta
highlight!  PmenuMatch   cterm=bold          ctermfg=Black       ctermbg=none
highlight!  PmenuSel     cterm=bold          ctermfg=Black       ctermbg=Gray
highlight!  SpecialKey   cterm=none          ctermfg=DarkGray    ctermbg=none
highlight!  ColorColumn  cterm=none          ctermfg=none        ctermbg=Black
