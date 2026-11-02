# Browser URL → fai

A native Tinycast hotkey that opens the frontmost browser tab's URL in
[`fai`](../../../../bash/.functions), the Rex fuzzy project launcher.

| Shortcut | Runs        |
| -------- | ----------- |
| Hyper+A  | `fai <url>` |

Hyper is Tinycast's Caps Lock → Control+Option+Command. Focus a browser tab,
press Hyper+A, and fai opens in a floating layer in the Rex app, exactly as with
Rex's `ctrl+b p`, but seeded with the URL:

- A GitHub URL picks its repo (cloning it into `~/Projects/github.com` if
  needed) and, with a unique match, launches the default agent straight away in
  a new Rex window. A pull request, issue or file link is typed into the agent's
  prompt, unsubmitted.
- Any other URL becomes the picker's query, which falls back to a GitHub repo
  search; edit it to pick a repo. Its link is not prefilled.
- TAB / SHIFT-TAB in the picker choose the agent; see `fai` in `bash/.functions`
  for the rest.

## How it works

1. Tinycast runs `~/.local/bin/agent-url` (`utils/.local/bin/agent-url`), which
   runs `launch.py`.
2. `launch.py` reads the **frontmost** browser's URL with the compiled `fai`
   helper (Accessibility's window document URL, else the address bar via
   Command+L; never the clipboard). Firefox, Brave, Chrome, Safari, Edge, Arc,
   Zen, Vivaldi and Opera are supported.
3. It finds the session the connected Rex app shows and runs the `fai` action
   from `rex/.config/rex/init.lua` there (`rex do -s SESSION fai --args -`). The
   URL goes on stdin, so it never lands in argv. Then it brings Rex to the
   front.

The Rex app must be running; otherwise Tinycast shows an error.

## Install or re-register

Requires Tinycast, the Rex app, and Xcode Command Line Tools (for `swiftc` and
`/usr/bin/python3`). `~/.local/bin/agent-url` must already be linked from the
`utils` package, and `~/.config/rex/init.lua` from the `rex` package
(`rex config reload` after changing it). Then run:

```sh
PYTHONDONTWRITEBYTECODE=1 /usr/bin/python3 \
  ~/.dotfiles/macos/.local/share/agent-url/install.py
```

The installer compiles the URL capture helper into
`~/Library/Caches/agent-url/fai`, links this directory to
`~/.local/share/agent-url`, briefly quits Tinycast, and merges the command and
hotkey. Every command named **Browser URL — …** (including the per-agent
commands earlier versions installed) and its hotkey is replaced; unrelated
settings and commands are preserved, and a failed preference import is rolled
back. Original preferences are backed up, owner-only, under
`~/.local/state/agent-url/tinycast-*.plist`. Rerun it if the helper cache is
cleared, or after changing `config.json` (the command name and Carbon key code).

Check for conflicts without changing anything:

```sh
PYTHONDONTWRITEBYTECODE=1 /usr/bin/python3 \
  ~/.local/share/agent-url/install.py --check
```

## Permissions

Tinycast needs Accessibility permission in **System Settings → Privacy &
Security → Accessibility** (normally already on for Hyper). A capture failure
appears in Tinycast's command error dialog.

## Verify without opening fai

```sh
agent-url --dry-run --url 'https://github.com/org/repo/pull/123'
```

Omit `--url` to capture the frontmost browser tab instead. Run the unit tests:

```sh
PYTHONDONTWRITEBYTECODE=1 /usr/bin/python3 -m unittest discover \
  -s ~/.local/share/agent-url -v
```

## Remove

Delete the **Browser URL — fai** command in Tinycast Settings → Commands;
Tinycast removes its hotkey too. For a full rollback, quit Tinycast, run
`defaults import com.tinycast.app /path/to/the/backup.plist`, and reopen it.
