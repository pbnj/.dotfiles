# General
set --export PATH $HOME/.local/bin $PATH

# Go
set --export GODEBUG x509ignoreCN=0
set --export GOPATH $HOME/go
set --export PATH $GOPATH/bin $PATH

set --export EDITOR vim
set --export DOTFILES $HOME/.dotfiles
set --export FZF_DEFAULT_COMMAND 'rg --files --hidden --follow'
set --export FZF_DEFAULT_OPTS '--bind alt-a:select-all,alt-d:deselect-all,ctrl-j:preview-down,ctrl-k:preview-up'
set --export GIT_TERMINAL_PROMPT 1
set --export RIPGREP_CONFIG_PATH $HOME/.config/ripgrep/.ripgreprc

# 1Password Agent
if test "(uname)" = "Darwin"
	set --export SSH_AUTH_SOCK $HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock
end

# BREW
if test -d "/opt/homebrew/bin"
	eval (/opt/homebrew/bin/brew shellenv)
end

# Rootless Docker
# docs: https://docs.docker.com/engine/security/rootless/
#   $ dockerd-rootless-setuptool.sh install
if test "(uname)" = "Linux"
	set --export DOCKER_HOST unix:///run/user/1000/docker.sock
end

# MISC
set --export DOTFILES $HOME/.dotfiles
