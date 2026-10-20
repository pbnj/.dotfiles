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

# Charge-level colors apply on battery and AC power alike.
# 100%: green; remaining charge split into thirds.
# 67-99%: normal; 34-66%: yellow; 0-33%: red.
if [ "$PERCENTAGE" -eq 100 ]; then
  COLOR=$GREEN
elif [ "$PERCENTAGE" -ge 67 ]; then
  COLOR=$FG
elif [ "$PERCENTAGE" -ge 34 ]; then
  COLOR=$YELLOW
else
  COLOR=$RED
fi

sketchybar --set "$NAME" icon="$ICON" label="${PERCENTAGE}%" icon.color="$COLOR" label.color="$COLOR"
