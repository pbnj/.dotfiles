#!/bin/sh

FREE="$(memory_pressure -Q | awk -F': ' '/free percentage/ { sub("%", "", $2); print $2 }')"

sketchybar --set "$NAME" label="$((100 - FREE))%"
