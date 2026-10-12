# Pi PR status widget

Loaded automatically from `~/.pi/agent/extensions/gh-pr-status/`. In interactive
Pi sessions, shows the active model, repo/branch, context usage, and up to five
watched PRs below the editor. Reads `${XDG_CACHE_HOME:-~/.cache}/gh-pr` every 30
seconds; it never calls GitHub. PRs watched by this Pi session
(`watcher.pi_session`) are included across repos, with the current origin
repo/branch as a fallback. Missing, old (>15 min), or malformed snapshots are
ignored.

Start `gh-pr-watch` separately from a Pi shell to populate the cache (it
inherits `PI_SESSION_ID`). This extension does not start or own watcher
processes. It does not render Scalr runs yet: the current `gh-pr-watch` cache
writer does not publish `scalr.runs` and deletes the PR snapshot at merge. Add
those fields and preserve merged apply-watch snapshots in the producer before
enabling Scalr rows here.

Tests: `node --test pi/tests/gh-pr-status.test.ts` from the dotfiles root (Node
26+).
