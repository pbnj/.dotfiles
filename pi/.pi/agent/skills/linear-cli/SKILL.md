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
  version: 0.2.0
---

# Linear CLI Skill

[`linear`](https://github.com/schpet/linear-cli) is a CLI for
[Linear.app](https://linear.app) — v2.0.0.

The binary is `linear`. Always run `linear <command> --help` to discover flags
for any subcommand before guessing.

## Environment Variables

| Variable         | Purpose                                        |
| ---------------- | ---------------------------------------------- |
| `LINEAR_DEBUG=1` | Show full error details including stack traces |

## Multi-Workspace

Pass `--workspace <slug>` to any command to target a specific workspace:

```bash
linear --workspace myorg issue mine
```

## Aliases

| Full command         | Aliases                   |
| -------------------- | ------------------------- |
| `issue`              | `i`                       |
| `issue mine`         | `i mine`, `i list`, `i l` |
| `issue query`        | `i query`, `i q`          |
| `issue view`         | `i view`, `i v`           |
| `issue pull-request` | `i pr`                    |
| `issue delete`       | `i d`                     |
| `team`               | `t`                       |
| `project`            | `p`                       |
| `project-update`     | `pu`                      |
| `cycle`              | `cy`                      |
| `milestone`          | `m`                       |
| `initiative`         | `init`                    |
| `initiative-update`  | `iu`                      |
| `label`              | `l`                       |
| `document`           | `docs`, `doc`             |

## Reference

Detailed command reference is in `references/`:

- [auth](references/auth.md) — authentication and workspace credentials
- [issue](references/issue.md) — create, view, update, start, PR, delete, comments, links, relations
- [team](references/team.md) — list, create, delete, members, autolinks
- [project](references/project.md) — list, view, create, update, delete; project-update
- [cycle](references/cycle.md) — list, view
- [milestone](references/milestone.md) — list, view, create, update, delete
- [initiative](references/initiative.md) — full CRUD + project linking; initiative-update
- [label](references/label.md) — list, create, delete
- [document](references/document.md) — list, view, create, update, delete
- [api](references/api.md) — raw GraphQL requests; schema dump
- [config](references/config.md) — interactive `.linear.toml` generation
- [completions](references/completions.md) — shell completion setup
- [workflows](references/workflows.md) — common multi-step patterns
