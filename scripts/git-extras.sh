#!/bin/bash

set -eou pipefail

SUDO=$(which sudo)

git clone https://github.com/tj/git-extras.git /tmp/git-extras
git -C /tmp/git-extras checkout "$(git -C /tmp/git-extras describe --tags "$(git -C /tmp/git-extras rev-list --tags --max-count=1)")"
${SUDO} make -C /tmp/git-extras install
