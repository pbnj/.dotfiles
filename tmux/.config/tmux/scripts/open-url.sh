#!/usr/bin/env bash
# Read text from stdin (a tmux selection), extract a URL, strip trailing
# punctuation, and open it with the system opener.
set -euo pipefail

selection="$(cat)"

# Extract the first URL-looking token from the selection.
url="$(printf '%s' "$selection" | grep -oE '(https?|ftp|file)://[^[:space:]]+' | head -n1 || true)"

# Fall back to the whole selection if no scheme matched.
[ -z "$url" ] && url="$selection"

# Strip common trailing punctuation: . , ; : ! ? ) ] } > " ' and whitespace.
url="$(printf '%s' "$url" | sed -E "s/[][:space:].,;:!?)}>\"']+$//")"

[ -n "$url" ] && open "$url"
