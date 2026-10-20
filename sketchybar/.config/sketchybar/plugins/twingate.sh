#!/bin/sh

# shellcheck source=../colors.sh
. "$CONFIG_DIR/colors.sh"

# colored by the state of the Twingate VPN services (tokyonight green/yellow/red)
STATUS="$(scutil --nc list | grep 'com\.twingate')"

case "$STATUS" in
  *"(Connected)"*) COLOR=$GREEN ;;
  *"(Connecting)"* | *"(Disconnecting)"* | *"(Reasserting)"*) COLOR=$YELLOW ;;
  *) COLOR=$RED ;;
esac

sketchybar --set "$NAME" icon.color="$COLOR"
