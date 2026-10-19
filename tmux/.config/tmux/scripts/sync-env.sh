#!/usr/bin/env bash
# Copy every variable exported by ~/.work.profile into the tmux server's global
# environment, so panes tmux launches directly (e.g. `split-window -- claude`),
# which never source a shell profile, still inherit them.

set -euo pipefail

profile="${HOME}/.work.profile"
[[ -f "${profile}" ]] || exit 0

names=$(grep -oE '^[[:space:]]*export[[:space:]]+[A-Za-z_][A-Za-z0-9_]*' "${profile}" | awk '{print $2}')

# shellcheck disable=SC1090
source "${profile}" >/dev/null 2>&1

for name in ${names}; do
  if [[ -n "${!name+x}" ]]; then
    tmux set-environment -g "${name}" "${!name}"
  else
    tmux set-environment -gu "${name}"
  fi
done
