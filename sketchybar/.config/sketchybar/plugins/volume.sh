#!/usr/bin/env bash

POPUP="$(sketchybar --query volume | jq -r '.popup.drawing')"
CLICK=false
if [ "${SENDER:-}" = mouse.clicked ]; then
  CLICK=true
  if [ "$POPUP" = on ]; then
    sketchybar --set volume popup.drawing=off
    exit 0
  fi
fi

# Read-only Standard Additions: no Automation or microphone permission needed.
# Unlike INFO, this also works on startup, wake, a click, and device switches.
SETTINGS="$(osascript \
  -e 'set v to get volume settings' \
  -e 'return (output volume of v as text) & "|" & (output muted of v as text)' 2>/dev/null)"
IFS='|' read -r VOLUME MUTED <<<"$SETTINGS"
case "$VOLUME" in
  [0-9] | [1-9][0-9] | 100) ;;
  *)
    VOLUME=""
    if [ "${SENDER:-}" = volume_change ]; then
      case "${INFO:-}" in
        [0-9] | [1-9][0-9] | 100) VOLUME=$INFO ;;
      esac
    fi
    ;;
esac

ICON=󰕾
LABEL="Volume: Unavailable"
if [ -n "$VOLUME" ]; then
  LABEL="Volume: $VOLUME%"
  case "$VOLUME" in
    [6-9][0-9] | 100) ICON=󰕾 ;;
    [3-5][0-9]) ICON=󰖀 ;;
    [1-9] | [1-2][0-9]) ICON=󰕿 ;;
    0) ICON=󰖁 ;;
  esac
fi
if [ "$MUTED" = true ]; then
  ICON=󰖁
  LABEL="$LABEL (muted)"
fi

args=(
  --set volume icon="$ICON" label.drawing=off
  --set volume.level icon="$ICON" label="$LABEL"
)

# system_profiler exposes CoreAudio's default-device flags as structured data.
# Only query devices when opening the menu or while it is visible.
if $CLICK || [ "$POPUP" = on ]; then
  AUDIO="$(system_profiler SPAudioDataType -json -timeout 3 2>/dev/null)"
  OUTPUT="$(jq -r '[.. | objects | select(.coreaudio_default_audio_output_device == "spaudio_yes") | ._name | select(type == "string" and length > 0)] | first // "Unavailable"' <<<"$AUDIO" 2>/dev/null)"
  INPUT="$(jq -r '[.. | objects | select(.coreaudio_default_audio_input_device == "spaudio_yes") | ._name | select(type == "string" and length > 0)] | first // "Unavailable"' <<<"$AUDIO" 2>/dev/null)"
  args+=(
    --set volume.output label="Output: ${OUTPUT:-Unavailable}"
    --set volume.input label="Input: ${INPUT:-Unavailable}"
  )
fi

# Refreshes never toggle, reopen, or recreate a popup.
$CLICK && args+=(--set volume popup.drawing=on)
sketchybar "${args[@]}"
