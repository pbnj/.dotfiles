#!/usr/bin/env bash

# The Claude icon: the most urgent state across Claude Code sessions, the 5h /
# 7d usage limits beside it, and a menu of every tmux pane running Claude Code.
# Usage and session state come from the Claude Code "usage" mod, which fires
# claude_update after each write; session state also includes native worker
# status and live tmux activity, including active subagents.
#
# Clicks on the icon:
#   left   toggles the menu; each row is a pane with a dot colored by its
#          state, and jumps to that pane
#   right  jumps straight to the session that most needs you: one blocked on a
#          prompt, then the one that finished most recently, then one working
export LC_ALL=en_US.UTF-8
DIR="${CLAUDE_SKETCHYBAR_DIR:-$HOME/.cache/claude-sketchybar}"

# Updates arrive in bursts and can overlap a click. Each run reads the menu's
# rows before adding or removing some, so runs must not interleave.
if [ -z "${CLAUDE_LOCKED:-}" ]; then
  mkdir -p "$DIR"
  CLAUDE_LOCKED=1 exec lockf -k -t 10 "$DIR/.lock" "$BASH" "$0" "$@"
fi

# shellcheck source-path=SCRIPTDIR
# shellcheck source=claude_sessions.sh
source "$CONFIG_DIR/plugins/claude_sessions.sh"

# shellcheck source=../colors.sh
source "$CONFIG_DIR/colors.sh"

CLICK=false
[ "${SENDER:-}" = mouse.clicked ] && CLICK=true

POPUP_QUERY="$(sketchybar --query claude)"
POPUP="$(jq -r '.popup.drawing' <<<"$POPUP_QUERY")"

# left click on an open menu closes it; no lookup needed
if $CLICK && [ "${BUTTON:-}" != right ] && [ "$POPUP" = on ]; then
  sketchybar --set claude popup.drawing=off
  exit 0
fi

SESSIONS="$(claude_sessions)"
# Unmatched cache records still inform the icon, but are not live panes.
PANES="$(jq -c 'select(.source == "pane")' <<<"$SESSIONS")"

if $CLICK && [ "${BUTTON:-}" = right ]; then
  sketchybar --set claude popup.drawing=off
  while read -r socket pane; do
    "$CONFIG_DIR/plugins/claude_jump.sh" "$socket" "$pane" && exit 0
  done < <(jq -s -r 'map(select(.state != "unknown")) | sort_by({ blocked: 0, idle: 1, working: 2 }[.state], -.updatedAt)[] | "\(.socket) \(.pane)"' <<<"$PANES")
  open -a Ghostty
  exit 0
fi

# most urgent state: blocked > working > idle
case "$(jq -s 'map({blocked: 2, working: 1}[.state] // 0) | max // 0' <<<"$SESSIONS")" in
  2) ICON_COLOR=$RED ;;
  1) ICON_COLOR=$ORANGE ;;
  *) ICON_COLOR=$DIM ;;
esac
args=(--set claude icon.color="$ICON_COLOR" icon.padding_right=2)

# ended and abandoned sessions
find "$DIR/sessions" -name '*.json' -mtime +1 -delete 2>/dev/null

# one item per window: "NN%", hidden once its reset has passed, colored by
# its own usage
NOW="$(date +%s)"
LAST_WINDOW=claude
window() {
  local item="$1" key="$2" pct
  pct="$(jq -r --argjson now "$NOW" --arg key "$key" '
    .[$key] // empty
    | select(
        (.resetsAt // null) as $r
        | $r == null or ((try ($r | sub("\\.[0-9]+"; "") | fromdateiso8601) catch null) // ($now + 1)) > $now
      )
    | .percentUsed | round
  ' "$DIR/usage.json" 2>/dev/null)"

  if [ -z "$pct" ]; then
    args+=(--set "$item" drawing=off)
    return
  fi

  local color=$FG
  if ((pct >= 90)); then
    color=$RED
  elif ((pct >= 70)); then
    color=$YELLOW
  fi
  args+=(--set "$item" drawing=on label="$(printf '%02d%%' "$pct")" label.color="$color" label.padding_right=2)
  LAST_WINDOW="$item"
}
window claude.5h five_hour
window claude.7d seven_day

# Usage windows can disappear independently; keep the outer inset on the
# last visible member, including when only the Claude icon remains.
if [ "$LAST_WINDOW" = claude ]; then
  args+=(--set claude icon.padding_right=8)
else
  args+=(--set "$LAST_WINDOW" label.padding_right=8)
fi

# The menu's rows: built by a left click, kept current by updates while open.
if $CLICK || [ "$POPUP" = on ]; then
  row=(
    background.drawing=off
    icon.padding_left=8
    icon.font="JetBrainsMono Nerd Font:Bold:13.0"
    label.padding_right=8
    padding_left=0
    padding_right=0
  )

  # Rows are numbered and reused in place: removing and recreating the whole
  # popup disrupts its window and mouse tracking while it is being read.
  OLD="$(jq '[.popup.items[]? | select(startswith("claude.row."))] | length' <<<"$POPUP_QUERY")"
  set_row() {
    local item="claude.row.$1"
    (($1 >= OLD)) && args+=(--add item "$item" popup.claude)
    args+=(--set "$item" "${row[@]}" "${@:2}")
  }

  i=0
  while IFS=$'\x1f' read -r socket pane window name state title; do
    ((${#title} > 48)) && title="${title:0:47}…"

    case "$state" in
      blocked) dot="●" color=$RED ;;
      working) dot="●" color=$ORANGE ;;
      idle) dot="●" color=$DIM ;;
      *) dot="○" color=$DIM ;;
    esac

    set_row "$i" icon="$dot" icon.color="$color" \
      label="$window:$name  $title" \
      click_script="sketchybar --set claude popup.drawing=off; '$CONFIG_DIR/plugins/claude_jump.sh' '$socket' '$pane'"
    i=$((i + 1))
  done < <(jq -r '[.socket, .pane, .window, .name, .state, .title] | join("\u001f")' <<<"$PANES")

  if ((i == 0)); then
    set_row 0 icon="○" icon.color="$DIM" label="No Claude sessions in tmux" click_script=""
    i=1
  fi

  # drop rows left over from a longer list
  for ((j = i; j < OLD; j++)); do
    args+=(--remove "claude.row.$j")
  done

  # Only a click opens the menu. An update must neither reopen it nor close it,
  # even if the user closed it during the lookup.
  $CLICK && args+=(--set claude popup.drawing=on)
fi

sketchybar "${args[@]}"
