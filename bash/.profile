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

# Load every key whose passphrase is already in the login Keychain into the
# agent macOS is already running. No key paths here on purpose: adding a key
# once with `ssh-add --apple-use-keychain ~/.ssh/<key>` is all it takes to have
# it picked up from then on. Skipped when the agent already holds keys.
if [[ "$(uname)" == "Darwin" ]] && [[ -S "${SSH_AUTH_SOCK:-}" ]]; then
  ssh-add -l >/dev/null 2>&1 || ssh-add --apple-load-keychain -q 2>/dev/null
fi

eval "$(direnv hook bash)"
