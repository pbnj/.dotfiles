# vim: set ft=bash
# shellcheck shell=bash

# formulae

brew install awscli
brew install bash
brew install bash-completion
brew install commitizen
brew install coreutils
brew install curl
brew install dasel
brew install ddgr
brew install direnv
brew install docker
brew install exa
brew install fd
brew install fx
brew install fzf
brew install gawk
brew install gh
brew install git
brew install git-extras
brew install gitleaks
brew install glib
brew install glow
brew install go
brew install golangci-lint
brew install helm
brew install jq
brew install kind
brew install kubectl
brew install kubernetes-cli
brew install make
brew install node
brew install pre-commit
brew install reattach-to-user-namespace
brew install ripgrep
brew install ronn
brew install shellcheck
brew install starship
brew install stow
brew install terraform
brew install terraform-docs
brew install terraform-ls
brew install tflint
brew install tfsec
brew install tmux
brew install tmux-mem-cpu-load
brew install tree
brew install universal-ctags
brew install vault
brew install watch
brew install wget
brew install xsv
brew install yamllint
brew install yq

# brew install glab
# brew install go-md2man
# brew install octant
# brew install stern

# taps

brew install ankitpokhrel/jira-cli/jira-cli
brew install golangci/tap/golangci-lint
brew install instrumenta/instrumenta/conftest
brew install hashicorp/tap/terraform-ls

# macOS casks

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

# fonts

brew install homebrew/cask-fonts/font-input

# secrity

# brew install gpg
# brew install homebrew/cask-drivers/yubico-yubikey-manager
