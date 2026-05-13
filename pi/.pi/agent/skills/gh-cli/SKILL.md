---
name: gh-cli
description: "Use when interacting with GitHub from the command line. Triggers on any
  request involving pull requests, issues, repositories, GitHub Actions
  workflows, releases, GitHub API calls, or the `gh` command — even if the user
  doesn't say 'gh' but mentions checking out a PR, creating an issue, viewing
  workflow runs, listing releases, or querying the GitHub API. Use proactively
  for any GitHub operation that can be done from the terminal."
compatibility: "Requires gh CLI v2+ (https://cli.github.com). Authenticate with `gh auth
  login`. Run `gh auth status` to verify. Extensions installable via `gh
  extension install`."
metadata:
  author: Peter Benjamin
  version: 0.1.0
allowed-tools: Bash(gh:*) Read Write
---

# GitHub CLI Skill

Use `gh help` or `gh <command> --help` to explore commands and sub-commands.

```sh
gh help                # all top-level commands
gh pr --help           # PR sub-commands
gh issue --help        # issue sub-commands
```

## Safety: Read vs. Write Operations

Read operations (`list`, `view`, `status`, `diff`, `checks`, `search`) are safe
to run freely. Write operations (`create`, `merge`, `close`, `edit`, `delete`,
`rerun`, `approve`) make real changes to repositories, pull requests, issues,
and workflows. Before running any write operation, confirm with the user what
you're about to do and why. When in doubt, ask.

## Authentication

```sh
# Check auth status
gh auth status

# Log in (browser-based)
gh auth login

# Log in to a specific host (e.g. GHES)
gh auth login --hostname github.example.com
```

## Common Patterns

See `references/patterns.md` for CLI examples by category: Auth, Repos, Pull
Requests, Issues, Workflows & Runs, Releases, Secrets & Variables, and API.
