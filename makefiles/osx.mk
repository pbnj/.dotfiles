.PHONY: osx
osx: osx-disable-ds-store osx-disable-press-and-hold osx-disable-special-chars ## disable all osx settings

.PHONY: osx-disable-ds-store
osx-disable-ds-store: ## disable .DS-Store
	defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool TRUE

.PHONY: osx-disable-press-and-hold
osx-disable-press-and-hold: ## disable press-and-hold
	defaults write -g ApplePressAndHoldEnabled -bool false

.PHONY: osx-disable-special-chars
osx-disable-special-chars: ## disable special characters, like emdash & smart quotes
	defaults write 'Apple Global Domain' NSAutomaticQuoteSubstitutionEnabled 0
	defaults write 'Apple Global Domain' NSAutomaticDashSubstitutionEnabled 0
