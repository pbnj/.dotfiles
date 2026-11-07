# fai-send: browser URLs and selected text → fai

Send work to [`fai`](../../../../utils/.local/bin/fai), the Rex fuzzy project
launcher, from anywhere on macOS:

| Trigger                                | Runs                  |
| -------------------------------------- | --------------------- |
| Hyper+A                                | `fai <url>`           |
| Right-click a selection → Send to fai… | `FAI_TEXT=<text> fai` |

Hyper is Tinycast's Caps Lock → Control+Option+Command. Focus a browser tab,
press Hyper+A, and fai opens in a floating layer in the Rex app, exactly as with
Rex's `ctrl+b f`, but seeded with the URL:

- A GitHub URL picks its repo (cloning it into `~/Projects/github.com` if
  needed) and, with a unique match, launches the default agent straight away in
  a new Rex window. A pull request, issue or file link is typed into the agent's
  prompt, unsubmitted.
- Any other URL (a Linear issue, a blog post) is shown under the picker, which
  lists your repos; pick one, and the URL is typed into the agent's prompt,
  unsubmitted.
- TAB / SHIFT-TAB in the picker choose the agent; see
  [`fai`](../../../../utils/.local/bin/fai) for the rest.

## Right-click → Send to fai…

Select text in any app (an error message, a code snippet, a paragraph of a
spec), right-click it and choose **Send to fai…** (under **Services** when the
menu has several). The picker always opens, showing the text's first line under
it; pick a repo and agent, and the whole text is pasted into the agent's prompt,
unsent, for you to add to. A selection that is just one URL is sent as a URL
instead, exactly like Hyper+A. The cloud agent still asks for its task and gets
the text below it. Selections over 16 KiB are refused.

The Quick Action, `Send to fai.workflow`, runs `~/.local/bin/fai-send --stdin`
with the selection on stdin. If the menu item doesn't show, enable it in
**System Settings → Keyboard → Keyboard Shortcuts → Services → Text** (a
shortcut can be assigned there too).

## How it works

1. Tinycast runs `~/.local/bin/fai-send` (`utils/.local/bin/fai-send`), which
   runs `launch.py`. The Quick Action runs it with `--stdin`, which skips the
   next step and sends `{"text": ...}` (or `{"url": ...}`) instead.
2. `launch.py` reads the **frontmost** browser's URL with the compiled `fai`
   helper (Accessibility's window document URL, else the address bar via
   Command+L; never the clipboard). Firefox, Brave, Chrome, Safari, Edge, Arc,
   Zen, Vivaldi and Opera are supported.
3. It brings Rex to the front and waits until it is frontmost, then runs the
   `fai` action from `rex/.config/rex/init.lua` in the session the Rex app shows
   (`rex do -s SESSION fai --args -`). The URL goes on stdin, so it never lands
   in argv. A layer created while Rex was still in the background would show in
   front, but keyboard focus would stay on the block behind it.

The Rex app must be running; otherwise Tinycast shows an error.

## Install or re-register

Requires Tinycast, the Rex app, and Xcode Command Line Tools (for `swiftc` and
`/usr/bin/python3`). `~/.local/bin/fai-send` must already be linked from the
`utils` package, and `~/.config/rex/init.lua` from the `rex` package
(`rex config reload` after changing it). Then run:

```sh
PYTHONDONTWRITEBYTECODE=1 /usr/bin/python3 \
  ~/.dotfiles/macos/.local/share/fai-send/install.py
```

The installer compiles the URL capture helper into
`~/Library/Caches/fai-send/fai`, links this directory to
`~/.local/share/fai-send`, copies the Quick Action into `~/Library/Services`
(replacing only an earlier copy of it), removes what the old `agent-url` name
left in `~/.local/share` and `~/.local/bin`, briefly quits Tinycast, and merges
the command and hotkey. Old backups under `~/.local/state/agent-url` and the old
`~/Library/Caches/agent-url` are left alone and can be deleted. Every command
named **Browser URL — …** (including the per-agent commands earlier versions
installed) and its hotkey is replaced; unrelated settings and commands are
preserved, and a failed preference import is rolled back. Original preferences
are backed up, owner-only, under `~/.local/state/fai-send/tinycast-*.plist`.
Rerun it if the helper cache is cleared, or after changing `config.json` (the
command name and Carbon key code).

Check for conflicts without changing anything:

```sh
PYTHONDONTWRITEBYTECODE=1 /usr/bin/python3 \
  ~/.local/share/fai-send/install.py --check
```

## Permissions

Tinycast needs Accessibility permission in **System Settings → Privacy &
Security → Accessibility** (normally already on for Hyper). A capture failure
appears in Tinycast's command error dialog.

## Verify without opening fai

```sh
fai-send --dry-run --url 'https://github.com/org/repo/pull/123'
printf 'some error\nline 2' | fai-send --stdin --dry-run
```

Omit `--url` to capture the frontmost browser tab instead. Run the unit tests:

```sh
PYTHONDONTWRITEBYTECODE=1 /usr/bin/python3 -m unittest discover \
  -s ~/.local/share/fai-send -v
```

## Remove

Delete `~/Library/Services/Send to fai.workflow` to remove the Quick Action.
Delete the **Browser URL — fai** command in Tinycast Settings → Commands;
Tinycast removes its hotkey too. For a full rollback, quit Tinycast, run
`defaults import com.tinycast.app /path/to/the/backup.plist`, and reopen it.
