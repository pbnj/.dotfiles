# Browser URL → coding agent

Native Tinycast hotkeys; no AeroSpace, SketchyBar, or key-sequence daemon.

| Shortcut      | Agent   | Model / effort     |
| ------------- | ------- | ------------------ |
| Hyper+H       | Claude  | Haiku / max        |
| Hyper+O       | Claude  | Opus / medium      |
| Hyper+S       | Claude  | Sonnet / medium    |
| Hyper+Shift+S | Copilot | GPT-6.1 Sol / high |
| Hyper+Shift+G | Copilot | Auto               |
| Hyper+Shift+L | Copilot | GPT-6 Luna / max   |
| Hyper+P       | Pi      | Configured default |

Hyper is Tinycast's Caps Lock → Control+Option+Command, **without Shift**.
Release the shortcut after pressing it. Focus a browser tab first. The selected
agent opens with **only the URL in its input editor**. Nothing is submitted:
edit the draft and press Enter yourself when you are ready.

## Behavior

- Reads the **frontmost** browser's current URL, never another background
  browser's last tab.
- Reads Accessibility's window document URL when available; otherwise focuses
  the address bar with Command+L, reads its Accessibility value, then escapes.
  It never reads or writes the clipboard. The address-bar fallback can change
  keyboard focus/selection.
- Supports Firefox, Brave, Chrome, Safari, Edge, Arc, Zen, Vivaldi, and Opera
  (including their bundle-ID-suffixed channels). Accessibility behavior varies
  by browser; capture fails explicitly if the URL is unavailable.
- Opens a **new tmux window**, or a split in an existing window with the same
  name (see below). From tmux, it uses the current session; from a browser
  shortcut, it prefers the most recently active attached session. If only an
  unattached session exists, Ghostty attaches to it. With no tmux sessions at
  all, it creates an `agent-url` session and opens Ghostty attached to it.
  Existing agent sessions are never typed over.
- GitHub URLs resolve to `~/Projects/github.com/<org>/<repo>`, including repo
  roots, pull requests, issues, files, and Actions links. If the checkout is
  missing, `gh repo clone` clones it **before** the tmux window/agent opens,
  following the convention in `~/.local/bin/fzf-tmux-project`.
- Existing checkouts/worktrees are reused without pulling or changing branches.
  Failed clones leave no partial checkout at the destination. Concurrent
  shortcuts share a clone lock. Existing non-Git paths are never overwritten.
- Other URLs (and GitHub account/product pages) use `~/Projects/github.com`. The
  draft retains the **original full URL**, not just the org/repo.
- Window names: Linear issue → its ID (`ENG-123`); GitHub PR → `<repo>#<n>`
  (`widget#123`); other GitHub repo URLs → `<repo>` (`widget`); anything else →
  `<dir>-<preset>`. If the target session already has a window with that name,
  the agent opens in a new split there and that window is selected.
- Claude uses `--dangerously-skip-permissions --remote-control`. Copilot uses
  `--yolo --mode interactive`; Pi uses its normal defaults. These settings do
  not submit the URL or start a task.
- **All agents use the same prefill mechanism as `fzf-tmux-project`.** The pane
  runner schedules `~/.local/bin/fzf-tmux-project --prefill <pane> <url>` using
  `tmux run-shell -b`, then replaces itself with the selected agent. The URL is
  not passed to the agent as an initial prompt.
- The existing shared worker checks every 0.5 seconds (up to about 30 seconds).
  It waits for a non-shell command and a nonempty screen unchanged across two
  samples, skips screens containing `trust`, then uses
  `tmux send-keys -t <pane> -l <url>` **without Enter**.
- This deliberately shares the reference script's stable-screen heuristic,
  rather than parsing each agent's UI. If the pane exits or never settles before
  the timeout, it quietly leaves the URL unfilled, just like the reference.
  Login/trust dialogs remain manual; settle detection is not a guarantee that
  every possible startup dialog has finished.
