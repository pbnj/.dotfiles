"         _            _
"   _ __ | |__  _ __  (_)
"  | '_ \| '_ \| '_ \ | |
"  | |_) | |_) | | | || |
"  | .__/|_.__/|_| |_|/ |
"  |_|              |__/
"
" Author:      Peter Benjamin
" Description: Minimal, 16-color colorscheme that works on light & dark terminals.

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

highlight clear

if v:version > 589
	highlight clear
	if exists('syntax_on')
		syntax reset
	endif
endif

let g:colors_name='pbnj'

highlight DiffAdd    NONE
highlight DiffChange NONE
highlight DiffDelete NONE
highlight ModeMsg    NONE
highlight NonText    NONE
highlight Normal     NONE
highlight SignColumn NONE
highlight SpecialKey NONE
highlight Visual     NONE

" terminal colors

highlight Comment      cterm=NONE           ctermfg=DarkGray   ctermbg=NONE
highlight CursorLineNr cterm=bold           ctermfg=NONE       ctermbg=NONE
highlight DiffAdd      cterm=NONE           ctermfg=DarkGreen  ctermbg=NONE
highlight DiffChange   cterm=NONE           ctermfg=DarkYellow ctermbg=NONE
highlight DiffDelete   cterm=NONE           ctermfg=DarkRed    ctermbg=NONE
highlight DiffText     cterm=bold,underline ctermfg=DarkGreen  ctermbg=NONE
highlight LineNr       cterm=NONE           ctermfg=DarkGray   ctermbg=NONE
highlight MatchParen   cterm=NONE           ctermfg=NONE       ctermbg=DarkGray
highlight NonText      cterm=NONE           ctermfg=DarkGray   ctermbg=NONE
highlight PmenuSel     cterm=underline      ctermfg=White      ctermbg=Magenta
highlight Search       cterm=NONE           ctermfg=Black      ctermbg=Yellow

" gui colors

highlight Comment      gui=NONE           guifg=Gray       guibg=NONE
highlight CursorLine   gui=NONE           guifg=NONE       guibg=Gray20
highlight CursorLineNr gui=bold           guifg=NONE       guibg=NONE
highlight DiffAdd      gui=NONE           guifg=DarkGreen  guibg=NONE
highlight DiffChange   gui=NONE           guifg=DarkYellow guibg=NONE
highlight DiffDelete   gui=NONE           guifg=DarkRed    guibg=NONE
highlight DiffText     gui=bold,underline guifg=DarkGreen  guibg=NONE
highlight LineNr       gui=NONE           guifg=Gray       guibg=NONE
highlight MatchParen   gui=NONE           guifg=NONE       guibg=Gray30
highlight NonText      gui=NONE           guifg=Gray       guibg=NONE
highlight PmenuSel     gui=underline      guifg=White      guibg=LightMagenta
highlight Search       gui=NONE           guifg=Black      guibg=Yellow

if &background ==# 'light'
	highlight CursorLine guibg=Gray95
	highlight MatchParen guibg=Gray80
endif

" ALE
highlight ALEError cterm=underline
highlight ALEInfo cterm=underline
highlight ALEWarning cterm=underline
highlight link ALEErrorSign Error
highlight link ALEInfoSign Todo
highlight link ALEWarningSign Todo

highlight link CurSearch Search
highlight link ModeMsg IncSearch
highlight link SpecialKey NonText
highlight link Visual IncSearch
highlight link diffAdded DiffAdd
highlight link diffChanged DiffChange
highlight link diffRemoved DiffDelete
