#!/usr/bin/env bash

# Shared state for the icon, popup and right-click target. A tmux client can
# attach to a daemon-owned Claude worker, so its launcher's mod file is not
# necessarily the session currently displayed in the pane.
claude_sessions() {
  local dir="${CLAUDE_SKETCHYBAR_DIR:-$HOME/.cache/claude-sketchybar}"
  local registry="${CLAUDE_SESSION_DIR:-$HOME/.claude/sessions}"
  local now
  now="$(date +%s)"

  {
    local file pid socket pane window name command title screen activity
    for file in "$dir"/sessions/*.json; do
      [ -f "$file" ] || continue
      jq -c --argjson now "$now" '
        select((.updatedAt | type) == "number")
        | select(.state == "idle" or
            ((.state == "working" or .state == "blocked") and
             $now - .updatedAt / 1000 <= 300))
        | {source: "mod", state, updatedAt,
           socket: .tmux.socket, pane: .tmux.pane}
      ' "$file" 2>/dev/null
    done

    # Native busy includes work delegated to subagents. Only trust records
    # whose process is still alive; timestamps are not heartbeats when idle.
    for file in "$registry"/*.json; do
      [ -f "$file" ] || continue
      pid="$(jq -r '.pid // empty' "$file" 2>/dev/null)"
      [[ "$pid" =~ ^[1-9][0-9]*$ ]] || continue
      kill -0 "$pid" 2>/dev/null || continue
      jq -c '
        (if .status == "busy" then "working"
         elif .status == "idle" then "idle"
         else empty end) as $state
        | {source: "native", state: $state, pid, name,
           updatedAt: (.updatedAt // 0)}
      ' "$file" 2>/dev/null
    done

    # Fields are split on the unit separator: names and titles may hold any
    # printable character.
    while IFS=$'\x1f' read -r socket pane pid window name command title; do
      [[ "$command" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ || "$command" == "claude" ]] || continue
      title="$(sed -E 's/^[^[:alnum:]]+//' <<<"$title")"
      activity=""
      # Read only the visible footer, never scrollback. Attached workers have
      # no TMUX variables, and /tasks can hide the usual interrupt hint while
      # the main turn waits for background subagents.
      screen="$(tmux -S "$socket" capture-pane -p -t "$pane" 2>/dev/null | tail -n 16)"
      if grep -Eq '^[[:space:]]+(esc to interrupt|.* · esc to interrupt)([[:space:]]|$)|^[✻✽✶✳✢·*][[:space:]]+Waiting for [1-9][0-9]* background agents? to finish' <<<"$screen"; then
        activity=working
      fi
      jq -cn --arg socket "$socket" --arg pane "$pane" --argjson pid "$pid" \
        --arg window "$window" --arg name "$name" --arg title "$title" \
        --arg activity "$activity" --argjson now "$now" '
        {source: "pane", socket: $socket, pane: $pane, pid: $pid,
         window: $window, name: $name, title: $title, activity: $activity,
         updatedAt: ($now * 1000)}
      '
    done < <(tmux list-panes -a -F "$(printf '%s\x1f' '#{socket_path}' '#{pane_id}' '#{pane_pid}' '#{window_index}' '#{window_name}' '#{pane_current_command}')#{pane_title}" 2>/dev/null)
  } | jq -sc '
    def latest: sort_by(.updatedAt) | last;
    . as $all
    | map(select(.source == "mod")) as $mods
    | map(select(.source == "native")) as $native
    | [ $all[] | select(.source == "pane") | . as $p
        | ([$mods[] | select(.socket == $p.socket and .pane == $p.pane)] | latest) as $mod
        | ([$native[] | select(.pid == $p.pid)] | latest) as $owner
        # A worker may have been resumed/compacted under a different session
        # id. Its current name matches the title of the attached pane. Do not guess
        # when multiple live workers share that name.
        | ([$native[] | select(.name != null and .name != "" and .name == $p.title)]
           | if length == 1 then .[0] else null end) as $attached
        | ($attached //
           (if $owner.state == "working" then $owner
            else ([$mod, $owner] | map(select(. != null)) | latest) end)) as $base
        | .state = (if $mod.state == "blocked" or $base.state == "blocked" then "blocked"
                    elif .activity == "working" then "working"
                    else $base.state // "unknown" end)
        | .updatedAt = ($base.updatedAt // .updatedAt)
        | del(.activity)
      ] as $panes
    | ($panes +
       [$mods[] | . as $m
        | select(any($panes[]; .socket == $m.socket and .pane == $m.pane) | not)] +
       $native)[]
  '
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  claude_sessions
fi
