#!/usr/bin/env -S uv run --script

# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "click",
#   "ddgs",
#   "requests",
#   "simple-term-menu",
# ]
# ///

import sys
import json
import webbrowser
import click
import requests
from typing import Optional
from ddgs import DDGS
from simple_term_menu import TerminalMenu

SEARXNG_DEFAULT_URL = "http://localhost:8888"


def _search_searxng(
    query: str, base_url: str, num_results: int, region: str, safesearch: str
) -> list[dict]:
    safesearch_map = {"off": 0, "moderate": 1, "strict": 2}
    params = {
        "q": query,
        "format": "json",
        "language": region,
        "safesearch": safesearch_map.get(safesearch, 1),
        "pageno": 1,
    }
    url = f"{base_url.rstrip('/')}/search"
    resp = requests.get(url, params=params, timeout=5)
    resp.raise_for_status()
    data = resp.json()
    return [
        {
            "title": r.get("title", ""),
            "href": r.get("url", ""),
            "body": r.get("content", ""),
        }
        for r in data.get("results", [])[:num_results]
    ]


def _search_ddgs(
    query: str, num_results: int, region: str, safesearch: str
) -> list[dict]:
    return list(
        DDGS().text(
            query, region=region, safesearch=safesearch, max_results=num_results
        )
    )


@click.command()
@click.argument("query")
@click.option(
    "--num-results", type=int, default=10, help="Number of results to return (1-50)"
)
@click.option(
    "--region", default="wt-wt", help="Geographic region (e.g., wt-wt, en-us)"
)
@click.option(
    "--site",
    default=None,
    help="Restrict search to a specific domain (e.g., github.com)",
)
@click.option(
    "--safesearch",
    type=click.Choice(["off", "moderate", "strict"]),
    default="moderate",
    help="Safe search level",
)
@click.option(
    "--json", "json_output", is_flag=True, help="Output results in JSON format"
)
@click.option(
    "--searxng-url",
    default=None,
    envvar="SEARXNG_URL",
    help=f"SearXNG base URL (default: {SEARXNG_DEFAULT_URL})",
)
def search(
    query: str,
    num_results: int,
    region: str,
    site: Optional[str],
    safesearch: str,
    json_output: bool,
    searxng_url: Optional[str],
) -> None:
    """Search the web via SearXNG (primary) with DuckDuckGo fallback.

    Examples:
        python search.py "Python asyncio" --num-results 5
        python search.py "async patterns" --num-results 10 --site github.com
        SEARXNG_URL=http://searxng.internal python search.py "Rust ownership"
    """
    if num_results < 1 or num_results > 50:
        click.echo("Error: num-results must be between 1 and 50", err=True)
        sys.exit(1)

    if site:
        query = f"site:{site} {query}"

    base_url = searxng_url or SEARXNG_DEFAULT_URL
    results = None
    engine_used = None

    try:
        results = _search_searxng(query, base_url, num_results, region, safesearch)
        engine_used = "SearXNG"
    except Exception as e:
        click.echo(
            f"SearXNG unavailable ({e}), falling back to DuckDuckGo...", err=True
        )

    if not results:
        try:
            results = _search_ddgs(query, num_results, region, safesearch)
            engine_used = "DuckDuckGo"
        except Exception as e:
            click.echo(f"Error during search: {e}", err=True)
            sys.exit(1)

    if not results:
        click.echo("No results found.")
        if json_output:
            click.echo(json.dumps([]))
        return

    if json_output:
        click.echo(json.dumps(results, indent=2))
        return

    click.echo(f"[{engine_used}]\n", err=True)

    if not sys.stdin.isatty():
        for i, result in enumerate(results, 1):
            title = result.get("title", "")
            url = result.get("href", "")
            excerpt = result.get("body", "")
            click.echo(f" {i}. {title}")
            click.echo(f"    {url}")
            if excerpt:
                click.echo(f"    {excerpt}")
            click.echo()
        return

    entries = [
        f"{i + 1}. {r.get('title', '') or '(no title)'}" for i, r in enumerate(results)
    ]

    def preview(entry: str) -> str:
        try:
            idx = int(entry.split(".")[0].strip()) - 1
            r = results[idx]
        except (ValueError, IndexError):
            return ""
        parts = []
        if r.get("title"):
            parts.append(r["title"])
        if r.get("href"):
            parts.append(r["href"])
        if r.get("body"):
            parts.append("")
            parts.append(r["body"])
        return "\n".join(parts)

    last_idx = 0
    while True:
        menu = TerminalMenu(
            entries,
            title="j/k or ↑/↓ to navigate, Enter to open, q/Esc to quit",
            preview_command=preview,
            preview_size=0.4,
            preview_title="Preview",
            cursor_index=last_idx,
            clear_screen=False,
        )
        idx = menu.show()
        if idx is None:
            break
        last_idx = idx
        url = results[idx].get("href", "")
        # click.echo(f"Opening: {url}", err=True)
        webbrowser.open(url)


if __name__ == "__main__":
    search()
