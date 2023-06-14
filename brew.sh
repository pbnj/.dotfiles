# shellcheck shell=bash
# vim: set ft=bash
brew install --cask 1password
brew install --cask 1password-cli
brew install --cask alacritty
brew install --cask docker
brew install --cask firefox
brew install --cask keycastr
brew install --cask macvim
brew install --cask minecraft
brew install --cask rectangle
brew install --cask slack
brew install --cask spotify
brew install awscli
brew install azure-cli
brew install bash
brew install bash-completion
brew install coreutils
brew install curl
brew install ddgr
brew install direnv
brew install docker
brew install exa
brew install fzf
brew install gh
brew install git
brew install git-extras
brew install glow
brew install grep
brew install hadolint
brew install helm
brew install homebrew/cask-fonts/font-fira-code-nerd-font
brew install htop
brew install instrumenta/instrumenta/conftest
brew install jq
brew install kubernetes-cli
brew install nmap
brew install pandoc
brew install rust-analyzer
brew install rustfmt
brew install shellcheck
brew install shfmt
brew install slides
brew install stow
brew install terraform
brew install tflint
brew install tmux
brew install tmux-mem-cpu-load
brew install universal-ctags
brew install vhs
brew install wget

brew install go &&
  go install golang.org/x/tools/...@latest &&
  go install golang.org/x/tools/gopls@latest &&
  go install github.com/cweill/gotests/...@latest

brew install node &&
  npm install --global prettier doctoc markdownlint-cli
