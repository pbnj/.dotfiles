#!/usr/bin/env python3
"""Block commits that add banned (e.g. work) words to this public repo.

Checks the lines and file paths a commit adds (or, with --commit-msg, the
commit message) against a private, uncommitted list of case-insensitive
regular expressions, one per line:

    # comment
    acme              block any added line or path matching this
    !github\\.com/acme  ...unless the line also matches an exemption

The list lives outside version control, since it is itself proprietary:
$BANNED_WORDS_FILE, else ~/.config/git/banned-words. When the list
is missing the check warns and passes, so other machines can still commit.
Bypass once with SKIP=banned-words,banned-words-msg git commit ...
"""

import argparse
import os
from pathlib import Path
import re
import subprocess
import sys

DEFAULT_LIST = Path.home() / ".config/git/banned-words"
HUNK = re.compile(r"^@@ -\d+(?:,\d+)? \+(\d+)")


def load_patterns(path):
    blocked, exempt = [], []
    for number, line in enumerate(path.read_text().splitlines(), 1):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        target = exempt if line.startswith("!") else blocked
        try:
            target.append(re.compile(line.removeprefix("!"), re.IGNORECASE))
        except re.error as error:
            sys.exit("{}:{}: invalid pattern: {}".format(path, number, error))
    return blocked, exempt


def staged_additions():
    """Yield (location, text) for each added path and added line."""
    diff = subprocess.run(
        [
            "git",
            "diff",
            "--cached",
            "--no-color",
            "--no-ext-diff",
            "-U0",
            "--diff-filter=ACMR",
            "--find-renames",
        ],
        capture_output=True,
        check=True,
        text=True,
        errors="replace",
    ).stdout
    path, line_number = None, 0
    for line in diff.splitlines():
        if line.startswith("+++ "):
            path = line[4:].removeprefix("b/")
            yield path, path
        elif line.startswith("@@"):
            match = HUNK.match(line)
            line_number = int(match.group(1)) if match else 0
        elif line.startswith("+") and path:
            yield "{}:{}".format(path, line_number), line[1:]
            line_number += 1


def message_lines(path):
    for number, line in enumerate(Path(path).read_text().splitlines(), 1):
        if not line.startswith("#"):  # git strips comment lines
            yield "commit message:{}".format(number), line


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--commit-msg", metavar="FILE", help="check a commit message")
    args = parser.parse_args()
    words = Path(os.environ.get("BANNED_WORDS_FILE", DEFAULT_LIST)).expanduser()
    if not words.is_file():
        print("banned-words: no list at {}; skipping".format(words), file=sys.stderr)
        return 0
    blocked, exempt = load_patterns(words)
    lines = message_lines(args.commit_msg) if args.commit_msg else staged_additions()
    found = 0
    for location, text in lines:
        if any(pattern.search(text) for pattern in exempt):
            continue
        hits = sorted({m.group(0) for p in blocked for m in p.finditer(text)})
        if hits:
            found += 1
            print("{}: {}".format(location, ", ".join(hits)))
    if found:
        print(
            "\nbanned-words: {} match(es) from {}.\n"
            "Rewrite them, add an !exemption, or bypass once with\n"
            "SKIP=banned-words,banned-words-msg git commit ...".format(found, words)
        )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
