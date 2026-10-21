#!/usr/bin/env bash

# SketchyBar's launch environment may not include Homebrew. Keep inherited PATH
# first so tests and explicit user overrides still work.
export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"
umask 077
DIR="${GITHUB_SKETCHYBAR_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/sketchybar/github}"
CACHE="$DIR/attention.json"
LOCK="$DIR/refresh.lock"
PAGE_SIZE=10
FONT="JetBrainsMono Nerd Font"
mkdir -p "$DIR" || exit 1

# shellcheck source=../colors.sh
source "$CONFIG_DIR/colors.sh"
printf -v script_q '%q' "$CONFIG_DIR/plugins/github.sh"

render() {
  local query popup old_items total count_failing count_feedback count_approved count_review
  local page pages color label status fetched_at item url rank title index click prev next
  local -a args row row_names
  query="$(sketchybar --query github 2>/dev/null)"
  popup="$(jq -r '.popup.drawing // "off"' <<<"$query" 2>/dev/null)"

  if [ "${1:-}" = toggle ] && [ "$popup" = on ]; then
    sketchybar --set github popup.drawing=off
    return
  fi

  total=0 count_failing=0 count_feedback=0 count_approved=0 count_review=0 fetched_at=""
  if [ -f "$CACHE" ]; then
    IFS=$'\t' read -r total count_failing count_feedback count_approved count_review fetched_at < <(
      jq -r '[.prs | length] + [.counts.failing, .counts.feedback, .counts.approved, .counts.review, .fetchedAt] | @tsv' "$CACHE"
    )
  fi
  color=$DIM label=…
  status="Waiting for first refresh"
  if [ -n "$fetched_at" ]; then
    label=$total color=$GREEN
    status="Updated $fetched_at · refresh every 5 min"
    if ((count_failing > 0)); then
      color=$RED
    elif ((count_feedback > 0)); then
      color=$ORANGE
    elif ((total > 0)); then
      color=$YELLOW
    fi
  fi
  if [ -d "$LOCK" ]; then
    status="Refreshing…${fetched_at:+ · last success $fetched_at}"
  elif [ -f "$DIR/error" ]; then
    color=$RED label=!
    [ -n "$fetched_at" ] && label="$total!"
    status="Refresh failed · ${fetched_at:+cached $fetched_at · }retry below"
  fi
  args=(--set github icon.color="$color" label.color="$color" label="$label")

  # Timers and theme refreshes never open a closed popup.
  if [ "$popup" != on ] && [ "${1:-}" != toggle ]; then
    sketchybar "${args[@]}"
    return
  fi

  row=(
    background.drawing=off
    icon.font="$FONT:Bold:13.0"
    icon.padding_left=8
    label.font="$FONT:Bold:12.0"
    label.padding_right=8
    label.color="$FG"
    padding_left=0
    padding_right=0
  )
  old_items="$(jq -r '.popup.items[]? | select(startswith("github.row."))' <<<"$query")"
  row_names=()
  # Reuse popup rows: refreshing in place preserves mouse tracking.
  set_row() {
    local name="github.row.$1"
    if ! grep -Fxq "$name" <<<"$old_items"; then
      args+=(--add item "$name" popup.github)
    fi
    row_names+=("$name")
    args+=(--set "$name" "${row[@]}" drawing=on icon.color="$DIM" click_script= "${@:2}")
  }

  set_row summary icon= \
    label="CI: $count_failing · Feedback: $count_feedback · Approved: $count_approved · Review: $count_review"
  page=0
  [ ! -f "$DIR/page" ] || read -r page <"$DIR/page"
  [[ "$page" =~ ^[0-9]{1,6}$ ]] || page=0
  page=$((10#$page))
  pages=$(((total + PAGE_SIZE - 1) / PAGE_SIZE))
  ((pages > 0)) || pages=1
  ((page < pages)) || page=$((pages - 1))
  printf '%s\n' "$page" >"$DIR/page"

  index=0
  if ((total > 0)); then
    while IFS=$'\t' read -r url rank title; do
      case "$rank" in
        0) item=✘ color=$RED ;;
        1) item=✎ color=$ORANGE ;;
        2) item= color=$ORANGE ;;
        3) item=✔ color=$GREEN ;;
        4) item= color=$ACCENT ;;
        *) item=◷ color=$YELLOW ;;
      esac
      # URL validation happens in github.jq; quote again at the shell boundary.
      printf -v click 'open %q; sketchybar --set github popup.drawing=off' "$url"
      set_row "$index" icon="$item" icon.color="$color" label="$title" click_script="$click"
      index=$((index + 1))
    done < <(
      jq -r --argjson start "$((page * PAGE_SIZE))" --argjson size "$PAGE_SIZE" '
        .prs[$start:$start + $size][] |
        [ .url, .rank,
          ((.repo | split("/") | last) + "#" + (.number | tostring) +
            (if .draft then " [draft]" else "" end) + " · " + .title |
            gsub("[[:cntrl:]]"; " ") | if length > 76 then .[:75] + "…" else . end)
        ] | map(tostring) | join("\t")
      ' "$CACHE"
    )
  fi

  # Popup order is insertion order: SketchyBar's --move only reorders bar
  # items, not popup children. Keep fixed slots and hide unused rows so the
  # footer stays at the bottom after visiting a short final page.
  while ((index < PAGE_SIZE)); do
    set_row "$index" drawing=off label= icon=
    index=$((index + 1))
  done
  if ((total == 0)); then
    title="Nothing needs your attention"
    item=✔
    if [ -z "$fetched_at" ]; then
      title="Run gh attention --all in a terminal to check setup"
      item=
    fi
    set_row empty icon="$item" icon.color="$color" label="$title"
  else
    set_row empty drawing=off label=
  fi
  prev=$(((page + pages - 1) % pages))
  next=$(((page + 1) % pages))
  item=off
  ((pages > 1)) && item=on
  set_row prev drawing="$item" icon= label="Previous · page $((page + 1))/$pages" \
    click_script="$script_q page $prev"
  set_row next drawing="$item" icon= label="Next · page $((page + 1))/$pages" \
    click_script="$script_q page $next"
  set_row refresh icon= icon.color="$ACCENT" label="$status · Refresh now" \
    click_script="sketchybar --trigger github_refresh"

  while IFS= read -r item; do
    [ -n "$item" ] || continue
    [[ " ${row_names[*]} " == *" $item "* ]] || args+=(--remove "$item")
  done <<<"$old_items"
  # A fetch finishing after the user closes the popup must not reopen it.
  [ "${1:-}" != toggle ] || args+=(--set github popup.drawing=on)
  sketchybar "${args[@]}"
}

