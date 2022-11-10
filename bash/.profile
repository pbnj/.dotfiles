# shellcheck shell=bash
# SHELL OPTIONS

# set -o xtrace

if [[ "${BASH_VERSINFO:-0}" -ge 4 ]]; then
	shopt -s nocaseglob
	shopt -s histappend
	shopt -s dirspell
	shopt -s cdspell
	shopt -s autocd
	shopt -s globstar
fi

# BASH COMPLETION
[[ -f "/usr/local/etc/bash_completion" ]] && source "/usr/local/etc/bash_completion"
[[ -r "/usr/local/etc/profile.d/bash_completion.sh" ]] && source "/usr/local/etc/profile.d/bash_completion.sh"
[[ -f "/usr/share/bash-completion/bash_completion" ]] && source "/usr/share/bash-completion/bash_completion"
[[ -r "/opt/homebrew/etc/profile.d/bash_completion.sh" ]] && source "/opt/homebrew/etc/profile.d/bash_completion.sh"

# EXPORTS
[[ -f "${HOME}/.exports" ]] && source "${HOME}/.exports"

# FUNCTIONS
[ -f "${HOME}/.functions" ] && source "${HOME}/.functions"

# FZF
[ -f "${HOME}/.fzf.bash" ] && source "${HOME}/.fzf.bash"

# CARGO
[[ -f "${HOME}/.cargo/env" ]] && source "$HOME/.cargo/env"

# PROFILES & ALIASES
[[ -f "${HOME}/.aliases" ]] && source "${HOME}/.aliases"
[[ -f "${HOME}/.profile.work" ]] && source "${HOME}/.profile.work"

# DIRENV
hash direnv 2>/dev/null && eval "$(direnv hook bash)"
