# vim:ft=bash:sts=2:ts=2:sw=2:et:
# shellcheck shell=bash

# EXPORTS
[ -f "${HOME}/.exports" ] && . "${HOME}/.exports"

# SHELL OPTIONS
if [ "${BASH_VERSINFO:-0}" -ge 4 ]; then
  shopt -s nocaseglob
  shopt -s histappend
  shopt -s dirspell
  shopt -s cdspell
  shopt -s autocd
  shopt -s globstar
  # BASH COMPLETION
  [ -r "/opt/homebrew/etc/profile.d/bash_completion.sh" ] && . "/opt/homebrew/etc/profile.d/bash_completion.sh"
fi

# CARGO
[ -f "${HOME}/.cargo/env" ] && . "${HOME}/.cargo/env"

# PROFILES & ALIASES
[ -f "${HOME}/.aliases" ] && . "${HOME}/.aliases"
[ -f "${HOME}/.profile.work" ] && . "${HOME}/.profile.work"
[ -f "${HOME}/.env" ] && . "${HOME}/.env"

# FZF
[ -f ~/.fzf.bash ] && eval "$(fzf --bash)"

# FUNCTIONS
[ -f "${HOME}/.functions" ] && . "${HOME}/.functions"

# ARGOCD
[ -f "${HOME}/.config/argocd/completion" ] && . "${HOME}/.config/argocd/completion"

# STARSHIP
command -v starship &>/dev/null && eval "$(starship init bash)"
