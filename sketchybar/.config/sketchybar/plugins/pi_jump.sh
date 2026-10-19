#!/usr/bin/env bash

# usage: pi_jump.sh <tmux socket> <pane id>
# Focus Ghostty and select the tmux pane running this Pi session.
socket="${1:-}"
pane="${2:-}"

if [ -z "$socket" ] || [ -z "$pane" ]; then
  open -a Ghostty
  exit 0
fi

# display-message exits successfully for a missing pane, so verify the live list.
if ! tmux -S "$socket" list-panes -a -F '#{pane_id}' 2>/dev/null | grep -qxF -- "$pane"; then
  open -a Ghostty
  exit 1
fi

open -a Ghostty
client="$(
  tmux -S "$socket" list-clients -F '#{client_activity} #{client_name}' 2>/dev/null |
    sort -rn |
    head -1 |
    cut -d' ' -f2-
)"
[ -n "$client" ] || exit 0

tmux -S "$socket" switch-client -c "$client" -t "$pane" \; \
  select-window -t "$pane" \; select-pane -t "$pane"
