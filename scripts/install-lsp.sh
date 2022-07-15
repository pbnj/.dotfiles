#!/bin/bash

set -eou pipefail

npm i --location=global bash-language-server
npm i --location=global dockerfile-language-server-nodejs
npm i --location=global remark-language-server
npm i --location=global vscode-langservers-extracted
npm i --location=global yaml-language-server

go install github.com/nametake/golangci-lint-langserver
go install github.com/golangci/golangci-lint/cmd/golangci-lint
go install golang.org/x/tools/gopls

# TODO: https://github.com/rust-lang/rust-analyzer/releases
