# SketchyBar

The bar follows macOS appearance with TokyoNight Day/Moon, matching Ghostty,
tmux and Pi. `.config/sketchybar/colors.sh` supplies every plugin's palette. Day
accents are darkened for small-text contrast. In both themes, the bar background
is 50% transparent and pill backgrounds are 35% transparent (65% opacity). Popup
backgrounds stay opaque. Translucent pill contrast depends on the wallpaper.

A hidden `theme_watcher` subscribes to `AppleInterfaceThemeChangedNotification`
and `system_woke`. Its `theme.sh` script recolors existing items and popups,
then triggers `theme_refresh` to reapply state colors and workspace focus. It
does not reload the bar, toggle popups, or run an appearance-polling daemon. New
popup rows use the same palette.

Pills use balanced 8px outer content padding. Icon-and-label pairs retain a
smaller 4px internal gap; icon-only and label-only items pad both visible edges.
The stats group uses 4px gaps between members, with the 8px outer insets applied
only to the first and last visible members. Popup rows and workspace app
segments retain their own insets.

The Wi-Fi icon next to Twingate is green when associated with a network, yellow
when powered on but disconnected, dim when powered off, and red if its state is
unavailable. It tracks the Wi-Fi link, not internet reachability or the default
route (which may use a VPN). Click for connection status, IPv4 address,
interface, and a Wi-Fi Settings shortcut. Network names are neither queried nor
displayed, so no Location access is needed. There is no network scan or
connectivity probe. Details are read only when opening the dropdown or while it
is open. It refreshes on Wi-Fi changes, wake, theme changes, and every 10
seconds as a fallback, without reopening a closed dropdown.

The audio indicator is icon-only. Click it for the output volume percentage
(including mute state), current default output, and current default input. Click
a popup row to open Sound settings. Device names come from macOS's built-in
`system_profiler`; no extra audio utility or microphone permission is needed.
The popup refreshes on volume changes and every 5 seconds while open, without
reopening a closed popup.

The battery has its own icon-only pill: five fill levels on battery power, a
battery with a lightning bolt while charging (including finishing charge), and a
plug when connected to power but not charging. Charging icons track the fill in
10% steps, with an outline below 10%. The dropdown keeps the charge-level icon.
Green is reserved for 100%; 67–99% uses the normal text color, 34–66% is yellow,
and 0–33% is red, regardless of power source. Click for charge percentage, power
source, charging status, the macOS time estimate, and Battery Settings. Routine
and theme updates refresh the rows without reopening the dropdown.

The Claude pill is icon-only, colored by the most urgent session state. Click
for a single usage line (`5h: 25% · 7d: 50%`) followed by the live tmux session
list. Each value keeps its own warning color. The usage row opens the usage
page; session rows focus that session. Missing or expired usage windows stay
hidden, and updates refresh an open dropdown without reopening a closed one.
Right-click still jumps to the session needing attention.

The Copilot pill appears while a native `copilot` CLI process owned by the
current user is running, and disappears when the last one exits. It checks every
5 seconds and on wake/theme changes without launching Copilot. Editor extensions
and commands that merely mention Copilot do not count. Its icon uses the
`sketchybar-app-font` Copilot glyph and the shared theme accent.

The GitHub pill runs `gh attention --all --json`, independent of the bar’s
working directory. It counts **distinct PRs**, not the sum of the overlapping
approved/review/feedback/failing sections (including drafts, just like the CLI).
Click for section counts and a clickable PR list, ten per page. CI failures,
feedback and conflicts come first, then approved PRs and pending reviews; each
group is newest-first. Previous/Next wrap around the list. The icons match the
CLI: ✘ CI, ✎ feedback, ✔ approved, ◷ pending review;  marks conflicts.

It refreshes on startup, wake, every five minutes, or **Refresh now** in the
popup. Clicking, paging, and theme changes use cached data, not network calls.
Green means no attention needed, yellow means pending/approved PRs, orange means
feedback, and red means failing CI. A failed refresh retains the last successful
count with `!` appended (or just `!` before the first success), never a
misleading zero. The footer shows the last successful update and errors.
Requires `gh` authenticated to GitHub, the `pbnj/gh-attention` extension, `jq`,
and coreutils `timeout` (Homebrew tools are already in `brew.sh`). Cache and
refresh diagnostics live in `${XDG_CACHE_HOME:-~/.cache}/sketchybar/github/`;
`GITHUB_SKETCHYBAR_CACHE_DIR` overrides that directory for tests.

After editing the config, run `sketchybar --reload` once. To reapply the current
system theme without reloading, run `sketchybar --trigger theme_change`.

Offline tests mock macOS commands, SketchyBar, and tmux; they do not change the
real system appearance:

```sh
python3 -m unittest discover -s sketchybar/tests -v
```
