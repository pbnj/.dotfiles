# Search-Web Skill Quick Reference

## Basic Syntax

```bash
uv run /path/to/scripts/search.py --query "search terms" [OPTIONS]
```

## All Options

| Option          | Description               | Example                  | Default            |
| --------------- | ------------------------- | ------------------------ | ------------------ |
| `--query`       | **Required** search terms | `--query "Python async"` | N/A                |
| `--num-results` | Number of results (1-50)  | `--num-results 10`       | 10                 |
| `--region`      | Geographic region         | `--region us-en`         | wt-wt (worldwide)  |
| `--site`        | Limit to domain           | `--site github.com`      | none (all results) |
| `--safesearch`  | Safe search level         | `--safesearch strict`    | moderate           |

## Common Commands

### General search

```bash
uv run scripts/search.py --query "topic"
```

### Search with custom result count

```bash
uv run scripts/search.py --query "topic" --num-results 15
```

### Search GitHub

```bash
uv run scripts/search.py --query "code example" --site github.com
```

### Search Stack Overflow

```bash
uv run scripts/search.py --query "error message" --site stackoverflow.com
```

### Search documentation

```bash
uv run scripts/search.py --query "function" --site docs.python.org
```

### Search with specific region

```bash
uv run scripts/search.py --query "topic" --region us-en
```

### Strict safe search

```bash
uv run scripts/search.py --query "topic" --safesearch strict
```

### Combine multiple options

```bash
uv run scripts/search.py --query "async" --num-results 10 --site github.com
```

## Domain Shortcuts

```bash
# Code & Open Source
--site github.com                      # GitHub repositories
--site github.com/topics               # GitHub topic collections

# Q&A & Community
--site stackoverflow.com                # Stack Overflow answers
--site reddit.com/r/programming        # Reddit communities

# Documentation
--site docs.python.org                  # Python docs
--site nodejs.org                       # Node.js docs
--site developer.mozilla.org            # MDN Web Docs
--site docs.aws.amazon.com              # AWS documentation
--site doc.rust-lang.org                # Rust documentation
--site pkg.go.dev                       # Go packages

# Articles & Blogs
--site dev.to                           # Dev.to articles
--site medium.com                       # Medium posts
--site hashnode.com                     # Hashnode blogs

# Official Resources
--site github.blog                      # GitHub blog
--site blog.rust-lang.org               # Rust blog
```

## Output Format

Each result includes:

1. **Number** — Result index (1, 2, 3, ...)
2. **Title** — Result title/heading
3. **URL** — Full, expanded, copy-paste-ready URL
4. **Excerpt** — Preview text (if available)

```text
 1. Title of First Result
    https://example.com/full/url/here
    Preview text about what's on the page...

 2. Title of Second Result
    https://another-example.com/resource
    More preview text...
```

## Region Codes

Common region codes for `--region` option:

- `wt-wt` — Worldwide (default)
- `us-en` — United States (English)
- `en-gb` — United Kingdom (English)
- `de-de` — Germany (German)
- `fr-fr` — France (French)
- `es-es` — Spain (Spanish)
- `it-it` — Italy (Italian)
- `ja-jp` — Japan (Japanese)
- `zh-cn` — China (Chinese)

## Safe Search Levels

- `off` — No filtering
- `moderate` — Default, balanced filtering
- `strict` — Maximum filtering

```bash
# No filtering
uv run scripts/search.py --query "topic" --safesearch off

# Strict filtering
uv run scripts/search.py --query "topic" --safesearch strict
```

## Workflow Integration with Fetch-URL

1. **Search** for information:

   ```bash
   uv run scripts/search.py --query "asyncio" --site docs.python.org --num-results 3
   ```

2. **Copy** the expanded URL from results

3. **Fetch** the full page content:

   ```text
   Use fetch-url skill with URL: https://docs.python.org/3/library/asyncio.html
   ```

4. **Get** clean Markdown content for analysis

## Tips & Tricks

- **URLs are always ready to copy** — Just select and copy the full URL line
- **Use `--site` for precision** — Much better than adding keywords to query
- **5-10 results usually enough** — Limits noise while finding good sources
- **Combine searches** — Try different `--site` values for different
  perspectives
- **Check excerpts first** — They often have the answer without needing to fetch
- **Get more if needed** — Can always run again with `--num-results 20` to see
  more
- **No API key needed** — Uses public DuckDuckGo service
- **Python-based** — More portable and reliable than CLI tools

## Examples

### Research topic

```bash
uv run scripts/search.py --query "Kubernetes networking" --num-results 10
```

### Troubleshoot error

```bash
uv run scripts/search.py --query "ModuleNotFoundError: No module named" --site stackoverflow.com
```

### Find GitHub examples

```bash
uv run scripts/search.py --query "rest api fastapi" --site github.com --num-results 10
```

### Get latest info

```bash
uv run scripts/search.py --query "PostgreSQL 16 new features" --num-results 5
```

### Search tutorials

```bash
uv run scripts/search.py --query "Docker best practices" --site dev.to
```

### Search with region

```bash
uv run scripts/search.py --query "tech news" --region us-en --num-results 5
```

### Multi-constraint search

```bash
uv run scripts/search.py --query "async patterns" --site github.com --num-results 15 --region en-gb
```
