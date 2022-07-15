# vim: ft=make
.PHONY: deps-deb
deps-deb: ## install dependencies. Must run manually first.
	apt-get update
	apt-get install -y \
		ca-certificates \
		curl \
		git \
		stow \
		tmux \
		vim
