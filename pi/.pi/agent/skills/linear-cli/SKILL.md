---
name: linear-cli
description: >
  Use when interacting with Linear.app from the command line. Triggers on any
  request involving Linear issues, projects, cycles, sprints, teams, roadmaps,
  milestones, documents, triage, notifications, comments, bulk operations, or
  any Linear workflow. Also triggers when the user references a Linear issue
  identifier (e.g. ENG-123, LIN-456), wants to list/create/update/close/assign
  issues, check sprint status, run burndown charts, import/export Linear data,
  manage webhooks, or automate Linear tasks from the terminal. Use proactively
  whenever the user mentions "Linear", "linear issue", "linear sprint", "linear
  project", "linear ticket", or any Linear-related workflow — even if they don't
  explicitly ask for the CLI.
metadata:
  author: Peter Benjamin
  version: 0.1.0
---

# Linear CLI Skill

[`linear-cli`](https://github.com/Finesssee/linear-cli) is a fast, comprehensive
CLI for [Linear.app](https://linear.app) built in Rust.

## Installation

You need `brew` + `cargo-binstall` to install pre-compiled linear-cli binaries:

```bash
brew install cargo-binstall
cargo binstall linear-cli
```

Alternatively, you may build from source:

```bash
# From crates.io (compiles from source)
cargo install linear-cli

# With OS keyring support (Keychain, Credential Manager, Secret Service)
cargo install linear-cli --features secure-storage
```

Run `linear-cli --help` or `linear-cli <subcommand> --help` to discover all
flags for any command.

## Authentication

API key is the simplest method. Check current auth status before doing anything:

```bash
linear-cli auth status
```

If not authenticated, then initiate oauth flow:

```bash
linear-cli auth oauth
```

Run `linear-cli doctor` to verify config and connectivity. Use
`linear-cli doctor --fix` to auto-remediate issues.

## Quick Reference: Short Aliases

Most command groups have short aliases:

| Full command      | Short alias |
| ----------------- | ----------- |
| `issues`          | `i`         |
| `projects`        | `p`         |
| `project-updates` | `pu`        |
| `teams`           | `t`         |
| `cycles`          | `c`         |
| `sprint`          | `sp`        |
| `documents`       | `d`         |
| `labels`          | `l`         |
| `comments`        | `cm`        |
| `milestones`      | `ms`        |
| `roadmaps`        | `rm`        |
| `initiatives`     | `init`      |
| `views`           | `v`         |
| `relations`       | `rel`       |
| `attachments`     | `att`       |
| `templates`       | `tpl`       |
| `notifications`   | `n`         |
| `statuses`        | `st`        |
| `time`            | `tm`        |
| `favorites`       | `fav`       |
| `users`           | `u`         |
| `webhooks`        | `wh`        |
| `watch`           | `w`         |
| `triage`          | `tr`        |
| `bulk`            | `b`         |
| `git`             | `g`         |
| `search`          | `s`         |
| `import`          | `import`    |
| `export`          | `export`    |

## Issues

Issues are the core of Linear. Use `linear-cli i` for all issue operations.

```bash
# List issues
linear-cli i list --mine                          # My issues
linear-cli i list -t ENG --mine                   # My issues on team ENG
linear-cli i list --since 7d --group-by state     # Last 7 days, grouped by status
linear-cli i list -l bug --count-only             # Count bugs
linear-cli i list --view "My Sprint"              # Apply a saved custom view
linear-cli i list --state "In Progress" -t ENG    # Issues in a specific state

# Get issue details
linear-cli i get ENG-123                          # Full details
linear-cli i get ENG-123 --history                # Activity timeline
linear-cli i get ENG-123 --comments               # Inline comments
linear-cli i get ENG-1 ENG-2 ENG-3               # Batch fetch

# Create issues
linear-cli i create "Fix login" -t ENG -p 1       # Create urgent issue (priority 1 = urgent)
linear-cli i create "Add feature" -t ENG -s "Backlog" -l "enhancement"
linear-cli i create "Bug" -t ENG --id-only --quiet  # Return only the new issue ID

# Update issues
linear-cli i update ENG-123 -s Done               # Update status
linear-cli i update ENG-123 -l bug -l urgent      # Add labels
linear-cli i update ENG-123 --due tomorrow        # Set due date
linear-cli i update ENG-123 -e 3                  # Set estimate (story points)
linear-cli i update ENG-123 -a "Alice"            # Assign to user

# Issue actions
linear-cli i start ENG-123 --checkout             # Assign to you + In Progress + checkout git branch
linear-cli i stop ENG-123                         # Return to backlog
linear-cli i close ENG-123                        # Mark as Done
linear-cli i assign ENG-123 "alice@example.com"   # Assign to user
linear-cli i move ENG-123 "Q2 Project"            # Move to project
linear-cli i transfer ENG-123 PLATFORM            # Transfer to another team
linear-cli i comment ENG-123 -b "LGTM"            # Add comment
linear-cli i archive ENG-123                      # Archive
linear-cli i open ENG-123                         # Open in browser
linear-cli i link ENG-123                         # Print issue URL

# Mark current git branch issue as Done
linear-cli done
```

**Priority values:** `1` = Urgent, `2` = High, `3` = Medium, `4` = Low

## Projects

```bash
linear-cli p list                                 # List all projects
linear-cli p get "Q1 Roadmap"                     # Project details
linear-cli p create "New Feature" -t ENG          # Create project
linear-cli p update PROJECT_ID --name "Renamed"   # Rename project
linear-cli p members "Q1 Roadmap"                 # List members
linear-cli p add-labels PROJECT_ID bug            # Add labels
linear-cli p archive PROJECT_ID                   # Archive
linear-cli p unarchive PROJECT_ID                 # Unarchive
linear-cli p open "Q1 Roadmap"                    # Open in browser
linear-cli p delete PROJECT_ID                    # Delete
```

## Sprint Planning

```bash
linear-cli sp status -t ENG                       # Current sprint status
linear-cli sp progress -t ENG                     # Progress bar visualization
linear-cli sp plan -t ENG                         # Next sprint's planned issues
linear-cli sp carry-over -t ENG --force           # Move incomplete to next cycle
linear-cli sp burndown -t ENG                     # ASCII burndown chart
linear-cli sp velocity -t ENG                     # Velocity across past 6 sprints
linear-cli sp velocity -t ENG -n 10               # Velocity across past 10 sprints
```

## Cycles

```bash
linear-cli c list -t ENG                          # List cycles
linear-cli c current -t ENG                       # Current cycle
linear-cli c get CYCLE_ID                         # Cycle details with issues
linear-cli c create -t ENG --start 2026-03-01 --end 2026-03-14
linear-cli c update CYCLE_ID --name "Sprint 5"
linear-cli c complete CYCLE_ID
linear-cli c delete CYCLE_ID
```

## Teams

```bash
linear-cli t list                                 # List all teams
linear-cli t get ENG                              # Team details
linear-cli t members ENG                          # List members
linear-cli t create "Platform" -k PLT             # Create team with key
```

## Search

```bash
linear-cli s issues "auth bug"                    # Search issues
linear-cli s projects "platform"                  # Search projects
linear-cli context                                # Issue for current git branch
linear-cli metrics -t ENG                         # Team velocity and stats
linear-cli history ENG-123                        # Activity timeline
```

## Bulk Operations

Use bulk operations when working with multiple issues at once — saves many round
trips.

```bash
linear-cli b update-state ENG-1 ENG-2 -s Done    # Bulk status update
linear-cli b assign ENG-1 ENG-2 -a "Alice"       # Bulk assign
linear-cli b label ENG-1 ENG-2 -l bug            # Bulk add label
linear-cli b unassign ENG-1 ENG-2                 # Bulk unassign
```

## Git Integration

`linear-cli` integrates with both Git and Jujutsu (jj).

```bash
linear-cli g checkout ENG-123                     # Create + checkout branch
linear-cli g branch ENG-123                       # Show branch name
linear-cli g create ENG-123                       # Create branch (no checkout)
linear-cli g pr ENG-123                           # Create GitHub PR linked to issue
linear-cli g pr ENG-123 --draft                   # Create draft PR
```

## Comments

```bash
linear-cli cm list ISSUE_ID                       # List comments
linear-cli cm create ENG-123 -b "Comment text"    # Add comment
linear-cli cm update COMMENT_ID -b "Edited text"  # Edit comment
linear-cli cm delete COMMENT_ID                   # Delete comment
```

## Notifications

```bash
linear-cli n list                                 # Unread notifications
linear-cli n count                                # Unread count
linear-cli n read NOTIFICATION_ID                 # Mark as read
linear-cli n read-all                             # Mark all as read
linear-cli n archive-all                          # Archive all
```

## Triage

```bash
linear-cli tr list -t ENG                         # Unassigned triage issues
linear-cli tr claim ENG-123                       # Assign to yourself
linear-cli tr snooze ENG-123                      # Snooze for later
```

## Labels

```bash
linear-cli l list                                 # List labels
linear-cli l create "priority:p0" -c "#FF0000"   # Create label with color
linear-cli l update LABEL_ID -n "Renamed"         # Rename
linear-cli l delete LABEL_ID                      # Delete
```

## Users

```bash
linear-cli u list                                 # List workspace users
linear-cli u me                                   # Current user info
linear-cli u get "alice@example.com"              # Look up a user
linear-cli whoami                                 # Alias for `users me`
```

## Roadmaps, Milestones & Initiatives

```bash
# Roadmaps
linear-cli rm list                                # List roadmaps
linear-cli rm get ROADMAP_ID                      # Details
linear-cli rm create "2026 Plan"                  # Create

# Milestones
linear-cli ms list -p "Q1 Roadmap"               # List project milestones
linear-cli ms create "Beta" -p PROJECT_ID         # Create milestone

# Initiatives
linear-cli init list                              # List initiatives
linear-cli init create "Platform Migration"       # Create
```

## Custom Views

```bash
linear-cli v list                                 # List saved views
linear-cli v get VIEW_ID                          # View details
linear-cli v create "My Bugs" -t ENG              # Create view
linear-cli v update VIEW_ID --name "Open Bugs"    # Update
linear-cli v delete VIEW_ID                       # Delete
linear-cli i list --view "My Bugs"                # Apply view to issue list
```

## Relations

```bash
linear-cli rel list ENG-123                       # List relationships
linear-cli rel add ENG-123 blocks ENG-456         # Add relation
linear-cli rel remove ENG-123 blocks ENG-456      # Remove relation
linear-cli rel parent ENG-456 ENG-123             # Set parent issue
linear-cli rel unparent ENG-456                   # Remove parent
```

## Import / Export

```bash
# Import
linear-cli import csv issues.csv -t ENG           # Import from CSV
linear-cli import json issues.json -t ENG         # Import from JSON
linear-cli import csv issues.csv -t ENG --dry-run # Preview without creating

# Export
linear-cli export csv -t ENG -f issues.csv        # Export issues to CSV
linear-cli export json -t ENG -f issues.json      # Export issues to JSON
linear-cli export markdown -t ENG                 # Export to Markdown
linear-cli export projects-csv -f projects.csv    # Export projects to CSV
```

## Raw GraphQL API

Use when a built-in command doesn't cover the operation you need.

```bash
linear-cli api query '{ viewer { name email } }'
linear-cli api mutate 'mutation { issueUpdate(id: "...", input: { ... }) { success } }'
```

## Output Flags (for Scripting & Automation)

These flags make `linear-cli` easy to compose in scripts and pipelines:

| Flag                | Purpose                                                |
| ------------------- | ------------------------------------------------------ |
| `--output json`     | JSON output (also `ndjson`)                            |
| `--compact`         | Compact JSON (no pretty-printing)                      |
| `--fields a,b,c`    | Limit JSON to specific fields (dot paths supported)    |
| `--sort field`      | Sort JSON arrays by field                              |
| `--order asc\|desc` | Sort direction                                         |
| `--quiet`           | Suppress decorative output                             |
| `--id-only`         | Only output resource ID (for chaining)                 |
| `--format tpl`      | Template output, e.g. `"{{identifier}} {{title}}"`     |
| `--filter f=v`      | Client-side filter (`=`, `!=`, `~=`; case-insensitive) |
| `--fail-on-empty`   | Non-zero exit when list is empty                       |
| `--dry-run`         | Preview without making changes                         |
| `--yes`             | Auto-confirm all prompts                               |
| `--no-pager`        | Disable auto-paging                                    |
| `--no-cache`        | Bypass cache                                           |
| `--all`             | Fetch all pages                                        |
| `--limit N`         | Limit results                                          |

### Scripting patterns

```bash
# Get the ID of a newly created issue
ID=$(linear-cli i create "Bug" -t ENG --id-only --quiet)

# JSON output for programmatic consumption
linear-cli i list --output json --fields identifier,title,state.name --compact

# Pipe description from a file
cat desc.md | linear-cli i create "Title" -t ENG -d -

# Batch fetch with structured output
linear-cli i get ENG-1 ENG-2 ENG-3 --output json --compact

# Default JSON for entire session
export LINEAR_CLI_OUTPUT=json
```

### Exit codes

| Code | Meaning       |
| ---- | ------------- |
| `0`  | Success       |
| `1`  | General error |
| `2`  | Not found     |
| `3`  | Auth error    |
| `4`  | Rate limited  |

## Configuration & Multiple Workspaces

```bash
linear-cli config show                            # Show current config
linear-cli config set default_team ENG            # Set default team
linear-cli config get default_team                # Get a config value

# Multiple workspaces / profiles
linear-cli config workspace-add work              # Add workspace profile
linear-cli config workspace-list                  # List profiles
linear-cli config workspace-switch work           # Switch active profile
linear-cli config workspace-current               # Show current profile

# Per-invocation override
linear-cli --profile work i list
export LINEAR_CLI_PROFILE=work
```

Config is stored at `~/.config/linear-cli/config.toml`.

## Interactive TUI

```bash
linear-cli interactive                            # Full TUI for browsing/managing issues
```

## Webhooks (Advanced)

```bash
linear-cli wh list                                # List webhooks
linear-cli wh create https://hook.example.com     # Create webhook
linear-cli wh listen --port 8080                  # Local listener with HMAC-SHA256 verification
```

## Watch Mode

```bash
linear-cli w issue ENG-123                        # Poll for real-time issue changes
linear-cli w project PROJECT_ID                   # Watch a project
linear-cli w team ENG                             # Watch a team
```

## Common Workflow Patterns

### Daily standup / issue triage

```bash
linear-cli i list --mine                          # See what's assigned to me
linear-cli sp status -t ENG                       # Sprint health at a glance
linear-cli n list                                 # Check notifications
```

### Start working on an issue

```bash
linear-cli i start ENG-123 --checkout             # Assigns, sets In Progress, checks out branch
# ... do the work ...
linear-cli done                                   # Marks the current branch issue as Done
linear-cli g pr ENG-123                           # Open a GitHub PR linked to the issue
```

### Bulk triage after planning meeting

```bash
linear-cli i list -t ENG --state "Triage" --output json --compact  # Get all triage issues
linear-cli b update-state ENG-1 ENG-2 ENG-3 -s "Backlog"          # Move to backlog
linear-cli b assign ENG-4 ENG-5 -a "alice@example.com"            # Bulk assign
```

### Sprint planning

```bash
linear-cli sp plan -t ENG                         # See what's planned for next sprint
linear-cli sp burndown -t ENG                     # Check current burndown
linear-cli sp velocity -t ENG                     # Review velocity trend
linear-cli sp carry-over -t ENG                   # Move incomplete issues to next cycle
```
