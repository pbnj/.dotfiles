---
name: search-web
description:
  Search the web for information, documentation, articles, code examples, and
  answers. Use this skill whenever the user wants to find something online —
  even if they don't say "search" but instead say "look up", "find info about",
  "what is X", "latest news on", "find examples of", "research X", or any
  request that requires retrieving up-to-date information from the internet.
  Always use this skill proactively when the user asks about something you don't
  have current knowledge of, or when they explicitly want web sources.
---

# Search Web

Query the web via a local SearXNG instance (`http://localhost:8888`) with
automatic fallback to DuckDuckGo when SearXNG is unavailable.

## Running a search

Use the bundled script. Always run from the skill directory so the path
resolves:

```bash
uv run scripts/search.py "your query here" --json
```

The `--json` flag returns structured results. Omit it for human-readable output.

## Key options

| Option            | Default                 | Purpose                           |
| ----------------- | ----------------------- | --------------------------------- |
| `--num-results N` | `10`                    | How many results (1–50)           |
| `--site domain`   | _(all)_                 | Restrict to one domain            |
| `--region code`   | `wt-wt`                 | Geographic region (e.g., `us-en`) |
| `--safesearch`    | `moderate`              | `off` / `moderate` / `strict`     |
| `--searxng-url`   | `http://localhost:8888` | Override SearXNG base URL         |

## Engine priority

1. **SearXNG** (`http://localhost:8888`) — tried first; if it times out or
   errors, falls back automatically.
2. **DuckDuckGo** (`ddgs` Python package) — used when SearXNG is unreachable.

The engine actually used is printed to stderr. You don't need to manage the
fallback yourself.

## Common patterns

```bash
# General lookup
uv run scripts/search.py "Python asyncio tutorial" --json

# Restrict to a domain
uv run scripts/search.py "ownership rules" --site doc.rust-lang.org --json

# More results for broad research
uv run scripts/search.py "GraphQL best practices 2024" --num-results 15 --json

# Narrow to a community
uv run scripts/search.py "ModuleNotFoundError requests" --site stackoverflow.com --json
```

## Output fields (JSON)

Each result object contains:

- `title` — page heading
- `href` — full URL, ready to pass to the `fetch` skill
- `body` — excerpt / snippet

## Combining with the fetch skill

Search gives you URLs. Pass them to the `fetch` skill to retrieve full page
content as clean Markdown:

1. Run search, collect relevant `href` values.
2. Load the `fetch` skill and fetch each URL of interest.
3. Synthesize the content for the user.

## Reference

Full usage examples and domain shortcuts: `references/USAGE.md`
