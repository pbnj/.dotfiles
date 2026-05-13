#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "gql[requests]",
# ]
# ///
"""
Execute a NRQL query against New Relic via the NerdGraph GraphQL API.

Supports synchronous queries, automatic async polling for long-running queries,
and cross-account queries.

Usage:
    nrql_query.py [OPTIONS] <NRQL>

    nrql_query.py "SELECT * FROM Log WHERE level = 'ERROR' SINCE 1 hour ago LIMIT 100"
    nrql_query.py --async "SELECT * FROM Log SINCE 7 days ago"
    nrql_query.py --accounts 111 222 "SELECT count(*) FROM Log FACET account SINCE 1 day ago"
    nrql_query.py --region eu "SELECT * FROM Log SINCE 30 minutes ago LIMIT 50"

Options:
    --accounts ID...    One or more account IDs. A single ID queries that account;
                        multiple IDs trigger a cross-account query.
                        Overrides NEWRELIC_ACCOUNT_ID when provided.
    --async             Use async query mode (required for queries > 60s)
    --timeout SECONDS   Sync query timeout in seconds (default: 60)
    --region REGION     API region: us (default) or eu
    --raw               Print raw GraphQL response instead of just results array

Environment variables required:
    NEWRELIC_API_KEY       Your New Relic user API key
    NEWRELIC_ACCOUNT_ID    Default account ID (used when --accounts is not provided)
"""

import argparse
import json
import os
import sys
import time

from gql import Client, gql
from gql.transport.requests import RequestsHTTPTransport

ENDPOINTS = {
    "us": "https://api.newrelic.com/graphql",
    "eu": "https://api.eu.newrelic.com/graphql",
}


# ---------------------------------------------------------------------------
# GraphQL documents
# ---------------------------------------------------------------------------

SYNC_SINGLE_ACCOUNT = gql("""
  query NRQLQuery($accountId: Int!, $nrql: Nrql!, $timeout: Seconds) {
    actor {
      account(id: $accountId) {
        nrql(query: $nrql, timeout: $timeout) {
          results
          metadata {
            timeWindow {
              begin
              end
            }
          }
        }
      }
    }
  }
""")

SYNC_CROSS_ACCOUNT = gql("""
  query NRQLCrossAccountQuery($accounts: [Int!]!, $nrql: Nrql!, $timeout: Seconds) {
    actor {
      nrql(accounts: $accounts, query: $nrql, timeout: $timeout) {
        results
        metadata {
          timeWindow {
            begin
            end
          }
        }
      }
    }
  }
""")

ASYNC_SINGLE_ACCOUNT = gql("""
  query NRQLAsyncQuery($accountId: Int!, $nrql: Nrql!) {
    actor {
      account(id: $accountId) {
        nrql(query: $nrql, async: true) {
          results
          queryProgress {
            queryId
            completed
            retryAfter
            retryDeadline
            resultExpiration
          }
        }
      }
    }
  }
""")

ASYNC_POLL = gql("""
  query NRQLAsyncPoll($accountId: Int!, $queryId: ID!) {
    actor {
      account(id: $accountId) {
        nrqlQueryProgress(queryId: $queryId) {
          results
          queryProgress {
            queryId
            completed
            retryAfter
            retryDeadline
            resultExpiration
          }
        }
      }
    }
  }
""")


# ---------------------------------------------------------------------------
# Client factory
# ---------------------------------------------------------------------------


def get_client(region: str) -> Client:
    api_key = os.environ.get("NEWRELIC_API_KEY")
    if not api_key:
        sys.exit("Error: NEWRELIC_API_KEY environment variable is not set.")

    endpoint = ENDPOINTS.get(region)
    if not endpoint:
        sys.exit(f"Error: Unknown region '{region}'. Use 'us' or 'eu'.")

    transport = RequestsHTTPTransport(
        url=endpoint,
        headers={"API-Key": api_key, "Content-Type": "application/json"},
        verify=True,
        retries=3,
    )
    return Client(transport=transport, fetch_schema_from_transport=False)


# ---------------------------------------------------------------------------
# Query runners
# ---------------------------------------------------------------------------


def run_sync(client: Client, account_id: int, nrql: str, timeout: int) -> list:
    """Execute a synchronous single-account NRQL query."""
    print(f"Executing sync query on account {account_id}…", file=sys.stderr)
    data = client.execute(
        SYNC_SINGLE_ACCOUNT,
        variable_values={"accountId": account_id, "nrql": nrql, "timeout": timeout},
    )
    return data["actor"]["account"]["nrql"]["results"]


