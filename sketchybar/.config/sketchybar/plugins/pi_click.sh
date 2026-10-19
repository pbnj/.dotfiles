#!/usr/bin/env bash

DIR="${PI_SKETCHYBAR_SESSION_DIR:-$HOME/.cache/pi-sketchybar/sessions}"
NOW="$(date +%s)"
STALE=300
FONT="JetBrainsMono Nerd Font"

# tokyonight
DIM=0xff737aa2
ORANGE=0xffff9e64
RED=0xfff7768e

if [ "$(sketchybar --query pi 2>/dev/null | jq -r '.popup.drawing // "off"')" = "on" ]; then
  sketchybar --set pi popup.drawing=off
  exit 0
fi

row=(
  background.drawing=off
  icon.padding_left=10
  icon.font="$FONT:Bold:13.0"
  label.padding_right=12
  padding_left=0
  padding_right=0
)
args=()
item_count="$(sketchybar --query pi 2>/dev/null | jq -r '.popup.items | length' 2>/dev/null)"
if [[ "$item_count" =~ ^[0-9]+$ ]] && ((item_count > 0)); then
  args+=(--remove '/pi\.row\..*/')
fi

JUMP_SCRIPT="$CONFIG_DIR/plugins/pi_jump.sh"
printf -v jump_script_q '%q' "$JUMP_SCRIPT"
i=0
for file in "$DIR"/*.json; do
  [ -f "$file" ] || continue
  if ! IFS=$'\t' read -r pid state updated cwd session_name socket pane < <(
    jq -r '
      [
        (.pid // ""),
        (.state // ""),
        ((.updatedAt // 0) / 1000 | floor),
        (if (.cwd // "") == "" then "-" else .cwd end),
        (if (.sessionName // "") == "" then "-" else .sessionName end),
        (if (.tmux.socket // "") == "" then "-" else .tmux.socket end),
        (if (.tmux.pane // "") == "" then "-" else .tmux.pane end)
      ] | @tsv
    ' "$file" 2>/dev/null
  ); then
    continue
  fi
  [[ "$pid" =~ ^[0-9]+$ && "$updated" =~ ^[0-9]+$ ]] || continue
  case "$state" in
    blocked) dot=● color=$RED ;;
    working) dot=● color=$ORANGE ;;
    idle) dot=● color=$DIM ;;
    *) continue ;;
  esac
  if ! kill -0 "$pid" 2>/dev/null || ((NOW - updated > STALE)); then
    rm -f "$file"
    continue
  fi

  [ "$cwd" = "-" ] && cwd=""
  [ "$session_name" = "-" ] && session_name=""
  [ "$socket" = "-" ] && socket=""
  [ "$pane" = "-" ] && pane=""

  project="${cwd%/}"
  project="${project##*/}"
  [ -n "$project" ] || project="Pi"
  location="Ghostty"
  if [ -n "$socket" ] && [ -n "$pane" ]; then
    location="$(tmux -S "$socket" display-message -p -t "$pane" '#{session_name}:#{window_index}.#{pane_index}' 2>/dev/null)"
    [ -n "$location" ] || location="tmux $pane"
  fi

  label="$project  ·  $location"
  [ -n "$session_name" ] && label="$label  ·  $session_name"
  label="$label  ·  $state"
  label="${label//$'\n'/ }"
  label="${label//$'\r'/ }"
  label="${label//$'\t'/ }"
  if ((${#label} > 78)); then
    label="${label:0:77}…"
  fi

  printf -v socket_q '%q' "$socket"
  printf -v pane_q '%q' "$pane"
  click_script="sketchybar --set pi popup.drawing=off; $jump_script_q $socket_q $pane_q"
  args+=(
    --add item "pi.row.$i" popup.pi
    --set "pi.row.$i" "${row[@]}" icon="$dot" icon.color="$color"
    label="$label" click_script="$click_script"
  )
  i=$((i + 1))
done

if ((i == 0)); then
  args+=(
    --add item pi.row.empty popup.pi
    --set pi.row.empty "${row[@]}" icon="○" icon.color="$DIM"
    label="No active Pi sessions"
  )
fi

sketchybar "${args[@]}" --set pi popup.drawing=on
