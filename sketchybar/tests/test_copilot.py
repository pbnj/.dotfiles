"""Offline native Copilot process detection tests."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

CONFIG = Path(__file__).resolve().parents[1] / ".config/sketchybar"
MOCK = r"""#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys

root = Path(os.environ["FIXTURE"])
data = json.loads((root / "fixture.json").read_text())
name = Path(sys.argv[0]).name
args = sys.argv[1:]
with (root / "commands.jsonl").open("a") as log:
    log.write(json.dumps([name, *args]) + "\n")
if name == "defaults":
    if data.get("appearance", "Dark") == "Dark":
        print("Dark")
    else:
        sys.exit(1)
elif name == "pgrep":
    assert args == ["-u", str(os.getuid()), "-x", "copilot"], args
    if data.get("error"):
        sys.exit(2)
    found = [
        process for process in data.get("processes", [])
        if process["uid"] == os.getuid() and process["name"] == "copilot"
    ]
    if found:
        print("123")
        sys.exit(0)
    sys.exit(1)
elif name == "sketchybar":
    with (root / "calls.jsonl").open("a") as log:
        log.write(json.dumps(args) + "\n")
elif name == "copilot":
    sys.exit("Never launch Copilot from the status plugin")
"""


class CopilotTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for command in ("defaults", "sketchybar", "pgrep", "copilot"):
            executable = self.bin / command
            executable.write_text(MOCK)
            executable.chmod(0o755)
        self.data = {}

    def run_plugin(self, sender="routine", expected_status=0):
        (self.root / "fixture.json").write_text(json.dumps(self.data))
        for filename in ("calls.jsonl", "commands.jsonl"):
            (self.root / filename).unlink(missing_ok=True)
        result = subprocess.run(
            ["bash", str(CONFIG / "plugins/copilot.sh")],
            env={
                **os.environ,
                "PATH": f"{self.bin}:{os.environ['PATH']}",
                "FIXTURE": str(self.root),
                "CONFIG_DIR": str(CONFIG),
                "SENDER": sender,
                "NAME": "copilot",
            },
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
        self.assertEqual(result.returncode, expected_status, result.stderr)
        self.assertEqual(result.stderr, "")
        log = self.root / "calls.jsonl"
        calls = (
            [json.loads(line) for line in log.read_text().splitlines()]
            if log.exists()
            else []
        )
        commands = [
            json.loads(line)[0]
            for line in (self.root / "commands.jsonl").read_text().splitlines()
        ]
        self.assertNotIn("copilot", commands)
        return calls

    def test_hidden_with_no_sessions(self):
        self.assertIn("drawing=off", self.run_plugin()[0])

    def test_visible_for_one_or_more_current_user_native_processes(self):
        for count in (1, 3):
            self.data["processes"] = [
                {"uid": os.getuid(), "name": "copilot"} for _ in range(count)
            ]
            with self.subTest(count=count):
                calls = self.run_plugin()
                self.assertEqual(len(calls), 1)
                self.assertIn("drawing=on", calls[0])

    def test_other_users_editor_extensions_and_command_mentions_do_not_count(self):
        self.data["processes"] = [
            {"uid": os.getuid() + 1, "name": "copilot"},
            {"uid": os.getuid(), "name": "copilot-language-server"},
            {"uid": os.getuid(), "name": "node /extensions/github.copilot/index.js"},
            {"uid": os.getuid(), "name": "bash -c echo copilot"},
        ]
        self.assertIn("drawing=off", self.run_plugin()[0])

    def test_last_exit_hides_the_pill(self):
        self.data["processes"] = [{"uid": os.getuid(), "name": "copilot"}]
        self.assertIn("drawing=on", self.run_plugin()[0])
        self.data["processes"] = []
        self.assertIn("drawing=off", self.run_plugin()[0])

    def test_wake_and_theme_refresh_use_the_current_palette(self):
        self.data["processes"] = [{"uid": os.getuid(), "name": "copilot"}]
        for appearance, accent in (("Dark", "0xff82aaff"), ("Light", "0xff244c99")):
            self.data["appearance"] = appearance
            for sender in ("routine", "system_woke", "theme_refresh"):
                with self.subTest(appearance=appearance, sender=sender):
                    args = self.run_plugin(sender)[0]
                    self.assertIn("drawing=on", args)
                    self.assertIn("icon.color=" + accent, args)

    def test_discovery_failure_is_not_reported_as_no_session(self):
        self.data["error"] = True
        self.assertEqual(self.run_plugin(expected_status=2), [])


if __name__ == "__main__":
    unittest.main()
