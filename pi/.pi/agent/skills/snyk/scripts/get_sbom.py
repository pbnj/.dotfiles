#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = ["httpx", "rich"]
# ///
"""Get SBOM document for a Snyk project.

Usage:
    op run -- uv run get_sbom.py --org-id ORG_ID --project-id PROJECT_ID [options]

Options:
    --org-id        ORG_ID      Required. Organization UUID.
    --project-id    PROJECT_ID  Required. Project UUID.
    --format        FORMAT      SBOM format (default: cyclonedx1.6+json).
                                Choices: cyclonedx1.6+json, cyclonedx1.6+xml,
                                         cyclonedx1.5+json, cyclonedx1.5+xml,
                                         cyclonedx1.4+json, cyclonedx1.4+xml,
                                         spdx2.3+json
    --output        FILE        Write SBOM to file instead of stdout.

Environment:
    SNYK_TOKEN  Snyk API token (injected via 1Password op run)
"""

import os
import sys
import argparse
import httpx
from rich.console import Console

BASE_URL = "https://api.snyk.io/rest"
API_VERSION = "2025-11-05"
console = Console()

FORMATS = [
    "cyclonedx1.6+json",
    "cyclonedx1.6+xml",
    "cyclonedx1.5+json",
    "cyclonedx1.5+xml",
    "cyclonedx1.4+json",
    "cyclonedx1.4+xml",
    "spdx2.3+json",
]


def get_headers() -> dict:
    token = os.environ.get("SNYK_TOKEN")
    if not token:
        console.print("[red]Error:[/red] SNYK_TOKEN environment variable is not set.")
        sys.exit(1)
    return {"Authorization": f"token {token}"}


def main():
    parser = argparse.ArgumentParser(description="Get SBOM document for a Snyk project")
    parser.add_argument("--org-id", required=True, help="Organization UUID")
    parser.add_argument("--project-id", required=True, help="Project UUID")
    parser.add_argument(
        "--format", default="cyclonedx1.6+json", choices=FORMATS, help="SBOM format"
    )
    parser.add_argument("--output", "-o", help="Output file path (default: stdout)")
    args = parser.parse_args()

    url = f"{BASE_URL}/orgs/{args.org_id}/projects/{args.project_id}/sbom"
    params = {"version": API_VERSION, "format": args.format}

    with httpx.Client(timeout=60) as client:
        resp = client.get(url, headers=get_headers(), params=params)
        resp.raise_for_status()
        content = resp.text

    if args.output:
        with open(args.output, "w") as f:
            f.write(content)
        console.print(f"[green]✓[/green] SBOM written to [bold]{args.output}[/bold]")
    else:
        print(content)


if __name__ == "__main__":
    main()
