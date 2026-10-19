#!/bin/sh

# toggles the connection through Twingate's own menu: login starts the Okta
# flow, which only works when the app begins it
TWINGATE_MENU="$CONFIG_DIR/helpers/bin/twingate_menu"

if scutil --nc list | grep -q '^\* (Connected).*com\.twingate'; then
  "$TWINGATE_MENU" logout
else
  "$TWINGATE_MENU" login
fi
