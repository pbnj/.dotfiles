#!/usr/bin/env bash

# Update existing items in place: never reload the bar or toggle a popup.
# shellcheck source=../colors.sh
source "$CONFIG_DIR/colors.sh"

args=(
  --bar color="$BAR_BG"
  --default icon.color="$FG" label.color="$FG" background.color="$ITEM_BG"
  --set '/.*/' icon.color="$FG" label.color="$FG"
  --set '/space[.].*/' icon.highlight_color="$RED" label.highlight_color="$RED"
  label.background.color="$APPS_BG"
)

# Setting background.color implicitly enables drawing in SketchyBar. Only
# recolor the real pills/brackets, not transparent children or popup rows.
for item in spaces stats claude clock twingate wifi volume battery docker github copilot pi; do
  args+=(--set "$item" background.color="$ITEM_BG")
done
for item in apple.logo wifi volume battery docker github claude pi; do
  args+=(--set "$item" popup.background.color="$BG" popup.background.border_color="$SELECTED_BG")
done
args+=(--set apple.logo icon.color="$GREEN")
for item in cpu memory disk docker docker.containers docker.images docker.volumes copilot; do
  args+=(--set "$item" icon.color="$ACCENT")
done

# Reapply state colors and focused-workspace backgrounds AFTER the base colors.
# Only this item handles the native notification, avoiding ordering races.
sketchybar "${args[@]}" && sketchybar --trigger theme_refresh
