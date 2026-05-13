---
name: search-glean
description: >
  Search internal, work-related knowledge using Glean. Use this skill whenever
  the user wants to find internal documentation, runbooks, ADRs, Jira tickets,
  Confluence pages, Slack conversations, GitHub code, Google Drive files, or any
  other company-internal resource. Trigger phrases: "search glean for", "search
  internal docs", "find the runbook for", "look up our", "search Confluence",
  "search our knowledge base", "what does our wiki say about", "find internal
  info on". Requires $GLEAN_API_TOKEN to be set. Always use this skill instead
  of search-web when the query is about work-specific topics, internal tools,
  team processes, or proprietary systems.
---

# Search Glean Skill

Search internal company knowledge via the **Glean REST API**. Covers all indexed
datasources — Confluence, Jira, GitHub, Google Drive, Slack, and more.

## Prerequisites

- Python 3.11+ (used via `uv run`)
- `requests` package (automatically installed via uv script metadata)
- `$GLEAN_API_TOKEN` environment variable set to a valid Glean API token

## Setup

`GLEAN_API_TOKEN` is stored in 1Password. Use `op run --` to inject it at
runtime — never export the raw token into your shell environment.

Set the 1Password reference in your shell profile:

```bash
# 1Password reference — op resolves this to the real token at runtime
export GLEAN_API_TOKEN="op://Private/Glean/api-token"
```

Then prefix every invocation with `op run --`:

```bash
op run -- op run -- uv run <absolute-path-to-skill>/scripts/search.py \
  --query "your search terms"
```

To generate an API token: Glean Settings → API Tokens → Create token.

## Basic Search Workflow

> **Important for LLMs**: Always resolve `scripts/search.py` to the absolute
> path of this skill's directory. Locate the `search-glean/` skill directory at
> runtime — never hardcode or guess paths. Example: if this skill lives at
> `~/.pi/agent/skills/search-glean/`, run
> `uv run ~/.pi/agent/skills/search-glean/scripts/search.py`.

### 1. Search internal knowledge

```bash
op run -- uv run <absolute-path-to-skill>/scripts/search.py \
  --query "your search terms"
```

### 2. Review and identify relevant results

Each result shows the title, source URL, datasource label, and a text snippet.
Pick the most relevant URLs and fetch full content using the `fetch-url` skill.

## Search Parameters

- `--query` (required): Your search terms
- `--num-results`: Number of results (default: 10, max: 50)
- `--datasource`: Filter to a specific source (see datasources below)
- `--api-token`: Glean API token (also reads `$GLEAN_API_TOKEN`)
- `--backend-url`: Glean backend URL (also reads `$GLEAN_BACKEND_URL`)

## Datasource Filters

Use `--datasource` to restrict results to a single source:

| Datasource   | Content                       |
| ------------ | ----------------------------- |
| `confluence` | Internal wiki, runbooks, ADRs |
| `jira`       | Tickets, epics, sprints       |
| `github`     | Code, PRs, issues, READMEs    |
| `gdrive`     | Google Docs, Sheets, Slides   |
| `slack`      | Channel messages, threads     |
| `gmail`      | Email threads                 |
| `figma`      | Design files                  |

Omit `--datasource` to search across all sources simultaneously.

## Common Use Cases

### Find a runbook or process doc

```bash
op run -- uv run <absolute-path-to-skill>/scripts/search.py \
  --query "incident response runbook" --datasource confluence
```

### Look up a Jira ticket or epic

```bash
op run -- uv run <absolute-path-to-skill>/scripts/search.py \
  --query "data pipeline migration epic" --datasource jira
```

### Search internal code or READMEs

```bash
op run -- uv run <absolute-path-to-skill>/scripts/search.py \
  --query "authentication middleware" --datasource github
```

### Find a design doc or ADR

```bash
op run -- uv run <absolute-path-to-skill>/scripts/search.py \
  --query "ADR database sharding decision" --datasource confluence
```

### Search across all internal sources

```bash
op run -- uv run <absolute-path-to-skill>/scripts/search.py \
  --query "onboarding checklist" --num-results 15
```

### Find a Slack discussion

```bash
op run -- uv run <absolute-path-to-skill>/scripts/search.py \
  --query "deploy freeze policy" --datasource slack
```

## Output Format

Each result includes:

- **Title** — Document or issue title
- **Label** — `[datasource · doc type]` for quick identification
- **URL** — Direct link, ready for the fetch-url skill
- **Snippet** — Relevant excerpt from the content

## Workflow Pattern

1. **Search** — Run with your query, optionally scoped to a datasource
2. **Review** — Scan titles, labels, and snippets to find the right result
3. **Fetch** — Use the `fetch-url` skill on the most relevant URL
4. **Analyze** — Reason over the full Markdown content returned

## Tips

- **Omit `--datasource` first** — cross-source search often surfaces the best
  result faster than guessing which system it lives in
- **Use natural language** — Glean's ranking understands intent, not just
  keywords
- **Narrow with `--datasource`** — when you know exactly where something is
- **Fetch the URL** — snippets are short; always fetch for full content before
  drawing conclusions
- **Increase `--num-results`** — internal search can have lower recall; try 20
  if top results miss

## Technical Details

- **API**: Glean REST API `POST /rest/api/v1/search`
- **Auth**: Bearer token via `$GLEAN_API_TOKEN`
- **Backend**: `$GLEAN_BACKEND_URL`
- **No fallback** — Glean is internal-only; failures surface as errors with
  actionable messages
