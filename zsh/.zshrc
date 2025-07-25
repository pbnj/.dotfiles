# vim:ft=zsh:sw=2:sts=2:ts=2:et:
# shellcheck disable=all

setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS

# BREW
[[ -d "/opt/homebrew/bin" ]] && eval "$(/opt/homebrew/bin/brew shellenv)"

########################################
# PROMPT
########################################
# git
autoload -Uz vcs_info
precmd_vcs_info() { vcs_info }
precmd_functions+=( precmd_vcs_info )
precmd() {
  print ""
  print -Pn "\e]133;A\e\\"
}

setopt prompt_subst
PROMPT='%~ ${vcs_info_msg_0_}
%# '
zstyle ':vcs_info:git:*' formats '(%F{red}%b%f)'

# key bindings
autoload edit-command-line
zle -N edit-command-line

bindkey '^P' history-beginning-search-backward
bindkey '^N' history-beginning-search-forward
bindkey '^X^E' edit-command-line
bindkey -e

########################################
# Utilities
########################################
autoload bashcompinit && bashcompinit
autoload -Uz compinit && compinit

# aws completion
complete -C '/opt/homebrew/bin/aws_completer' aws
complete -C '/opt/homebrew/bin/aws_completer' awe

# fzf integration
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# aliases
alias ..="cd .."
alias bubu="brew update && brew upgrade && brew cleanup"
alias cp='cp -i'
alias grep="grep --color=auto"
alias ll="ls -alFh"
alias mv='mv -i'
alias nv=nvim
alias rm='rm -i'
alias tm="tmux a || tmux"
alias vi=vim
alias vim=nvim

cdp() {
  mkdir -p "${1}"
  cd "${1}" || return
}

# kubectl
# https://github.com/ahmetb/kubectl-aliases
[ -f ~/.kubectl_aliases ] && source ~/.kubectl_aliases

# terraform
alias tf=terraform
alias tfa="terraform apply"
alias tff="terraform fmt"
alias tfp="terraform plan"
alias tfsl="terraform state list"
alias tfsr="terraform state list | fzf --multi --reverse --height=20 | xargs -I{} -L1 terraform state rm '{}'"
alias tfss="terraform state show"
alias tfv="terraform validate"

# fzf
command -v fzf &>/dev/null && source <(fzf --zsh)

# direnv
command -v direnv &>/dev/null && eval "$(direnv hook zsh)"
