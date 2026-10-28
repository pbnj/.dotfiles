# twingate_menu

Log in to or out of Twingate from the command line by pressing items in
Twingate's menu bar menu through the Accessibility API. Login has to start in
the Twingate app, which begins the Okta flow and receives the redirect, so
opening the auth page directly is not enough.

## Build

From the repo root:

```bash
mise run twingate:build
```

This compiles `twingate_menu.swift` with `swiftc -O` into
`~/.local/bin/twingate_menu`. mise skips the build when the binary is newer than
the source; add `--force` to rebuild anyway. The binary is gitignored.

Without mise:

```bash
swiftc -O macos/twingate/twingate_menu.swift -o ~/.local/bin/twingate_menu
```

Building needs the Xcode command line tools (`xcode-select --install`).

## Run

```bash
twingate_menu login    # press "Log in to ..."
twingate_menu logout   # press "Log Out & Disconnect"
```

The Twingate app must be running. The first run fails with
`not trusted for Accessibility`: add `~/.local/bin/twingate_menu` under System
Settings → Privacy & Security → Accessibility. It is a standalone binary so that
permission goes to it alone, not to `osascript` or a terminal.

The binary is ad-hoc signed, so rebuilding it can invalidate the grant. If
`not trusted for Accessibility` comes back after a rebuild, remove the entry and
add it again.

## Exit codes

| Code | Meaning                                                                  |
| ---- | ------------------------------------------------------------------------ |
| 0    | The menu item was pressed                                                |
| 1    | Not trusted, Twingate not running, or the menu or menu item wasn't found |
| 2    | Usage error                                                              |

Errors are printed to stderr, prefixed with `twingate_menu:`.
