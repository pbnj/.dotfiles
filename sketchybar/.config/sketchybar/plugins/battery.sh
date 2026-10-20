#!/bin/sh

# shellcheck source=../colors.sh
. "$CONFIG_DIR/colors.sh"

BATT="$(pmset -g batt)"
PERCENTAGE="$(echo "$BATT" | grep -Eo '[0-9]+%' | cut -d% -f1)"

[ -z "$PERCENTAGE" ] && exit 0

case "$PERCENTAGE" in
  9[0-9] | 100) ICON="" ;;
  [6-8][0-9]) ICON="" ;;
  [3-5][0-9]) ICON="" ;;
  [1-2][0-9]) ICON="" ;;
  *) ICON="" ;;
esac

if echo "$BATT" | grep -q 'AC Power'; then
  ICON=""
fi

# tokyonight: green full, orange charging (or plugged in but holding below
# full, e.g. optimized charging), yellow discharging
case "$BATT" in
  *"; charged;"* | *"100%;"*) COLOR=$GREEN ;;
  *"; charging;"* | *"AC Power"*) COLOR=$ORANGE ;;
  *) COLOR=$YELLOW ;;
esac

sketchybar --set "$NAME" icon="$ICON" label="${PERCENTAGE}%" icon.color="$COLOR" label.color="$COLOR"
