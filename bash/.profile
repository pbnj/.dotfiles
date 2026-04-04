# vim:ft=bash:sts=2:ts=2:sw=2:et:
# shellcheck shell=bash

# set -x

# EXPORTS, ALIASES, & FUNCTIONS
# shellcheck disable=SC2206
files=(
  ${HOME}/.*exports
  ${HOME}/.*aliases
  ${HOME}/.*functions
  ${HOME}/.cargo/env
  "/opt/homebrew/etc/profile.d/bash_completion.sh"
)
for file in "${files[@]}"; do
  [ -f "${file}" ] && source "${file}"
done

# SHELL OPTIONS
if [ "${BASH_VERSINFO:-0}" -ge 4 ]; then
  shopt -s nocaseglob
  shopt -s histappend
  shopt -s dirspell
  shopt -s cdspell
  shopt -s autocd
  shopt -s globstar
fi
