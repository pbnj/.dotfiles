#!/bin/bash

set -eou pipefail

SUDO="$(which sudo)"

if hash brew &>/dev/null; then
	echo "Installing 1password cli via brew..."

	brew install --cask 1password/tap/1password-cli

elif hash apt &>/dev/null; then
	echo "Installing 1password cli via apt..."

	${SUDO} apt update
	${SUDO} apt install -y curl gpg

	curl -sS https://downloads.1password.com/linux/keys/1password.asc |
		${SUDO} gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg

	echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" |
		${SUDO} tee /etc/apt/sources.list.d/1password.list

	${SUDO} mkdir -p /etc/debsig/policies/AC2D62742012EA22/

	curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol |
		${SUDO} tee /etc/debsig/policies/AC2D62742012EA22/1password.pol

	${SUDO} mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22

	curl -sS https://downloads.1password.com/linux/keys/1password.asc |
		${SUDO} gpg --dearmor --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg

	${SUDO} apt update
	${SUDO} apt install 1password-cli

elif hash yum &>/dev/null; then
	echo "Installing 1password cli via yum..."
	${SUDO} rpm --import https://downloads.1password.com/linux/keys/1password.asc
	${SUDO} sh -c 'echo -e "[1password]\nname=1Password Stable Channel\nbaseurl=https://downloads.1password.com/linux/rpm/stable/\$basearch\nenabled=1\ngpgcheck=1\nrepo_gpgcheck=1\ngpgkey=\"https://downloads.1password.com/linux/keys/1password.asc\"" > /etc/yum.repos.d/1password.repo'
	${SUDO} dnf check-update -y 1password-cli && sudo dnf install 1password-cli
else
	echo "Cannot detect OS/ARCH. Install manually from https://app-updates.agilebits.com/product_history/CLI2"
	exit 1
fi

op --version
