# tmux

Window tabs show the most urgent tracked agent state across their panes:

| Badge | State                 | Inactive tab |
| ----- | --------------------- | ------------ |
| ◐     | Working               | Amber        |
| ○     | Idle                  | Dim          |
| !     | Blocked on user input | Red          |

The selected tab retains its high-contrast foreground; the symbol still
identifies the state. Windows without a known agent state have no badge. Native
tmux flags stay beside the window name, with a space before the agent badge (for
example, `4:project* ◐`). Each tab keeps a trailing inset so the badge cannot
touch its neighbour. Window names and bell navigation are unchanged.

A single cached status-left `#()` job runs with the existing 1-second status
refresh. It resolves every window once, rather than scanning agents separately
for each tab, and updates window-local `@agent_state` options only on changes.
It starts no background daemon.

- **Pi:** uses the existing lifecycle status files in
  `~/.cache/pi-sketchybar/sessions` (or `PI_SKETCHYBAR_SESSION_DIR`). Dead
  processes, invalid records, and heartbeats older than 5 minutes are ignored.
- **Claude:** reuses the SketchyBar configuration's `claude_sessions.sh`
  resolver, including attached native workers and the visible-footer fallback.
  SketchyBar need not be running. Unknown states are not reported as idle.
- Socket paths and live pane IDs scope records to the right tmux server and
  window, including after panes move. Closing an agent clears its badge on the
  next refresh. Other agents are currently untracked.

Requires Python 3; Claude resolution also uses Bash, jq, and the stowed
SketchyBar configuration. Reload with
`tmux source-file ~/.config/tmux/tmux.conf`.

Tests use fixtures and a temporary tmux server, never the real agent sessions:

```sh
python3 -m unittest discover -s tmux/tests -v
```
