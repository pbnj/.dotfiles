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
            yield record


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
    for record in json_records(directory / "sessions"):
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
            }
        )

    # Native busy includes work delegated to subagents. Only trust records
    # whose process is still alive; timestamps are not heartbeats when idle.
    native = []
    registry = Path(
        os.environ.get("CLAUDE_SESSION_DIR", str(Path.home() / ".claude/sessions"))
    )
    for record in json_records(registry):
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
        yield {"socket": pane_socket, "pane": pane, "state": state}


def refresh(socket):
    windows = {}
    for line in tmux(
        socket, "list-windows", "-a", "-F", "#{window_id}\t#{@agent_state}"
    ).splitlines():
        window, _, state = line.partition("\t")
        if re.fullmatch(r"@[0-9]+", window):
            windows[window] = state

    panes = {}
    has_claude = False
    for line in tmux(
        socket,
        "list-panes",
        "-a",
        "-F",
        "#{pane_id}\t#{window_id}\t#{pane_current_command}",
    ).splitlines():
        fields = line.split("\t")
        if len(fields) != 3:
            continue
        pane, window, command = fields
        if re.fullmatch(r"%[0-9]+", pane) and window in windows:
            panes[pane] = window
            has_claude |= command == "claude" or bool(
                re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", command)
            )

    states = {}

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
        if window and RANK[state] > RANK.get(states.get(window), -1):
            states[window] = state

    for record in pi_sessions(time.time() * 1000):
        add(record)
    if has_claude:
        for record in claude_sessions(socket):
            add(record)

    commands = []
    for window, previous in windows.items():
        state = states.get(window, "")
        if state == previous:
            continue
        if commands:
            commands.append(";")
        if state:
            commands.extend(["set-option", "-w", "-t", window, "@agent_state", state])
        else:
            commands.extend(["set-option", "-wu", "-t", window, "@agent_state"])
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
