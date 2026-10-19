#!/usr/bin/env bash

# The Pi extension publishes one small status file per live TUI process.
DIR="${PI_SKETCHYBAR_SESSION_DIR:-$HOME/.cache/pi-sketchybar/sessions}"
NAME="${NAME:-pi}"
NOW="$(date +%s)"
STALE=300

# tokyonight
DIM=0xff737aa2
ORANGE=0xffff9e64
RED=0xfff7768e

# Most urgent state across Pi sessions: blocked > working > idle.
RANK=0
COUNT=0
for file in "$DIR"/*.json; do
  [ -f "$file" ] || continue
  read -r pid state updated < <(
    jq -r '"\(.pid // "") \(.state // "") \((.updatedAt // 0) / 1000 | floor)"' \
      "$file" 2>/dev/null
  )
  [[ "$pid" =~ ^[0-9]+$ && "$updated" =~ ^[0-9]+$ ]] || continue

  case "$state" in
    blocked) rank=2 ;;
    working) rank=1 ;;
    idle) rank=0 ;;
    *) continue ;;
  esac

  if ! kill -0 "$pid" 2>/dev/null || ((NOW - updated > STALE)); then
    rm -f "$file"
    continue
  fi

  ((COUNT += 1))
  ((rank > RANK)) && RANK=$rank
done

case "$RANK" in
  2) ICON_COLOR=$RED ;;
  1) ICON_COLOR=$ORANGE ;;
  *) ICON_COLOR=$DIM ;;
esac

args=(--set "$NAME" icon.color="$ICON_COLOR")
if ((COUNT > 0)); then
  args+=(drawing=on)
else
  args+=(drawing=off)
fi
sketchybar "${args[@]}"
