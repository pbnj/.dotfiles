# gh CLI Patterns by Category

## Repos

```sh
# Clone a repo
gh repo clone <owner>/<repo>

# View repo details
gh repo view <owner>/<repo>

# Open repo in browser
gh repo view <owner>/<repo> --web

# Fork a repo
gh repo fork <owner>/<repo>

# Create a new repo
gh repo create <name> --public --clone

# List repos for a user/org
gh repo list <owner> --limit 50
```

## Pull Requests

```sh
# List open PRs
gh pr list

# List all PRs (open + closed + merged)
gh pr list --state all

# View a PR
gh pr view <number>

# View PR diff
gh pr diff <number>

# Check PR status / CI checks
gh pr checks <number>

# Checkout a PR branch locally
gh pr checkout <number>

# Create a PR (interactive)
gh pr create

# Create a PR (non-interactive)
gh pr create --title "Title" --body "Description" --base main

# Merge a PR (requires approval)
gh pr merge <number> --squash --delete-branch

# Request review
gh pr review <number> --approve
gh pr review <number> --request-changes --body "Needs fixes"

# Add a comment
gh pr comment <number> --body "LGTM"

# Close a PR (requires approval)
gh pr close <number>
```

## Issues

```sh
# List open issues
gh issue list

# Filter by label
gh issue list --label "bug"

# View an issue
gh issue view <number>

# Create an issue (interactive)
gh issue create

# Create an issue (non-interactive)
gh issue create --title "Title" --body "Description" --label "bug"

# Add a comment
gh issue comment <number> --body "Comment text"

# Close an issue (requires approval)
gh issue close <number>

# Reopen an issue
gh issue reopen <number>
```

## Workflows & Runs

```sh
# List workflows
gh workflow list

# View a workflow
gh workflow view <workflow-name-or-id>

# Enable / disable a workflow (requires approval)
gh workflow enable <workflow-name>
gh workflow disable <workflow-name>

# List recent workflow runs
gh run list

# List runs for a specific workflow
gh run list --workflow <workflow-name>

# View a run (summary)
gh run view <run-id>

# Watch a run live
gh run view <run-id> --log

# Download run logs
gh run view <run-id> --log > run.log

# Re-run a failed run (requires approval)
gh run rerun <run-id> --failed-only

# Trigger a workflow_dispatch run (requires approval)
gh workflow run <workflow-name> --ref main
```

## Releases

```sh
# List releases
gh release list

# View a release
gh release view <tag>

# Download release assets
gh release download <tag> --pattern "*.tar.gz"

# Create a release (requires approval)
gh release create <tag> --title "v1.0.0" --notes "Release notes"

# Delete a release (requires approval)
gh release delete <tag>
```

## Search

```sh
# Search repositories
gh search repos "topic:kubernetes stars:>1000"

# Search issues
gh search issues "is:open label:bug repo:owner/repo"

# Search pull requests
gh search prs "is:open review-requested:@me"

# Search code
gh search code "function authenticate" --repo owner/repo
```

## Secrets & Variables

```sh
# List secrets (names only — values are never shown)
gh secret list
gh secret list --repo <owner>/<repo>

# Set a secret (requires approval)
gh secret set MY_SECRET

# List Actions variables
gh variable list
gh variable list --repo <owner>/<repo>
```

## API (REST & GraphQL)

```sh
# REST API call (GET)
gh api repos/<owner>/<repo>

# REST API with JQ filter
gh api repos/<owner>/<repo>/pulls --jq '.[].title'

# Paginate through all results
gh api --paginate repos/<owner>/<repo>/issues --jq '.[].number'

# GraphQL query
gh api graphql -f query='
  query {
    viewer {
      login
      repositories(first: 10) {
        nodes { name }
      }
    }
  }
'
```
