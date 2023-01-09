# shellcheck shell=bash

# set -x

# SHELL OPTIONS
if [[ "${BASH_VERSINFO:-0}" -ge 4 ]]; then
	shopt -s nocaseglob
	shopt -s histappend
	shopt -s dirspell
	shopt -s cdspell
	shopt -s autocd
	shopt -s globstar
fi

# EXPORTS
[[ -f "${HOME}/.exports" ]] && source "${HOME}/.exports"

# FUNCTIONS
[ -f "${HOME}/.functions" ] && source "${HOME}/.functions"

# CARGO
[[ -f "${HOME}/.cargo/env" ]] && source "$HOME/.cargo/env"

# PROFILES & ALIASES
[[ -f "${HOME}/.aliases" ]] && source "${HOME}/.aliases"
[[ -f "${HOME}/.profile.work" ]] && source "${HOME}/.profile.work"

# BASH COMPLETION
[[ -f "/usr/local/etc/bash_completion" ]] && source "/usr/local/etc/bash_completion"
[[ -r "/usr/local/etc/profile.d/bash_completion.sh" ]] && source "/usr/local/etc/profile.d/bash_completion.sh"
[[ -f "/usr/share/bash-completion/bash_completion" ]] && source "/usr/share/bash-completion/bash_completion"
[[ -r "/opt/homebrew/etc/profile.d/bash_completion.sh" ]] && source "/opt/homebrew/etc/profile.d/bash_completion.sh"

# PROMPT
if hash __git_ps1 2>/dev/null; then
	export GIT_PS1_SHOWDIRTYSTATE="true"
	export GIT_PS1_SHOWUNTRACKEDFILES="true"
	export GIT_PS1_SHOWUPSTREAM="auto"
	export GIT_PS1_SHOWSTASHSTATE="true"
	export GIT_PS1_HIDE_IF_PWD_IGNORED="false"
	export GIT_PS1_SHOWCOLORHINTS="true"
	export PROMPT_COMMAND='__git_ps1 "\\n" "\\n\\\$ "'
else
	export PS1="\\n\\$ "
fi

# DIRENV
hash direnv 2>/dev/null && eval "$(direnv hook bash)"
