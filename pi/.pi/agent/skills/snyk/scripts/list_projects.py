#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = ["httpx", "rich"]
# ///
"""List projects for a Snyk organization.

Usage:
    op run -- uv run list_projects.py --org-id ORG_ID [options]

Options:
    --org-id          ORG_ID     Required. Organization UUID.
    --origin          ORIGIN     Filter by origin (e.g. github, cli, bitbucket-cloud)
    --type            TYPE       Filter by project type (e.g. npm, pip, maven)
    --target-id       ID         Filter by target ID (repeatable)
    --name            NAME       Filter by name (substring)
    --tag             KEY=VALUE  Filter by tag (repeatable)
    --lifecycle       VALUE      Filter by lifecycle (development|production|sandbox)
    --environment     VALUE      Filter by environment
    --criticality     VALUE      Filter by business criticality
    --with-counts                Include latest issue counts in output
    --limit           N          Results per page (default 100)
    --json                       Output raw JSON

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


def list_projects(org_id: str, args) -> list[dict]:
    params: dict = {"version": API_VERSION, "limit": args.limit}
    if args.origin:
        params["origins"] = args.origin
    if args.type:
        params["types"] = args.type
    if args.target_id:
        params["target_id"] = args.target_id
    if args.name:
        params["names"] = args.name
    if args.tag:
        # CLI accepts KEY=VALUE; Snyk REST API expects KEY:VALUE
        params["tags"] = [t.replace("=", ":", 1) for t in args.tag]
    if args.lifecycle:
        params["lifecycle"] = args.lifecycle
    if args.environment:
        params["environment"] = args.environment
    if args.criticality:
        params["business_criticality"] = args.criticality
    if args.with_counts:
        params["meta.latest_issue_counts"] = "true"

    projects = []
    url = f"{BASE_URL}/orgs/{org_id}/projects"
    first_page = True
    with httpx.Client(timeout=30) as client:
        while url:
            # Pagination next_links already contain all query params in the URL;
            # passing params= to httpx replaces the query string, so only send
            # params on the first request.
            resp = client.get(url, headers=get_headers(), params=params if first_page else None)
            if not resp.is_success:
                try:
                    detail = resp.json()
                except Exception:
                    detail = resp.text
                console.print(f"[red]HTTP {resp.status_code}[/red] {resp.request.url}")
                console.print(f"[red]Response:[/red] {detail}")
                resp.raise_for_status()
            first_page = False
            data = resp.json()
            projects.extend(data.get("data", []))
            next_link = data.get("links", {}).get("next")
            if next_link:
                url = (
                    next_link
                    if next_link.startswith("http")
                    else f"https://api.snyk.io{next_link}"
                )
            else:
                url = None
    return projects


def main():
    parser = argparse.ArgumentParser(
        description="List Snyk projects for an organization"
    )
    parser.add_argument(
        "--org-id",
        default=os.environ.get("SNYK_ORG"),
        help="Organization UUID (defaults to SNYK_ORG env var)",
    )
    parser.add_argument(
        "--origin", action="append", help="Filter by origin (repeatable)"
    )
    parser.add_argument(
        "--type", action="append", help="Filter by project type (repeatable)"
    )
    parser.add_argument(
        "--target-id", action="append", help="Filter by target ID (repeatable)"
    )
    parser.add_argument("--name", help="Filter by name (substring)")
    parser.add_argument(
        "--tag", action="append", help="Filter by tag KEY=VALUE (repeatable)"
    )
    parser.add_argument("--lifecycle", action="append", help="Filter by lifecycle")
    parser.add_argument("--environment", action="append", help="Filter by environment")
    parser.add_argument(
        "--criticality", action="append", help="Filter by business criticality"
    )
    parser.add_argument(
        "--with-counts", action="store_true", help="Include latest issue counts"
    )
    parser.add_argument(
        "--limit", type=int, default=100, help="Results per page (default 100)"
    )
    parser.add_argument(
        "--json", action="store_true", dest="as_json", help="Output raw JSON"
    )
    args = parser.parse_args()

    if not args.org_id:
        parser.error("--org-id is required (or set the SNYK_ORG environment variable)")

    args.org_id = args.org_id.strip()

    projects = list_projects(args.org_id, args)

    if args.as_json:
        print(json.dumps(projects, indent=2))
        return

    if not projects:
        console.print("[yellow]No projects found.[/yellow]")
        return

    table = Table(
        title=f"Snyk Projects for org {args.org_id} ({len(projects)} total)",
        show_lines=False,
    )
    table.add_column("ID", style="dim", no_wrap=True, max_width=36)
    table.add_column("Name", style="bold", max_width=50)
    table.add_column("Type")
    table.add_column("Origin")
    table.add_column("Status")
    if args.with_counts:
        table.add_column("Critical", style="red")
        table.add_column("High", style="orange3")
        table.add_column("Medium", style="yellow")
        table.add_column("Low", style="green")

    for p in projects:
        attrs = p.get("attributes", {})
        row = [
            p.get("id", ""),
            attrs.get("name", ""),
            attrs.get("type", ""),
            attrs.get("origin", ""),
            attrs.get("status", ""),
        ]
        if args.with_counts:
            counts = p.get("meta", {}).get("latest_issue_counts", {})
            row += [
                str(counts.get("critical", 0)),
                str(counts.get("high", 0)),
                str(counts.get("medium", 0)),
                str(counts.get("low", 0)),
            ]
        table.add_row(*row)

    console.print(table)


if __name__ == "__main__":
    main()
