# vim: ft=make
.PHONY: go
go: ## install go
	gh repo clone https://github.com/travis-ci/gimme $(PROJECT_DIR)/gimme
	chmod +x $(PROJECT_DIR)/gimme/gimme
	cp $(PROJECT_DIR)/gimme/gimme $(HOME)/bin/

.PHONY: go-glab
go-glab: install-gh ## install glab cli
	gh release download --repo profclems/glab --pattern '*macOS*'

