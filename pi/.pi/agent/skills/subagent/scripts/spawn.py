#!/usr/bin/env python3
"""Spawn an AI subagent in a new tmux window.

Usage:
    ./spawn.py --agent claude --model opus --effort medium --yolo \
        --cwd ~/Projects/github.com/komodohealth/ --prompt "do xyz"
"""

import argparse
import os
import re
import shlex
import subprocess
import sys


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Spawn an AI subagent in a new tmux window"
    )
    parser.add_argument(
        "--agent",
        required=True,
        choices=["claude", "pi", "copilot"],
        help="Agent executable to run",
    )
    parser.add_argument(
        "--model",
        required=True,
        help="Model name/alias to pass to the agent",
    )
    parser.add_argument(
        "--effort",
        choices=["low", "medium", "high", "xhigh", "max"],
        help="Effort level (claude --effort)",
    )
    parser.add_argument(
        "--yolo",
        action="store_true",
        help="Add --dangerously-skip-permissions (claude yolo mode)",
    )
    parser.add_argument(
        "--cwd",
        default="~/Projects/github.com/komodohealth/",
        help="Working directory for the new tmux window",
    )
    parser.add_argument(
        "--prompt",
        required=True,
        help="Task prompt to send to the agent",
    )
    parser.add_argument(
        "--window-name",
        default=None,
        help="Tmux window name (default: derived from prompt)",
    )
    return parser.parse_args(argv)


def build_agent_command(args: argparse.Namespace) -> str:
    agent = "pi" if args.agent == "copilot" else args.agent

    cmd_parts: list[str] = [shlex.quote(agent)]
    cmd_parts.append(shlex.quote("--model"))
    cmd_parts.append(shlex.quote(args.model))
    if args.effort:
        cmd_parts.append(shlex.quote("--effort"))
        cmd_parts.append(shlex.quote(args.effort))
    if args.yolo:
        cmd_parts.append("--dangerously-skip-permissions")
    cmd_parts.append(shlex.quote(args.prompt))

    return " ".join(cmd_parts)


def derive_window_name(prompt: str) -> str:
    first = prompt.split()[0] if prompt else "subagent"
    name = re.sub(r"[^\w\-]", "-", first).lower().strip("-")[:20]
    return name or "subagent"


def spawn(agent_cmd: str, cwd: str, window_name: str) -> None:
    cwd = os.path.expanduser(cwd)
    tmux_cmd = [
        "tmux",
        "new-window",
        "-n",
        window_name,
        "-c",
        cwd,
        agent_cmd,
    ]
    print(" ".join(shlex.quote(str(c)) for c in tmux_cmd), file=sys.stderr)
    subprocess.run(tmux_cmd, check=True)
    print(f"Spawned subagent in tmux window '{window_name}': {agent_cmd}")


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    agent_cmd = build_agent_command(args)
    window_name = args.window_name or derive_window_name(args.prompt)
    spawn(agent_cmd, args.cwd, window_name)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
