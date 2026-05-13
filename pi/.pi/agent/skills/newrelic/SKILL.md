---
name: newrelic
description: >
  Search and query logs in New Relic via the NerdGraph GraphQL API. Use this
  skill whenever the user wants to search New Relic logs, run NRQL queries,
  query across multiple accounts, or execute long-running async log searches via
  the NerdGraph API. Triggers on: "search New Relic logs", "query New Relic",
  "NRQL query", "find errors in New Relic", "query logs in NR", "New Relic log
  search", "New Relic API", or any request to find, filter, or aggregate data in
  New Relic — even if the user just says "search our logs", "look up errors",
  "check New Relic", or "find this event in NR". Always use this skill
  proactively when the user asks about New Relic log data or observability
  queries.
---

# New Relic NerdGraph Skill

Query and search New Relic log data via the
[NerdGraph GraphQL API](https://docs.newrelic.com/docs/apis/nerdgraph/get-started/introduction-new-relic-nerdgraph/).

---

## Security Rules

- **Only access the 1Password secrets documented in env vars**:
  `NEWRELIC_API_KEY` & `NEWRELIC_ACCOUNT_ID`. Do not browse vaults, list items,
  or read any other secrets unless the user explicitly authorizes it.

---

## Credentials

Credentials are stored in **1Password** and injected at runtime via `op run`.

| Env var               | 1Password reference                |
| --------------------- | ---------------------------------- |
| `NEWRELIC_API_KEY`    | `op://Private/newrelic/api_key`    |
| `NEWRELIC_ACCOUNT_ID` | `op://Private/newrelic/account_id` |

All scripts are run with:

```bash
op run -- uv run /path/to/skill/scripts/<script>.py ...
```

Dependencies (`gql[requests]`) are managed via `uv` inline script metadata — no
separate install step is needed.

---

## Scripts

Scripts live in `scripts/` next to this file. Resolve their **absolute path**
relative to this skill file's location before running.

| Script          | Purpose                                           |
| --------------- | ------------------------------------------------- |
| `nrql_query.py` | Execute NRQL queries (sync, async, cross-account) |

---

## Querying Logs with NRQL

Use `nrql_query.py` to run any NRQL query. Logs live in the `Log` event type.

### Basic log search

```bash
op run -- uv run scripts/nrql_query.py \
    "SELECT * FROM Log WHERE message LIKE '%error%' SINCE 1 hour ago LIMIT 100"
```

### Filter by service and log level

```bash
op run -- uv run scripts/nrql_query.py \
    "SELECT * FROM Log WHERE service.name = 'payments-api' AND level = 'ERROR' SINCE 30 minutes ago LIMIT 200"
```

### Aggregate: count errors by service

```bash
op run -- uv run scripts/nrql_query.py \
    "SELECT count(*) FROM Log WHERE level = 'ERROR' FACET service.name SINCE 24 hours ago"
```

### Search by trace ID or request ID

```bash
op run -- uv run scripts/nrql_query.py \
    "SELECT * FROM Log WHERE trace.id = 'abc123' SINCE 1 day ago"
```

### Timeseries: error rate over time

```bash
op run -- uv run scripts/nrql_query.py \
    "SELECT count(*) FROM Log WHERE level = 'ERROR' TIMESERIES 5 minutes SINCE 6 hours ago"
```

### Specify account explicitly

```bash
op run -- uv run scripts/nrql_query.py \
    --accounts 1234567 \
    "SELECT * FROM Log SINCE 15 minutes ago LIMIT 50"
```

### EU region

```bash
op run -- uv run scripts/nrql_query.py \
    --region eu \
    "SELECT * FROM Log WHERE level = 'ERROR' SINCE 1 hour ago"
```

### Cross-account query

Pass multiple IDs to `--accounts` — the script automatically uses the
cross-account query path:

```bash
op run -- uv run scripts/nrql_query.py \
    --accounts 111111 222222 333333 \
    "SELECT count(*) FROM Log WHERE level = 'ERROR' FACET account SINCE 1 day ago"
```

### Async query (for long-running / large time windows)

Use `--async` when the query may take longer than 60 seconds (e.g., 7-day
windows, large result sets). The script polls automatically until complete:

```bash
op run -- uv run scripts/nrql_query.py \
    --async \
    "SELECT * FROM Log WHERE level = 'CRITICAL' SINCE 7 days ago LIMIT 2000"
```

---

## NRQL Query Reference for Logs

See [`references/logs.md`](references/logs.md) for the full field reference and
useful NRQL clause patterns. Read that file whenever you need to look up
available `Log` fields or construct a query.

---

## Key Patterns

- **Primary log table**: Always query `FROM Log` for log data. Other event types
  (`Transaction`, `PageView`, `SystemSample`, etc.) are also queryable with the
  same scripts.
- **Time window is required**: NRQL queries need a `SINCE` clause. Without one
  the query defaults to the last hour — be explicit.
- **LIMIT cap**: `SELECT *` is capped at 2000 rows per query. For exhaustive
  exports use multiple time-windowed queries.
- **Async for large windows**: Use `--async` for queries spanning days or
  involving millions of events. The script polls `nrqlQueryProgress` until
  `completed = true`.
- **Cross-account**: `--accounts` triggers the cross-account query path, which
  does not support async mode.
- **Credentials**: Always inject via `op run --` so secrets never appear in
  shell history or process lists.
- **EU region**: Pass `--region eu` to use `api.eu.newrelic.com`.
