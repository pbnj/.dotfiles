#!/usr/bin/env python3
"""Refresh per-window agent states for tmux's cached #() status job."""

import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

RANK = {"idle": 0, "working": 1, "blocked": 2}
STALE_MS = 300_000
# A gh-pr-watch snapshot is live while its poll keeps rewriting it. Allow a few
# missed polls and the gap while Claude re-arms an expired Monitor.
PR_GRACE_S = 180
# Claude's footer while a turn runs, or waits on background subagents.
CLAUDE_FOOTER = re.compile(
    r"^\s+(esc to interrupt|.* · esc to interrupt)(\s|$)"
    r"|^[✻✽✶✳✢·*]\s+Waiting for [1-9][0-9]* background agents? to finish"
)


def tmux(socket, *args):
    return subprocess.run(
        ["tmux", "-S", socket, *args],
        capture_output=True,
        text=True,
        check=True,
        timeout=3,
    ).stdout


def pi_sessions(now):
    directory = Path(
        os.environ.get(
            "PI_SKETCHYBAR_SESSION_DIR",
            str(Path.home() / ".cache/pi-sketchybar/sessions"),
        )
    )
    for file in directory.glob("*.json"):
        try:
            record = json.loads(file.read_text())
            if not isinstance(record, dict):
                continue
            pid, updated = record.get("pid"), record.get("updatedAt")
            if type(pid) is not int or not 0 < pid <= 2**31 - 1:
                continue
            if type(updated) not in (int, float) or not 0 <= now - updated <= STALE_MS:
                continue
            if not isinstance(record.get("state"), str) or record["state"] not in RANK:
                continue
            try:
                os.kill(pid, 0)
            except PermissionError:
                pass  # Alive, but owned by another user.
            yield record
        except (OSError, ValueError):
            continue


def json_records(directory):
    # Sorted like a shell glob, so ties in latest() resolve the same way.
    for file in sorted(directory.glob("*.json")):
        try:
            record = json.loads(file.read_text())
        except (OSError, ValueError):
            continue
        if isinstance(record, dict):
            yield file, record


def watched_prs(now):
    """Count the PRs each Claude session watches with the gh skill's gh-pr-watch.

    The watch rewrites ${XDG_CACHE_HOME:-~/.cache}/gh-pr/<owner>/<name>/<branch>/
    <number>.json every poll and names the session running it. A snapshot whose
    watch stopped (Monitor expired, session gone) just stops being refreshed.
    """
    root = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache")
    counts = {}
    # The branch is percent-encoded, so every snapshot sits at the same depth.
    for file in (root / "gh-pr").glob("*/*/*/*.json"):
        try:
            record = json.loads(file.read_text())
        except (OSError, ValueError):
            continue
        if not isinstance(record, dict) or record.get("state") not in (
            "open",
            "draft",
            "merged",
        ):
            continue
        fetched, interval, watcher = (
            record.get("fetched_at"),
            record.get("interval"),
            record.get("watcher"),
        )
        if type(fetched) not in (int, float) or type(interval) is not int:
            continue
        if not -60 <= now - fetched <= max(3 * interval, PR_GRACE_S):
            continue
        session = watcher.get("claude_session") if isinstance(watcher, dict) else None
        if isinstance(session, str) and session:
            counts[session] = counts.get(session, 0) + 1
    return counts


def latest(records):
    # Like jq's sort_by(.updatedAt) | last: ties go to the later record.
    records = sorted(records, key=lambda record: record["updatedAt"])
    return records[-1] if records else None


def claude_sessions(socket):
    # A tmux client can attach to a daemon-owned Claude worker, so the pane's
    # mod file is not necessarily the session currently displayed in it.
    now = int(time.time())
    mods = []
    directory = Path(
        os.environ.get(
            "CLAUDE_SKETCHYBAR_DIR", str(Path.home() / ".cache/claude-sketchybar")
        )
    )
    for file, record in json_records(directory / "sessions"):
        state, updated, location = (
            record.get("state"),
            record.get("updatedAt"),
            record.get("tmux") or {},
        )
        if type(updated) not in (int, float) or not isinstance(location, dict):
            continue
        if state != "idle" and not (
            state in ("working", "blocked") and now - updated / 1000 <= 300
        ):
            continue
        mods.append(
            {
                "state": state,
                "updatedAt": updated,
                "socket": location.get("socket"),
                "pane": location.get("pane"),
                "session": file.stem,
            }
        )

    # Native busy includes work delegated to subagents. Only trust records
    # whose process is still alive; timestamps are not heartbeats when idle.
    native = []
    registry = Path(
        os.environ.get("CLAUDE_SESSION_DIR", str(Path.home() / ".claude/sessions"))
    )
    for _, record in json_records(registry):
        pid, status, updated = (
            record.get("pid"),
            record.get("status"),
            record.get("updatedAt"),
        )
        if type(pid) is not int or not 0 < pid <= 2**31 - 1:
            continue
        try:
            os.kill(pid, 0)
        except OSError:
            continue  # Like `kill -0`: another user's process counts as gone.
        state = "working" if status == "busy" else "idle" if status == "idle" else ""
        if state:
            native.append(
                {
                    "state": state,
                    "pid": pid,
                    "name": record.get("name"),
                    "session": record.get("sessionId"),
                    "updatedAt": updated if type(updated) in (int, float) else 0,
                }
            )

    # Fields are split on the unit separator: titles may hold any printable
    # character.
    try:
        listing = tmux(
            socket,
            "list-panes",
            "-a",
            "-F",
            "#{socket_path}\x1f#{pane_id}\x1f#{pane_pid}\x1f#{pane_current_command}\x1f#{pane_title}",
        )
    except (OSError, subprocess.SubprocessError):
        return
    for line in listing.split("\n"):
        fields = line.split("\x1f", 4)
        if len(fields) != 5 or not fields[2].isdecimal():
            continue
        pane_socket, pane, pid, command, title = fields
        if command != "claude" and not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", command):
            continue
        pid, title = int(pid), re.sub(r"^[\W_]+", "", title)

        # Read only the visible footer, never scrollback. Attached workers have
        # no TMUX variables, and /tasks can hide the usual interrupt hint while
        # the main turn waits for background subagents.
        try:
            screen = tmux(socket, "capture-pane", "-p", "-t", pane).splitlines()
        except (OSError, subprocess.SubprocessError):
            screen = []
        working = any(CLAUDE_FOOTER.search(row) for row in screen[-16:])

        mod = latest(
            m for m in mods if m["socket"] == pane_socket and m["pane"] == pane
        )
        owner = latest(n for n in native if n["pid"] == pid)
        # A worker may have been resumed/compacted under a different session
        # id. Its current name matches the title of the attached pane. Do not
        # guess when multiple live workers share that name.
        attached = [n for n in native if n["name"] and n["name"] == title]
        if len(attached) == 1:
            base = attached[0]
        elif owner and owner["state"] == "working":
            base = owner
        else:
            base = latest(record for record in (mod, owner) if record)

        if "blocked" in (mod and mod["state"], base and base["state"]):
            state = "blocked"
        elif working:
            state = "working"
        elif base:
            state = base["state"]
        else:
            continue  # Unknown is not idle.
        # Every session id that may be the one in this pane, to match the
        # watcher a PR snapshot names.
        sessions = sorted(
            {
                record["session"]
                for record in (mod, owner, *attached[:1])
                if record and isinstance(record["session"], str) and record["session"]
            }
        )
        yield {
            "socket": pane_socket,
            "pane": pane,
            "state": state,
            "sessions": sessions,
        }


