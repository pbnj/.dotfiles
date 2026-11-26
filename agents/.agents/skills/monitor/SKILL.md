---
name: monitor
description:
  Watch a GitHub pull request with gh-pr-watch until it is closed, or merged and
  any Scalr applies of it have finished, fixing CI failures, unaddressed review
  threads and comments, merge conflicts, and failed Scalr plan/apply runs as
  they appear. Use when the user runs /monitor, or asks to monitor, watch or
  babysit a PR.
argument-hint: "<PR URL | OWNER/REPO#N | N>"
---

# Monitor a PR

Watch the PR the user named (`$ARGUMENTS`, or the text after the skill command
if that placeholder was not substituted) until it is closed, or merged and any
Scalr applies of it have finished. The watcher is `gh-pr-watch --stream`, which
prints one line per new event.

If your harness has a tool that runs a command in the background and wakes you
on each new output line (Claude Code's `Monitor`), use it:

```text
Monitor(
  description: "PR OWNER/REPO#N: CI, reviews, conflicts, Scalr",
  command: "gh-pr-watch --stream -p https://github.com/OWNER/REPO/pull/N",
  timeout_ms: 1800000,
)
```

Otherwise run it as a background process writing to a log, and read the new
lines every few minutes until it exits:

```bash
log="${TMPDIR:-/tmp}/gh-pr-watch-OWNER-REPO-N.log"
nohup gh-pr-watch --stream -p https://github.com/OWNER/REPO/pull/N >>"$log" 2>&1 &
echo $! >"$log.pid"
# later: tail -n +<last line read + 1> "$log"; kill -0 "$(cat "$log.pid")" tells you if it is still running
```

- Pass the PR to `-p` as its URL. Turn `OWNER/REPO#N` into
  `https://github.com/OWNER/REPO/pull/N`; a bare `N`, or no argument, works only
  from a checkout of the PR's repo (no argument means the current branch's PR).
- Each stdout line is one event, printed once: the first word is its kind (`CI`,
  `THREAD`, `REPLY`, `REVIEW`, `APPROVAL`, `CONFLICT`, `SCALR`, `WATCH`, `PR`).
  The full list is in the header of `gh-pr-watch`
  (`sed -n '/^# Lines/,/^# Dependencies/p' "$(command -v gh-pr-watch)"`). The
  user's own threads, replies and reviews are not reported.
- It exits 0 after `PR #N is MERGED|CLOSED -- stopping` or
  `SCALR finished on <sha> -- stopping`: the watch is over. Exit 1 with
  `SCALR cannot watch` means the Scalr applies need the `scalr` CLI,
  `SCALR_TOKEN` and `SCALR_HOSTNAME`: tell the user.
- When the monitor expires, re-arm it with the same command. What was already
  printed is kept per PR, so only new events arrive. Add `--fresh` only to
  replay everything.
- `WATCH gh|scalr failing` means polling has failed three times in a row; it
  keeps retrying. Check `gh auth status` (or the Scalr credentials) if it
  persists.
- The first run reports everything already on the PR at once: check whether each
  event is already handled (e.g. a thread you replied to) before acting on it.
- Top-level PR comments (`gh pr view --comments`) are not streamed. Check them
  when you arm or re-arm the monitor, and after each push.

Watch for these and fix them as they appear:

1. **CI failures** (`CI fail|cancel`): read the failing job's logs, push a fix,
   and watch the re-run. `CI pass` and `CI green` need no action.
2. **Unaddressed review threads, replies and comments** (`THREAD`, `REPLY`,
   `REVIEW`): push a fix, or explain why no change is needed. Then reply in the
   thread starting with the outcome, **Addressed** (with the fixing commit),
   **Won't fix** or **Incorrect**, followed by a sentence on why, and resolve
   the thread (GraphQL `resolveReviewThread`). Top-level PR comments can't be
   resolved: reply with the outcome only. Skip the user's own comments.
3. **Merge conflicts** (`CONFLICT`): update the branch from its base and resolve
   the conflicts.
4. **Scalr plan or apply runs that fail** (`SCALR errored`, a failing
   `scalr/...` check): fix the Terraform/OpenTofu cause and push. Report runs
   waiting for approval or a policy override (`SCALR approval`, `SCALR policy`)
   and `SCALR no run` to the user rather than confirming or overriding them
   yourself.
