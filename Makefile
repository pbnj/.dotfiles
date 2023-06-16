.DEFAULT_GOAL := help
SHELL := /bin/bash
PROJECT := dotfiles
PROJECT_DIR := $(HOME)/Projects
SUDO := $(shell which sudo)

.PHONY: help
help: ## Show this help.
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk -F':.*?##' '{printf "%-30s %s\n", $$1, $$2}'

.PHONY: md-toc
md-toc: ## generate markdown toc
	npx doctoc --notitle --update-only .

.PHONY: md-fmt
md-fmt: ## format markdown files
	npx prettier --write *.md

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
		unzip \
		vim

.PHONY: op
op: ## install 1password https://app-updates.agilebits.com/product_history/CLI
	curl -fsSL -o /tmp/op.zip \
		https://cache.agilebits.com/dist/1P/op/pkg/v1.12.3/op_linux_$(ARCH)_v1.12.3.zip
	unzip /tmp/op.zip -d /tmp
	$(SUDO) mv /tmp/op /usr/local/bin/

.PHONY: git-extras
git-extras: ## Install git extras
	sh $(CURDIR)/scripts/git-extras.sh

.PHONY: gh
gh: ## install gh
	curl -fsSL \
		https://cli.github.com/packages/githubcli-archive-keyring.gpg \
		| $(SUDO) gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg
	echo "deb [arch=$(shell dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
		| $(SUDO) tee /etc/apt/sources.list.d/github-cli.list > /dev/null
	$(SUDO) apt update
	$(SUDO) apt install gh

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
