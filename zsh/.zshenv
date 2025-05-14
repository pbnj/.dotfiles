# vim:ft=zsh:ts=2:sw=2:sts=2:et:
# shellcheck disable=all

# `.zshenv' is sourced on all invocations of the shell, unless the -f option is
# set. It should contain commands to set the command search path, plus other
# important environment variables.
# `.zshenv' should not contain commands that
# produce output or assume the shell is attached to a tty.

# General
export EDITOR=nvim
export FZF_DEFAULT_COMMAND="fd --type file --follow --hidden"
export FZF_CTRL_T_COMMAND="${FZF_DEFAULT_COMMAND}"
export FZF_DEFAULT_OPTS_FILE="${HOME}/.config/fzf/config"
export GIT_TERMINAL_PROMPT=1
export HISTCONTROL=ignoreboth
export RIPGREP_CONFIG_PATH="${HOME}/.config/ripgrep/.ripgreprc"

# PATH
typeset -U path PATH

path+=(~/.local/bin)
path+=(~/.aws)
path+=(~/.local/share/nvim/mason/bin)

# Go
export GODEBUG=x509ignoreCN=0
export GOPATH="${HOME}/go"
path+=(${HOME}/go/bin)

# 1Password Agent
if [[ -S "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock" ]]; then
  export SSH_AUTH_SOCK="~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
fi

# PATH (must be last)
export -U PATH
