#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "gql[aiohttp]",
# ]
# ///
"""
Execute a Panther indicator search query and print all results to stdout.

Usage:
    python indicator_search.py \\
        --indicators "1.2.3.4" "5.6.7.8" \\
        --start-time "2024-01-01T00:00:00.000Z" \\
        --end-time   "2024-01-31T23:59:59.000Z" \\
        [--indicator-name p_any_ip_addresses]

    The --indicator-name flag is optional; Panther will auto-detect the type
    if omitted. Common values:
        p_any_ip_addresses
        p_any_aws_account_ids
        p_any_domain_names
        p_any_sha256_hashes
        p_any_md5_hashes

Environment variables required:
    PANTHER_INSTANCE_URL  e.g. https://your-company.runpanther.net/public/graphql
    PANTHER_API_TOKEN     your Panther API key
"""

import argparse
import json
import os
import sys
import time

from gql import Client, gql
from gql.transport.aiohttp import AIOHTTPTransport


def get_client() -> Client:
    url = os.environ.get("PANTHER_INSTANCE_URL")
    token = os.environ.get("PANTHER_API_TOKEN")

    if not url:
        sys.exit("Error: PANTHER_INSTANCE_URL environment variable is not set.")
    if not token:
        sys.exit("Error: PANTHER_API_TOKEN environment variable is not set.")

    transport = AIOHTTPTransport(
        url=url,
        headers={"X-API-Key": token},
    )
    return Client(transport=transport, fetch_schema_from_transport=True)


ISSUE_QUERY = gql("""
  mutation IssueQuery($input: ExecuteIndicatorSearchQueryInput!) {
    executeIndicatorSearchQuery(input: $input) {
      id
    }
  }
""")

GET_RESULTS = gql("""
  query GetQueryResults($id: ID!, $cursor: String) {
    dataLakeQuery(id: $id) {
      message
      status
      results(input: { cursor: $cursor }) {
        edges {
          node
        }
        pageInfo {
          endCursor
          hasNextPage
        }
      }
    }
  }
""")


def run(indicators: list[str], start_time: str, end_time: str, indicator_name: str | None) -> list:
    client = get_client()

    search_input = {
        "indicators": indicators,
        "startTime": start_time,
        "endTime": end_time,
    }
    if indicator_name:
        search_input["indicatorName"] = indicator_name

    print(f"Issuing indicator search for: {indicators}", file=sys.stderr)
    mutation_data = client.execute(ISSUE_QUERY, variable_values={"input": search_input})
    query_id = mutation_data["executeIndicatorSearchQuery"]["id"]
    print(f"Query ID: {query_id}", file=sys.stderr)

    all_results = []
    has_more = True
    cursor = None
    poll_interval = 2  # seconds between polls

    while has_more:
        data = client.execute(
            GET_RESULTS,
            variable_values={"id": query_id, "cursor": cursor},
        )
        q = data["dataLakeQuery"]
        status = q["status"]

        if status == "running":
            print(f"  Still running: {q['message']}", file=sys.stderr)
            time.sleep(poll_interval)
            continue

        if status != "succeeded":
            sys.exit(f"Query {status}: {q['message']}")

        page_nodes = [edge["node"] for edge in q["results"]["edges"]]
        all_results.extend(page_nodes)

        page_info = q["results"]["pageInfo"]
        has_more = page_info["hasNextPage"]
        cursor = page_info["endCursor"]

        print(
            f"  Fetched {len(page_nodes)} rows (total so far: {len(all_results)})",
            file=sys.stderr,
        )

    return all_results


def main():
    parser = argparse.ArgumentParser(
        description="Search Panther logs for one or more indicator values.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "--indicators",
        nargs="+",
        required=True,
        metavar="VALUE",
        help="One or more indicator values to search for (e.g. IP addresses, account IDs).",
    )
    parser.add_argument(
        "--start-time",
        required=True,
        metavar="ISO8601",
        help="Search window start (e.g. 2024-01-01T00:00:00.000Z).",
    )
    parser.add_argument(
        "--end-time",
        required=True,
        metavar="ISO8601",
        help="Search window end (e.g. 2024-01-31T23:59:59.000Z).",
    )
    parser.add_argument(
        "--indicator-name",
        default=None,
        metavar="FIELD",
        help=(
            "Panther p_any_* field to search against "
            "(e.g. p_any_ip_addresses). Omit for auto-detection."
        ),
    )

    args = parser.parse_args()
    results = run(args.indicators, args.start_time, args.end_time, args.indicator_name)

    print(json.dumps(results, indent=2))
    print(f"\nDone. {len(results)} row(s) returned.", file=sys.stderr)


if __name__ == "__main__":
    main()
