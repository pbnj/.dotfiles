#!/bin/bash

set -uo pipefail

FLOAT_TERM="${1:-}"
LIST_PANES="$(tmux list-panes -F '#F' )"
PANE_ZOOMED="$(echo "${LIST_PANES}" | grep Z)"
PANE_COUNT="$(echo "${LIST_PANES}" | wc -l | bc)"

if [ -n "${FLOAT_TERM}" ]; then
  if [ "$(tmux display-message -p -F "#{session_name}")" = "popup" ]; then
    tmux detach-client
  else
    tmux popup -d '#{pane_current_path}' -xC -yC -w90% -h80% -E "tmux attach -t popup || tmux new -s popup"
  fi
else
  if [ "${PANE_COUNT}" = 1 ]; then
    tmux split-window -c "#{pane_current_path}"
  elif [ -n "${PANE_ZOOMED}" ]; then
    tmux select-pane -t:.-
  else
    tmux resize-pane -Z -t1
  fi
fi
