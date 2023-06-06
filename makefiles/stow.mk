# vim:ft=make:
.PHONY: stow
stow: stow-git stow-tmux stow-bash ## Symlink all dot files

.PHONY: stow-git
stow-git: ## stow git
	stow git

.PHONY: stow-tmux
stow-tmux: ## stow tmux
	stow tmux

.PHONY: stow-bash
stow-bash: ## stow bash
	stow bash
