# vim: set ft=bash
# shellcheck shell=bash

# Utilities
brew install ankitpokhrel/jira-cli/jira-cli
brew install awscli
brew install bash
brew install bash-completion
brew install commitizen
brew install coreutils
brew install curl
brew install ddgr   # duckduckgo
brew install direnv # auto-source .envrc
brew install docker
brew install exa # better ls
brew install fd  # better find
brew install fx  # json viewer
brew install fzf
brew install gawk # gnu-awk
brew install gh   # github cli
brew install git
brew install git-extras
brew install gitleaks # secret detection
brew install glow     # markdown viewer
brew install helm
brew install instrumenta/instrumenta/conftest # unit tester for config files
brew install jq
brew install kind # kubernetes in docker
brew install kubernetes-cli
brew install make
brew install pre-commit # git hook manager
brew install ripgrep    # better grep
brew install slides     # terminal presentation tool
brew install stow       # symlink farm manager
brew install tmux
brew install tmux-mem-cpu-load
brew install universal-ctags
brew install vault
brew install watch
brew install wget
brew install xsv # csv cli

# Languages
## shell
brew install bash-language-server
brew install shellcheck
brew install shfmt

## markdown
brew install alexjs
brew install markdownlint-cli
brew install marksman
brew install prettier

## go
brew install go
brew install golangci/tap/golangci-lint
brew install gopls
brew install gotests
go install golang.org/x/tools/cmd/goimports@latest
go install github.com/editorconfig-checker/editorconfig-checker/cmd/editorconfig-checker@latest

## docker
brew install hadolint
npm install --global @microsoft/compose-language-service
npm install --global dockerfile-language-server-nodejs

## rust
brew install rust-analyzer
brew install rustfmt

## terraform
brew install terraform
brew install terraform-docs
brew install hashicorp/tap/terraform-ls
brew install tflint

## json/yaml
brew install yaml-language-server
brew install yamllint
brew install yq
npm install --global vscode-json-languageservice

## vim
npm install --global vim-language-server

# Casks
if [[ "$(uname)" == "Darwin" ]]; then
	# brew install --cask owasp-zap
	# brew install --cask pgadmin4
	brew install --cask 1password
	brew install --cask 1password-cli
	brew install --cask balenaetcher
	brew install --cask docker
	brew install --cask firefox
	brew install --cask keycastr
	brew install --cask macvim
	brew install --cask rectangle
	brew install --cask slack
fi
