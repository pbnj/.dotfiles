#!/bin/sh

# the whale is hidden unless Docker Desktop is running; its dropdown rows show
# running containers, images and volumes
# Docker Desktop links its cli into /usr/local/bin, which is not on the service PATH
PATH="$PATH:/usr/local/bin"

if ! pgrep -q com.docker.backend; then
  sketchybar --set docker drawing=off popup.drawing=off
  exit 0
fi

# number of unique lines from `docker <args>`, or "…" while the engine is
# still starting
count() {
  if OUT="$(docker "$@" 2>/dev/null)"; then
    printf '%s\n' "$OUT" | sort -u | grep -c .
  else
    echo "…"
  fi
}

# "<n> <noun>", singular for one
label() {
  if [ "$1" = 1 ]; then echo "1 $2"; else echo "$1 $2s"; fi
}

sketchybar --set docker drawing=on \
  --set docker.containers label="$(label "$(count ps -q)" "running container")" \
  --set docker.images label="$(label "$(count images -q)" image)" \
  --set docker.volumes label="$(label "$(count volume ls -q)" volume)"
