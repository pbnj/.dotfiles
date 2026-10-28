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

## Enable Accessibility permission

`twingate_menu` presses menu items through the Accessibility API, so macOS has
to trust it first. Until then it exits with `not trusted for Accessibility`.

1. Open System Settings → Privacy & Security → Accessibility.
2. Click **+**, press Command+Shift+G, enter `~/.local/bin/twingate_menu`, and
   click **Open**.
3. Make sure its switch is on.

It is a standalone binary so the permission goes to it alone, not to `osascript`
or your terminal.

The binary is ad-hoc signed, so rebuilding it can invalidate the permission. If
`not trusted for Accessibility` comes back after a rebuild, select the entry,
remove it with **−**, and add it again.

## Run

```bash
twingate_menu login    # press "Log in to ..."
twingate_menu logout   # press "Log Out & Disconnect"
```

The Twingate app must be running.

## Exit codes

| Code | Meaning                                                                  |
| ---- | ------------------------------------------------------------------------ |
| 0    | The menu item was pressed                                                |
| 1    | Not trusted, Twingate not running, or the menu or menu item wasn't found |
| 2    | Usage error                                                              |

Errors are printed to stderr, prefixed with `twingate_menu:`.