def run_sync_cross_account(
    client: Client, accounts: list[int], nrql: str, timeout: int
) -> list:
    """Execute a synchronous cross-account NRQL query."""
    print(
        f"Executing cross-account sync query on accounts {accounts}…", file=sys.stderr
    )
    data = client.execute(
        SYNC_CROSS_ACCOUNT,
        variable_values={"accounts": accounts, "nrql": nrql, "timeout": timeout},
    )
    return data["actor"]["nrql"]["results"]


def run_async(client: Client, account_id: int, nrql: str) -> list:
    """Execute an async NRQL query, polling until complete."""
    print(f"Issuing async query on account {account_id}…", file=sys.stderr)
    data = client.execute(
        ASYNC_SINGLE_ACCOUNT,
        variable_values={"accountId": account_id, "nrql": nrql},
    )

    nrql_result = data["actor"]["account"]["nrql"]

    # If NerdGraph returned results immediately (query finished within timeout)
    progress = nrql_result.get("queryProgress") or {}
    if progress.get("completed", True) or nrql_result.get("results"):
        print("Query completed immediately.", file=sys.stderr)
        return nrql_result.get("results") or []

    query_id = progress["queryId"]
    print(f"Query running asynchronously (id: {query_id}). Polling…", file=sys.stderr)

    poll_interval = max(progress.get("retryAfter", 2), 2)

    while True:
        time.sleep(poll_interval)
        poll_data = client.execute(
            ASYNC_POLL,
            variable_values={"accountId": account_id, "queryId": query_id},
        )
        poll_result = poll_data["actor"]["account"]["nrqlQueryProgress"]
        poll_progress = poll_result.get("queryProgress") or {}

        if poll_progress.get("completed"):
            print("Async query complete.", file=sys.stderr)
            return poll_result.get("results") or []

        retry_after = poll_progress.get("retryAfter", poll_interval)
        print(f"  Still running — retrying in {retry_after}s…", file=sys.stderr)
        poll_interval = max(retry_after, 2)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Execute NRQL queries against New Relic via NerdGraph.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("nrql", help="NRQL query string")
    parser.add_argument(
        "--accounts",
        type=int,
        nargs="+",
        metavar="ID",
        help=(
            "One or more account IDs. A single ID queries that account; "
            "multiple IDs trigger a cross-account query. "
            "Overrides NEWRELIC_ACCOUNT_ID."
        ),
    )
    parser.add_argument(
        "--async",
        dest="use_async",
        action="store_true",
        help="Use async query mode (good for queries > 60s)",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=60,
        help="Sync query timeout in seconds (default: 60)",
    )
    parser.add_argument(
        "--region",
        choices=["us", "eu"],
        default="us",
        help="API region: us (default) or eu",
    )
    parser.add_argument(
        "--raw",
        action="store_true",
        help="Print raw GraphQL response instead of just the results array",
    )
    return parser.parse_args()


def resolve_accounts(args: argparse.Namespace) -> list[int]:
    """Return the list of account IDs to query, from --accounts or env var."""
    if args.accounts:
        return args.accounts
    env_id = os.environ.get("NEWRELIC_ACCOUNT_ID")
    if env_id:
        try:
            return [int(env_id)]
        except ValueError:
            sys.exit(f"Error: NEWRELIC_ACCOUNT_ID='{env_id}' is not a valid integer.")
    sys.exit("Error: Provide --accounts or set NEWRELIC_ACCOUNT_ID.")


def main():
    args = parse_args()
    client = get_client(args.region)

    accounts = resolve_accounts(args)
    is_cross_account = len(accounts) > 1

    if is_cross_account:
        if args.use_async:
            print(
                "Warning: async mode is not supported for cross-account queries. "
                "Falling back to sync.",
                file=sys.stderr,
            )
        results = run_sync_cross_account(client, accounts, args.nrql, args.timeout)
    elif args.use_async:
        results = run_async(client, accounts[0], args.nrql)
    else:
        results = run_sync(client, accounts[0], args.nrql, args.timeout)

    print(json.dumps(results, indent=2))
    print(f"\nDone. {len(results)} result(s) returned.", file=sys.stderr)


if __name__ == "__main__":
    main()
