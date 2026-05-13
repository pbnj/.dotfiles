#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "gql[aiohttp]",
# ]
# ///
"""
Fetch full details for a single Panther alert by ID, including all associated log events.

Usage:
    uv run get_alert.py <alert-id> [--page-size N] [--no-events]

Examples:
    uv run get_alert.py 6087bc1d6fc49ce97ef3c85ca0e3f31b
    uv run get_alert.py 6087bc1d6fc49ce97ef3c85ca0e3f31b --page-size 50
    uv run get_alert.py 6087bc1d6fc49ce97ef3c85ca0e3f31b --no-events

Result is printed as a JSON object on stdout. The top-level key "events" contains
a flat list of all raw log event objects paginated from the API.
Progress messages go to stderr.

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


GET_ALERT = gql("""
  query GetAlert($id: ID!) {
    alert(id: $id) {
      id
      title
      description
      severity
      status
      type
      riskScore {
        classification
        classificationReasoning
        normalizedTotalRiskScore
        normalizedTotalRiskFormula
        riskyIndicators {
          description
          riskScore
          evidenceConfidence
          contextWeighting
          temporalRelevance
        }
        benignIndicators {
          description
          riskScore
          evidenceConfidence
          contextWeighting
          temporalRelevance
        }
      }
      createdAt
      updatedAt
      firstEventOccurredAt
      lastReceivedEventAt
      reference
      runbook
      assignee {
        id
        email
        givenName
        familyName
      }
      origin {
        ... on Detection {
          id
          name
          description
        }
        ... on SystemError {
          relatedComponent
          type
        }
      }
      deliveries {
        outputId
        dispatchedAt
        message
        statusCode
        success
      }
    }
  }
""")

GET_ALERT_EVENTS_PAGE = gql("""
  query GetAlertEventsPage($id: ID!, $cursor: String!, $pageSize: Int!) {
    alert(id: $id) {
      events(input: { cursor: $cursor, pageSize: $pageSize }) {
        edges {
          node
        }
        pageInfo {
          endCursor
        }
      }
    }
  }
""")


def fetch_events(client: Client, alert_id: str, page_size: int) -> list:
    """Paginate through all log events for the given alert."""
    events = []
    cursor = ""
    page = 1
    while True:
        print(f"  Fetching events page {page} (cursor={cursor!r}) ...", file=sys.stderr)
        data = client.execute(
            GET_ALERT_EVENTS_PAGE,
            variable_values={"id": alert_id, "cursor": cursor, "pageSize": page_size},
        )
        edge_list = data["alert"]["events"]["edges"]
        nodes = [edge["node"] for edge in edge_list]
        events.extend(nodes)
        print(
            f"    Got {len(nodes)} event(s) (total so far: {len(events)})",
            file=sys.stderr,
        )

        end_cursor = data["alert"]["events"]["pageInfo"]["endCursor"]
        # API signals last page with a null/empty endCursor or an empty edge list
        if not end_cursor or not nodes:
            break
        cursor = end_cursor
        page += 1
    return events


def run(alert_id: str, page_size: int = 25, include_events: bool = True) -> dict:
    client = get_client()
    print(f"Fetching alert {alert_id} ...", file=sys.stderr)
    data = client.execute(GET_ALERT, variable_values={"id": alert_id})
    alert = data.get("alert")
    if not alert:
        sys.exit(f"Error: alert '{alert_id}' not found.")

    if include_events:
        print("Fetching associated log events ...", file=sys.stderr)
        alert["events"] = fetch_events(client, alert_id, page_size)
        print(f"  Total events: {len(alert['events'])}", file=sys.stderr)
    else:
        alert["events"] = []

    return alert


def main():
    parser = argparse.ArgumentParser(
        description="Fetch full details for a single Panther alert by ID.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("id", metavar="ALERT_ID", help="The Panther alert ID to fetch.")
    parser.add_argument(
        "--page-size",
        type=int,
        default=25,
        metavar="N",
        help="Number of log events to fetch per page (default: 25).",
    )
    parser.add_argument(
        "--no-events",
        action="store_true",
        help="Skip fetching log events (return alert metadata only).",
    )

    args = parser.parse_args()
    alert = run(args.id, page_size=args.page_size, include_events=not args.no_events)

    print(json.dumps(alert, indent=2))
    print("\nDone.", file=sys.stderr)


if __name__ == "__main__":
    main()
