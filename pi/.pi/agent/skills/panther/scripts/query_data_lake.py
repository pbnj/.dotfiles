#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "gql[aiohttp]",
# ]
# ///
"""
Execute a Panther data lake SQL query and print all results to stdout.

Usage:
    python query_data_lake.py "select * from panther_logs.public.aws_alb limit 10"

Environment variables required:
    PANTHER_INSTANCE_URL  e.g. https://your-company.runpanther.net/public/graphql
    PANTHER_API_TOKEN     your Panther API key
"""

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
    return Client(transport=transport, fetch_schema_from_transport=False)


ISSUE_QUERY = gql("""
  mutation IssueQuery($sql: String!) {
    executeDataLakeQuery(input: { sql: $sql }) {
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


def run(sql: str) -> list:
    client = get_client()

    print(f"Issuing query: {sql}", file=sys.stderr)
    mutation_data = client.execute(ISSUE_QUERY, variable_values={"sql": sql})
    query_id = mutation_data["executeDataLakeQuery"]["id"]
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
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    sql = sys.argv[1]
    results = run(sql)

    print(json.dumps(results, indent=2))
    print(f"\nDone. {len(results)} row(s) returned.", file=sys.stderr)


if __name__ == "__main__":
    main()
