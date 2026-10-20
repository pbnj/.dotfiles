#!/bin/sh

# shellcheck source=../colors.sh
. "$CONFIG_DIR/colors.sh"

# SSIDs are redacted on recent macOS without Location permission. Read the
# Wi-Fi interface's link instead; a VPN/default route is not Wi-Fi status.
DEVICE="$(networksetup -listallhardwareports 2>/dev/null |
  awk '/^Hardware Port: (Wi-Fi|AirPort)$/ { getline; print $2; exit }')"

ICON=󰤭
COLOR=$RED

if [ -n "$DEVICE" ]; then
  POWER="$(networksetup -getairportpower "$DEVICE" 2>/dev/null)"
  case "$POWER" in
    *": On")
      if LINK="$(ifconfig "$DEVICE" 2>/dev/null)"; then
        ICON=󰤯
        COLOR=$YELLOW
        if printf '%s\n' "$LINK" | grep -q 'status: active'; then
          ICON=󰤨
          COLOR=$GREEN
        fi
      fi
      ;;
    *": Off") COLOR=$DIM ;;
  esac
fi

sketchybar --set "$NAME" icon="$ICON" icon.color="$COLOR"
