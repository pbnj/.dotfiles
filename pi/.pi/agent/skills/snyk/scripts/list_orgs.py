#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = ["httpx", "rich"]
# ///
"""List accessible Snyk organizations.

Usage:
    op run -- uv run list_orgs.py [--group-id GROUP_ID] [--name NAME] [--slug SLUG] [--json]

Environment:
    SNYK_TOKEN  Snyk API token (injected via 1Password op run)
"""

import os
import sys
import argparse
import json
import httpx
from rich.console import Console
from rich.table import Table

BASE_URL = "https://api.snyk.io/rest"
API_VERSION = "2025-11-05"
console = Console()


def get_headers() -> dict:
    token = os.environ.get("SNYK_TOKEN")
    if not token:
        console.print("[red]Error:[/red] SNYK_TOKEN environment variable is not set.")
        sys.exit(1)
    return {"Authorization": f"token {token}", "Content-Type": "application/json"}


def list_orgs(group_id: str | None, name: str | None, slug: str | None) -> list[dict]:
    params: dict = {"version": API_VERSION, "limit": 100}
    if group_id:
        params["group_id"] = group_id
    if name:
        params["name"] = name
    if slug:
        params["slug"] = slug

    orgs = []
    url = f"{BASE_URL}/orgs"
    with httpx.Client(timeout=30) as client:
        while url:
            resp = client.get(url, headers=get_headers(), params=params)
            resp.raise_for_status()
            data = resp.json()
            orgs.extend(data.get("data", []))
            # Pagination: follow next link
            next_link = data.get("links", {}).get("next")
            if next_link:
                # next link may be relative or absolute
                url = next_link if next_link.startswith("http") else f"https://api.snyk.io{next_link}"
                params = {}  # params are already encoded in the next link
            else:
                url = None
    return orgs


def main():
    parser = argparse.ArgumentParser(description="List accessible Snyk organizations")
    parser.add_argument("--group-id", help="Filter by group ID")
    parser.add_argument("--name", help="Filter orgs whose name contains this value")
    parser.add_argument("--slug", help="Filter orgs whose slug exactly matches")
    parser.add_argument("--json", action="store_true", dest="as_json", help="Output raw JSON")
    args = parser.parse_args()

    orgs = list_orgs(args.group_id, args.name, args.slug)

    if args.as_json:
        print(json.dumps(orgs, indent=2))
        return

    if not orgs:
        console.print("[yellow]No organizations found.[/yellow]")
        return

    table = Table(title=f"Snyk Organizations ({len(orgs)} total)", show_lines=False)
    table.add_column("ID", style="dim", no_wrap=True)
    table.add_column("Name", style="bold")
    table.add_column("Slug")
    table.add_column("Group ID", style="dim")

    for org in orgs:
        attrs = org.get("attributes", {})
        rel_group = org.get("relationships", {}).get("group", {}).get("data", {})
        table.add_row(
            org.get("id", ""),
            attrs.get("name", ""),
            attrs.get("slug", ""),
            rel_group.get("id", "") if rel_group else "",
        )

    console.print(table)


if __name__ == "__main__":
    main()
