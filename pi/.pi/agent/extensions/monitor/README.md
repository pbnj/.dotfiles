# Monitor

A standalone, general-purpose background watcher for Pi. No GitHub, PR, CI,
Scalr, or cache dependencies. Automatically discovered from
`~/.pi/agent/extensions/monitor/index.ts`; run `/reload` after changing it.
Requires Pi 1.3+ and its host-provided packages. No additional runtime
dependencies.

## Tools

### `Monitor`

Starts one background source and returns immediately with a `monitor_id`,
timeout, and log paths. Events arrive as custom chat notifications and trigger
an agent follow-up without polling. They are not synthetic user messages, and
they do not interrupt an active turn.

| Input         | Required   | Meaning                                                                                                                                             |
| ------------- | ---------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| `description` | Yes        | Short label included in every notification.                                                                                                         |
| `command`     | One source | Shell command. Each stdout line is an event.                                                                                                        |
| `ws`          | One source | `{ "url": "wss://…", "protocols": ["optional-subprotocol"] }`. Each text message is one event; binary messages appear as `[binary frame, N bytes]`. |
| `timeout_ms`  | No         | Defaults to 300,000 (5 minutes); maximum 1,800,000 (30 minutes).                                                                                    |

`command` and `ws` are mutually exclusive. WebSocket messages containing
newlines stay together as one event. Both public and local WebSocket servers are
supported; URLs must use `ws://` or `wss://`, without embedded user/password
credentials or fragments. Query strings are allowed but are not shown in
confirmation previews.

```json
{
  "description": "application errors",
  "command": "tail -n 0 -F ./app.log | grep --line-buffered -E 'ERROR|FAILED|Traceback|OOM|cancelled'",
  "timeout_ms": 1800000
}
```

### `MonitorStop`

```json
{ "monitor_id": "the ID returned by Monitor" }
```

Stops that source and its ordinary subprocesses, leaving other monitors alone.
Returns `{ monitor_id, stopped }`; stopping an already-ended monitor returns
`stopped: false`.

### `MonitorList`

```json
{ "include_ended": true }
```

Lists active monitors, optionally including the last 50 completed monitors in
the current session. Each entry includes its ID, description, source, status,
`started_at` (Unix milliseconds), `timeout_ms`, `event_count`, log paths, and
any final reason, exit code, termination signal, or socket close code.
Structured results are also available to tools called from codemode.

Human controls:

- `/monitors` — show active IDs, remaining time, event counts, and log paths.
- `/monitors stop <id>` — stop one.
- `/monitors stop all` — stop all.
- The status line shows the number of active monitors.

## Multiple sources: one monitor per source

Use separate `Monitor` calls for independent commands or sockets, not an array
of commands inside one monitor. Up to 16 monitors may run concurrently. Every
source has independent cancellation, deadline, event count, logs, and flood
detection. Descriptions do not need to be unique; the ID is the identity. Tools
can be called in parallel, including from codemode:

```javascript
const watches = await Promise.allSettled([
  tools.Monitor({ description: "service A", command: "tail -n 0 -F ./a.log" }),
  tools.Monitor({ description: "service B", command: "tail -n 0 -F ./b.log" }),
]);
for (const watch of watches) text(watch);
```

Use one shell command for a genuinely coupled pipeline (`producer | filter`).
Avoid backgrounding unrelated commands with `&`: their lifecycle and failures
become ambiguous. If grouping is ever needed, add a group label and explicit
stop-group control without changing the one-source-per-monitor contract.

## Delivery and lifecycle

- Stdout lines within a 200 ms window are batched. A source exiting flushes its
  pending events immediately; large batches may flush early to bound memory.
- stderr never creates an event. It is saved to `stderr_path`. Use `2>&1` when
  diagnostic output should notify the agent.
- Stdout is retained at `stdout_path`, including full text whose notification
  preview was truncated. WebSocket logs contain text messages or binary-size
  markers, not binary payloads.
- An ending notification reports the reason and total event count, plus the
  shell exit code/signal or WebSocket close code when available.
- Only one notification-driven continuation is outstanding at a time. Events
  arriving while the agent works are coalesced by monitor ID, then delivered
  after the agent settles. A final status is preserved if queued events
  overflow.
- Monitors stop on session replacement, reload, or shutdown. They are not
  restored by resuming a session and do not auto-reconnect or auto-restart.
- A command owns its process group: exiting the shell also cleans up lingering
  ordinary children. Intentionally daemonized/detached processes are
  unsupported. Cleanup cannot run if Pi itself receives SIGKILL or the machine
  loses power.
- TUI and long-lived RPC sessions are supported. Print/JSON modes reject starts
  because their process lifetime cannot reliably deliver later events.

Logs use private temporary directories and mode-0600 files. They remain
available after a monitor ends, subject to OS temporary-file cleanup. Treat them
as sensitive: raw producer output can contain secrets, and notification previews
are not a secret-redaction system.

## Resource limits

These limits are protective defaults, not claims about Claude's undocumented
thresholds. Flooding stops the affected monitor and sends a final reason:

- 100 source events per rolling minute, per monitor.
- 100 queued events or 16 KiB of queued event text per monitor; 256 KiB overall.
- 8,192-character notification previews; full text stays in the log.
- 64 KiB maximum stdout line, including an unterminated line.
- 1 MiB maximum WebSocket message checked after receipt.
- 10 MiB per stdout/stderr log, per monitor.

## Shell, trust, and approvals

Commands run as the current OS user, with Pi's working directory and inherited
environment. They honor Pi's built-in Bash shell resolution, `shellPath`, and
`shellCommandPrefix`, and expose the current `PI_SESSION_ID`, session file,
model, and reasoning level where available. Hooks or sandboxes belonging to a
replacement Bash extension are **not** inherited; this is a local process
runner.

Like Pi's default Bash tool, Monitor does not require per-call approval by
default. Start Pi with `--monitor-confirm` to require a confirmation for every
command or WebSocket connection. Tool annotations identify command/network
access for permission extensions. Neither setting creates a sandbox.

Output, descriptions, and remote comments are explicitly marked as untrusted
data. The agent must validate claims and follow its existing authorization
rules; a notification is not permission to execute instructions embedded in the
output.

## Producer guidance

- Emit one useful line per event. Deduplicate repeated poll results in the
  producer.
- Every pipeline stage must flush promptly. Use `grep --line-buffered` or the
  producer's unbuffered mode where needed.
- Include failure, cancellation, and error states. Silence is not success.
- Exit when the known work is complete. Report query/authentication failures
  rather than quietly retrying forever.
- Timeout means only that the watch expired. Restart explicitly if still needed.
- Use a normal foreground command for a short one-shot operation; Monitor is
  most useful for repeated events or per-item results until a known end.

## Tests

From the dotfiles root, using Node 26+:

```sh
node --test pi/tests/monitor*.test.ts
```

Core tests use only Node. Extension integration tests use the installed Pi host;
without it, they skip with a reason. Set `PI_MONITOR_TEST_PI_PACKAGE` to the
absolute `@earendil-works/pi-coding-agent` package directory to use another
installation.