case "${1:-${SENDER:-}}" in
  page)
    [[ "${2:-}" =~ ^[0-9]{1,6}$ ]] || exit 1
    printf '%s\n' "$2" >"$DIR/page"
    render
    exit
    ;;
  mouse.clicked)
    render toggle
    exit
    ;;
  theme_refresh)
    render
    exit
    ;;
esac

# Bound network work and avoid concurrent fetches on wake/timer/manual events.
# A hard-killed bar can leave an empty lock behind; reclaim it after 3 minutes.
if [ -d "$LOCK" ] && [ -n "$(find "$LOCK" -prune -mmin +3 2>/dev/null)" ]; then
  rmdir "$LOCK" 2>/dev/null
fi
if ! mkdir "$LOCK" 2>/dev/null; then
  render
  exit
fi
trap 'rm -f "$DIR/raw.$$" "$DIR/next.$$"; rmdir "$LOCK" 2>/dev/null' EXIT
trap 'exit 1' INT TERM
render
if timeout --kill-after=5s 90s gh attention --all --json >"$DIR/raw.$$" 2>"$DIR/refresh.log" &&
  jq --arg fetched_at "$(date '+%b %d %H:%M')" -f "$CONFIG_DIR/plugins/github.jq" \
    "$DIR/raw.$$" >"$DIR/next.$$" 2>>"$DIR/refresh.log" &&
  [ -s "$DIR/next.$$" ] && mv "$DIR/next.$$" "$CACHE"; then
  rm -f "$DIR/error"
else
  touch "$DIR/error"
fi
rmdir "$LOCK"
render