- No Pi extension, Copilot PTY bridge, Claude native prefill flag, boilerplate,
  positional initial prompt, or prompt-submission API is used. URL text is shell
  quoted, and hashes are escaped against tmux format expansion.
- No URL is written to launcher log files; normal CLI draft/session persistence
  still applies. Agent startup may connect to MCP/Remote Control services, but
  the launcher does not send the URL as a model request.

The permission-bypass flags are intentional and are **not a sandbox** once you
submit a prompt. Treat page content as untrusted.

## Customize

The installed directory is a symlink into this dotfiles directory:

- `~/.local/share/agent-url/config.json`: model IDs, effort levels, fallback
  `working_directory`, `github_root`, and native Carbon keycodes. Changes apply
  on the next launch; rerun the installer after changing shortcut metadata.
- `~/.local/bin/agent-url`: launcher entry point, also usable from a terminal.

Browser URLs can contain private identifiers or query parameters. The full URL
stays in the editable draft until you submit it to the selected provider.
Capturing a URL does not itself grant an agent access to an authenticated page;
the agent still needs an appropriate browser or connected integration.

## Install or re-register

Requires Tinycast, Ghostty, tmux, the three agent CLIs, and Xcode Command Line
Tools (for `swiftc` and macOS's `/usr/bin/python3`). Prefilling reuses
`~/.local/bin/fzf-tmux-project` and requires Bash 4+ (the installed Homebrew
Bash). Cloning requires an authenticated GitHub CLI (`gh auth login`). No Python
packages are needed.

The `utils` package must already provide `~/.local/bin/agent-url` (for example,
via the existing `~/.local/bin` symlink). Then run:

```sh
PYTHONDONTWRITEBYTECODE=1 /usr/bin/python3 \
  ~/.dotfiles/macos/.local/share/agent-url/install.py
```

The installer compiles the small URL capture helper into
`~/Library/Caches/agent-url/browser-url`, links the data directory, checks for
shortcut/name conflicts, briefly quits Tinycast, merges commands/bindings,
verifies the preferences, and reopens Tinycast if it was running. Unrelated
settings and commands are preserved; a failed preference import is rolled back.
Rerun this command if the helper cache is cleared.

Original preferences are backed up, with owner-only permissions, under
`~/.local/state/agent-url/tinycast-*.plist`.

To check for conflicts without modifying anything:

```sh
PYTHONDONTWRITEBYTECODE=1 /usr/bin/python3 \
  ~/.local/share/agent-url/install.py --check
```

## Permissions

Tinycast needs Accessibility permission in **System Settings → Privacy &
Security → Accessibility**. This is normally already enabled for Hyper. Direct
terminal use needs Accessibility permission for the invoking terminal.

No Accessibility permissions are granted or bypassed by the installer. A capture
failure appears in Tinycast's command error dialog.

## Verify without starting an agent

```sh
agent-url sol --dry-run --url 'https://github.com/org/repo/pull/123'
```

Omit `--url` to capture the frontmost browser tab without sending it to an
agent. Dry-run prints the resolved checkout directory, org/repo, command,
prefill URL, and `"submit": false`; it does not clone or create windows. Use a
non-private URL if sharing the output.

Run the unit tests:

```sh
PYTHONDONTWRITEBYTECODE=1 /usr/bin/python3 -m unittest discover \
  -s ~/.local/share/agent-url -v
```

An opt-in live TUI test uses a separate tmux server, opens only idle agents, and
never presses Enter (login/trust dialogs may require manual setup first):

```sh
bash ~/.local/share/agent-url/test-ui.sh haiku opus sonnet sol auto luna pi
```

## Remove or restore

To remove just these shortcuts, delete the seven **Browser URL — …** custom
commands in Tinycast Settings → Commands; Tinycast removes their hotkeys too.

For a full rollback, first quit Tinycast, then use
`defaults import com.tinycast.app /path/to/the/backup.plist` and reopen it. A
full rollback replaces preferences changed since that backup, so removing the
commands in Settings is preferable if you have made other changes.
