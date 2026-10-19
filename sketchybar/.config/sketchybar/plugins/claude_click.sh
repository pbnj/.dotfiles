#!/usr/bin/env bash

# Claude icon clicks:
#   left   toggles a menu of every tmux pane running Claude Code, each with a
#          dot colored by its state; a row jumps to its pane
#   right  jumps straight to the session that most needs you: one blocked on a
#          prompt, then the one that finished most recently, then one working
# States and panes come from the files the Claude Code "usage" mod writes
# (~/.claude/mods/usage); a pane it does not know shows a hollow dot.
DIR="$HOME/.cache/claude-sketchybar"
NOW="$(date +%s)"
# working/blocked sessions rewrite their file every minute; one silent for
# this long has crashed
STALE=300

# tokyonight
DIM=0xff737aa2
ORANGE=0xffff9e64
RED=0xfff7768e

# one JSON object per live session file
sessions() {
  for f in "$DIR"/sessions/*.json; do
    [ -e "$f" ] || continue
    jq -c --argjson now "$NOW" --argjson stale "$STALE" '
      select(.tmux != null)
      | select(.state == "idle" or ((.state == "blocked" or .state == "working") and $now - .updatedAt / 1000 <= $stale))
      | { state, updatedAt, socket: .tmux.socket, pane: .tmux.pane }
    ' "$f" 2>/dev/null
  done
}

if [ "$BUTTON" = "right" ]; then
  sketchybar --set claude popup.drawing=off
  while read -r socket pane; do
    "$CONFIG_DIR/plugins/claude_jump.sh" "$socket" "$pane" && exit 0
  done < <(sessions | jq -s -r 'sort_by({ blocked: 0, idle: 1, working: 2 }[.state], -.updatedAt)[] | "\(.socket) \(.pane)"')
  open -a Ghostty
  exit 0
fi

# left click: close an open menu, or rebuild and open it
if [ "$(sketchybar --query claude | jq -r '.popup.drawing')" = "on" ]; then
  sketchybar --set claude popup.drawing=off
  exit 0
fi

declare -A STATE
while read -r pane state; do
  STATE[$pane]=$state
done < <(sessions | jq -r '"\(.pane) \(.state)"')

SOCKET="$(tmux display-message -p '#{socket_path}' 2>/dev/null)"

row=(
  background.drawing=off
  icon.padding_left=10
  icon.font="JetBrainsMono Nerd Font:Bold:13.0"
  label.padding_right=12
  padding_left=0
  padding_right=0
)

# rows from the last opening
args=()
if [ "$(sketchybar --query claude | jq '.popup.items | length')" -gt 0 ]; then
  args+=(--remove '/claude\.row\..*/')
fi
i=0
# Claude Code's process name is its version (2.1.303); its pane title is the
# session's topic behind a status glyph
while IFS='|' read -r pane window name command title; do
  [[ "$command" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ || "$command" == "claude" ]] || continue
  title="$(sed -E 's/^[^[:alnum:]]+//' <<<"$title")"
  ((${#title} > 48)) && title="${title:0:47}…"

  case "${STATE[$pane]}" in
    blocked) dot="●" color=$RED ;;
    working) dot="●" color=$ORANGE ;;
    idle) dot="●" color=$DIM ;;
    *) dot="○" color=$DIM ;;
  esac

  args+=(
    --add item "claude.row.$i" popup.claude
    --set "claude.row.$i" "${row[@]}" icon="$dot" icon.color="$color"
    label="$window:$name  $title"
    click_script="sketchybar --set claude popup.drawing=off; '$CONFIG_DIR/plugins/claude_jump.sh' '$SOCKET' '$pane'"
  )
  i=$((i + 1))
done < <(tmux list-panes -a -F '#{pane_id}|#{window_index}|#{window_name}|#{pane_current_command}|#{pane_title}' 2>/dev/null)

if ((i == 0)); then
  args+=(
    --add item claude.row.0 popup.claude
    --set claude.row.0 "${row[@]}" icon="○" icon.color="$DIM" label="No Claude sessions in tmux"
  )
fi

sketchybar "${args[@]}" --set claude popup.drawing=on
