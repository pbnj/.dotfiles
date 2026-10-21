#!/usr/bin/env bash

# shellcheck source=../colors.sh
source "$CONFIG_DIR/colors.sh"

CLICK=false
if [ "${SENDER:-}" = mouse.clicked ]; then
  if [ "$(sketchybar --query battery | jq -r '.popup.drawing // "off"')" = on ]; then
    sketchybar --set battery popup.drawing=off
    exit 0
  fi
  CLICK=true
fi

BATT="$(pmset -g batt 2>/dev/null)" || BATT=""
PERCENTAGE="$(printf '%s\n' "$BATT" | grep -Eo '[0-9]+%' | head -n 1 | cut -d% -f1)"

ICON=""
COLOR=$RED
CHARGE="Charge: Unavailable"
case "$PERCENTAGE" in
  [0-9] | [1-9][0-9] | 100)
    CHARGE="Charge: ${PERCENTAGE}%"
    case "$PERCENTAGE" in
      9[0-9] | 100) ICON="" ;;
      [6-8][0-9]) ICON="" ;;
      [3-5][0-9]) ICON="" ;;
      [1-2][0-9]) ICON="" ;;
      *) ICON="" ;;
    esac

    # 100%: green; remaining charge split into thirds, on battery or AC.
    if [ "$PERCENTAGE" -eq 100 ]; then
      COLOR=$GREEN
    elif [ "$PERCENTAGE" -ge 67 ]; then
      COLOR=$FG
    elif [ "$PERCENTAGE" -ge 34 ]; then
      COLOR=$YELLOW
    fi
    ;;
esac

case "$BATT" in
  *"AC Power"*) SOURCE="Power Adapter" ;;
  *"Battery Power"*) SOURCE="Battery" ;;
  *) SOURCE="Unavailable" ;;
esac
case "$BATT" in
  *"; charging;"*) STATUS="Charging" ;;
  *"; charged;"*) STATUS="Fully charged" ;;
  *"; discharging;"*) STATUS="Discharging" ;;
  *"; not charging;"*) STATUS="Not charging" ;;
  *"; finishing charge;"*) STATUS="Finishing charge" ;;
  *) STATUS="Unavailable" ;;
esac

# Keep the dropdown's fill level; show power state in the bar when charge is valid.
BAR_ICON=$ICON
if [ "$ICON" != "" ]; then
  case "$STATUS" in
    Charging | "Finishing charge")
      # Nerd Font battery_charging_{10..100}; outline below 10%.
      case "$PERCENTAGE" in
        100) BAR_ICON="󰂅" ;;
        9[0-9]) BAR_ICON="󰂋" ;;
        8[0-9]) BAR_ICON="󰂊" ;;
        7[0-9]) BAR_ICON="󰢞" ;;
        6[0-9]) BAR_ICON="󰂉" ;;
        5[0-9]) BAR_ICON="󰢝" ;;
        4[0-9]) BAR_ICON="󰂈" ;;
        3[0-9]) BAR_ICON="󰂇" ;;
        2[0-9]) BAR_ICON="󰂆" ;;
        1[0-9]) BAR_ICON="󰢜" ;;
        *) BAR_ICON="󰢟" ;;
      esac
      ;;
    *) [ "$SOURCE" = "Power Adapter" ] && BAR_ICON="" ;;
  esac
fi

ESTIMATE="$(printf '%s\n' "$BATT" | grep -Eo '[0-9]+:[0-9]{2}' | head -n 1)"
TIME="Time estimate: Unavailable"
if [ -n "$ESTIMATE" ]; then
  case "$STATUS" in
    Charging | "Finishing charge") TIME="Time to full: $ESTIMATE" ;;
    Discharging) TIME="Time remaining: $ESTIMATE" ;;
  esac
elif [[ "$BATT" == *"(no estimate)"* ]]; then
  TIME="Time estimate: Calculating…"
fi

args=(
  --set battery icon="$BAR_ICON" icon.color="$COLOR" label="" label.drawing=off
  --set battery.level icon="$ICON" icon.color="$COLOR" label="$CHARGE"
  --set battery.source label="Power source: $SOURCE"
  --set battery.status label="Status: $STATUS"
  --set battery.time label="$TIME"
)

# Refresh existing rows, but never reopen a popup after a routine/theme update.
$CLICK && args+=(--set battery popup.drawing=on)
sketchybar "${args[@]}"
