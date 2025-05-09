# vim:ft=zsh:sw=2:sts=2:ts=2:et:
# shellcheck disable=all

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
RPROMPT='%D{%Y-%m-%d %L:%M:%S}'

# key bindings
bindkey '^P' history-beginning-search-backward
bindkey '^N' history-beginning-search-forward
bindkey -e

########################################
# Utilities
########################################
# aws completion
autoload bashcompinit && bashcompinit
autoload -Uz compinit && compinit
complete -C '/opt/homebrew/bin/aws_completer' aws
complete -C '/opt/homebrew/bin/aws_completer' awe

# fzf integration
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# aliases
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
