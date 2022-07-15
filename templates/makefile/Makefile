# vim:ft=make:noet:sts=0:sw=0:

.DEFAULT_GOAL := help
SHELL         := /bin/bash

.PHONY: help
help: ## Show this help.
	@fgrep -h "##" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/\\$$//' | sed -e 's/##//'
