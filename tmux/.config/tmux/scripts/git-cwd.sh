#!/usr/bin/env bash
# Shows "git-root (branch)" if in a git repo, else shows basename of current dir.
# Usage: git-cwd.sh <path>
path="${1:-$PWD}"
cd "$path" 2>/dev/null || { basename "$path"; exit; }

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  root=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
  branch=$(git branch --show-current 2>/dev/null)
  [ -z "$branch" ] && branch=$(git rev-parse --short HEAD 2>/dev/null)
  echo "$root ($branch)"
else
  basename "$path"
fi
