# shellcheck shell=bash
# vim: set ft=bash
brew install --cask 1password
brew install --cask 1password-cli
brew install --cask alacritty
brew install --cask docker
brew install --cask firefox
brew install --cask keycastr
brew install --cask macvim
brew install --cask minecraft
brew install --cask rectangle
brew install --cask slack
brew install --cask spotify
brew install awscli                           # aws cli
brew install azure-cli                        # azure cli
brew install bash                             # newer version of bash
brew install bash-completion                  # completion for common tools & utilities
brew install coreutils                        # core utilities
brew install curl                             # curl
brew install ddgr                             # duckduckgo cli
brew install direnv                           # auto source .env files
brew install docker                           # docker cli
brew install exa                              # ls alternative written in rust
brew install fzf                              # fuzzy finder
brew install gh                               # github cli
brew install git                              # git cli
brew install git-extras                       # extra git utils
brew install glow                             # terminal markdown renderer
brew install grep                             # newer version of grep
brew install grex                             # regex generator
brew install hadolint                         # docker linter
brew install helm                             # cli for helm
brew install instrumenta/instrumenta/conftest # configuration file tester using opa
brew install jq                               # terminal json processor
brew install kubernetes-cli                   # cli for k8s
brew install melody                           # regex generator
brew install nmap                             # network mapper
brew install pandoc                           # universal document processor
brew install rust-analyzer                    # lsp for rust
brew install rustfmt                          # formatter for rust
brew install shellcheck                       # linter for shell scripts
brew install shfmt                            # formatter for shell scripts
brew install slides                           # terminal presentation tool
brew install stow                             # symlink farm manager
brew install terraform                        # infra-as-code cli
brew install tflint                           # linter for terraform
brew install tmux                             # terminal multiplexer
brew install tmux-mem-cpu-load                # utility for showing mem & cpu load
brew install universal-ctags                  # universal tag generator
brew install vhs                              # terminal gif generator
brew install wget                             # wget

brew install go &&
  go install golang.org/x/tools/...@latest &&
  go install golang.org/x/tools/gopls@latest &&
  go install github.com/cweill/gotests/...@latest

brew install node &&
  npm install --global prettier doctoc markdownlint-cli
