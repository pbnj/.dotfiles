#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = ["httpx", "rich"]
# ///
"""List issues for a package by PURL (Package URL) in a Snyk organization.

Usage:
    op run -- uv run package_issues.py --org-id ORG_ID --purl PURL [options]

Options:
    --org-id    ORG_ID  Required. Organization UUID.
    --purl      PURL    Required. Package URL (e.g. pkg:npm/lodash@4.17.21).
    --limit     N       Results per page (default 1000, max 1000).
    --json              Output raw JSON.

Examples:
    op run -- uv run package_issues.py --org-id abc123 --purl "pkg:npm/lodash@4.17.21"
    op run -- uv run package_issues.py --org-id abc123 --purl "pkg:pypi/requests@2.31.0"
    op run -- uv run package_issues.py --org-id abc123 --purl "pkg:maven/org.apache.logging.log4j/log4j-core@2.14.1"

Environment:
    SNYK_TOKEN  Snyk API token (injected via 1Password op run)
"""

import os
import sys
import argparse
import json
from urllib.parse import quote
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
}


def get_headers() -> dict:
    token = os.environ.get("SNYK_TOKEN")
    if not token:
        console.print("[red]Error:[/red] SNYK_TOKEN environment variable is not set.")
        sys.exit(1)
    return {"Authorization": f"token {token}", "Content-Type": "application/json"}


def get_package_issues(org_id: str, purl: str, limit: int) -> list[dict]:
    # PURL must be URL-encoded in the path
    encoded_purl = quote(purl, safe="")
    url = f"{BASE_URL}/orgs/{org_id}/packages/{encoded_purl}/issues"
    params = {"version": API_VERSION, "limit": min(limit, 1000)}

    issues = []
    with httpx.Client(timeout=30) as client:
        while url:
            resp = client.get(url, headers=get_headers(), params=params)
            if resp.status_code == 404:
                console.print(f"[yellow]No data found for PURL:[/yellow] {purl}")
                return []
            resp.raise_for_status()
            data = resp.json()
            issues.extend(data.get("data", []))
            next_link = data.get("links", {}).get("next")
            if next_link:
                url = next_link if next_link.startswith("http") else f"https://api.snyk.io{next_link}"
                params = {}
            else:
                url = None
    return issues


def main():
    parser = argparse.ArgumentParser(description="List issues for a package by PURL")
    parser.add_argument("--org-id", required=True, help="Organization UUID")
    parser.add_argument("--purl", required=True, help="Package URL (e.g. pkg:npm/lodash@4.17.21)")
    parser.add_argument("--limit", type=int, default=1000, help="Results per page (max 1000)")
    parser.add_argument("--json", action="store_true", dest="as_json", help="Output raw JSON")
    args = parser.parse_args()

    issues = get_package_issues(args.org_id, args.purl, args.limit)

    if args.as_json:
        print(json.dumps(issues, indent=2))
        return

    if not issues:
        console.print("[yellow]No issues found for this package.[/yellow]")
        return

    table = Table(title=f"Issues for {args.purl} ({len(issues)} total)", show_lines=False)
    table.add_column("ID", style="dim", no_wrap=True, max_width=36)
    table.add_column("Title", max_width=60)
    table.add_column("Type")
    table.add_column("Severity")
    table.add_column("CVE / CWE", max_width=20)
    table.add_column("CVSS Score")

    for issue in issues:
        attrs = issue.get("attributes", {})
        sev = attrs.get("effective_severity_level", attrs.get("severity", ""))
        color = SEVERITY_COLORS.get(sev, "white")

        # Extract CVE / CWE identifiers
        identifiers = attrs.get("identifiers", [])
        cve_list = [i.get("name", "") for i in identifiers if i.get("type") == "CVE"]
        cwe_list = [i.get("name", "") for i in identifiers if i.get("type") == "CWE"]
        id_str = ", ".join(cve_list or cwe_list)[:20]

        # CVSS score
        slots = attrs.get("slots", {})
        cvss_score = str(slots.get("cvss_score", attrs.get("cvss_score", "")))

        table.add_row(
            issue.get("id", ""),
            attrs.get("title", ""),
            attrs.get("type", ""),
            f"[{color}]{sev}[/{color}]",
            id_str,
            cvss_score,
        )

    console.print(table)


if __name__ == "__main__":
    main()
