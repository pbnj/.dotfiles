---
name: fetch
description: >
  Fetch and convert web content from a URL into clean Markdown for LLM
  reasoning. Use this skill whenever user provides a URL or whenever you need to
  fetch content/documentation from the web to turn noisy source pages into
  structured text. Triggers include "fetch URL", "get content from page", "parse
  web page", "what's on URL", and any request involving a web URL.
compatibility: "Requires network access and `uv` to run `uvx --from crawl4ai crwl`."
metadata:
  author: Peter Benjamin
  version: 1.0.0
allowed-tools: Bash
---

# Fetch URL

Fetches web content from URLs and converts HTML to clean, structured Markdown
suitable for LLM reasoning using `crawl4ai`. This skill solves the "HTML noise
problem" — raw HTML from `curl` often contains megabytes of markup, styles,
scripts, and boilerplate that obscure the actual content. Using `markdown-fit`
heuristics dramatically reduces noise and improves reasoning quality.

## When to use this skill

Use this skill whenever:

- A user provides a URL and you need to understand its content
- You encounter HTML that needs to be parsed and converted to readable text
- You want to include web content in your reasoning context
- HTML is too large or noisy to reason about directly

Do NOT use this skill if:

- The user explicitly wants raw HTML (e.g., "give me the raw HTML source")
- You only need to fetch metadata (headers, status code) — use `curl -I`
  directly
- You are retrieving structured content (e.g., `curl api.example.com/data.json`
  or `curl -H "Accept: application/json" api.example.com/data`

## Usage

```bash
uvx --from crawl4ai crwl crawl -o markdown-fit "https://example.com/article"
```

The `-o markdown-fit` option is recommended as it uses heuristics to remove
boilerplate (headers, footers, ads) and keep only the core content.

## Examples

### Example 1: Fetch and convert blog post

```bash
uvx --from crawl4ai crwl crawl -o markdown-fit "https://example.com/my-article"
```

### Example 2: GitHub repository content

```bash
uvx --from crawl4ai crwl crawl -o markdown-fit "https://github.com/aquasecurity/trivy/blob/main/README.md"
```

### Example 3: Error handling

```bash
$ uvx --from crawl4ai crwl crawl -o markdown-fit "https://invalid-url-that-does-not-exist.local"

# The command will output an error or an empty result depending on the failure mode.
```

**Key principle**: Always try to provide the cleanest possible representation of
web content to the LLM context. This skill automates that process.
