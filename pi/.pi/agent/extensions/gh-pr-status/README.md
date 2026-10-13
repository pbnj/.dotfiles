# Pi PR status widget and Monitor tool

Loaded automatically from `~/.pi/agent/extensions/gh-pr-status/`. In interactive
Pi sessions, the widget shows up to five monitored PRs below the editor. Pi's
own status line already provides the active model, repo/branch, and context
usage. The widget reads `${XDG_CACHE_HOME:-~/.cache}/gh-pr` every 30 seconds; it
never calls GitHub. PR snapshots are included across repos when they match this
Pi session or a PR identity parsed from a `Monitor` description such as
`CI and reviews on owner/repo#42` (or a `gh-pr-watch` command); the current
origin repo/branch is a fallback. Active monitor targets appear as linked PR
numbers immediately, and the normal CI/review details fill in when a cache
snapshot becomes available. The managed PR list is retained for the session
because another agent can overwrite a snapshot's single `watcher` field.
Missing, old (>15 min), or malformed snapshots are ignored.

The former `/watch-pr` command is replaced by the model-callable `Monitor` tool.
For example, pass the absolute watcher path and a PR description:

```json
{
  "command": "/absolute/path/to/gh-pr-watch -R owner/repo 42 --fresh",
  "description": "CI and reviews on owner/repo#42",
  "timeout_ms": 1800000
}
```

`Monitor` also accepts a WebSocket source (`ws: { url, protocols? }`) instead of
`command`. Command stdout/stderr lines and WebSocket messages are delivered to
the agent as asynchronous, explicitly untrusted monitor events. Monitors default
to five minutes and cap at 30 minutes in TUI sessions or 10 minutes in
UI-capable RPC sessions; `MonitorStop` stops one by its returned `monitor_id`.
No-UI modes reject monitors because they cannot deliver events or request
approval. TUI/RPC sessions confirm command and WebSocket access before launch;
WebSocket targets resolving to private, link-local, or reserved addresses are
rejected. Commands execute as the current user and are not sandboxed; the
`Monitor` tool is marked open-world and destructive for permission extensions.
Monitors stop on session switch, reload, or shutdown.

The widget does not render Scalr runs yet: the current `gh-pr-watch` cache
writer does not publish `scalr.runs` and deletes the PR snapshot at merge. Add
those fields and preserve merged apply-watch snapshots in the producer before
enabling Scalr rows here.

Tests: `node --test pi/tests/*.test.ts` from the dotfiles root (Node 26+).
