# PR watch hooks for Pi

Keeps a `gh-pr-watch` Monitor armed for every PR this Pi session creates or
pushes to, using the same `~/.local/bin/gh-pr-watch-hook` script as Claude Code.
Requires Pi 1.4+, the sibling `monitor` extension, `gh`, and `jq`.

## Behavior

- `tool_result` detects successful `bash`/`Bash` PR creation and pushes,
  `mcp__…create_pull_request` calls, and `Monitor` calls that arm a watcher.
  Nested tool calls through codemode are included.
- When a PR lacks a live watch, the hook adds a custom context message telling
  Pi to start `gh-pr-watch` with Monitor for 30 minutes. The hook does not start
  a process on its own or modify the original tool result. Custom context
  survives codemode scripts that discard or filter their tool results.
- `agent_before_settle` checks the session's touched PRs. If an open PR lacks a
  live watch, it adds the watch instructions and requests one continuation. This
  can intervene only once per user/custom run, so a failed start cannot create
  an infinite continuation loop. Aborted/errored runs are not resumed.
- Print/JSON modes and sessions without an active Monitor tool are skipped.
- Hook calls are serialized, bounded to 15 seconds (tool results) or 30 seconds
  (settlement), and canceled on session replacement/reload/shutdown. Failures
  produce a warning rather than silently pretending a watcher is running.

The shared instructions cover CI failures/recovery, review feedback, merge
conflicts, Scalr plans and post-merge applies, and restarting expired Monitors
without `--fresh`. Review claims must be checked against the code; notifications
are not authorization to apply suggestions or approve Scalr runs.

## Installation and opting out

Pi auto-discovers `~/.pi/agent/extensions/gh-pr-watch/index.ts`; no settings
hook entries are needed. Run `/reload` after installing or changing it.

To stop nudges for a PR in the current Pi session:

```sh
gh-pr-watch-hook --agent pi ignore -R OWNER/REPO NUMBER
```

This does not stop an already running Monitor. Use `/monitors stop <id>` too if
needed. Tracking and ignore lists are scoped to the agent's unique session ID.

Pi's state lives in
`${XDG_STATE_HOME:-~/.local/state}/gh-pr-watch-hook/<session-id>/`. Claude
retains its original state directory and default command interface. Liveness
uses `watcher.pi_session` in the shared PR snapshots, not
`watcher.claude_session`. The Monitor extension already supplies `PI_SESSION_ID`
to its commands. A recently armed watch has a three-minute startup grace period;
otherwise its snapshot must be fresh and belong to this session.

## Tests

From the dotfiles root:

```sh
mise exec -- node --test pi/tests/gh-pr-watch.test.ts
mise exec -- shellcheck utils/.local/bin/gh-pr-watch-hook
```

Tests exercise the extension and shared shell hook with isolated state and a
stub `gh`; they never create PRs, push commits, or contact GitHub. The
host-loader smoke test uses the locally installed Pi package, or
`PI_GH_PR_WATCH_TEST_PI_PACKAGE` if set; it skips with a reason when neither is
available.
