---
name: search-web
description: Search the web for information, documentation, articles, code examples, and
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
uv run scripts/search.py "your query here"
```

Output is JSON by default.

## Key options

| Option          | Default                 | Purpose                              |
| --------------- | ----------------------- | ------------------------------------ |
| `--num N`       | `10`                    | How many results (1–50)              |
| `--site domain` | _(all)_                 | Restrict to one domain               |
| `--region code` | `wt-wt`                 | Geographic region (e.g., `us-en`)    |
| `--safesearch`  | `moderate`              | `off` / `moderate` / `strict`        |
| `--searxng-url` | `http://localhost:8888` | Override SearXNG base URL            |
| `--fetch`       | _(off)_                 | Fetch full page content via crawl4ai |
| `--output`      | `json`                  | Output format: `json` or `markdown`  |

## Engine priority

1. **SearXNG** (`http://localhost:8888`) — tried first; if it times out or
   errors, falls back automatically.
2. **DuckDuckGo** (`ddgs` Python package) — used when SearXNG is unreachable.

The engine actually used is printed to stderr. You don't need to manage the
fallback yourself.

## Common patterns

```bash
# General lookup
uv run scripts/search.py "Python asyncio tutorial"

# Human-readable markdown output
uv run scripts/search.py "Python asyncio tutorial" --output markdown

# Fetch full content and render as markdown
uv run scripts/search.py "Rust lifetimes" --fetch --output markdown

# Restrict to a domain
uv run scripts/search.py "ownership rules" --site doc.rust-lang.org

# More results for broad research
uv run scripts/search.py "GraphQL best practices 2024" --num 15

# Narrow to a community
uv run scripts/search.py "ModuleNotFoundError requests" --site stackoverflow.com

# Search and immediately fetch full page content
uv run scripts/search.py "crawl4ai quickstart" --num 3 --fetch
```

## Output fields (JSON)

Each result object contains:

- `title` — page heading
- `href` — full URL, ready to pass to the `fetch` skill
- `body` — excerpt / snippet
- `content` — full page markdown (only present when `--fetch` is used)

## Markdown output

With `--output markdown` each result is rendered as:

```markdown
## N. [Title](url)

excerpt text

full page content (if --fetch was used)
```

## Combining with the fetch skill

Search gives you URLs. Pass them to the `fetch` skill to retrieve full page
content as clean Markdown:

1. Run search, collect relevant `href` values.
2. Load the `fetch` skill and fetch each URL of interest.
3. Synthesize the content for the user.

Alternatively, pass `--fetch` directly to `search.py` to crawl all result
URLs in one step (uses `crawl4ai` under the hood — runs a headless browser,
handles JS-rendered pages):

```bash
uv run scripts/search.py "topic" --num 5 --fetch
```

## Reference

Full usage examples and domain shortcuts: `references/USAGE.md`
