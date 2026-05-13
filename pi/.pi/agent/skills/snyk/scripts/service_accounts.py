#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = ["httpx", "rich"]
# ///
"""Manage Snyk service accounts at org or group scope.

Subcommands:
    list      List service accounts
    get       Get a specific service account
    create    Create a new service account
    delete    Delete a service account
    rotate    Rotate a service account's client secret

Usage:
    op run -- uv run service_accounts.py list --org-id ORG_ID [--json]
    op run -- uv run service_accounts.py list --group-id GROUP_ID [--json]
    op run -- uv run service_accounts.py get --org-id ORG_ID --sa-id SA_ID [--json]
    op run -- uv run service_accounts.py create --org-id ORG_ID --name NAME --role-id ROLE_ID [--auth-type TYPE] [--json]
    op run -- uv run service_accounts.py delete --org-id ORG_ID --sa-id SA_ID
    op run -- uv run service_accounts.py rotate --org-id ORG_ID --sa-id SA_ID [--json]

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
    return {"Authorization": f"token {token}", "Content-Type": "application/vnd.api+json"}


def build_base_url(org_id: str | None, group_id: str | None) -> str:
    if org_id:
        return f"{BASE_URL}/orgs/{org_id}/service_accounts"
    return f"{BASE_URL}/groups/{group_id}/service_accounts"


def cmd_list(args):
    url = build_base_url(args.org_id, args.group_id)
    params = {"version": API_VERSION, "limit": 100}
    accounts = []
    with httpx.Client(timeout=30) as client:
        while url:
            resp = client.get(url, headers=get_headers(), params=params)
            resp.raise_for_status()
            data = resp.json()
            accounts.extend(data.get("data", []))
            next_link = data.get("links", {}).get("next")
            if next_link:
                url = next_link if next_link.startswith("http") else f"https://api.snyk.io{next_link}"
                params = {}
            else:
                url = None

    if args.as_json:
        print(json.dumps(accounts, indent=2))
        return

    if not accounts:
        console.print("[yellow]No service accounts found.[/yellow]")
        return

    scope = f"org {args.org_id}" if args.org_id else f"group {args.group_id}"
    table = Table(title=f"Service Accounts for {scope} ({len(accounts)} total)")
    table.add_column("ID", style="dim", no_wrap=True)
    table.add_column("Name", style="bold")
    table.add_column("Auth Type")
    table.add_column("Role ID", style="dim")
    for sa in accounts:
        attrs = sa.get("attributes", {})
        role = sa.get("relationships", {}).get("role", {}).get("data", {})
        table.add_row(
            sa.get("id", ""),
            attrs.get("name", ""),
            attrs.get("auth_type", ""),
            role.get("id", ""),
        )
    console.print(table)


def cmd_get(args):
    url = f"{build_base_url(args.org_id, args.group_id)}/{args.sa_id}"
    params = {"version": API_VERSION}
    with httpx.Client(timeout=30) as client:
        resp = client.get(url, headers=get_headers(), params=params)
        resp.raise_for_status()
        data = resp.json()

    if args.as_json:
        print(json.dumps(data, indent=2))
        return

    sa = data.get("data", data)
    attrs = sa.get("attributes", {})
    console.print(f"[bold]ID:[/bold]        {sa.get('id', '')}")
    console.print(f"[bold]Name:[/bold]      {attrs.get('name', '')}")
    console.print(f"[bold]Auth Type:[/bold] {attrs.get('auth_type', '')}")
    console.print(f"[bold]Client ID:[/bold] {attrs.get('client_id', '')}")


def cmd_create(args):
    url = build_base_url(args.org_id, args.group_id)
    params = {"version": API_VERSION}
    body = {
        "data": {
            "type": "service_account",
            "attributes": {
                "name": args.name,
                "auth_type": args.auth_type,
                "role_id": args.role_id,
            },
        }
    }
    with httpx.Client(timeout=30) as client:
        resp = client.post(url, headers=get_headers(), params=params, json=body)
        resp.raise_for_status()
        data = resp.json()

    if args.as_json:
        print(json.dumps(data, indent=2))
        return

    sa = data.get("data", data)
    attrs = sa.get("attributes", {})
    console.print(f"[green]✓[/green] Service account created:")
    console.print(f"  ID:          {sa.get('id', '')}")
    console.print(f"  Name:        {attrs.get('name', '')}")
    console.print(f"  Client ID:   {attrs.get('client_id', '')}")
    if attrs.get("client_secret"):
        console.print(f"  [bold red]Client Secret:[/bold red] {attrs['client_secret']}")
        console.print("[yellow]  ⚠ Save this secret now — it will not be shown again.[/yellow]")


def cmd_delete(args):
    url = f"{build_base_url(args.org_id, args.group_id)}/{args.sa_id}"
    params = {"version": API_VERSION}
    with httpx.Client(timeout=30) as client:
        resp = client.delete(url, headers=get_headers(), params=params)
        resp.raise_for_status()
    console.print(f"[green]✓[/green] Service account [bold]{args.sa_id}[/bold] deleted.")


def cmd_rotate(args):
    url = f"{build_base_url(args.org_id, args.group_id)}/{args.sa_id}/secrets"
    params = {"version": API_VERSION}
    body = {"data": {"type": "service_account", "attributes": {"mode": "replace"}}}
    with httpx.Client(timeout=30) as client:
        resp = client.post(url, headers=get_headers(), params=params, json=body)
        resp.raise_for_status()
        data = resp.json()

    if args.as_json:
        print(json.dumps(data, indent=2))
        return

    sa = data.get("data", data)
    attrs = sa.get("attributes", {})
    console.print(f"[green]✓[/green] Client secret rotated for service account [bold]{args.sa_id}[/bold]:")
    if attrs.get("client_secret"):
        console.print(f"  [bold red]New Client Secret:[/bold red] {attrs['client_secret']}")
        console.print("[yellow]  ⚠ Save this secret now — it will not be shown again.[/yellow]")


def main():
    parser = argparse.ArgumentParser(description="Manage Snyk service accounts")
    parser.add_argument("--json", action="store_true", dest="as_json", help="Output raw JSON")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # Shared scope args helper
    def add_scope(p):
        g = p.add_mutually_exclusive_group(required=True)
        g.add_argument("--org-id", help="Organization UUID")
        g.add_argument("--group-id", help="Group UUID")

    # list
    p_list = subparsers.add_parser("list", help="List service accounts")
    add_scope(p_list)

    # get
    p_get = subparsers.add_parser("get", help="Get a service account")
    add_scope(p_get)
    p_get.add_argument("--sa-id", required=True, help="Service account ID")

    # create
    p_create = subparsers.add_parser("create", help="Create a service account")
    add_scope(p_create)
    p_create.add_argument("--name", required=True, help="Service account name")
    p_create.add_argument("--role-id", required=True, help="Role UUID to assign")
    p_create.add_argument(
        "--auth-type",
        default="client_secret",
        choices=["client_secret", "private_key_jwt"],
        help="Authentication type (default: client_secret)",
    )

    # delete
    p_delete = subparsers.add_parser("delete", help="Delete a service account")
    add_scope(p_delete)
    p_delete.add_argument("--sa-id", required=True, help="Service account ID")

    # rotate
    p_rotate = subparsers.add_parser("rotate", help="Rotate a service account client secret")
    add_scope(p_rotate)
    p_rotate.add_argument("--sa-id", required=True, help="Service account ID")

    args = parser.parse_args()

    commands = {
        "list": cmd_list,
        "get": cmd_get,
        "create": cmd_create,
        "delete": cmd_delete,
        "rotate": cmd_rotate,
    }
    commands[args.command](args)


if __name__ == "__main__":
    main()
