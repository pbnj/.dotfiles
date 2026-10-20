"""Offline regression tests; never touch the real tmux server or SketchyBar."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest

PLUGINS = Path(__file__).resolve().parents[1] / ".config/sketchybar/plugins"
ORANGE = "icon.color=0xffff966c"
DIM = "icon.color=0xffa9b1d6"
RED = "icon.color=0xffff757f"

MOCK = """#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys

root = Path(os.environ["FIXTURE"])
data = json.loads((root / "fixture.json").read_text())
args = sys.argv[1:]
if Path(sys.argv[0]).name == "tmux":
    if "list-panes" in args:
        fmt = args[args.index("-F") + 1]
        for pane in data["panes"]:
            for key, value in pane.items():
                fmt = fmt.replace("#{" + key + "}", str(value))
            print(fmt)
            fmt = args[args.index("-F") + 1]
    elif "capture-pane" in args:
        if data.get("close_on_capture"):
            data["popup"] = "off"
            (root / "fixture.json").write_text(json.dumps(data))
        print(data["screens"].get(args[args.index("-t") + 1], ""))
elif Path(sys.argv[0]).name == "defaults":
    if data.get("appearance", "Dark") != "Dark":
        sys.exit(1)
    print("Dark")
else:
    if "--query" in args:
        print(json.dumps({"popup": {"drawing": data["popup"], "items": data.get("items", [])}}))
    else:
        with (root / "calls.jsonl").open("a") as log:
            log.write(json.dumps(args) + "\\n")
