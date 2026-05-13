# Agent Instructions

## Conversational Style

- Keep answers short and concise
- No emojis in commits, issues, PR comments, or code
- No fluff or cheerful filler text
- Technical prose only, be kind but direct (e.g., "Thanks @user" not "Thanks so
  much @user!")

## Bash Workflows

After editing bash scripts, always format and lint: `shfmt && shellcheck`

Prioritize faster utilities, falling back to traditional tools only if
unavailable:

- `rg` → `grep` (if `rg` not found)
- `fd` → `find` (if `fd` not found)

## Python Workflows

For all Python scripting purposes, use `uv`. Do NOT use the system `python`.

If you need to run an ad-hoc Python inline script, use `uv run python -c "..."`.

For 3rd-party dependencies, specify them with `--with <deps>`. Example:
`uv run --with foo python -c "import foo;..."`

For longer, self-contained Python scripts, leverage `uv` inline script metadata
to specify dependencies as comments. Example:

```python
#!/usr/bin/env -S uv run --script

# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "gql[aiohttp]",
# ]
# ///

from gql import Client, gql
from gql.transport.aiohttp import AIOHTTPTransport

# ...
```

Then run it with `uv run /tmp/file.py` to execute the code.
