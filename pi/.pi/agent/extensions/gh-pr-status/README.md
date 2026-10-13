# Pi PR status widget

Loaded automatically from `~/.pi/agent/extensions/gh-pr-status/`. In interactive
Pi sessions, shows up to five watched PRs below the editor. Pi's own status line
already provides the active model, repo/branch, and context usage. The widget
reads `${XDG_CACHE_HOME:-~/.cache}/gh-pr` every 30 seconds; it never calls
GitHub. PRs watched by this Pi session (`watcher.pi_session`) and PRs started
with `/watch-pr` are included across repos, with the current origin repo/branch
as a fallback. Active `/watch-pr` targets appear as linked PR numbers
immediately; check and review details fill in when a cache snapshot becomes
available. The managed-watch list is needed because another agent watching the
same PR can overwrite the snapshot's single `watcher` field. Missing, old (>15
min), or malformed snapshots are ignored.

Use `/watch-pr` for the current branch's PR, `/watch-pr 42` for a PR in the
current repo, or `/watch-pr https://github.com/owner/repo/pull/42` for another
repo. `-R owner/repo` selects a repo for a number or branch. `--fresh` clears
that PR's shared notification history and re-reports existing events, which can
also re-trigger agent tasks; use it only when that is intended. By default, new
CI failures/cancellations and review threads, replies, or reviews are batched
into agent tasks as well as Pi notifications. Each queued task contains only the
emitted event text, without a generated follow-up prompt. The agent must still
fetch current details and validate before making changes. Use `--notify-only` to
disable agent tasks for a watch. One watcher per PR runs in the background and
inherits Pi's session ID via `PI_SESSION_ID`. It stops when the PR closes (or
the Scalr apply watch finishes), and is terminated on session switch, reload, or
exit.

The command looks for `~/.local/bin/gh-pr-watch` or the checkout at
`~/Projects/github.com/komodohealth/security-automation/plugins/security-dev/skills/gh/scripts/gh-pr-watch/gh-pr-watch`.
Set `GH_PR_WATCH` to an absolute executable path to override that lookup. You
can still start an external watcher instead; the widget only reads cache.

The widget does not render Scalr runs yet: the current `gh-pr-watch` cache
writer does not publish `scalr.runs` and deletes the PR snapshot at merge. Add
those fields and preserve merged apply-watch snapshots in the producer before
enabling Scalr rows here.

Tests: `node --test pi/tests/*.test.ts` from the dotfiles root (Node 26+).
