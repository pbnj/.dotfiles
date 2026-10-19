#!/usr/bin/env bash

# Opens YouTube in a new Brave window on workspace Y (caps+y). Brave's window
# rule sends every new Brave window to B before its title says YouTube, so the
# new window is moved to Y once it appears.
PATH="/opt/homebrew/bin:$PATH"
BRAVE=com.brave.Browser

windows() {
  aerospace list-windows --monitor all --app-bundle-id "$BRAVE" --format '%{window-id}' | sort
}

before="$(windows)"
open -na "Brave Browser" --args --new-window https://www.youtube.com

# up to 5 s for the window to show up
for _ in $(seq 50); do
  new="$(comm -13 <(echo "$before") <(windows) | head -1)"
  if [ -n "$new" ]; then
    aerospace move-node-to-workspace --window-id "$new" Y
    aerospace workspace Y
    aerospace focus --window-id "$new"
    exit 0
  fi
  sleep 0.1
done
exit 1
