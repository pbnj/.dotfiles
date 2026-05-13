#!/usr/bin/env -S uv run --script

# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "click",
#   "requests",
# ]
# ///

import os
import sys
import click
import requests
from typing import Optional

GLEAN_BACKEND_URL = os.environ.get("GLEAN_BACKEND_URL")


def _search_glean(
    query: str,
    backend_url: str,
    api_token: str,
    num_results: int,
    datasource: Optional[str],
) -> list[dict]:
    url = f"{backend_url.rstrip('/')}/rest/api/v1/search"
    headers = {
        "Authorization": f"Bearer {api_token}",
        "Content-Type": "application/json",
    }
    payload: dict = {"query": query, "pageSize": num_results}
    if datasource:
        payload["requestOptions"] = {"datasourceFilter": datasource}

    resp = requests.post(url, headers=headers, json=payload, timeout=10)
    resp.raise_for_status()
    return resp.json().get("results", [])


def _format_results(results: list[dict]) -> None:
    for i, result in enumerate(results, 1):
        doc = result.get("document", {})
        title = doc.get("title", "")
        url = doc.get("url", "")
        datasource = doc.get("datasource", "")
        doc_type = doc.get("docType", "")

        label_parts = [p for p in [datasource, doc_type] if p]
        label = f"[{' · '.join(label_parts)}]" if label_parts else ""

        snippets = result.get("snippets", [])
        excerpt = ""
        if snippets:
            snippet = snippets[0]
            # Handle both string and dict formats
            if isinstance(snippet, str):
                raw = snippet
            elif isinstance(snippet, dict):
                # Try to extract text from nested structure
                if "snippet" in snippet:
                    snippet_obj = snippet.get("snippet", {})
                    if isinstance(snippet_obj, dict):
                        raw = snippet_obj.get("text", "")
                    else:
                        raw = str(snippet_obj)
                else:
                    raw = str(snippet)
            else:
                raw = str(snippet)
            excerpt = " ".join(raw.split())[:200]

        click.echo(f" {i}. {title} {label}")
        click.echo(f"    {url}")
        if excerpt:
            click.echo(f"    {excerpt}")
        click.echo()


@click.command()
@click.option("--query", required=True, help="Search query")
@click.option(
    "--num-results", type=int, default=10, help="Number of results to return (1-50)"
)
@click.option(
    "--datasource",
    default=None,
    help="Filter by datasource (e.g. github, confluence, jira, gdrive, slack)",
)
@click.option(
    "--backend-url",
    default=None,
    envvar="GLEAN_BACKEND_URL",
    help=f"Glean backend URL (default: {GLEAN_BACKEND_URL})",
)
@click.option(
    "--api-token",
    default=None,
    envvar="GLEAN_API_TOKEN",
    help="Glean API token (also: $GLEAN_API_TOKEN)",
)
def search(
    query: str,
    num_results: int,
    datasource: Optional[str],
    backend_url: Optional[str],
    api_token: Optional[str],
) -> None:
    """Search internal knowledge via the Glean REST API.

    Requires $GLEAN_API_TOKEN to be set (or passed via --api-token).

    Examples:
        search.py --query "incident response runbook"
        search.py --query "onboarding" --datasource confluence
        search.py --query "deploy pipeline" --datasource github --num-results 5
        GLEAN_API_TOKEN=xxx search.py --query "data model"
    """
    if num_results < 1 or num_results > 50:
        click.echo("Error: num-results must be between 1 and 50", err=True)
        sys.exit(1)

    token = api_token or os.environ.get("GLEAN_API_TOKEN")
    if not token:
        click.echo(
            "Error: Glean API token required. Set $GLEAN_API_TOKEN or use --api-token.",
            err=True,
        )
        sys.exit(1)

    base = backend_url or GLEAN_BACKEND_URL

    try:
        results = _search_glean(query, base, token, num_results, datasource)
    except requests.HTTPError as e:
        click.echo(f"Glean API error: {e}", err=True)
        sys.exit(1)
    except requests.ConnectionError:
        click.echo(f"Could not connect to Glean at {base}", err=True)
        sys.exit(1)
    except Exception as e:
        click.echo(f"Error: {e}", err=True)
        sys.exit(1)

    if not results:
        click.echo("No results found.")
        return

    _format_results(results)


if __name__ == "__main__":
    search()
