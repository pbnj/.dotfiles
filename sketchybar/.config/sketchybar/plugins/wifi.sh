#!/usr/bin/env bash

# shellcheck source=../colors.sh
source "$CONFIG_DIR/colors.sh"

POPUP="$(sketchybar --query wifi | jq -r '.popup.drawing // "off"')"
CLICK=false
if [ "${SENDER:-}" = mouse.clicked ]; then
  if [ "$POPUP" = on ]; then
    sketchybar --set wifi popup.drawing=off
    exit 0
  fi
  CLICK=true
fi

# A VPN/default route is not Wi-Fi status. Read the interface link without
# requesting network names or Location permission.
DEVICE="$(networksetup -listallhardwareports 2>/dev/null |
  awk '/^Hardware Port: (Wi-Fi|AirPort)$/ { getline; print $2; exit }')"

ICON=󰤭
COLOR=$RED
STATUS="Unavailable"
if [ -n "$DEVICE" ]; then
  POWER="$(networksetup -getairportpower "$DEVICE" 2>/dev/null)"
  case "$POWER" in
    *": On")
      if LINK="$(ifconfig "$DEVICE" 2>/dev/null)"; then
        ICON=󰤯
        COLOR=$YELLOW
        STATUS="Disconnected"
        if printf '%s\n' "$LINK" | grep -q 'status: active'; then
          ICON=󰤨
          COLOR=$GREEN
          STATUS="Connected"
        fi
      fi
      ;;
    *": Off")
      COLOR=$DIM
      STATUS="Off"
      ;;
  esac
fi

args=(
  --set wifi icon="$ICON" icon.color="$COLOR" label.drawing=off
  --set wifi.status icon="$ICON" icon.color="$COLOR" label="Status: $STATUS"
)

# Detail queries are read-only and only needed while opening/viewing the menu.
if $CLICK || [ "$POPUP" = on ]; then
  ADDRESS="Unavailable"
  if [ "$STATUS" = Connected ]; then
    ADDRESS="$(ipconfig getifaddr "$DEVICE" 2>/dev/null)" || ADDRESS=""
    ADDRESS="${ADDRESS:-Unavailable}"
  fi

  args+=(
    --set wifi.address label="IP address: $ADDRESS"
    --set wifi.interface label="Interface: ${DEVICE:-Unavailable}"
  )
fi

# A routine/theme update must never toggle or reopen the dropdown.
$CLICK && args+=(--set wifi popup.drawing=on)
sketchybar "${args[@]}"
