#!/bin/sh

# share of the APFS container in use, as System Settings reports it: volumes
# share free space, so 1 - available/total counts every volume, not just Data.
# /bin/df pinned: GNU df (coreutils gnubin) has different columns.
USED="$(/bin/df -k /System/Volumes/Data | awk 'NR == 2 { printf "%.0f", 100 - $4 / $2 * 100 }')"

sketchybar --set "$NAME" label="${USED}%"
