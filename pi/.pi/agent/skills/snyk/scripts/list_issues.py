#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = ["httpx", "rich"]
# ///
"""List and filter Snyk issues at org or group scope.

Usage:
    op run -- uv run list_issues.py --org-id ORG_ID [options]
    op run -- uv run list_issues.py --group-id GROUP_ID [options]

Options:
    --org-id          ORG_ID        Issues scoped to an organization.
    --group-id        GROUP_ID      Issues scoped to a group.
    --type            TYPE          Issue type: package_vulnerability, license, cloud, code, custom, config
    --severity        LEVEL         Effective severity: critical, high, medium, low (repeatable)
    --status          STATUS        Issue status (repeatable)
    --ignored                       Include only ignored issues
    --not-ignored                   Include only non-ignored issues
    --scan-item-id    ID            Filter by scan item (project/environment) ID
    --scan-item-type  TYPE          project or environment
    --created-after   DATE          RFC3339 date e.g. 2024-01-01
    --created-before  DATE          RFC3339 date
    --updated-after   DATE          RFC3339 date
    --updated-before  DATE          RFC3339 date
    --limit           N             Results per page (default 100, max 100)
    --max-results     N             Stop after N total results (default: all)
    --json                          Output raw JSON

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

SEVERITY_COLORS = {
    "critical": "red",
    "high": "orange3",
    "medium": "yellow",
    "low": "green",
    "info": "blue",
}


def get_headers() -> dict:
    token = os.environ.get("SNYK_TOKEN")
    if not token:
        console.print("[red]Error:[/red] SNYK_TOKEN environment variable is not set.")
        sys.exit(1)
    return {"Authorization": f"token {token}", "Content-Type": "application/json"}


def list_issues(args) -> list[dict]:
    if args.org_id:
        endpoint = f"{BASE_URL}/orgs/{args.org_id}/issues"
    elif args.group_id:
        endpoint = f"{BASE_URL}/groups/{args.group_id}/issues"
    else:
        console.print("[red]Error:[/red] Either --org-id or --group-id is required.")
        sys.exit(1)

    params: dict = {"version": API_VERSION, "limit": min(args.limit, 100)}
    if args.type:
        params["type"] = args.type
    if args.severity:
        params["effective_severity_level"] = args.severity
    if args.status:
        params["status"] = args.status
    if args.ignored is not None:
        params["ignored"] = str(args.ignored).lower()
    if args.scan_item_id:
        params["scan_item.id"] = args.scan_item_id
    if args.scan_item_type:
        params["scan_item.type"] = args.scan_item_type
    if args.created_after:
        params["created_after"] = args.created_after
    if args.created_before:
        params["created_before"] = args.created_before
    if args.updated_after:
        params["updated_after"] = args.updated_after
    if args.updated_before:
        params["updated_before"] = args.updated_before

    issues = []
    url = endpoint
    with httpx.Client(timeout=30) as client:
        while url:
            resp = client.get(url, headers=get_headers(), params=params)
            resp.raise_for_status()
            data = resp.json()
            batch = data.get("data", [])
            issues.extend(batch)

            if args.max_results and len(issues) >= args.max_results:
                issues = issues[:args.max_results]
                break

            next_link = data.get("links", {}).get("next")
            if next_link:
                url = next_link if next_link.startswith("http") else f"https://api.snyk.io{next_link}"
                params = {}
            else:
                url = None
    return issues


def main():
    parser = argparse.ArgumentParser(description="List Snyk issues at org or group scope")
    scope = parser.add_mutually_exclusive_group()
    scope.add_argument("--org-id", help="Organization UUID")
    scope.add_argument("--group-id", help="Group UUID")
    parser.add_argument(
        "--type",
        choices=["package_vulnerability", "license", "cloud", "code", "custom", "config"],
        help="Filter by issue type",
    )
    parser.add_argument(
        "--severity",
        action="append",
        choices=["critical", "high", "medium", "low", "info"],
        help="Filter by effective severity level (repeatable)",
    )
    parser.add_argument("--status", action="append", help="Filter by status (repeatable)")
    ignored_group = parser.add_mutually_exclusive_group()
    ignored_group.add_argument("--ignored", dest="ignored", action="store_true", default=None, help="Only ignored issues")
    ignored_group.add_argument("--not-ignored", dest="ignored", action="store_false", help="Only non-ignored issues")
    parser.add_argument("--scan-item-id", help="Filter by scan item ID")
    parser.add_argument("--scan-item-type", choices=["project", "environment"], help="Scan item type")
    parser.add_argument("--created-after", help="RFC3339 date")
    parser.add_argument("--created-before", help="RFC3339 date")
    parser.add_argument("--updated-after", help="RFC3339 date")
    parser.add_argument("--updated-before", help="RFC3339 date")
    parser.add_argument("--limit", type=int, default=100, help="Results per page (max 100)")
    parser.add_argument("--max-results", type=int, help="Stop after N total results")
    parser.add_argument("--json", action="store_true", dest="as_json", help="Output raw JSON")
    args = parser.parse_args()

    if not args.org_id and not args.group_id:
        parser.error("Either --org-id or --group-id is required.")

    issues = list_issues(args)

    if args.as_json:
        print(json.dumps(issues, indent=2))
        return

    if not issues:
        console.print("[yellow]No issues found.[/yellow]")
        return

    scope_label = f"org {args.org_id}" if args.org_id else f"group {args.group_id}"
    table = Table(title=f"Snyk Issues for {scope_label} ({len(issues)} results)", show_lines=False)
    table.add_column("ID", style="dim", no_wrap=True, max_width=36)
    table.add_column("Title", max_width=60)
    table.add_column("Type")
    table.add_column("Severity")
    table.add_column("Status")
    table.add_column("Ignored")

    for issue in issues:
        attrs = issue.get("attributes", {})
        sev = attrs.get("effective_severity_level", attrs.get("severity", ""))
        color = SEVERITY_COLORS.get(sev, "white")
        table.add_row(
            issue.get("id", ""),
            attrs.get("title", attrs.get("name", "")),
            attrs.get("type", ""),
            f"[{color}]{sev}[/{color}]",
            attrs.get("status", ""),
            str(attrs.get("ignored", False)),
        )

    console.print(table)
    console.print(f"\n[dim]Total: {len(issues)} issues[/dim]")


if __name__ == "__main__":
    main()
