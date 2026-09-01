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

# not part of `make osx`: needs sudo, and running hot in a closed bag is opt-in.
# disablesleep is GLOBAL despite the -b/-c flags: it never lands in either
# profile of `pmset -g custom`, only as a single `SleepDisabled 1` in
# `pmset -g`. So this holds on battery too -- turn it off before you pack up.
.PHONY: osx-lid-awake-on
osx-lid-awake-on: ## stay awake with the lid closed (applies on battery too)
	sudo pmset -a disablesleep 1
	pmset -g | grep SleepDisabled

.PHONY: osx-lid-awake-off
osx-lid-awake-off: ## restore normal sleep-on-lid-close
	sudo pmset -a disablesleep 0
	pmset -g | grep SleepDisabled
