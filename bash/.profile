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

# FZF
[ -f ~/.fzf.bash ] && . ~/.fzf.bash

# FUNCTIONS
[ -f "${HOME}/.functions" ] && . "${HOME}/.functions"

# DIRENV
hash direnv 2>/dev/null && eval "$(direnv hook bash)"
