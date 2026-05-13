# Search-Glean Skill Quick Reference

## Basic Syntax

```bash
op run -- uv run /path/to/scripts/search.py --query "search terms" [OPTIONS]
```

> `op run --` injects the `GLEAN_API_TOKEN` 1Password reference at runtime. Set
> `GLEAN_API_TOKEN="op://Private/Glean/api-token"` in your shell profile.

## All Options

<!-- markdownlint-disable MD013 -->

| Option          | Description               | Example                     | Default              |
| --------------- | ------------------------- | --------------------------- | -------------------- |
| `--query`       | **Required** search terms | `--query "deploy runbook"`  | N/A                  |
| `--num-results` | Number of results (1-50)  | `--num-results 20`          | 10                   |
| `--datasource`  | Limit to one source       | `--datasource confluence`   | all sources          |
| `--api-token`   | Glean API token           | `--api-token xxx`           | `$GLEAN_API_TOKEN`   |
| `--backend-url` | Glean backend base URL    | `--backend-url https://...` | `$GLEAN_BACKEND_URL` |

<!-- markdownlint-enable MD013 -->

## Common Commands

### Search all internal sources

```bash
op run -- uv run scripts/search.py --query "topic"
```

### Search Confluence (wiki, runbooks, ADRs)

```bash
op run -- uv run scripts/search.py --query "topic" --datasource confluence
```

### Search Jira (tickets, epics)

```bash
op run -- uv run scripts/search.py --query "topic" --datasource jira
```

### Search GitHub (code, PRs, READMEs)

```bash
op run -- uv run scripts/search.py --query "topic" --datasource github
```

### Search Google Drive (Docs, Sheets, Slides)

```bash
op run -- uv run scripts/search.py --query "topic" --datasource gdrive
```

### Search Slack

```bash
op run -- uv run scripts/search.py --query "topic" --datasource slack
```

### Get more results

```bash
op run -- uv run scripts/search.py --query "topic" --num-results 25
```

## Datasource Reference

| Value        | Covers                              |
| ------------ | ----------------------------------- |
| `confluence` | Wiki pages, runbooks, ADRs, how-tos |
| `jira`       | Issues, epics, sprints, bug reports |
| `github`     | Code, PRs, issues, READMEs, wikis   |
| `gdrive`     | Google Docs, Sheets, Slides, Forms  |
| `slack`      | Messages, threads, channel history  |
| `gmail`      | Email threads                       |
| `figma`      | Design files and prototypes         |

## Workflow: Search → Fetch → Analyze

1. **Search** for internal knowledge:

   ```bash
   op run -- uv run scripts/search.py \
     --query "deploy runbook" --datasource confluence
   ```

2. **Copy** the URL from the most relevant result

3. **Fetch** the full page content:

   ```text
   Use fetch-url skill with URL: https://...
   ```

4. **Analyze** the full Markdown content
