# vim: ft=make
.PHONY: rust
rust: ## install rust
	curl https://sh.rustup.rs -sSf | sh -s -- -y
	source $(HOME)/.cargo/env

.PHONY: rust-crate-deps
rust-crate-deps: ## install crate dependencies
	apt-get update
	apt-get install -y \
		build-essential \
		clang \
		libclang-dev \
		libssl-dev \
		llvm \
		pkg-config

.PHONY: rust-cargo-crates
rust-cargo-crates: rust-cargo-exa rust-cargo-ripgrep rust-cargo-starship ## install rust crates

.PHONY: rust-cargo-exa
rust-cargo-exa: ## cargo install exa
	source "$(HOME)"/.cargo/env && cargo install exa

.PHONY: rust-cargo-ripgrep
rust-cargo-ripgrep: ## cargo install ripgrep
	source "$(HOME)"/.cargo/env && cargo install ripgrep

.PHONY: rust-cargo-starship
rust-cargo-starship: ## cargo install starship
	source "$(HOME)"/.cargo/env && cargo install starship

