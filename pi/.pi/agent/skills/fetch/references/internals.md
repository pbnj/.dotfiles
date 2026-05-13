# Internal Implementation Details

## Why this matters for LLMs

Raw HTML is extremely noisy. A typical web page might be:

- **1-5% actual content**
- **95-99% markup, scripts, styles, tracking, ads**

This means fetching raw HTML often wastes thousands of tokens on boilerplate,
making it hard to reason about the actual content. Converting to Markdown:

- ✅ Reduces token overhead by 80-95%
- ✅ Improves signal-to-noise ratio dramatically
- ✅ Makes content structure clear (headers, lists, tables)
- ✅ Preserves semantics while removing visual markup
- ✅ Enables better reasoning with cleaner input

## Implementation

The skill uses a dedicated **Python script** (`scripts/fetch.py`) that:

- **Fetches URLs** using the `requests` library with proper HTTP headers
- **Converts HTML to Markdown** using the `markdownify` library
- **Handles GitHub blob URLs** automatically by transforming them to raw URLs
- **Cleans up output** by removing excessive whitespace
- **Provides proper error handling** with meaningful error messages

## How it works

1. **Validate and normalize URL**
   - Check if URL is valid and accessible
   - Transform GitHub blob URLs to raw URLs automatically

2. **Fetch content**
   - Send HTTP request with proper user-agent headers
   - Handle timeouts and connection errors gracefully

3. **Identify content type**
   - If raw GitHub URL: return content as-is (no conversion needed)
   - Otherwise: convert HTML to Markdown

4. **Clean output**
   - Remove excessive whitespace
   - Preserve structure (headers, lists, links, code blocks)
   - Return clean, readable Markdown

## GitHub blob URL handling

The script automatically detects and transforms GitHub blob URLs:

**Input:**

```text
https://github.com/user/repo/blob/main/path/to/file.md
```

**Transformed to:**

```text
https://raw.githubusercontent.com/user/repo/main/path/to/file.md
```

This bypasses GitHub's web interface and fetches the raw file directly, which is
already plain text and doesn't need HTML conversion.

## Prerequisites

### Install `uv`

The script relies on `uv` for Python script execution with automatic dependency
management.

```bash
# macOS
brew install uv

# Linux/other systems
curl -LsSf https://astral.sh/uv/install.sh | sh
```

### Python 3.9+

`uv` will automatically use Python 3.9 or later. If not available on your
system:

```bash
# macOS
brew install python3

# Ubuntu/Debian
sudo apt-get install python3.9
```

**Note:** Dependencies (`requests`, `markdownify`) are **automatically
installed** by `uv` when you run the script. No manual package installation is
needed.

## Error handling

The Python script handles common error cases gracefully:

### Connection errors (404, timeout, network unavailable)

```text
Error fetching https://invalid-url.local: [Errno -2] Name or service not known
```

**Action:** Inform user, suggest checking the URL and network connectivity.

### Invalid URL format

```text
Invalid URL: not-a-valid-url
```

**Action:** Validate URL format before attempting fetch.

### HTTP errors (401, 403, 5xx)

```text
Error fetching https://example.com/private: 403 Client Error: Forbidden
```

**Action:** Inform user about authentication requirements or server issues.

### Timeout (default 30 seconds)

```text
Error fetching https://slow-server.example.com: ConnectTimeout
```

**Action:** Suggest checking server availability or trying again later.

### HTML conversion issues

The `markdownify` library is forgiving and produces best-effort output. If
conversion produces unexpected results:

**Action:** Inform user and offer to provide raw HTML for manual review.

## Output quality tips

- **Preserve structure**: Tables, lists, and headers are converted to Markdown
  equivalents
- **Remove noise**: Scripts, styles, and boilerplate are stripped
- **Readable**: The output is suitable for copy-paste into LLM prompts
- **Links preserved**: URLs in the original HTML are converted to Markdown links
  `[text](url)`
- **Code blocks**: HTML `<code>` and `<pre>` tags become Markdown code blocks
  with language hints (if available)
