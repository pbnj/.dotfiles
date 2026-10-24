#!/bin/sh

# toggles the connection through Twingate's own menu: login starts the Okta
# flow, which only works when the app begins it
TWINGATE_MENU="$HOME/.local/bin/twingate_menu"

if [ ! -x "$TWINGATE_MENU" ]; then
  osascript -e 'display notification "Run: mise run twingate:build (in ~/.dotfiles)" with title "twingate_menu is not built"'
  exit 1
fi

if scutil --nc list | grep -q '^\* (Connected).*com\.twingate'; then
  "$TWINGATE_MENU" logout
else
  "$TWINGATE_MENU" login
fi
