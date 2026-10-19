#!/bin/sh

# updates the docker.* items: hidden unless Docker Desktop is running, then
# running containers, images and volumes
# Docker Desktop links its cli into /usr/local/bin, which is not on the service PATH
PATH="$PATH:/usr/local/bin"

if ! pgrep -q com.docker.backend; then
  sketchybar --set docker drawing=off \
    --set docker.containers drawing=off \
    --set docker.images drawing=off \
    --set docker.volumes drawing=off
  exit 0
fi

# number of unique lines from `docker <args>`, or nothing while the engine is
# still starting
count() {
  if OUT="$(docker "$@" 2>/dev/null)"; then
    printf '%s\n' "$OUT" | sort -u | grep -c .
  fi
}

sketchybar --set docker drawing=on \
  --set docker.containers drawing=on label="$(count ps -q)" \
  --set docker.images drawing=on label="$(count images -q)" \
  --set docker.volumes drawing=on label="$(count volume ls -q)"
