#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = ["httpx", "rich"]
# ///
"""Get current Snyk user details and personal access tokens.

Usage:
    op run -- uv run whoami.py [--tokens] [--json]

Options:
    --tokens    Also list personal access tokens.
    --json      Output raw JSON.

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


def main():
    parser = argparse.ArgumentParser(description="Get current Snyk user details")
    parser.add_argument(
        "--tokens", action="store_true", help="Also list personal access tokens"
    )
    parser.add_argument(
        "--json", action="store_true", dest="as_json", help="Output raw JSON"
    )
    args = parser.parse_args()

    params = {"version": API_VERSION}
    with httpx.Client(timeout=30) as client:
        resp = client.get(f"{BASE_URL}/self", headers=get_headers(), params=params)
        resp.raise_for_status()
        user_data = resp.json()

        pat_data = None
        if args.tokens:
            resp2 = client.get(
                f"{BASE_URL}/self/personal_access_tokens",
                headers=get_headers(),
                params=params,
            )
            resp2.raise_for_status()
            pat_data = resp2.json()

    if args.as_json:
        output = {"user": user_data}
        if pat_data:
            output["personal_access_tokens"] = pat_data
        print(json.dumps(output, indent=2))
        return

    user = user_data.get("data", user_data)
    attrs = user.get("attributes", {})
    console.print(f"[bold]ID:[/bold]       {user.get('id', '')}")
    console.print(f"[bold]Name:[/bold]     {attrs.get('name', '')}")
    console.print(f"[bold]Email:[/bold]    {attrs.get('email', '')}")
    console.print(f"[bold]Username:[/bold] {attrs.get('username', '')}")
    console.print(f"[bold]Avatar:[/bold]   {attrs.get('avatar_url', '')}")

    if pat_data:
        tokens = pat_data.get("data", [])
        if tokens:
            console.print()
            table = Table(title=f"Personal Access Tokens ({len(tokens)} total)")
            table.add_column("ID", style="dim", no_wrap=True)
            table.add_column("Name", style="bold")
            table.add_column("Created At", no_wrap=True)
            table.add_column("Expires At", no_wrap=True)
            for tok in tokens:
                tattrs = tok.get("attributes", {})
                table.add_row(
                    tok.get("id", ""),
                    tattrs.get("name", ""),
                    str(tattrs.get("created_at", ""))[:10],
                    str(tattrs.get("expires_at", ""))[:10],
                )
            console.print(table)
        else:
            console.print("\n[yellow]No personal access tokens found.[/yellow]")


if __name__ == "__main__":
    main()
