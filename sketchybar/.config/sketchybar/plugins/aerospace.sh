#!/usr/bin/env bash

# one pass over all aerospace workspaces: the focused one is highlighted,
# others show only when they have windows, labelled with one
# sketchybar-app-font icon per app

# defines __icon_map, which sets icon_result
# shellcheck source=/dev/null
source "$CONFIG_DIR/plugins/icon_map.sh"
icon_result=""

FOCUSED="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused)}"

# app pill backgrounds (tokyonight): brighter for the focused workspace
APPS_BG=0xff414868
FOCUSED_BG=0xff565f89

declare -A ICONS
while IFS='|' read -r ws app; do
  [ -n "$app" ] || continue
  __icon_map "$app"
  ICONS[$ws]+="$icon_result"
done < <(aerospace list-windows --all --format '%{workspace}|%{app-name}' | sort -u)

args=()
while IFS= read -r ws; do
  icons="${ICONS[$ws]}"
  if [ "$ws" = "$FOCUSED" ]; then
    args+=(--set "space.$ws" drawing=on icon.highlight=on label.highlight=on label.background.color="$FOCUSED_BG")
  elif [ -n "$icons" ]; then
    args+=(--set "space.$ws" drawing=on icon.highlight=off label.highlight=off label.background.color="$APPS_BG")
  else
    args+=(--set "space.$ws" drawing=off icon.highlight=off label.highlight=off label.background.color="$APPS_BG")
  fi
  if [ -n "$icons" ]; then
    args+=(label="$icons" label.drawing=on)
  else
    args+=(label.drawing=off)
  fi
done < <(aerospace list-workspaces --all)

sketchybar "${args[@]}"
