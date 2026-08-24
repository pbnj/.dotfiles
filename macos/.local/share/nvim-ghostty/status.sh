#!/bin/bash
# Report which app currently handles each extension claimed in filetypes.conf,
# so registration is inspectable rather than guessed at.
#
# Usage: ./status.sh [group...]        (default: every group)

set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="$SRC_DIR/filetypes.conf"
BUNDLE_ID="com.peterbenjamin.nvim-ghostty"

command -v duti >/dev/null 2>&1 || {
	printf 'error: duti not found; install it with '\''brew install duti'\''\n' >&2
	exit 1
}

groups=("$@")
if [[ ${#groups[@]} -eq 0 ]]; then
	while IFS= read -r g; do groups+=("$g"); done < <(
		awk -F: '/^[[:space:]]*#/ || NF < 3 { next } { gsub(/[[:space:]]/, "", $1); print $1 }' \
			"$CONF" | awk '!seen[$0]++'
	)
fi

for group in "${groups[@]}"; do
	printf '%s\n' "$group"
	exts=$(awk -F: -v g="$group" '
		/^[[:space:]]*#/ || NF < 3 { next }
		{ gsub(/[[:space:]]/, "", $1); gsub(/[[:space:]]/, "", $2)
		  gsub(/^[[:space:]]+|[[:space:]]+$/, "", $3)
		  if ($1 == g && $2 == "ext") print $3 }
	' "$CONF")
	for ext in $exts; do
		handler=$(duti -x "$ext" 2>/dev/null | tail -1 || true)
		[[ -n "$handler" ]] || handler="(none)"
		marker=" "
		[[ "$handler" == "$BUNDLE_ID" ]] && marker="*"
		printf '  %s .%-10s %s\n' "$marker" "$ext" "$handler"
	done
done
