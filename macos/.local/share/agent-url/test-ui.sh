#!/bin/bash
# Opt-in smoke test: open idle TUIs in an isolated tmux server, never press Enter.
set -euo pipefail
root="$(cd "$(dirname "$0")" && pwd)"
socket="agent-url-ui-test-$$"
tmux_bin="/opt/homebrew/bin/tmux"
trap '"$tmux_bin" -L "$socket" kill-server 2>/dev/null || true' EXIT
tm() { "$tmux_bin" -L "$socket" -f /dev/null "$@"; }
tm new-session -d -x 120 -y 40 -s verify -c "$HOME/Projects/github.com" 'sleep 300'
url='https://example.com/draft'
if [[ "$#" -eq 0 ]]; then set -- haiku auto pi; fi
for kind in "$@"; do
    printf -v command 'exec /usr/bin/python3 %q %q --run --url %q' "$root/launch.py" "$kind" "$url"
    pane="$(tm new-window -d -t verify: -c "$HOME/Projects/github.com" -P -F '#{pane_id}' "$command")"
    found=false
    for ((i=0; i<150; i++)); do
      screen="$(tm capture-pane -p -t "$pane" 2>/dev/null)" || { echo "FAIL $kind: pane exited"; exit 1; }
      if [[ "$screen" == *"$url"* ]]; then found=true; break; fi
      sleep 0.2
    done
    if [[ "$found" != true ]]; then
      printf 'FAIL %s: draft not visible (startup dialog or prefill failure)\n%s\n' "$kind" "$screen"
      exit 1
    fi
    sleep 1
    screen="$(tm capture-pane -p -t "$pane")"
    if [[ "$screen" != *"$url"* ]]; then echo "FAIL $kind: draft disappeared"; exit 1; fi
    printf 'PASS %s: URL draft visible and remains unsubmitted\n' "$kind"
    tm kill-pane -t "$pane"
done
echo 'DONE: idle TUI smoke tests passed; no Enter keys were sent.'
