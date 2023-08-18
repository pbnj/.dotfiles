.DEFAULT_GOAL := help
SHELL := /bin/bash
PROJECT := dotfiles
PROJECT_DIR := $(HOME)/Projects
SUDO := $(shell which sudo)

.PHONY: help
help: ## Show this help.
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk -F':.*?##' '{printf "%-30s %s\n", $$1, $$2}'

# Dependencies
.PHONY: apt-update
apt-update:
	$(SUDO) apt update

.PHONY: curl
curl:
	if ! hash curl >/dev/null 2>&1 ; then $(SUDO) apt install -y curl ; fi

.PHONY: gpg
gpg:
	if ! hash gpg >/dev/null 2>&1 ; then $(SUDO) apt install -y gpg ; fi

# Recipes
.PHONY: all
all: ## install all the things
all: essential gh fzf docker

.PHONY: stow-all
stow-all: ## stow all the things
stow-all: stow-vim stow-git stow-bash stow-tmux

.PHONY: essential
essential: ## install essential dependencies
	$(SUDO) apt update
	$(SUDO) apt install -y \
		build-essential \
		curl \
		ddgr \
		git \
		less \
		make \
		man \
		python3 \
		stow \
		tmux \
		vim

.PHONY: op
op: apt-update curl gpg ## install 1password https://app-updates.agilebits.com/product_history/CLI
	curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
		$(SUDO) gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
	echo "deb [arch=$(shell dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(shell dpkg --print-architecture) stable main" | \
		$(SUDO) tee /etc/apt/sources.list.d/1password.list
	$(SUDO) apt update
	$(SUDO) apt install -y 1password-cli
	op --version

.PHONY: git-extras
git-extras: ## Install git extras
	sh $(CURDIR)/scripts/git-extras.sh

.PHONY: gh
gh: apt-update curl gpg ## install gh
	curl -fsSL \
		https://cli.github.com/packages/githubcli-archive-keyring.gpg \
		| $(SUDO) gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg
	echo "deb [arch=$(shell dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
		| $(SUDO) tee /etc/apt/sources.list.d/github-cli.list > /dev/null
	$(SUDO) apt update
	$(SUDO) apt install -y gh

.PHONY: docker
docker: ## install docker
	-$(SUDO) apt remove docker docker-engine docker.io containerd runc
	$(SUDO) apt update
	-$(SUDO) apt install -y uidmap
	curl -fsSL https://get.docker.com | sh

# STOW

.PHONY: stow-vim
stow-vim: ## stow vim
	stow vim -t $(HOME)

.PHONY: stow-git
stow-git: ## stow git
	stow git -t $(HOME)

.PHONY: stow-bash
stow-bash: ## stow bash
	stow bash -t $(HOME)

.PHONY: stow-tmux
stow-tmux: ## stow tmux
	stow tmux -t $(HOME)

# MACOS

.PHONY: macos-change-screenshot-location
macos-change-screenshot-location: ## Change default screenshot location to /tmp
	defaults write com.apple.screencapture location /tmp

.PHONY: macos-disable-keypresshold
macos-disable-keypresshold: ## Disable key press and hold feature
	defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
