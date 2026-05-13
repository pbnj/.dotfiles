---
name: panther
description:
  'Queries Panther SIEM data lake via GraphQL API. Use when the user wants to
  query Panther logs, run SQL against the data lake, search for indicators of
  compromise, explore databases/tables/columns, poll for query results, list
  past queries, build GraphQL scripts, or manage Panther alerts. Triggers on:
  "query Panther", "Panther data lake", "Panther GraphQL", "search Panther
  logs", "indicator search in Panther", "executeDataLakeQuery",
  "executeIndicatorSearchQuery", "panther_logs", "Panther alerts", "list
  alerts", "alert status", "triage alert", "resolve alert", "assign alert",
  "mark alert as resolved", "update alert", "comment on alert", or any request
  to pull log data, hunt threats, or manage security alerts via the Panther API.
  Also triggers on "search my logs", "find this IP in Panther", "show me my
  alerts", or "close these alerts".'
---

# Panther Data Lake GraphQL Queries

---

## Security Rules

- **Never access 1Password secrets beyond what is documented in this skill**
  (i.e. `op://Employee/panther/instance_url` and
  `op://Employee/panther/api_token`). Do not browse vaults, list items, or read
  any other secrets unless the user explicitly authorizes it.

---

## How to run queries

This skill includes two ready-to-run Python scripts. **Always use these
scripts** to execute queries rather than writing GraphQL by hand — they handle
auth, async polling, and pagination automatically.

The scripts live next to this file in `scripts/`. Resolve their absolute path
relative to this skill file's location before running.

### Prerequisites

Dependencies are managed with `uv` — no separate install step needed. `uv run`
reads the inline script metadata and installs `gql` and `aiohttp` into an
isolated environment on first run automatically.

Credentials are stored in **1Password** and injected at runtime via `op run`.
The expected secret references are:

```sh
PANTHER_INSTANCE_URL = op://Private/panther/instance_url
PANTHER_API_TOKEN = op://Private/panther/api_token
```

If the item name or vault differs in the user's 1Password, ask them to confirm
the correct `op://vault/item/field` references before running.

### Run a SQL query

```bash
op run -- uv run /path/to/skill/scripts/query_data_lake.py "<SQL>"
```

Example:

```bash
op run -- uv run scripts/query_data_lake.py "select * from panther_logs.public.aws_cloudtrail limit 20"
```

- Results are returned as a **JSON array on stdout**.
- Progress and status messages are on **stderr** (won't pollute captured
  output).
- The script polls until the query completes and pages through all results
  automatically.

### Run an indicator search

```bash
op run -- uv run scripts/indicator_search.py \
        --indicators "<value1>" "<value2>" \
        --start-time "<ISO8601>" \
        --end-time "<ISO8601>" \
        [--indicator-name field <p_any_* >]
```

Example:

```bash
op run -- uv run scripts/indicator_search.py \
        --indicators "1.2.3.4" \
        --start-time "2024-06-01T00:00:00.000Z" \
        --end-time "2024-06-30T23:59:59.000Z" \
        --indicator-name p_any_ip_addresses
```

- Omit `--indicator-name` to let Panther auto-detect the indicator type.
- Common `--indicator-name` values: `p_any_ip_addresses`,
  `p_any_aws_account_ids`, `p_any_domain_names`, `p_any_sha256_hashes`,
  `p_any_md5_hashes`.

---

## Working with Alerts

Two scripts handle all alert operations. Run them with `op run -- uv run` just
like the query scripts.

### Get a single alert

```bash
op run -- uv run scripts/get_alert.py <alert-id>
```

Example:

```bash
op run -- uv run scripts/get_alert.py 6087bc1d6fc49ce97ef3c85ca0e3f31b
```

Outputs a JSON object with full alert details: `id`, `title`, `description`,
`severity`, `status`, `type`, `riskScore` (classification, indicators),
`createdAt`, `updatedAt`, `firstEventOccurredAt`, `lastReceivedEventAt`,
`reference`, `runbook`, `assignee`, `origin` (detection or system error), and
`deliveries` (Jira/Slack dispatch records).

### List alerts

```bash
op run -- uv run scripts/list_alerts.py \
        --start-time "<ISO8601>" \
        --end-time "<ISO8601>" \
        [--severities INFO LOW MEDIUM HIGH CRITICAL] \
        [--statuses OPEN TRIAGED RESOLVED CLOSED]
```

Example — all open HIGH/CRITICAL alerts in June 2024:

```bash
op run -- uv run scripts/list_alerts.py \
        --start-time "2024-06-01T00:00:00.000Z" \
        --end-time "2024-06-30T23:59:59.000Z" \
        --severities HIGH CRITICAL \
        --statuses OPEN
```

Outputs a JSON array. Each alert includes: `id`, `title`, `severity`, `status`,
`createdAt`, `updatedAt`, `assignee`, and `origin` (detection name or system
error type).

### Update alert status

```bash
op run -- uv run scripts/update_alerts.py status \
        --ids "<alert-id-1>" "<alert-id-2>" \
        --status RESOLVED
```

Valid statuses: `OPEN` `TRIAGED` `RESOLVED` `CLOSED`

### Add a comment

```bash
op run -- uv run scripts/update_alerts.py comment \
        --id "<alert-id>" \
        --body "Investigation complete. False positive."
```

Add `--html` to send the body as HTML instead of plain text.

### Assign alerts to a user

```bash
# by email
op run -- uv run scripts/update_alerts.py assign \
        --ids "<alert-id-1>" "<alert-id-2>" \
        --email analyst@example.com

# by Panther user ID
op run -- uv run scripts/update_alerts.py assign \
        --ids "<alert-id-1>" \
        --user-id "<panther-user-id>"
```

### Unassign alerts

```bash
op run -- uv run scripts/update_alerts.py unassign \
        --ids "<alert-id-1>" "<alert-id-2>"
```

---

## Key Patterns to Remember

- **Always poll**: `executeDataLakeQuery` and `executeIndicatorSearchQuery`
  return an `id` immediately — the query runs async. Poll
  `dataLakeQuery(id: ...)` in a loop until `status !== "running"`.
- **SQL only**: API queries must be SQL. PantherFlow syntax is not accepted.
- **Table naming**: Standard format is `panther_logs.public.<log_type>`, e.g.
  `panther_logs.public.aws_cloudtrail`.
- **Indicator fields**: Common `indicatorName` values include
  `p_any_ip_addresses`, `p_any_aws_account_ids`, `p_any_domain_names`,
  `p_any_sha256_hashes`. Leave blank for auto-detection.
- **Alert filters require a time range**: `alerts()` always needs
  `createdAtAfter` and `createdAtBefore` — the query will fail without them.
- **Alert status is an enum**: Pass values unquoted in raw GraphQL (`RESOLVED`),
  but as plain strings in the scripts (`--status RESOLVED`).
- **Credentials**: All scripts need `PANTHER_INSTANCE_URL` and
  `PANTHER_API_TOKEN`. Always inject via `op run --` so secrets never touch the
  shell history.
