#!/usr/bin/env bash

# shellcheck source=../colors.sh
source "$CONFIG_DIR/colors.sh"

# Match the native CLI's executable name, not prompts, editor extensions or
# other users' sessions. Do not launch Copilot just to discover its state.
DRAWING=off
if pgrep -u "$(id -u)" -x copilot >/dev/null; then
  DRAWING=on
else
  STATUS=$?
  # pgrep uses 1 for no match; a discovery failure must not look like no session.
  [ "$STATUS" -eq 1 ] || exit "$STATUS"
fi

sketchybar --set copilot drawing="$DRAWING" icon.color="$ACCENT"
