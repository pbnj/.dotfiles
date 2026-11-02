#!/usr/bin/python3
"""Open the frontmost browser tab's URL in fai, in a Rex floating layer."""

import argparse
import fcntl
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parent
CACHE = Path.home() / "Library/Caches/agent-url"
# GUI-launched commands do not inherit the interactive shell's PATH.
SEARCH_PATH = os.pathsep.join(
    [
        str(Path.home() / ".local/bin"),
        # The Rex app installs its CLI here, off every default PATH.
        str(
            Path.home()
            / "Library/Application Support/com.superlogical.rex/RexServer/Versions/Current"
            / "Rex Server.app/Contents/MacOS"
        ),
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "/usr/bin",
        "/bin",
        os.environ.get("PATH", ""),
    ]
)
REX_BUNDLE = "com.superlogical.rex"
REX_SESSION_ID = re.compile(r"session:[0-9A-Fa-f-]+")
# The init.lua action (rex/.config/rex/init.lua) that opens fai in a layer.
REX_ACTION = "fai"


def load_config():
    return json.loads((ROOT / "config.json").read_text())


def validate_url(value):
    if not value or len(value) > 65536 or re.search(r"[\x00-\x20\x7f]", value):
        raise ValueError("The browser did not provide a valid URL.")
    parsed = urlsplit(value)
    if not parsed.scheme or (
        parsed.scheme.lower() in ("http", "https", "ftp") and not parsed.netloc
    ):
        raise ValueError("The browser did not provide an absolute URL.")
    return value


def capture_url():
    helper = CACHE / "fai"
    if not helper.is_file():
        raise ValueError("URL capture helper is missing. Run install.py first.")
    # Serialize captures so two hotkey presses cannot interfere with browser focus.
    CACHE.mkdir(parents=True, exist_ok=True)
    with (CACHE / "capture.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        result = subprocess.run(
            [str(helper)],
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
    if result.returncode:
        raise ValueError(result.stderr.strip() or "Could not capture the browser URL.")
    return validate_url(result.stdout.strip())


def rex_target():
    """(rex, session_id) of the session the connected Rex app shows.

    A launch from a Rex terminal uses that terminal's session. Raises when the
    Rex app is not running, since there is nowhere to show fai.
    """
    rex = shutil.which("rex", path=SEARCH_PATH)
    if not rex:
        raise ValueError("Cannot find the rex executable.")
    try:
        result = subprocess.run(
            [rex, "--autostart=false", "client", "ls", "--json"],
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
        clients = (
            json.loads(result.stdout).get("clients", [])
            if not result.returncode
            else []
        )
    except (subprocess.SubprocessError, ValueError, AttributeError):
        clients = []
    sessions = [
        session
        for client in clients
        if (client.get("info") or {}).get("kind") == "app"
        and client.get("connection_state") == "connected"
        for session in client.get("session_ids") or []
    ]
    current = os.environ.get("REX_SESSION", "")
    session = current if current in sessions else next(iter(sessions), None)
    if not session or not REX_SESSION_ID.fullmatch(session):
        raise ValueError("The Rex app is not running.")
    return rex, session


def fai_command(rex, session):
    """argv that runs the fai action; the URL goes on stdin, never in argv."""
    return [rex, "do", "-s", session, REX_ACTION, "--args", "-"]


def frontmost():
    """Bundle ID of the frontmost app, or "" if it can't be read."""
    result = subprocess.run(
        [
            "/usr/bin/osascript",
            "-e",
            "id of application (path to frontmost application as text)",
        ],
        capture_output=True,
        text=True,
        timeout=5,
        check=False,
    )
    return result.stdout.strip()


def activate_rex(timeout=3.0, interval=0.05):
    """Bring the Rex app to the front and wait until it is.

    A layer created while Rex is in the background shows in front, but once
    the app activates it gives keyboard focus back to the block it had.
    Created after activation, the layer gets focus as with ctrl+b p.
    """
    subprocess.run(["/usr/bin/open", "-b", REX_BUNDLE], check=False)
    deadline = time.monotonic() + timeout
    while frontmost() != REX_BUNDLE and time.monotonic() < deadline:
        time.sleep(interval)


def open_fai(rex, session, url):
    activate_rex()
    result = subprocess.run(
        fai_command(rex, session),
        input=json.dumps({"url": url}),
        capture_output=True,
        text=True,
        timeout=10,
        check=False,
    )
    if result.returncode:
        raise ValueError("Rex could not open fai: " + result.stderr.strip())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--url", help="Use an explicit URL instead of capturing the browser"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print what would run without opening fai",
    )
    args = parser.parse_args()
    url = validate_url(args.url) if args.url is not None else capture_url()
    rex, session = rex_target()
    if args.dry_run:
        print(
            json.dumps(
                {"argv": fai_command(rex, session), "args": {"url": url}}, indent=2
            )
        )
        return 0
    open_fai(rex, session, url)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        print("Browser URL: " + str(error), file=sys.stderr)
        sys.exit(1)
