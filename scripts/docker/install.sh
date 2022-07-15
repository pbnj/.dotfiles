#!/bin/bash

set -e
set -x

SUDO=$(which sudo)

curl -fsSL https://get.docker.com | sh

${SUDO} usermod -aG docker "$(whoami)"
