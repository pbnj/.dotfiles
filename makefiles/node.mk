# vim:ft=make:
.PHONY: node
node: ## install node.js 
	gh repo clone https://github.com/nvm-sh/nvm $(HOME)/.nvm
	git checkout $(git describe --abbrev=0 --tags --match "v[0-9]*" $(git rev-list --tags --max-count=1))

# npm install -g bash-language-server
# npm install -g vim-language-server
# npm install -g typescript
# npm i -g prettier
# npm i -g prettier-plugin-sh
# npm i -g prettier-plugin-go-template
# npm i -g @prettier/plugin-ruby
# npm i -g prettier-plugin-java
# npm i -g doctoc
# npm i -g markdownlint-cli

