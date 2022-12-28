# Dotfiles

## Table of Contents

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Overview](#overview)
- [Dependencies & Utilities](#dependencies--utilities)
  - [General Purpose](#general-purpose)
  - [Languages](#languages)
  - [Formatters](#formatters)
  - [Linters](#linters)
  - [Language Servers](#language-servers)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Overview

This repo contains my
[dotfiles](https://en.wikipedia.org/wiki/Hidden_file_and_hidden_directory) &
configurations for various utilities and command-line interface (CLI)
applications.

Much of the guiding principles behind my development workflow revolves around
the [Unix Philosophy](https://en.wikipedia.org/wiki/Unix_philosophy),
minimalism, simplicity, and composability.

The major underpinning themes are as follow:

- My editor is [`vim`](https://github.com/pbnj/dotfiles/blob/main/vim/.vimrc)
- My IDE is the surrounding environment: the shell, the compilers/interpreters,
  the various command-line applications and programs, the custom shell
  scripts/functions/aliases, ...etc

This allows me to compose various utilities into a workflow that is ergonomic
and productive for me.

## Dependencies & Utilities

### General Purpose

- curl
- docker
- git
- make
- op (1password cli)
- ssh
- tmux
- vim
- fzf

Optional:

- ripgrep (better `grep`)
- fd (better `find`)

### Languages

- bash
- go
- node / typescript
- rust
- terraform / hcl

### Formatters

- editorconfig
- goimports
- gotests
- prettier
- rustfmt
- shfmt

### Linters

- commitlint
- golangci-lint
- hadolint
- jsonlint
- markdownlint
- shellcheck
- tflint
- tfsec
- yamllint

### Language Servers

- bash-language-server
- dockerfile-language-server
- gopls
- rust-analyzer
- terraform-ls
- vscode-langservers-extracted (json, css, html)
- yaml-language-server
