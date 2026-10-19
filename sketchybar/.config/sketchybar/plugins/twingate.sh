#!/bin/sh

# colored by the state of the Twingate VPN services (tokyonight green/yellow/red)
STATUS="$(scutil --nc list | grep 'com\.twingate')"

case "$STATUS" in
  *"(Connected)"*) COLOR=0xff9ece6a ;;
  *"(Connecting)"* | *"(Disconnecting)"* | *"(Reasserting)"*) COLOR=0xffe0af68 ;;
  *) COLOR=0xfff7768e ;;
esac

sketchybar --set "$NAME" icon.color="$COLOR"
