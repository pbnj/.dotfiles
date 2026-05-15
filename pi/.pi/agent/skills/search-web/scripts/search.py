#!/usr/bin/env -S uv run --script

# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "click",
#   "crawl4ai",
#   "ddgs",
#   "requests",
# ]
# ///

import asyncio
import sys
import json
import click
import requests
from typing import Optional
from ddgs import DDGS
from crawl4ai import AsyncWebCrawler, CrawlerRunConfig
from crawl4ai.async_configs import CacheMode

SEARXNG_DEFAULT_URL = "http://localhost:8888"


async def _fetch_contents(urls: list[str]) -> dict[str, str]:
    """Fetch page content for a list of URLs using crawl4ai.

    Returns a mapping of URL -> markdown content (empty string on failure).
    """
    config = CrawlerRunConfig(cache_mode=CacheMode.BYPASS)
    async with AsyncWebCrawler() as crawler:
        results = await crawler.arun_many(urls=urls, config=config)
    return {r.url: (r.markdown or "") if r.success else "" for r in results}


def _search_searxng(
    query: str, base_url: str, num: int, region: str, safesearch: str, page: int = 1
) -> list[dict]:
    safesearch_map = {"off": 0, "moderate": 1, "strict": 2}
    params = {
        "q": query,
        "format": "json",
        "language": region,
        "safesearch": safesearch_map.get(safesearch, 1),
        "pageno": page,
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
        for r in data.get("results", [])[:num]
    ]


def _search_ddgs(
    query: str, num: int, region: str, safesearch: str, page: int = 1
) -> list[dict]:
    return list(
        DDGS().text(
            query,
            region=region,
            safesearch=safesearch,
            max_results=num,
            offset=(page - 1) * num,
        )
    )


def _render_markdown(results: list[dict]) -> str:
    parts = []
    for i, r in enumerate(results, 1):
        title = r.get("title") or "(no title)"
        href = r.get("href", "")
        body = r.get("body", "")
        content = r.get("content", "")

        parts.append(f"## {i}. [{title}]({href})")
        if body:
            parts.append(f"{body}")
        if content:
            parts.append("")
            parts.append(content.strip())
        parts.append("")
    return "\n".join(parts).rstrip()


@click.command()
@click.argument("query")
@click.option("--num", type=int, default=10, help="Number of results to return (1-50)")
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
    "--searxng-url",
    default=None,
    envvar="SEARXNG_URL",
    help=f"SearXNG base URL (default: {SEARXNG_DEFAULT_URL})",
)
@click.option("--page", type=int, default=1, help="Page number (1-indexed)")
@click.option(
    "--fetch",
    "fetch_content",
    is_flag=True,
    default=False,
    help="Fetch full page content for each result using crawl4ai.",
)
@click.option(
    "--output",
    type=click.Choice(["json", "markdown"]),
    default="json",
    help="Output format: json (default) or markdown.",
)
def search(
    query: str,
    num: int,
    region: str,
    site: Optional[str],
    safesearch: str,
    searxng_url: Optional[str],
    page: int,
    fetch_content: bool,
    output: str,
) -> None:
    """Search the web via SearXNG (primary) with DuckDuckGo fallback.

    Output is JSON by default.

    Examples:
        python search.py "Python asyncio" --num 5
        python search.py "async patterns" --num 10 --site github.com
        SEARXNG_URL=http://searxng.internal python search.py "Rust ownership"
        python search.py "crawl4ai quickstart" --fetch
        python search.py "Rust lifetimes" --output markdown
        python search.py "Rust lifetimes" --fetch --output markdown
    """
    if num < 1 or num > 50:
        click.echo("Error: num must be between 1 and 50", err=True)
        sys.exit(1)

    if site:
        query = f"site:{site} {query}"

    base_url = searxng_url or SEARXNG_DEFAULT_URL
    results = None

    if page < 1:
        click.echo("Error: page must be >= 1", err=True)
        sys.exit(1)

    try:
        results = _search_searxng(query, base_url, num, region, safesearch, page)
        click.echo("engine: SearXNG", err=True)
    except Exception as e:
        click.echo(
            f"SearXNG unavailable ({e}), falling back to DuckDuckGo...", err=True
        )

    if not results:
        try:
            results = _search_ddgs(query, num, region, safesearch, page)
            click.echo("engine: DuckDuckGo", err=True)
        except Exception as e:
            click.echo(f"Error during search: {e}", err=True)
            sys.exit(1)

    if not results:
        click.echo(json.dumps([]) if output == "json" else "No results found.")
        return

    if fetch_content:
        click.echo("Fetching page content...", err=True)
        urls = [r["href"] for r in results if r.get("href")]
        content_map = asyncio.run(_fetch_contents(urls))
        for r in results:
            r["content"] = content_map.get(r.get("href", ""), "")

    if output == "markdown":
        click.echo(_render_markdown(results))
    else:
        click.echo(json.dumps(results, indent=2))


if __name__ == "__main__":
    search()
