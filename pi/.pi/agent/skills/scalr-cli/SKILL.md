---
name: scalr-cli
description: >
  Use this skill whenever the user wants to work with the Scalr CLI tool
  (scalr). Triggers include: any mention of scalr cli, scalr command, scalr
  workspace, scalr environment, scalr run, managing Terraform/OpenTofu
  infrastructure via Scalr, scripting Scalr API operations via CLI, automating
  Scalr workflows, or any task involving scalr commands. Also trigger when the
  user asks how to install, configure, or use any scalr CLI subcommand
  (create-workspace, list-environments, create-run, lock-workspace,
  get-variables, etc.). Use this skill proactively even if the user just says
  "how do I X in Scalr" -- they likely need CLI guidance.
compatibility: "Requires scalr CLI binary in $PATH
  (https://github.com/Scalr/scalr-cli/releases). Configure with SCALR_HOSTNAME
  and SCALR_TOKEN environment variables or run `scalr -configure` for
  interactive setup."
metadata:
  author: Peter Benjamin
  version: 0.1.0
---

# Scalr CLI Skill

Scalr is a Terraform/OpenTofu management platform. The `scalr` CLI communicates
directly with the Scalr API and is the primary tool for scripting and
automation.

## Installation

Single static binary — download from
[GitHub releases](https://github.com/Scalr/scalr-cli/releases), unzip, place in
`$PATH`.

```bash
# Self-update once installed
scalr -update
```

## Configuration

Required before first use. Three env vars OR a config file:

| Variable         | Purpose                                   | Example               |
| ---------------- | ----------------------------------------- | --------------------- |
| `SCALR_HOSTNAME` | Your Scalr instance hostname              | `example.scalr.io`    |
| `SCALR_TOKEN`    | API token (from Scalr UI → User Settings) | —                     |
| `SCALR_ACCOUNT`  | Default account ID (optional)             | `acc-tq8cgt2hu6hpfuj` |

```bash
# Interactive wizard writes ~/.scalr/scalr.conf
scalr -configure
```

## Global Options

| Flag            | Effect                                            |
| --------------- | ------------------------------------------------- |
| `-help`         | Help for all commands or a specific command       |
| `-verbose`      | Show full HTTP request/response                   |
| `-version`      | Print binary version                              |
| `-update`       | Download and replace binary with latest           |
| `-configure`    | Run setup wizard                                  |
| `-autocomplete` | Enable shell tab-completion (restart shell after) |

## Core Usage Patterns

### Get help for a command

```bash
scalr -help <command>
# e.g.:
scalr -help create-workspace
```

### Use flags

```bash
scalr create-environment -name=production
```

### Use JSON blob (for complex creates/updates)

```bash
# From file
scalr create-environment < payload.json

# Inline
echo '{"data":{"attributes":{"name":"production"},"type":"environments"}}' | scalr create-environment
```

### Find missing required flags

```bash
# Run without flags — CLI reports what's missing
scalr lock-workspace
# → Missing required flag(s): [workspace]
```

## Command Reference by Category

See `references/commands.md` for the full command list. Key categories:

| Category               | Example Commands                                                                                                   |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------ |
| **Workspace**          | `create-workspace`, `get-workspaces`, `lock-workspace`, `unlock-workspace`, `update-workspace`, `delete-workspace` |
| **Environment**        | `create-environment`, `list-environments`, `update-environment`, `delete-environment`                              |
| **Run**                | `create-run`, `get-runs`, `confirm-run`, `cancel-run`, `discard-run`                                               |
| **Variable**           | `create-variable`, `get-variables`, `update-variable`, `delete-variable`                                           |
| **Policy Group**       | `create-policy-group`, `list-policy-groups`, `update-policy-group`                                                 |
| **Provider Config**    | `create-provider-configuration`, `list-provider-configurations`                                                    |
| **State Version**      | `get-current-state-version`, `list-state-versions`, `get-state-version-download`                                   |
| **Agent Pool**         | `create-agent-pool`, `get-agent-pools`, `delete-agent-pool`                                                        |
| **Module**             | `create-module`, `list-modules`, `resync-module`                                                                   |
| **Tag**                | `create-tag`, `list-tags`, `add-workspace-tags`                                                                    |
| **Team / User / Role** | `create-team`, `invite-user-to-account`, `create-role`                                                             |
| **Webhook / Endpoint** | `create-webhook`, `list-endpoints`                                                                                 |
| **VCS Provider**       | `create-vcs-provider`, `list-vcs-providers`                                                                        |
| **Service Account**    | `create-service-account`, `get-service-accounts`                                                                   |
| **Access Policy**      | `create-access-policy`, `get-access-policies`                                                                      |

## Common Workflows

### Create and trigger a workspace run

```bash
# 1. Create a CLI-driven workspace
scalr create-workspace -name=my-infra -environment=env-xxxx -terraform-version=1.6.0

# 2. Queue a run
scalr create-run -workspace=ws-xxxx -message="Deploy v2"

# 3. Watch/confirm
scalr get-run -run=run-xxxx
scalr confirm-run -run=run-xxxx   # if auto-apply is off
```

### List workspaces in an environment

```bash
scalr get-workspaces -filter-environment=env-xxxx
```

### Lock / unlock a workspace

```bash
scalr lock-workspace -workspace=ws-xxxx
scalr unlock-workspace -workspace=ws-xxxx
```

### Set a workspace variable

```bash
scalr create-variable \
  -key=TF_VAR_region \
  -value=us-east-1 \
  -category=terraform \
  -workspace=ws-xxxx
```

### Download current state

```bash
scalr get-state-version-download -workspace=ws-xxxx
```

### Override a failing policy check

```bash
scalr override-policy -policy-check=polcheck-xxxx
```

## Tips

- **Tab completion** drastically speeds up usage — run `scalr -autocomplete`
  then restart your shell.
- **`-verbose`** is invaluable for debugging: it prints the exact API request
  and response.
- **IDs vs names**: most filter flags (e.g., `-filter-environment`) accept the
  resource ID (`env-xxxx`), not the name. Use `list-*` commands first to get
  IDs.
- **JSON blob input** is best for complex payloads with relationships (linking
  account, environment, VCS provider, etc.).
- **Required flags**: instead of memorising them, just run the command without
  flags — the CLI will tell you what's missing.
- **`-include=`**: many list/get commands support an `-include=` flag to
  sideload related resources (e.g., `-include=tags,created-by`). Use
  tab-complete to discover available values.

## Reference Files

- `references/commands.md` — Complete flat list of every CLI command with its
  description
