#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = ["httpx", "rich"]
# ///
"""Search Snyk audit logs at org or group scope.

Usage:
    op run -- uv run audit_logs.py --org-id ORG_ID [options]
    op run -- uv run audit_logs.py --group-id GROUP_ID [options]

Options:
    --org-id        ORG_ID      Search org audit logs.
    --group-id      GROUP_ID    Search group audit logs.
    --from          DATE        Start date (RFC3339, e.g. 2024-01-01T00:00:00Z). Defaults to yesterday.
    --to            DATE        End date (exclusive, RFC3339).
    --user-id       USER_ID     Filter by user ID.
    --project-id    PROJECT_ID  Filter by project ID.
    --event         EVENT       Filter by event type (repeatable).
    --exclude-event EVENT       Exclude event type (repeatable, mutually exclusive with --event).
    --sort-order    ORDER       ASC or DESC (default DESC).
    --size          N           Results per page (default 100, max 100).
    --max-results   N           Stop after N total results.
    --json                      Output raw JSON.

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


def search_audit_logs(args) -> list[dict]:
    if args.org_id:
        endpoint = f"{BASE_URL}/orgs/{args.org_id}/audit_logs/search"
    elif args.group_id:
        endpoint = f"{BASE_URL}/groups/{args.group_id}/audit_logs/search"
    else:
        console.print("[red]Error:[/red] Either --org-id or --group-id is required.")
        sys.exit(1)

    params: dict = {"version": API_VERSION, "size": min(args.size, 100)}
    if args.from_date:
        params["from"] = args.from_date
    if args.to_date:
        params["to"] = args.to_date
    if args.user_id:
        params["user_id"] = args.user_id
    if args.project_id:
        params["project_id"] = args.project_id
    if args.event:
        params["events"] = args.event
    if args.exclude_event:
        params["exclude_events"] = args.exclude_event
    if args.sort_order:
        params["sort_order"] = args.sort_order

    logs = []
    url = endpoint
    with httpx.Client(timeout=30) as client:
        while url:
            resp = client.get(url, headers=get_headers(), params=params)
            resp.raise_for_status()
            data = resp.json()
            batch = data.get("items", data.get("data", []))
            logs.extend(batch)

            if args.max_results and len(logs) >= args.max_results:
                logs = logs[: args.max_results]
                break

            # Pagination via cursor
            next_cursor = data.get("links", {}).get("next")
            if next_cursor:
                url = (
                    next_cursor
                    if next_cursor.startswith("http")
                    else f"https://api.snyk.io{next_cursor}"
                )
                params = {}
            else:
                url = None
    return logs


def main():
    parser = argparse.ArgumentParser(description="Search Snyk audit logs")
    scope = parser.add_mutually_exclusive_group()
    scope.add_argument("--org-id", help="Organization UUID")
    scope.add_argument("--group-id", help="Group UUID")
    parser.add_argument(
        "--from",
        dest="from_date",
        help="Start date (RFC3339, e.g. 2024-01-01T00:00:00Z)",
    )
    parser.add_argument("--to", dest="to_date", help="End date exclusive (RFC3339)")
    parser.add_argument("--user-id", help="Filter by user ID")
    parser.add_argument("--project-id", help="Filter by project ID")
    parser.add_argument(
        "--event", action="append", help="Filter by event type (repeatable)"
    )
    parser.add_argument(
        "--exclude-event", action="append", help="Exclude event type (repeatable)"
    )
    parser.add_argument(
        "--sort-order",
        choices=["ASC", "DESC"],
        default="DESC",
        help="Sort order (default DESC)",
    )
    parser.add_argument(
        "--size", type=int, default=100, help="Results per page (max 100)"
    )
    parser.add_argument("--max-results", type=int, help="Stop after N total results")
    parser.add_argument(
        "--json", action="store_true", dest="as_json", help="Output raw JSON"
    )
    args = parser.parse_args()

    if not args.org_id and not args.group_id:
        parser.error("Either --org-id or --group-id is required.")

    logs = search_audit_logs(args)

    if args.as_json:
        print(json.dumps(logs, indent=2))
        return

    if not logs:
        console.print("[yellow]No audit log entries found.[/yellow]")
        return

    scope_label = f"org {args.org_id}" if args.org_id else f"group {args.group_id}"
    table = Table(
        title=f"Audit Logs for {scope_label} ({len(logs)} entries)", show_lines=False
    )
    table.add_column("Created At", no_wrap=True)
    table.add_column("Event", style="bold")
    table.add_column("User ID", style="dim", max_width=36)
    table.add_column("Project ID", style="dim", max_width=36)
    table.add_column("Content", max_width=60)

    for entry in logs:
        # Audit log entries vary in shape; handle both top-level and nested attributes
        created = entry.get("created", entry.get("attributes", {}).get("created", ""))
        event = entry.get("event", entry.get("attributes", {}).get("event", ""))
        user_id = entry.get("user_id", entry.get("attributes", {}).get("user_id", ""))
        project_id = entry.get(
            "project_id", entry.get("attributes", {}).get("project_id", "")
        )
        content = entry.get("content", entry.get("attributes", {}).get("content", {}))
        content_str = json.dumps(content, separators=(",", ":"))[:80] if content else ""
        table.add_row(
            str(created)[:19],
            str(event),
            str(user_id)[:36],
            str(project_id)[:36],
            content_str,
        )

    console.print(table)


if __name__ == "__main__":
    main()
