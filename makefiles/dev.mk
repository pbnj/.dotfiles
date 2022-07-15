.PHONY: dev-container
dev-container: ## Run dev container
	docker run \
		--rm \
		-it \
		--volume $(PWD):/$(PROJECT) \
		--workdir /$(PROJECT) \
		ubuntu:20.04

.PHONY: dev
dev: apt-update ## Setup dev container from scratch. Use -j8 flag for parallel threads.
	$(MAKE) install-deps
	$(MAKE) -j8 vim-plug node go rust crate-deps stow
	$(MAKE) -j8 crates vim-plugs

