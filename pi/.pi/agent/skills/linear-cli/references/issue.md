# issue (alias: i)

Manage Linear issues.

## List / query

```bash
# My issues (default: unstarted state)
linear i mine
linear i mine --all-states                          # All states
linear i mine -s started -s backlog                 # Multiple states
linear i mine --team ENG                            # Specific team
linear i mine --project "Q2 Launch"                 # Filter by project
linear i mine --cycle active                        # Active cycle
linear i mine --label bug                           # Filter by label
linear i mine --limit 100                           # More results (0 = unlimited)
linear i mine --created-after 2025-01-01
linear i mine --updated-after 2025-01-01
linear i mine --sort priority                       # Sort: manual | priority
linear i mine -w                                    # Open in browser
linear i mine -a                                    # Open in Linear.app
linear i mine --no-pager

# Broad query (all assignees, all states by default)
linear i query --search "auth bug"                  # Full-text search
linear i query --search "login" --search-comments   # Also search comments
linear i query --team ENG --team PLT                # Multiple teams
linear i query --all-teams                          # Every team
linear i query --assignee alice                     # By assignee username
linear i query -U                                   # Unassigned only
linear i query -s started                           # Filter by state
linear i query --project "Q2" --milestone "Beta"
linear i query --include-archived
linear i query -j                                   # JSON output
```

**State values:** `triage`, `backlog`, `unstarted`, `started`, `completed`, `canceled`

## View

```bash
linear i view ENG-123                    # View issue details (uses pager)
linear i view ENG-123 -j                 # JSON output
linear i view ENG-123 -w                 # Open in browser
linear i view ENG-123 -a                 # Open in Linear.app
linear i view ENG-123 --no-comments      # Skip comments
linear i view ENG-123 --show-resolved-threads
linear i view ENG-123 --no-download      # Keep remote URLs

# issueId can be omitted when on a branch linked to an issue
linear i view
```

## Scripting helpers

```bash
linear i id                              # Print issue ID for current git branch
linear i title ENG-123                  # Print issue title
linear i url ENG-123                    # Print issue URL
linear i describe ENG-123               # Print title + "Fixes: <url>" trailer
linear i describe ENG-123 --ref         # Use "References" instead of "Fixes"
```

## Create

```bash
linear i create -t "Fix login bug" --team ENG
linear i create \
  -t "Add feature" \
  --team ENG \
  -s backlog \
  -l bug -l enhancement \
  -p 2 \
  --assignee self \
  --project "Q2 Launch" \
  --cycle active \
  --milestone "Beta" \
  --due-date 2025-06-01 \
  --estimate 3 \
  -d "Short description" \
  --description-file desc.md

linear i create --no-interactive -t "Bug" --team ENG   # Non-interactive
linear i create --start -t "Urgent fix" --team ENG     # Create and start immediately
```

**Priority values:** `1` = Urgent, `2` = High, `3` = Medium, `4` = Low

## Update

```bash
linear i update ENG-123 -s started
linear i update ENG-123 -p 1
linear i update ENG-123 --assignee alice
linear i update ENG-123 --due-date 2025-07-01
linear i update ENG-123 --estimate 5
linear i update ENG-123 -l bug -l "good first issue"
linear i update ENG-123 --project "Q3 Launch"
linear i update ENG-123 --cycle 12
linear i update ENG-123 --parent ENG-100
linear i update ENG-123 -t "New title"
linear i update ENG-123 -d "New description"
linear i update ENG-123 --description-file updated.md

# issueId can be omitted when on a linked branch
linear i update -s started
```

## Start working on an issue

```bash
linear i start ENG-123                  # Assign to you, set started, create branch
linear i start ENG-123 -f main          # Branch from main
linear i start ENG-123 -b my-branch     # Custom branch name
linear i start                          # Interactive picker (all/unassigned)
linear i start -A                       # Show all assignees in picker
linear i start -U                       # Show only unassigned in picker
```

## Pull request

```bash
linear i pr ENG-123                     # Create GitHub PR with issue details
linear i pr ENG-123 --draft
linear i pr ENG-123 --base main
linear i pr ENG-123 -t "Custom title"   # Linear ID will be prefixed automatically
linear i pr ENG-123 --web               # Open in browser after creating
linear i pr ENG-123 --head feature-branch

# issueId can be omitted when on a linked branch
linear i pr
```

## Delete

```bash
linear i delete ENG-123
linear i delete ENG-123 -y              # Skip confirmation
linear i delete --bulk ENG-1 ENG-2 ENG-3
linear i delete --bulk-file ids.txt     # One ID per line
linear i delete --bulk-stdin            # Read IDs from stdin
```

## Comments

```bash
linear i comment list ENG-123
linear i comment add ENG-123 -b "LGTM"
linear i comment add ENG-123 --body-file comment.md
linear i comment add ENG-123 -p COMMENT_ID -b "Replying..."   # Reply
linear i comment add ENG-123 -a screenshot.png                # With attachment
linear i comment update COMMENT_ID -b "Edited text"
linear i comment update COMMENT_ID --body-file updated.md
linear i comment delete COMMENT_ID
```

## Attachments & links

```bash
linear i attach ENG-123 ./screenshot.png
linear i attach ENG-123 ./file.pdf -t "Design spec" -c "See attached"

linear i link ENG-123 https://github.com/org/repo/pull/123
linear i link ENG-123 https://example.com -t "Design doc"
linear i link https://github.com/org/repo/pull/123   # Issue inferred from branch
```

## Relations

```bash
linear i relation list ENG-123
linear i relation add ENG-123 blocks ENG-456
linear i relation delete ENG-123 blocks ENG-456
```

## Agent sessions

```bash
linear i agent-session list ENG-123
linear i agent-session view SESSION_ID
```

## Commits (jj only)

```bash
linear i commits ENG-123
```
