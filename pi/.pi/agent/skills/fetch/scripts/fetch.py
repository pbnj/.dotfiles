#!/usr/bin/env -S uv run --script

# /// script
# requires-python = ">=3.9"
# dependencies = [
#   "requests",
#   "markdownify",
# ]
# ///

import sys
import re
from urllib.parse import urlparse
import requests
from markdownify import markdownify as md


def transform_github_url(url: str) -> str:
    """
    Transform GitHub blob URL to raw URL.

    Input:  https://github.com/user/repo/blob/branch/path/to/file
    Output: https://raw.githubusercontent.com/user/repo/branch/path/to/file
    """
    match = re.match(r"https://github\.com/([^/]+)/([^/]+)/blob/(.+?)/(.*)", url)
    if match:
        user, repo, branch, filepath = match.groups()
        return f"https://raw.githubusercontent.com/{user}/{repo}/{branch}/{filepath}"
    return url


def is_github_blob_url(url: str) -> bool:
    """Check if URL is a GitHub blob URL."""
    return "github.com" in url and "/blob/" in url


def fetch_url(url: str) -> str:
    """
    Fetch URL content with proper headers.
    Returns the raw content as string.
    """
    headers = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"}

    try:
        response = requests.get(url, headers=headers, timeout=30)
        response.raise_for_status()
        return response.text
    except requests.exceptions.RequestException as e:
        print(f"Error fetching {url}: {e}", file=sys.stderr)
        sys.exit(1)


def is_raw_github_url(url: str) -> bool:
    """Check if URL is a raw GitHub URL or raw file content."""
    return "raw.githubusercontent.com" in url


def html_to_markdown(html: str) -> str:
    """
    Convert HTML to Markdown using markdownify.
    """
    try:
        markdown = md(html, heading_style="atx")
        # Clean up excessive whitespace
        markdown = re.sub(r"\n\n\n+", "\n\n", markdown)
        return markdown.strip()
    except Exception as e:
        print(f"Error converting HTML to Markdown: {e}", file=sys.stderr)
        sys.exit(1)


def main():
    if len(sys.argv) < 2:
        print("Usage: fetch.py <url>", file=sys.stderr)
        print("\nFetch content from URL and convert to Markdown.", file=sys.stderr)
        sys.exit(1)

    url = sys.argv[1]

    # Validate URL format
    try:
        urlparse(url)
    except Exception:
        print(f"Invalid URL: {url}", file=sys.stderr)
        sys.exit(1)

    # Handle GitHub blob URLs
    if is_github_blob_url(url):
        url = transform_github_url(url)

    # Fetch content
    content = fetch_url(url)

    # If it's a raw GitHub URL, return as-is (no conversion needed)
    if is_raw_github_url(url):
        print(content)
    else:
        # Convert HTML to Markdown
        markdown = html_to_markdown(content)
        print(markdown)


if __name__ == "__main__":
    main()
