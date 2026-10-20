# SketchyBar

The bar follows macOS appearance with TokyoNight Day/Moon, matching Ghostty,
tmux and Pi. `.config/sketchybar/colors.sh` supplies every plugin's palette. Day
accents are darkened for small-text contrast; backgrounds are opaque so contrast
does not depend on the wallpaper.

A hidden `theme_watcher` subscribes to `AppleInterfaceThemeChangedNotification`
and `system_woke`. Its `theme.sh` script recolors existing items and popups,
then triggers `theme_refresh` to reapply state colors and workspace focus. It
does not reload the bar, toggle popups, or run an appearance-polling daemon. New
popup rows use the same palette.

Pills use balanced 8px outer content padding. Icon-and-label pairs retain a
smaller 4px internal gap; icon-only and label-only items pad both visible edges.
The stats and Claude groups use 4px gaps between members, with the 8px outer
insets applied only to the first and last visible members. Claude's edge padding
follows usage windows as they appear or expire. Popup rows and workspace app
segments retain their own insets.

The Wi-Fi icon next to Twingate is green when associated with a network, yellow
when powered on but disconnected, dim when powered off, and red if its state is
unavailable. It tracks the Wi-Fi link, not internet reachability or the default
route (which may use a VPN). It does not need SSID/location access. Click it to
open Wi-Fi settings. It refreshes on Wi-Fi changes, wake, theme changes, and
every 10 seconds as a fallback.

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

After editing the config, run `sketchybar --reload` once. To reapply the current
system theme without reloading, run `sketchybar --trigger theme_change`.

Offline tests mock macOS commands, SketchyBar, and tmux; they do not change the
real system appearance:

```sh
python3 -m unittest discover -s sketchybar/tests -v
```
