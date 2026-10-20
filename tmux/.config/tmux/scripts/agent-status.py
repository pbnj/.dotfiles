#!/usr/bin/env python3
"""Refresh per-window agent states for tmux's cached #() status job."""

import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

RANK = {"idle": 0, "working": 1, "blocked": 2}
STALE_MS = 300_000


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


def claude_sessions(socket):
    # Reuse SketchyBar's resolver for daemon-owned workers and attached panes.
    # It is just a shell library; the SketchyBar service need not be running.
    helper = Path(
        os.environ.get(
            "TMUX_AGENT_CLAUDE_HELPER",
            str(Path.home() / ".config/sketchybar/plugins/claude_sessions.sh"),
        )
    )
    if not helper.is_file():
        return
    try:
        result = subprocess.run(
            ["bash", str(helper)],
            # Plain tmux calls inside the resolver must use THIS server.
            env={**os.environ, "TMUX": f"{socket},0,0"},
            capture_output=True,
            text=True,
            check=True,
            timeout=3,
        )
    except (OSError, subprocess.SubprocessError):
        return
    for line in result.stdout.splitlines():
        try:
            record = json.loads(line)
            if isinstance(record, dict) and record.get("source") == "pane":
                yield record
        except ValueError:
            continue


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