"""


class ClaudeStateTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.cache = self.root / ".cache/claude-sketchybar/sessions"
        self.native = self.root / ".claude/sessions"
        self.cache.mkdir(parents=True)
        self.native.mkdir(parents=True)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for command in ("tmux", "sketchybar", "defaults"):
            path = self.bin / command
            path.write_text(MOCK)
            path.chmod(0o755)
        self.env = {
            **os.environ,
            "HOME": str(self.root),
            "PATH": f"{self.bin}:{os.environ['PATH']}",
            "FIXTURE": str(self.root),
            "CONFIG_DIR": str(PLUGINS.parent),
            "BUTTON": "left",
            "SENDER": "claude_update",
            "CLAUDE_SKETCHYBAR_DIR": str(self.cache.parent),
            "CLAUDE_SESSION_DIR": str(self.native),
        }
        self.now = int(time.time() * 1000)
        self.pane = {
            "socket_path": "/tmp/test-tmux/default",
            "pane_id": "%15",
            "pane_pid": 987654321,
            "window_index": 3,
            "window_name": "marmot",
            "pane_current_command": "2.1.303",
            "pane_title": "✳ Marmot Threat Model",
        }
        self.data = {"panes": [self.pane], "screens": {}, "popup": "off"}

    def mod(self, state="idle", age=0, filename="session", **extra):
        record = {
            "state": state,
            "updatedAt": self.now - age * 1000,
            "tmux": {
                "socket": self.pane["socket_path"],
                "pane": self.pane["pane_id"],
            },
            **extra,
        }
        (self.cache / f"{filename}.json").write_text(json.dumps(record))

    def registry(self, status="busy", name="Marmot Threat Model", **extra):
        record = {
            "pid": os.getpid(),
            "name": name,
            "status": status,
            "updatedAt": self.now,
            **extra,
        }
        (self.native / f"{record['pid']}.json").write_text(json.dumps(record))

    def click(self):
        self.env["SENDER"] = "mouse.clicked"
        self.run_plugin("claude.sh")

    def run_plugin(self, script, *args):
        (self.root / "fixture.json").write_text(json.dumps(self.data))
        result = subprocess.run(
            ["bash", str(PLUGINS / script), *args],
            env=self.env,
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, "")
        return result.stdout

    def states(self):
        return [
            json.loads(line)
            for line in self.run_plugin("claude_sessions.sh").splitlines()
        ]

    def pane_state(self):
        return next(s["state"] for s in self.states() if s.get("pane") == "%15")

    def calls(self):
        path = self.root / "calls.jsonl"
        return [json.loads(line) for line in path.read_text().splitlines()]

    def test_usage_group_padding_tracks_visible_windows(self):
        active = {"percentUsed": 10}
        expired = {"percentUsed": 10, "resetsAt": "2000-01-01T00:00:00Z"}
        settings = {}
        for usage, visible in (
            ({}, []),
            ({"five_hour": active}, ["claude.5h"]),
            ({"five_hour": active, "seven_day": active}, ["claude.5h", "claude.7d"]),
            ({"seven_day": active}, ["claude.7d"]),
            ({"five_hour": active}, ["claude.5h"]),
            ({"five_hour": expired, "seven_day": active}, ["claude.7d"]),
            ({"five_hour": expired}, []),
        ):
            with self.subTest(visible=visible, usage=usage):
                (self.cache.parent / "usage.json").write_text(json.dumps(usage))
                self.run_plugin("claude.sh")
                args = self.calls()[-1]
                for index, argument in enumerate(args):
                    if argument != "--set":
                        continue
                    end = next(
                        (
                            i
                            for i in range(index + 2, len(args))
                            if args[i].startswith("--")
                        ),
                        len(args),
                    )
                    settings.setdefault(args[index + 1], {}).update(
                        arg.split("=", 1) for arg in args[index + 2 : end]
                    )
                self.assertEqual(
                    settings["claude"]["icon.padding_right"],
                    "2" if visible else "8",
                )
                for item in ("claude.5h", "claude.7d"):
                    self.assertEqual(
                        settings[item]["drawing"], "on" if item in visible else "off"
                    )
                    if item in visible:
                        self.assertEqual(
                            settings[item]["label.padding_right"],
                            "8" if item == visible[-1] else "2",
                        )

    def test_mod_working_and_blocked_states(self):
        self.mod("working")
        self.assertEqual(self.pane_state(), "working")
        self.mod("blocked")
        self.assertEqual(self.pane_state(), "blocked")

    def test_attached_worker_overrides_idle_launcher(self):
        self.mod("idle", age=7200)
        self.registry()
        self.assertEqual(self.pane_state(), "working")

    def test_live_footer_overrides_idle_launcher_without_registry(self):
        self.mod("idle", age=7200)
        self.data["screens"]["%15"] = (
            "❯\n  ⏵⏵ bypass permissions on · ← 1 agent · esc to interrupt"
        )
        self.assertEqual(self.pane_state(), "working")

    def test_waiting_for_background_subagents_in_tasks_view(self):
        self.mod("idle")
        self.data["screens"]["%15"] = (
            "✻ Waiting for 2 background agents to finish\n"
            "────────────────\n❯\n────────────────\n"
            "  ↑/↓ to select\n❯ ⏺ main\n❯ ◯ general-purpose  Auditing"
        )
        self.assertEqual(self.pane_state(), "working")
        self.data["screens"]["%15"] = "✻ Waiting for 1 background agent to finish\n❯"
        self.assertEqual(self.pane_state(), "working")

    def test_native_busy_covers_subagents_when_mod_says_idle(self):
        self.mod("idle", age=20)
        self.pane["pane_pid"] = os.getpid()
        self.registry(name="different name")
        self.assertEqual(self.pane_state(), "working")

    def test_native_busy_survives_newer_main_turn_idle(self):
        self.mod("idle")
        self.pane["pane_pid"] = os.getpid()
        self.registry(name="different name", updatedAt=self.now - 10000)
        self.assertEqual(self.pane_state(), "working")

    def test_attached_worker_preserves_blocked_mod_state(self):
        self.mod("blocked")
        self.registry()
        self.assertEqual(self.pane_state(), "blocked")

    def test_non_claude_panes_are_not_included(self):
        self.pane["pane_current_command"] = "bash"
        self.assertEqual(self.states(), [])

    def test_agent_count_alone_does_not_mean_working(self):
        self.mod("idle")
        self.data["screens"]["%15"] = "❯\n  ⏵⏵ bypass permissions on · ← 1 agent"
        self.assertEqual(self.pane_state(), "idle")

    def test_ended_worker_returns_to_idle(self):
        self.mod("idle", age=7200)
        self.registry()
        self.assertEqual(self.pane_state(), "working")
        self.registry(status="idle")
        self.assertEqual(self.pane_state(), "idle")

    def test_blocked_mod_wins_over_interrupt_footer(self):
        self.mod("blocked")
        self.data["screens"]["%15"] = "  ⏵⏵ · esc to interrupt"
        self.assertEqual(self.pane_state(), "blocked")

    def test_stale_working_file_and_dead_native_worker_are_ignored(self):
        self.mod("working", age=301)
        self.registry(pid=2147483647)
        self.assertEqual(self.pane_state(), "unknown")

    def test_latest_mod_wins_not_filename_order(self):
        self.mod("working", age=1, filename="a-new")
        self.mod("idle", age=50, filename="z-old")
        self.assertEqual(self.pane_state(), "working")

    def test_ambiguous_worker_names_do_not_guess_attachment(self):
        self.mod("idle")
        self.registry()
        self.registry(pid=os.getppid())
        self.assertEqual(self.pane_state(), "idle")

    def test_only_visible_footer_is_checked(self):
        self.mod("idle")
        self.data["screens"]["%15"] = (
            "✻ Waiting for 1 background agent to finish\n" + "old output\n" * 20
        )
        self.assertEqual(self.pane_state(), "idle")

    def test_malformed_files_are_ignored(self):
        (self.cache / "bad.json").write_text("{")
        (self.native / "bad.json").write_text("{")
        self.assertEqual(self.pane_state(), "unknown")

    def test_no_sessions_is_valid(self):
        self.data["panes"] = []
        self.assertEqual(self.states(), [])

    def test_icon_preserves_mod_state_without_access_to_tmux_server(self):
        self.mod("working")
        self.data["panes"] = []
        self.run_plugin("claude.sh")
        self.assertIn(ORANGE, self.calls()[0])

    def test_non_tmux_working_session_still_colors_icon(self):
        self.mod("working", tmux=None)
        self.run_plugin("claude.sh")
        self.assertIn(ORANGE, self.calls()[0])

    def test_icon_and_open_menu_both_show_working(self):
        self.mod("idle", age=7200)
        self.registry()
        self.data["popup"] = "on"
        self.run_plugin("claude.sh")
        calls = self.calls()
        self.assertIn(ORANGE, calls[0])
        row = calls[-1]
        self.assertIn(ORANGE, row)
        self.assertNotIn("popup.drawing=on", row)
        self.assertNotIn("popup.drawing=off", row)

    def test_orphaned_cache_record_does_not_create_blank_menu_row(self):
        self.mod(tmux={"socket": self.pane["socket_path"], "pane": "%19"})
        self.click()
        labels = [arg for arg in self.calls()[-1] if arg.startswith("label=")]
        self.assertEqual(labels, ["label=3:marmot  Marmot Threat Model"])

    def test_orphaned_cache_record_does_not_hide_empty_menu_message(self):
        self.mod()
        self.data["panes"] = []
        self.click()
        labels = [arg for arg in self.calls()[-1] if arg.startswith("label=")]
        self.assertEqual(labels, ["label=No Claude sessions in tmux"])

    def test_refresh_updates_existing_rows_without_recreating_them(self):
        self.mod("working")
        self.data.update(popup="on", items=["claude.row.0"])
        self.run_plugin("claude.sh")
        args = self.calls()[-1]
        self.assertNotIn("--remove", args)
        self.assertNotIn("--add", args)
        self.assertNotIn("popup.drawing=on", args)
        self.assertNotIn("popup.drawing=off", args)
        self.assertIn(ORANGE, args)

    def test_refresh_adds_only_new_rows(self):
        self.data.update(popup="on", items=["claude.row.0"])
        self.data["panes"].append({**self.pane, "pane_id": "%16", "window_index": 4})
        self.run_plugin("claude.sh")
        args = self.calls()[-1]
        added = [args[i + 2] for i, arg in enumerate(args) if arg == "--add"]
        self.assertEqual(added, ["claude.row.1"])
        self.assertNotIn("--remove", args)
        self.assertNotIn("popup.drawing=on", args)

    def test_refresh_removes_only_disappeared_rows(self):
        self.data.update(popup="on", items=["claude.row.0", "claude.row.1"])
        self.run_plugin("claude.sh")
        args = self.calls()[-1]
        removed = [args[i + 1] for i, arg in enumerate(args) if arg == "--remove"]
        self.assertEqual(removed, ["claude.row.1"])
        self.assertNotIn("--add", args)
        self.assertNotIn("popup.drawing=on", args)

    def test_refresh_does_not_reopen_menu_closed_during_lookup(self):
        self.data.update(popup="on", items=["claude.row.0"], close_on_capture=True)
        self.run_plugin("claude.sh")
        self.assertNotIn("popup.drawing=on", self.calls()[-1])

    def test_refresh_does_not_open_closed_menu(self):
        self.run_plugin("claude.sh")
        args = self.calls()[-1]
        self.assertFalse(
            any(a.startswith(("claude.row.", "popup.drawing")) for a in args)
        )

    def test_click_opens_menu(self):
        self.click()
        args = self.calls()[-1]
        self.assertEqual(args[-2:], ["claude", "popup.drawing=on"])
        self.assertIn("claude.row.0", args)

    def test_window_name_with_separator_keeps_fields(self):
        self.pane["window_name"] = "a|b"
        self.click()
        labels = [arg for arg in self.calls()[-1] if arg.startswith("label=")]
        self.assertEqual(labels, ["label=3:a|b  Marmot Threat Model"])

    def test_click_still_closes_open_menu(self):
        self.data["popup"] = "on"
        self.click()
        self.assertEqual(self.calls(), [["--set", "claude", "popup.drawing=off"]])

    def test_theme_refresh_recolors_open_menu_without_recreating_it(self):
        self.mod("working")
        self.data.update(popup="on", items=["claude.row.0"], appearance="Light")
        self.env["SENDER"] = "theme_refresh"
        self.run_plugin("claude.sh")
        args = self.calls()[-1]
        self.assertIn("icon.color=0xff8a3d17", args)
        self.assertIn("icon.padding_left=8", args)
        self.assertIn("label.padding_right=8", args)
        self.assertNotIn("--add", args)
        self.assertNotIn("--remove", args)
        self.assertFalse(any(arg.startswith("popup.drawing=") for arg in args))

    def test_icon_keeps_blocked_priority(self):
        self.mod("blocked")
        self.run_plugin("claude.sh")
        self.assertIn(RED, self.calls()[0])

    def test_icon_returns_to_idle_when_subagents_finish(self):
        self.mod("idle")
        self.registry(status="idle")
        self.run_plugin("claude.sh")
        self.assertIn(DIM, self.calls()[0])


if __name__ == "__main__":
    unittest.main()
