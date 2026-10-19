#!/usr/bin/env bash

# Jumps to the Claude Code session that most needs you, in Ghostty + tmux:
# one blocked on a prompt first, then the one that finished most recently
# (idle, waiting for your next message), then one still working. Sessions and
# their tmux panes come from the files the Claude Code "usage" mod writes (~/.claude/mods/usage).
DIR="$HOME/.cache/claude-sketchybar"
NOW="$(date +%s)"
# working/blocked sessions rewrite their file every minute; one silent for
# this long has crashed
STALE=300

open -a Ghostty

# "<socket> <pane>" per candidate, best first
candidates() {
  for f in "$DIR"/sessions/*.json; do
    [ -e "$f" ] || continue
    jq -c --argjson now "$NOW" --argjson stale "$STALE" '
      select(.tmux != null)
      | select(.state == "idle" or ((.state == "blocked" or .state == "working") and $now - .updatedAt / 1000 <= $stale))
      | { rank: { blocked: 0, idle: 1, working: 2 }[.state], updatedAt, socket: .tmux.socket, pane: .tmux.pane }
    ' "$f" 2>/dev/null
  done | jq -s -r 'sort_by(.rank, -.updatedAt)[] | "\(.socket) \(.pane)"'
}

while read -r socket pane; do
  # an idle session's file outlives the session; skip panes that are gone
  # (display-message exits 0 for a missing pane, so check the live list)
  tmux -S "$socket" list-panes -a -F '#{pane_id}' 2>/dev/null | grep -qxF "$pane" || continue

  # the most recently active client, i.e. the Ghostty window in front
  client="$(tmux -S "$socket" list-clients -F '#{client_activity} #{client_name}' | sort -rn | head -1 | cut -d' ' -f2)"
  [ -n "$client" ] || exit 0

  tmux -S "$socket" switch-client -c "$client" -t "$pane" \; select-window -t "$pane" \; select-pane -t "$pane"
  exit 0
done < <(candidates)
