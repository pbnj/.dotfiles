#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = ["httpx", "rich"]
# ///
"""List targets for a Snyk organization.

Usage:
    op run -- uv run list_targets.py --org-id ORG_ID [options]

Options:
    --org-id          ORG_ID       Required. Organization UUID.
    --url             URL          Filter by remote URL.
    --display-name    NAME         Filter targets whose display name starts with this prefix.
    --source-type     TYPE         Filter by source type (repeatable).
    --exclude-empty               Only return targets that have projects.
    --is-private                  Filter to private targets only.
    --limit           N            Results per page (default 100).
    --json                         Output raw JSON.

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


def list_targets(org_id: str, args) -> list[dict]:
    params: dict = {"version": API_VERSION, "limit": args.limit}
    if args.url:
        params["url"] = args.url
    if args.display_name:
        params["display_name"] = args.display_name
    if args.source_type:
        params["source_types"] = args.source_type
    if args.exclude_empty:
        params["exclude_empty"] = "true"
    if args.is_private:
        params["is_private"] = "true"

    targets = []
    url = f"{BASE_URL}/orgs/{org_id}/targets"
    with httpx.Client(timeout=30) as client:
        while url:
            resp = client.get(url, headers=get_headers(), params=params)
            resp.raise_for_status()
            data = resp.json()
            targets.extend(data.get("data", []))
            next_link = data.get("links", {}).get("next")
            if next_link:
                url = next_link if next_link.startswith("http") else f"https://api.snyk.io{next_link}"
                params = {}
            else:
                url = None
    return targets


def main():
    parser = argparse.ArgumentParser(description="List Snyk targets for an organization")
    parser.add_argument("--org-id", required=True, help="Organization UUID")
    parser.add_argument("--url", help="Filter by remote URL")
    parser.add_argument("--display-name", help="Filter by display name prefix")
    parser.add_argument("--source-type", action="append", help="Filter by source type (repeatable)")
    parser.add_argument("--exclude-empty", action="store_true", help="Only return targets with projects")
    parser.add_argument("--is-private", action="store_true", help="Only return private targets")
    parser.add_argument("--limit", type=int, default=100, help="Results per page (default 100)")
    parser.add_argument("--json", action="store_true", dest="as_json", help="Output raw JSON")
    args = parser.parse_args()

    targets = list_targets(args.org_id, args)

    if args.as_json:
        print(json.dumps(targets, indent=2))
        return

    if not targets:
        console.print("[yellow]No targets found.[/yellow]")
        return

    table = Table(title=f"Snyk Targets for org {args.org_id} ({len(targets)} total)", show_lines=False)
    table.add_column("ID", style="dim", no_wrap=True, max_width=36)
    table.add_column("Display Name", style="bold", max_width=50)
    table.add_column("URL", max_width=60)
    table.add_column("Source Type")
    table.add_column("Private")
    table.add_column("Created At", no_wrap=True)

    for t in targets:
        attrs = t.get("attributes", {})
        table.add_row(
            t.get("id", ""),
            attrs.get("display_name", ""),
            attrs.get("url", attrs.get("remote_url", ""))[:60],
            attrs.get("source_type", ""),
            str(attrs.get("is_private", "")),
            str(attrs.get("created_at", ""))[:10],
        )

    console.print(table)


if __name__ == "__main__":
    main()
