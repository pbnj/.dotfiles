"         _            _
"   _ __ | |__  _ __  (_)
"  | '_ \| '_ \| '_ \ | |
"  | |_) | |_) | | | || |
"  | .__/|_.__/|_| |_|/ |
"  |_|              |__/
"
" Author: Peter Benjamin <petermbenjamin@gmail.com>
" Description: Minimal, dark, 16-color colorscheme that improves on vim's default colorscheme.

" :help cterm-colors
" NR-16   NR-8    COLOR NAME
" 0 	    0 	    Black
" 1 	    4 	    DarkBlue
" 2 	    2 	    DarkGreen
" 3 	    6 	    DarkCyan
" 4 	    1 	    DarkRed
" 5 	    5 	    DarkMagenta
" 6 	    3 	    Brown, DarkYellow
" 7 	    7 	    LightGray, LightGrey, Gray, Grey
" 8 	    0*	    DarkGray, DarkGrey
" 9 	    4*	    Blue, LightBlue
" 10	    2*	    Green, LightGreen
" 11	    6*	    Cyan, LightCyan
" 12	    1*	    Red, LightRed
" 13	    5*	    Magenta, LightMagenta
" 14	    3*	    Yellow, LightYellow
" 15	    7*	    White

highlight clear

if v:version > 589
	highlight clear
	if exists('syntax_on')
		syntax reset
	endif
endif

let g:colors_name='pbnj'

highlight SignColumn NONE
highlight Normal NONE
highlight DiffAdd NONE
highlight DiffChange NONE
highlight DiffDelete NONE
highlight SpecialKey NONE
highlight NonText NONE
highlight Visual NONE
highlight ModeMsg NONE

highlight Comment ctermfg=Gray
highlight Comment guifg=Gray
highlight CursorLine guibg=Gray20
highlight DiffAdd ctermfg=DarkGreen ctermbg=NONE
highlight DiffAdd guifg=DarkGreen guibg=NONE
highlight DiffChange ctermfg=DarkYellow ctermbg=NONE
highlight DiffChange guifg=DarkYellow guibg=NONE
highlight DiffDelete ctermfg=DarkRed ctermbg=NONE
highlight DiffDelete guifg=DarkRed guibg=NONE
highlight DiffText cterm=bold,underline ctermfg=DarkYellow ctermbg=NONE
highlight DiffText gui=bold,underline guifg=DarkYellow guibg=NONE
highlight LineNr ctermfg=Gray
highlight LineNr guifg=Gray
highlight MatchParen cterm=NONE ctermbg=DarkGray
highlight MatchParen gui=NONE guibg=Gray30
highlight NonText ctermfg=Gray
highlight NonText guifg=Gray
highlight Search ctermbg=Yellow ctermfg=Black
highlight Search guibg=Yellow guifg=Black

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
highlight link diffAdded DiffAdd
highlight link diffChanged DiffChange
highlight link diffRemoved DiffDelete
highlight link ModeMsg IncSearch
highlight link SpecialKey NonText
highlight link Visual IncSearch