def refresh(socket):
    windows = {}
    for line in tmux(
        socket,
        "list-windows",
        "-a",
        "-F",
        "#{window_id}\t#{@agent_state}\t#{@agent_prs}",
    ).splitlines():
        window, _, options = line.partition("\t")
        state, _, prs = options.partition("\t")
        if re.fullmatch(r"@[0-9]+", window):
            windows[window] = {"@agent_state": state, "@agent_prs": prs}

    panes = {}
    # A pane's own @pane_prs; a separate name because pane options fall back to
    # the window's, so #{@agent_prs} cannot tell a pane's count from its window's.
    pane_prs = {}
    has_claude = False
    for line in tmux(
        socket,
        "list-panes",
        "-a",
        "-F",
        "#{pane_id}\t#{window_id}\t#{pane_current_command}\t#{@pane_prs}",
    ).splitlines():
        fields = line.split("\t")
        if len(fields) == 3:
            fields.append("")
        if len(fields) != 4:
            continue
        pane, window, command, prs = fields
        if re.fullmatch(r"%[0-9]+", pane) and window in windows:
            panes[pane] = window
            pane_prs[pane] = prs
            has_claude |= command == "claude" or bool(
                re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", command)
            )

    states = {}
    sessions = {}
    pane_sessions = {}

    def add(record):
        location = record.get("tmux") if "tmux" in record else record
        state = record.get("state")
        if (
            not isinstance(location, dict)
            or not isinstance(state, str)
            or state not in RANK
        ):
            return
        source_socket, pane = location.get("socket"), location.get("pane")
        if not isinstance(source_socket, str) or not isinstance(pane, str):
            return
        try:
            if os.path.realpath(source_socket) != os.path.realpath(socket):
                return
        except (OSError, ValueError):
            return
        window = panes.get(pane)
        if not window:
            return
        if RANK[state] > RANK.get(states.get(window), -1):
            states[window] = state
        ids = record.get("sessions")
        if isinstance(ids, list):
            ids = {id for id in ids if isinstance(id, str)}
            sessions.setdefault(window, set()).update(ids)
            pane_sessions.setdefault(pane, set()).update(ids)

    for record in pi_sessions(time.time() * 1000):
        add(record)
    if has_claude:
        for record in claude_sessions(socket):
            add(record)
    watched = watched_prs(time.time()) if sessions else {}

    commands = []
    for window, previous in windows.items():
        prs = sum(watched.get(id, 0) for id in sessions.get(window, ()))
        current = {
            "@agent_state": states.get(window, ""),
            "@agent_prs": str(prs) if prs else "",
        }
        for option, value in current.items():
            if value == previous[option]:
                continue
            if commands:
                commands.append(";")
            if value:
                commands.extend(["set-option", "-w", "-t", window, option, value])
            else:
                commands.extend(["set-option", "-wu", "-t", window, option])
    for pane, previous in pane_prs.items():
        prs = sum(watched.get(id, 0) for id in pane_sessions.get(pane, ()))
        value = str(prs) if prs else ""
        if value == previous:
            continue
        if commands:
            commands.append(";")
        if value:
            commands.extend(["set-option", "-p", "-t", pane, "@pane_prs", value])
        else:
            commands.extend(["set-option", "-pu", "-t", pane, "@pane_prs"])
    if commands:
        tmux(socket, *commands)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(2)
    try:
        refresh(sys.argv[1])
    except (OSError, subprocess.SubprocessError):
        # A server/window can disappear while tmux's asynchronous job is running.
        # Never print diagnostics into the status-left format.
        pass
