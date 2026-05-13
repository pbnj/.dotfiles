#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "gql[aiohttp]",
# ]
# ///
"""
Manage Panther alert status, comments, and assignees.

Sub-commands:

  status   Update the status of one or more alerts
             uv run update_alerts.py status --ids <id1> <id2> --status RESOLVED

  comment  Add a comment to an alert
             uv run update_alerts.py comment --id <alert-id> --body "Investigation complete."

  assign   Assign one or more alerts to a user (by email or user-id)
             uv run update_alerts.py assign --ids <id1> <id2> --email user@example.com
             uv run update_alerts.py assign --ids <id1> <id2> --user-id <panther-user-id>

  unassign Remove the assignee from one or more alerts
             uv run update_alerts.py unassign --ids <id1> <id2>

Valid statuses: OPEN  TRIAGED  RESOLVED  CLOSED

Environment variables required:
    PANTHER_INSTANCE_URL  e.g. https://your-company.runpanther.net/public/graphql
    PANTHER_API_TOKEN     your Panther API key
"""

import argparse
import json
import os
import sys

from gql import Client, gql
from gql.transport.aiohttp import AIOHTTPTransport


def get_client() -> Client:
    url = os.environ.get("PANTHER_INSTANCE_URL")
    token = os.environ.get("PANTHER_API_TOKEN")

    if not url:
        sys.exit("Error: PANTHER_INSTANCE_URL environment variable is not set.")
    if not token:
        sys.exit("Error: PANTHER_API_TOKEN environment variable is not set.")

    transport = AIOHTTPTransport(url=url, headers={"X-API-Key": token})
    return Client(transport=transport, fetch_schema_from_transport=False)


UPDATE_STATUS = gql("""
  mutation UpdateAlertStatus($input: UpdateAlertStatusByIdInput!) {
    updateAlertStatusById(input: $input) {
      alerts {
        id
        status
      }
    }
  }
""")

ADD_COMMENT = gql("""
  mutation AddComment($input: CreateAlertCommentInput!) {
    createAlertComment(input: $input) {
      comment {
        id
      }
    }
  }
""")

ASSIGN_BY_EMAIL = gql("""
  mutation AssignByEmail($input: UpdateAlertsAssigneeByEmailInput!) {
    updateAlertsAssigneeByEmail(input: $input) {
      alerts {
        id
        assignee {
          id
          email
          givenName
          familyName
        }
      }
    }
  }
""")

ASSIGN_BY_ID = gql("""
  mutation AssignById($input: UpdateAlertsAssigneeByIdInput!) {
    updateAlertsAssigneeById(input: $input) {
      alerts {
        id
        assignee {
          id
          email
          givenName
          familyName
        }
      }
    }
  }
""")


def cmd_status(client: Client, args: argparse.Namespace) -> dict:
    print(f"Setting status={args.status} on {len(args.ids)} alert(s)...", file=sys.stderr)
    data = client.execute(UPDATE_STATUS, variable_values={
        "input": {"ids": args.ids, "status": args.status}
    })
    return data["updateAlertStatusById"]


def cmd_comment(client: Client, args: argparse.Namespace) -> dict:
    fmt = "HTML" if args.html else "PLAIN_TEXT"
    print(f"Adding {fmt} comment to alert {args.id}...", file=sys.stderr)
    data = client.execute(ADD_COMMENT, variable_values={
        "input": {"alertId": args.id, "body": args.body, "format": fmt}
    })
    return data["createAlertComment"]


def cmd_assign(client: Client, args: argparse.Namespace) -> dict:
    if args.email:
        print(f"Assigning {len(args.ids)} alert(s) to {args.email}...", file=sys.stderr)
        data = client.execute(ASSIGN_BY_EMAIL, variable_values={
            "input": {"assigneeEmail": args.email, "ids": args.ids}
        })
        return data["updateAlertsAssigneeByEmail"]
    else:
        print(f"Assigning {len(args.ids)} alert(s) to user ID {args.user_id}...", file=sys.stderr)
        data = client.execute(ASSIGN_BY_ID, variable_values={
            "input": {"assigneeId": args.user_id, "ids": args.ids}
        })
        return data["updateAlertsAssigneeById"]


def cmd_unassign(client: Client, args: argparse.Namespace) -> dict:
    # Panther unassigns by setting assigneeId to null
    print(f"Unassigning {len(args.ids)} alert(s)...", file=sys.stderr)
    data = client.execute(ASSIGN_BY_ID, variable_values={
        "input": {"assigneeId": None, "ids": args.ids}
    })
    return data["updateAlertsAssigneeById"]


def main():
    parser = argparse.ArgumentParser(
        description="Manage Panther alert status, comments, and assignees.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    sub = parser.add_subparsers(dest="command", required=True)

    # status sub-command
    p_status = sub.add_parser("status", help="Update alert status.")
    p_status.add_argument("--ids", nargs="+", required=True, metavar="ALERT_ID",
                          help="One or more alert IDs to update.")
    p_status.add_argument("--status", required=True,
                          choices=["OPEN", "TRIAGED", "RESOLVED", "CLOSED"],
                          help="New status to apply.")

    # comment sub-command
    p_comment = sub.add_parser("comment", help="Add a comment to an alert.")
    p_comment.add_argument("--id", required=True, metavar="ALERT_ID",
                           help="Alert ID to comment on.")
    p_comment.add_argument("--body", required=True,
                           help="Comment body text.")
    p_comment.add_argument("--html", action="store_true",
                           help="Treat --body as HTML (default: plain text).")

    # assign sub-command
    p_assign = sub.add_parser("assign", help="Assign alerts to a user.")
    p_assign.add_argument("--ids", nargs="+", required=True, metavar="ALERT_ID",
                          help="One or more alert IDs to assign.")
    assign_by = p_assign.add_mutually_exclusive_group(required=True)
    assign_by.add_argument("--email", metavar="EMAIL",
                           help="Assignee's email address.")
    assign_by.add_argument("--user-id", metavar="USER_ID",
                           help="Assignee's Panther user ID.")

    # unassign sub-command
    p_unassign = sub.add_parser("unassign", help="Remove assignee from alerts.")
    p_unassign.add_argument("--ids", nargs="+", required=True, metavar="ALERT_ID",
                            help="One or more alert IDs to unassign.")

    args = parser.parse_args()
    client = get_client()

    dispatch = {
        "status":   cmd_status,
        "comment":  cmd_comment,
        "assign":   cmd_assign,
        "unassign": cmd_unassign,
    }
    result = dispatch[args.command](client, args)

    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
