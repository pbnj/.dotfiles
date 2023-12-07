# shellcheck shell=bash

# SHELL OPTIONS
if [ "${BASH_VERSINFO:-0}" -ge 4 ]; then
	shopt -s nocaseglob
	shopt -s histappend
	shopt -s dirspell
	shopt -s cdspell
	shopt -s autocd
	shopt -s globstar
fi

# EXPORTS
[ -f "${HOME}/.exports" ] && . "${HOME}/.exports"

# FUNCTIONS
[ -f "${HOME}/.functions" ] && . "${HOME}/.functions"

# CARGO
[ -f "${HOME}/.cargo/env" ] && . "${HOME}/.cargo/env"

# PROFILES & ALIASES
[ -f "${HOME}/.aliases" ] && . "${HOME}/.aliases"
[ -f "${HOME}/.profile.work" ] && . "${HOME}/.profile.work"

# BASH COMPLETION
[ -r "/opt/homebrew/etc/profile.d/bash_completion.sh" ] && . "/opt/homebrew/etc/profile.d/bash_completion.sh"

# FZF
[ -f ~/.fzf.bash ] && . ~/.fzf.bash

# PROMPT
export PS1="\\n\w \$(git branch --show-current 2>/dev/null | awk '{print \"[\"\$0\"]\"}')\\n\\$ "

# STARSHIP
hash starship 2>/dev/null && eval "$(starship init bash)"

# DIRENV
hash direnv 2>/dev/null && eval "$(direnv hook bash)"
