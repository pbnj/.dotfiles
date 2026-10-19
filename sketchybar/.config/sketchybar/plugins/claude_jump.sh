#!/usr/bin/env bash

# usage: claude_jump.sh <tmux socket> <pane id>
# Brings Ghostty forward and shows the pane in the most recently active tmux
# client. Fails when the pane is gone.
socket="$1"
pane="$2"

# display-message exits 0 for a missing pane, so check the live list
tmux -S "$socket" list-panes -a -F '#{pane_id}' 2>/dev/null | grep -qxF "$pane" || exit 1

open -a Ghostty

client="$(tmux -S "$socket" list-clients -F '#{client_activity} #{client_name}' | sort -rn | head -1 | cut -d' ' -f2)"
[ -n "$client" ] || exit 0

tmux -S "$socket" switch-client -c "$client" -t "$pane" \; select-window -t "$pane" \; select-pane -t "$pane"
