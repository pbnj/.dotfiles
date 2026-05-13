#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "gql[aiohttp]",
# ]
# ///
"""
List Panther alerts with optional filters, paginating through all results.

Usage:
    uv run list_alerts.py \\
        --start-time "2024-06-01T00:00:00.000Z" \\
        --end-time   "2024-06-30T23:59:59.000Z" \\
        [--severities INFO LOW MEDIUM HIGH CRITICAL] \\
        [--statuses OPEN TRIAGED RESOLVED CLOSED]

Results are printed as a JSON array on stdout.
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


LIST_ALERTS = gql("""
  query ListAlerts($input: AlertsInput!) {
    alerts(input: $input) {
      edges {
        node {
          id
          title
          severity
          status
          createdAt
          updatedAt
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
            }
            ... on SystemError {
              relatedComponent
              type
            }
          }
        }
      }
      pageInfo {
        hasNextPage
        endCursor
      }
    }
  }
""")


def run(start_time: str, end_time: str, severities: list[str] | None, statuses: list[str] | None) -> list:
    client = get_client()

    query_input: dict = {
        "createdAtAfter": start_time,
        "createdAtBefore": end_time,
    }
    if severities:
        query_input["severities"] = severities
    if statuses:
        query_input["statuses"] = statuses

    print(f"Listing alerts from {start_time} to {end_time}", file=sys.stderr)
    if severities:
        print(f"  Filtering severities: {severities}", file=sys.stderr)
    if statuses:
        print(f"  Filtering statuses: {statuses}", file=sys.stderr)

    all_alerts = []
    has_more = True

    while has_more:
        data = client.execute(LIST_ALERTS, variable_values={"input": query_input})
        page = data["alerts"]

        nodes = [edge["node"] for edge in page["edges"]]
        all_alerts.extend(nodes)
        print(f"  Fetched {len(nodes)} alerts (total so far: {len(all_alerts)})", file=sys.stderr)

        has_more = page["pageInfo"]["hasNextPage"]
        query_input["cursor"] = page["pageInfo"]["endCursor"]

    return all_alerts


def main():
    parser = argparse.ArgumentParser(
        description="List Panther alerts with optional filters.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("--start-time", required=True, metavar="ISO8601",
                        help="Earliest alert creation time (e.g. 2024-01-01T00:00:00.000Z).")
    parser.add_argument("--end-time", required=True, metavar="ISO8601",
                        help="Latest alert creation time (e.g. 2024-01-31T23:59:59.000Z).")
    parser.add_argument("--severities", nargs="+", metavar="SEVERITY",
                        choices=["INFO", "LOW", "MEDIUM", "HIGH", "CRITICAL"],
                        help="Filter by one or more severity levels.")
    parser.add_argument("--statuses", nargs="+", metavar="STATUS",
                        choices=["OPEN", "TRIAGED", "RESOLVED", "CLOSED"],
                        help="Filter by one or more alert statuses.")

    args = parser.parse_args()
    results = run(args.start_time, args.end_time, args.severities, args.statuses)

    print(json.dumps(results, indent=2))
    print(f"\nDone. {len(results)} alert(s) returned.", file=sys.stderr)


if __name__ == "__main__":
    main()
