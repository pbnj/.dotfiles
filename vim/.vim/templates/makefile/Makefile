.DEFAULT_GOAL := help
SHELL         := /bin/bash

.PHONY: help
help: ## Show this help.
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk -F':.*?##' '{printf "%-30s %s\n", $$1, $$2}'
