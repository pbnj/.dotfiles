#!/usr/bin/env bash

# Claude's usage limits and the most urgent state across Claude Code sessions,
# from the files the Claude Code "usage" mod writes (~/.claude/mods/usage). It fires
# claude_update after each write; update_freq re-reads so expired windows and
# crashed sessions drop off.
DIR="$HOME/.cache/claude-sketchybar"
NOW="$(date +%s)"
# working/blocked sessions rewrite their file every minute; one silent for
# this long has crashed
STALE=300

# tokyonight
FG=0xffc0caf5
DIM=0xff737aa2
ORANGE=0xffff9e64
YELLOW=0xffe0af68
RED=0xfff7768e

# most urgent state: blocked > working > idle
RANK=0
for f in "$DIR"/sessions/*.json; do
  [ -e "$f" ] || continue
  read -r state updated < <(jq -r '"\(.state) \(.updatedAt / 1000 | floor)"' "$f" 2>/dev/null)
  case "$state" in
    blocked) rank=2 ;;
    working) rank=1 ;;
    *) continue ;;
  esac
  ((NOW - updated > STALE)) && continue
  ((rank > RANK)) && RANK=$rank
done
case "$RANK" in
  2) ICON_COLOR=$RED ;;
  1) ICON_COLOR=$ORANGE ;;
  *) ICON_COLOR=$DIM ;;
esac

# ended and abandoned sessions
find "$DIR/sessions" -name '*.json' -mtime +1 -delete 2>/dev/null

# one item per window: "NN%", hidden once its reset has passed, colored by
# its own usage
window() {
  local item="$1" key="$2" pct
  pct="$(jq -r --argjson now "$NOW" --arg key "$key" '
    .[$key] // empty
    | select(
        (.resetsAt // null) as $r
        | $r == null or ((try ($r | sub("\\.[0-9]+"; "") | fromdateiso8601) catch null) // ($now + 1)) > $now
      )
    | .percentUsed | round
  ' "$DIR/usage.json" 2>/dev/null)"

  if [ -z "$pct" ]; then
    args+=(--set "$item" drawing=off)
    return
  fi

  local color=$FG
  if ((pct >= 90)); then
    color=$RED
  elif ((pct >= 70)); then
    color=$YELLOW
  fi
  args+=(--set "$item" drawing=on label="$(printf '%02d%%' "$pct")" label.color="$color")
}

args=(--set "$NAME" icon.color="$ICON_COLOR")
window claude.5h five_hour
window claude.7d seven_day
sketchybar "${args[@]}"
