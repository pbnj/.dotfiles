#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = ["httpx", "rich"]
# ///
"""Manage Snyk org and group memberships.

Subcommands:
    list-org      List all memberships in an org
    list-group    List all memberships in a group
    invite        Invite a user to an org
    cancel-invite Cancel a pending org invite

Usage:
    op run -- uv run memberships.py list-org --org-id ORG_ID [--json]
    op run -- uv run memberships.py list-group --group-id GROUP_ID [--json]
    op run -- uv run memberships.py invite --org-id ORG_ID --email EMAIL --role ROLE [--json]
    op run -- uv run memberships.py cancel-invite --org-id ORG_ID --invite-id INVITE_ID

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
    return {
        "Authorization": f"token {token}",
        "Content-Type": "application/vnd.api+json",
    }


def paginate(client, url, params) -> list[dict]:
    items = []
    while url:
        resp = client.get(url, headers=get_headers(), params=params)
        resp.raise_for_status()
        data = resp.json()
        items.extend(data.get("data", []))
        next_link = data.get("links", {}).get("next")
        if next_link:
            url = (
                next_link
                if next_link.startswith("http")
                else f"https://api.snyk.io{next_link}"
            )
            params = {}
        else:
            url = None
    return items


def cmd_list_org(args):
    url = f"{BASE_URL}/orgs/{args.org_id}/memberships"
    params = {"version": API_VERSION, "limit": 100}
    with httpx.Client(timeout=30) as client:
        members = paginate(client, url, params)

    if args.as_json:
        print(json.dumps(members, indent=2))
        return

    if not members:
        console.print("[yellow]No memberships found.[/yellow]")
        return

    table = Table(title=f"Org Memberships for {args.org_id} ({len(members)} total)")
    table.add_column("Membership ID", style="dim", no_wrap=True)
    table.add_column("User ID", style="dim", max_width=36)
    table.add_column("Email / Name", max_width=40)
    table.add_column("Role")
    for m in members:
        attrs = m.get("attributes", {})
        user = attrs.get("user", {})
        table.add_row(
            m.get("id", ""),
            user.get("id", attrs.get("user_id", "")),
            user.get("email", user.get("name", "")),
            attrs.get("role", attrs.get("role_name", "")),
        )
    console.print(table)


def cmd_list_group(args):
    url = f"{BASE_URL}/groups/{args.group_id}/memberships"
    params = {"version": API_VERSION, "limit": 100}
    with httpx.Client(timeout=30) as client:
        members = paginate(client, url, params)

    if args.as_json:
        print(json.dumps(members, indent=2))
        return

    if not members:
        console.print("[yellow]No memberships found.[/yellow]")
        return

    table = Table(title=f"Group Memberships for {args.group_id} ({len(members)} total)")
    table.add_column("Membership ID", style="dim", no_wrap=True)
    table.add_column("User ID", style="dim", max_width=36)
    table.add_column("Email / Name", max_width=40)
    table.add_column("Role")
    for m in members:
        attrs = m.get("attributes", {})
        user = attrs.get("user", {})
        table.add_row(
            m.get("id", ""),
            user.get("id", attrs.get("user_id", "")),
            user.get("email", user.get("name", "")),
            attrs.get("role", attrs.get("role_name", "")),
        )
    console.print(table)


def cmd_invite(args):
    url = f"{BASE_URL}/orgs/{args.org_id}/invites"
    params = {"version": API_VERSION}
    body = {
        "data": {
            "type": "org_invitation",
            "attributes": {
                "email": args.email,
                "role": args.role,
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

    inv = data.get("data", data)
    attrs = inv.get("attributes", {})
    console.print(f"[green]✓[/green] Invitation sent to [bold]{args.email}[/bold]")
    console.print(f"  Invite ID: {inv.get('id', '')}")
    console.print(f"  Role:      {attrs.get('role', args.role)}")


def cmd_cancel_invite(args):
    url = f"{BASE_URL}/orgs/{args.org_id}/invites/{args.invite_id}"
    params = {"version": API_VERSION}
    with httpx.Client(timeout=30) as client:
        resp = client.delete(url, headers=get_headers(), params=params)
        resp.raise_for_status()
    console.print(
        f"[green]✓[/green] Invitation [bold]{args.invite_id}[/bold] cancelled."
    )


def main():
    parser = argparse.ArgumentParser(
        description="Manage Snyk memberships and invitations"
    )
    parser.add_argument(
        "--json", action="store_true", dest="as_json", help="Output raw JSON"
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    p_lo = subparsers.add_parser("list-org", help="List org memberships")
    p_lo.add_argument("--org-id", required=True, help="Organization UUID")

    p_lg = subparsers.add_parser("list-group", help="List group memberships")
    p_lg.add_argument("--group-id", required=True, help="Group UUID")

    p_inv = subparsers.add_parser("invite", help="Invite a user to an org")
    p_inv.add_argument("--org-id", required=True, help="Organization UUID")
    p_inv.add_argument("--email", required=True, help="User email address")
    p_inv.add_argument(
        "--role", required=True, help="Role name (e.g. collaborator, admin)"
    )

    p_ci = subparsers.add_parser("cancel-invite", help="Cancel a pending org invite")
    p_ci.add_argument("--org-id", required=True, help="Organization UUID")
    p_ci.add_argument("--invite-id", required=True, help="Invitation UUID")

    args = parser.parse_args()
    commands = {
        "list-org": cmd_list_org,
        "list-group": cmd_list_group,
        "invite": cmd_invite,
        "cancel-invite": cmd_cancel_invite,
    }
    commands[args.command](args)


if __name__ == "__main__":
    main()
