# shellcheck shell=bash
#
# Sourced by the git PR helpers (git-unresolved, git-failing-checks, git-pb) —
# not a command, so not executable.
#
# pr_arg_resolve PROG — resolves the caller's $pr and $repo in place.
#
# $pr may be empty (the PR for the current branch), a number (123 or #123),
# OWNER/REPO#123, or a PR URL (https://github.com/OWNER/REPO/pull/123, any
# /files or #discussion suffix included). The last two set $repo, and it is an
# error for them to disagree with a $repo the caller already set from -R. On
# return $pr is a bare number; $repo is OWNER/REPO, or empty for the current
# repo. PROG prefixes the error messages.

pr_arg_resolve() {
  local prog="$1" pr_repo=""
  local url_re='^https?://(www\.)?github\.com/([^/]+)/([^/]+)/pull/([0-9]+)([/?#].*)?$'
  local ref_re='^([^/#[:space:]]+)/([^/#[:space:]]+)#([0-9]+)$'

  command -v gh >/dev/null || { echo "$prog: gh is not installed" >&2; exit 1; }

  if [ -z "$pr" ]; then
    # gh pr view needs a PR argument once --repo is set, so -R alone fails here.
    pr=$(gh pr view ${repo:+--repo "$repo"} --json number --jq .number) ||
      { echo "$prog: no PR for the current branch — pass a PR number or URL." >&2; exit 1; }
    return 0
  fi

  if [[ $pr =~ $url_re ]]; then
    pr_repo="${BASH_REMATCH[2]}/${BASH_REMATCH[3]}" pr="${BASH_REMATCH[4]}"
  elif [[ $pr =~ $ref_re ]]; then
    pr_repo="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}" pr="${BASH_REMATCH[3]}"
  else
    pr="${pr#\#}"
  fi
  [[ $pr =~ ^[0-9]+$ ]] ||
    { echo "$prog: not a PR number, OWNER/REPO#N, or github.com PR URL: $pr" >&2; exit 2; }

  if [ -n "$pr_repo" ]; then
    if [ -n "$repo" ] && [ "$(tr '[:upper:]' '[:lower:]' <<< "$repo")" != "$(tr '[:upper:]' '[:lower:]' <<< "$pr_repo")" ]; then
      echo "$prog: -R $repo conflicts with the PR's repo $pr_repo" >&2; exit 2
    fi
    repo="$pr_repo"
  fi
}
