# vim:ft=bash:sts=2:ts=2:sw=2:et:
# shellcheck shell=bash

# EXPORTS, ALIASES, & FUNCTIONS
# shellcheck disable=SC2206
files=(${HOME}/.*exports ${HOME}/.*aliases ${HOME}/.*functions)
for file in "${files[@]}"; do
  # shellcheck disable=SC1090
  source "${file}"
done

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

# NVM
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && . "/opt/homebrew/opt/nvm/nvm.sh"

# FZF
[ -f ~/.fzf.bash ] && eval "$(fzf --bash)"

# FUNCTIONS
[ -f "${HOME}/.functions" ] && . "${HOME}/.functions"

# STARSHIP
command -v starship &>/dev/null && eval "$(starship init bash)"
