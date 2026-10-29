#!/usr/bin/env bash
# Select the next window, wrapping around, that has a blocked agent
# (@agent_state, set by agent-status.py) or a tmux alert (bell, activity,
# silence). Usage: next-alert.sh <socket_path>
set -euo pipefail

socket=$1
t() { tmux -S "$socket" "$@"; }

current=$(t display-message -p '#{window_index}')
targets=$(t list-windows -F '#{window_index} #{?#{||:#{==:#{@agent_state},blocked},#{||:#{window_bell_flag},#{||:#{window_activity_flag},#{window_silence_flag}}}},1,0}' |
  awk '$2 == 1 { print $1 }')

next=$(awk -v cur="$current" '$1 > cur { print; exit }' <<<"$targets")
next=${next:-$(awk -v cur="$current" '$1 != cur { print; exit }' <<<"$targets")}

if [[ -n $next ]]; then
  t select-window -t ":=$next"
else
  t display-message 'No blocked agents or alerts'
fi
