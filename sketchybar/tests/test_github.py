"""Offline gh-attention pill tests; never contact GitHub or the real bar."""

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
import subprocess
import sys

root = Path(os.environ["FIXTURE"])
data = json.loads((root / "fixture.json").read_text())
name = Path(sys.argv[0]).name
args = sys.argv[1:]
with (root / "commands.jsonl").open("a") as log:
    log.write(json.dumps([name, *args]) + "\n")
state_file = root / "bar.json"
state = json.loads(state_file.read_text())
if name == "defaults":
    if data.get("appearance", "Dark") != "Dark":
        sys.exit(1)
    print("Dark")
elif name == "timeout":
    sys.exit(subprocess.call(args[2:]))
elif name == "gh":
    if data.get("close_during_fetch"):
        state["popup"]["drawing"] = "off"
        state_file.write_text(json.dumps(state))
    if data.get("error"):
        print("simulated auth/network failure", file=sys.stderr)
        sys.exit(data["error"])
    print(data.get("raw", json.dumps(data["attention"])))
elif name == "sketchybar":
    if args == ["--query", "github"]:
        print(json.dumps(state))
    else:
        with (root / "calls.jsonl").open("a") as log:
            log.write(json.dumps(args) + "\n")
        i = 0
        while i < len(args):
            command = args[i]
            j = next((n for n in range(i + 1, len(args)) if args[n].startswith("--")), len(args))
            values = args[i + 1:j]
            if command == "--add":
                state["popup"]["items"].append(values[1])
            elif command == "--remove":
                state["popup"]["items"].remove(values[0])
                state["settings"].pop(values[0], None)
            elif command == "--set":
                settings = dict(value.split("=", 1) for value in values[1:])
                state["settings"].setdefault(values[0], {}).update(settings)
                if values[0] == "github" and "popup.drawing" in settings:
                    state["popup"]["drawing"] = settings["popup.drawing"]
            i = j
        state_file.write_text(json.dumps(state))
"""


def pr(number, **kwargs):
    return {
        "repo": "owner/project",
        "number": number,
        "title": f"PR {number}",
        "url": f"https://github.com/owner/project/pull/{number}",
        "draft": False,
        "updatedAt": f"2026-10-{number:02d}T12:00:00Z",
        "conflicting": False,
        **kwargs,
    }


class GithubTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for name in ("sketchybar", "gh", "timeout", "defaults", "open"):
            executable = self.bin / name
            executable.write_text(MOCK)
            executable.chmod(0o755)
        (self.root / "bar.json").write_text(
            json.dumps({"popup": {"drawing": "off", "items": []}, "settings": {}})
        )
        self.cache = self.root / "cache"
        self.data = {
            "attention": {"approved": [], "review": [], "feedback": [], "failing": []}
        }
        self.env = {
            **os.environ,
            "PATH": f"{self.bin}:{os.environ['PATH']}",
            "FIXTURE": str(self.root),
            "CONFIG_DIR": str(CONFIG),
            "GITHUB_SKETCHYBAR_CACHE_DIR": str(self.cache),
            "NAME": "github",
        }

    def run_plugin(self, sender="routine", *args):
        (self.root / "fixture.json").write_text(json.dumps(self.data))
        (self.root / "commands.jsonl").write_text("")
        (self.root / "calls.jsonl").write_text("")
        result = subprocess.run(
            ["bash", str(CONFIG / "plugins/github.sh"), *args],
            env={**self.env, "SENDER": sender},
            cwd=self.root,
            capture_output=True,
            text=True,
            timeout=15,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, "")
        self.calls = [
            json.loads(line)
            for line in (self.root / "calls.jsonl").read_text().splitlines()
        ]
        return self.state()["settings"]

    def state(self):
        return json.loads((self.root / "bar.json").read_text())

    def commands(self, name):
        return [
            json.loads(line)[1:]
            for line in (self.root / "commands.jsonl").read_text().splitlines()
            if json.loads(line)[0] == name
        ]

    def cached(self):
        return json.loads((self.cache / "attention.json").read_text())

    def test_union_count_and_priority_with_overlapping_sections(self):
        self.data["attention"] = {
            "approved": [pr(1)],
            "review": [pr(2), pr(3)],
            "feedback": [pr(3), pr(4)],
            "failing": [pr(3), pr(5, draft=True)],
        }
        settings = self.run_plugin()
        self.assertEqual(settings["github"]["label"], "5")
        self.assertEqual(settings["github"]["icon.color"], "0xffff757f")
        self.assertEqual(self.commands("gh"), [["attention", "--all", "--json"]])
        self.assertEqual(self.commands("timeout")[0][:2], ["--kill-after=5s", "90s"])
        self.assertEqual([p["number"] for p in self.cached()["prs"]], [5, 3, 4, 1, 2])
        self.assertEqual(self.state()["popup"]["drawing"], "off")
        settings = self.run_plugin("mouse.clicked")
        self.assertEqual(self.commands("gh"), [])
        self.assertEqual(self.state()["popup"]["drawing"], "on")
        self.assertIn("[draft]", settings["github.row.0"]["label"])
        self.assertEqual(
            settings["github.row.summary"]["label"],
            "CI: 2 · Feedback: 2 · Approved: 1 · Review: 2",
        )
        self.assertEqual(
            [settings[f"github.row.{i}"]["icon"] for i in range(5)],
            ["✘", "✘", "✎", "✔", "◷"],
        )

    def test_empty_success_is_green_and_visible(self):
        settings = self.run_plugin()
        self.assertEqual(settings["github"]["label"], "0")
        self.assertEqual(settings["github"]["icon.color"], "0xffc3e88d")
        settings = self.run_plugin("mouse.clicked")
        self.assertEqual(
            settings["github.row.empty"]["label"], "Nothing needs your attention"
        )

    def test_both_palettes_and_cached_theme_refreshes(self):
        cases = (
            ("review", "0xffffc777", "0xff6b4b16"),
            ("approved", "0xffffc777", "0xff6b4b16"),
            ("feedback", "0xffff966c", "0xff8a3d17"),
            ("failing", "0xffff757f", "0xff982346"),
        )
        for section, dark, light in cases:
            with self.subTest(section=section):
                self.data["appearance"] = "Dark"
                self.data["attention"] = {
                    name: [pr(1)] if name == section else []
                    for name in ("approved", "review", "feedback", "failing")
                }
                settings = self.run_plugin()
                self.assertEqual(settings["github"]["icon.color"], dark)
                self.data["appearance"] = "Light"
                settings = self.run_plugin("theme_refresh")
                self.assertEqual(settings["github"]["icon.color"], light)
                self.assertEqual(self.commands("gh"), [])
                self.assertEqual(self.state()["popup"]["drawing"], "off")

    def test_pagination_wraps_and_keeps_rows_in_order_after_short_last_page(self):
        self.data["attention"]["review"] = [pr(n) for n in range(1, 24)]
        self.run_plugin()
        settings = self.run_plugin("mouse.clicked")
        self.assertIn("project#23", settings["github.row.0"]["label"])
        self.assertIn("page 1/3", settings["github.row.next"]["label"])
        settings = self.run_plugin("mouse.clicked", "page", "2")
        self.assertEqual(self.commands("gh"), [])
        self.assertIn("project#3", settings["github.row.0"]["label"])
        self.assertEqual(settings["github.row.3"]["drawing"], "off")
        self.assertTrue(settings["github.row.next"]["click_script"].endswith("page 0"))
        settings = self.run_plugin("mouse.clicked", "page", "0")
        self.assertEqual(
            self.state()["popup"]["items"],
            [
                "github.row.summary",
                *[f"github.row.{i}" for i in range(10)],
                "github.row.empty",
                "github.row.prev",
                "github.row.next",
                "github.row.refresh",
            ],
        )
        self.assertTrue(settings["github.row.prev"]["click_script"].endswith("page 2"))

    def test_shrinking_results_clamp_page_and_remove_obsolete_rows(self):
        self.data["attention"]["review"] = [pr(n) for n in range(1, 24)]
        self.run_plugin()
        self.run_plugin("mouse.clicked")
        self.run_plugin("mouse.clicked", "page", "2")
        self.data["attention"]["review"] = [pr(1)]
        settings = self.run_plugin("github_refresh")
        self.assertEqual(settings["github"]["label"], "1")
        self.assertEqual((self.cache / "page").read_text().strip(), "0")
        self.assertEqual(settings["github.row.next"]["drawing"], "off")
        self.assertEqual(settings["github.row.1"]["drawing"], "off")
        self.assertEqual(self.state()["popup"]["drawing"], "on")

    def test_network_timeout_or_invalid_json_retains_cache_with_warning(self):
        self.data["attention"]["review"] = [pr(1)]
        self.run_plugin()
        expected = (self.cache / "attention.json").read_text()
        for failure in (
            {"error": 1},
            {"error": 124},
            {"raw": "invalid"},
            {"raw": "{}"},
            {"raw": ""},
        ):
            with self.subTest(failure=failure):
                self.data.pop("error", None)
                self.data.pop("raw", None)
                self.data.update(failure)
                settings = self.run_plugin("github_refresh")
                self.assertEqual(settings["github"]["label"], "1!")
                self.assertEqual((self.cache / "attention.json").read_text(), expected)
                self.assertFalse((self.cache / "refresh.lock").exists())
        self.data.pop("raw")
        settings = self.run_plugin()
        self.assertEqual(settings["github"]["label"], "1")
        self.assertFalse((self.cache / "error").exists())

    def test_initial_failure_is_not_reported_as_zero(self):
        self.data["error"] = 1
        settings = self.run_plugin()
        self.assertEqual(settings["github"]["label"], "!")
        self.assertFalse((self.cache / "attention.json").exists())
        settings = self.run_plugin("mouse.clicked")
        self.assertIn("Refresh failed", settings["github.row.refresh"]["label"])
        self.assertNotEqual(
            settings["github.row.empty"]["label"], "Nothing needs your attention"
        )

    def test_click_close_does_not_fetch_or_modify_rows(self):
        self.run_plugin()
        self.run_plugin("mouse.clicked")
        self.run_plugin("mouse.clicked")
        self.assertEqual(self.calls, [["--set", "github", "popup.drawing=off"]])
        self.assertEqual(self.commands("gh"), [])

    def test_open_theme_refresh_reuses_rows_without_toggling(self):
        self.data["attention"]["review"] = [pr(1)]
        self.run_plugin()
        self.run_plugin("mouse.clicked")
        self.data["appearance"] = "Light"
        settings = self.run_plugin("theme_refresh")
        self.assertEqual(settings["github.row.0"]["icon.color"], "0xff6b4b16")
        for call in self.calls:
            self.assertNotIn("--add", call)
            self.assertNotIn("--remove", call)
            self.assertNotIn("--move", call)
            self.assertFalse(any(s.startswith("popup.drawing=") for s in call))
        self.assertEqual(self.commands("gh"), [])

    def test_refresh_finishing_after_popup_closes_does_not_reopen(self):
        self.run_plugin()
        self.run_plugin("mouse.clicked")
        self.data["close_during_fetch"] = True
        self.run_plugin("github_refresh")
        self.assertEqual(self.state()["popup"]["drawing"], "off")

    def test_active_lock_skips_duplicate_fetch_and_stale_lock_is_reclaimed(self):
        self.run_plugin()
        lock = self.cache / "refresh.lock"
        lock.mkdir()
        self.run_plugin("system_woke")
        self.assertEqual(self.commands("gh"), [])
        os.utime(lock, (1, 1))
        self.run_plugin("system_woke")
        self.assertEqual(len(self.commands("gh")), 1)
        self.assertFalse(lock.exists())

    def test_titles_are_literal_and_only_valid_pr_urls_can_be_opened(self):
        title = 'A "quote"; $(touch NOT_EXECUTED) \\ path\nnew\tline'
        self.data["attention"]["review"] = [pr(1, title=title)]
        self.run_plugin()
        settings = self.run_plugin("mouse.clicked")
        self.assertEqual(
            settings["github.row.0"]["label"],
            "project#1 · " + title.replace("\n", " ").replace("\t", " "),
        )
        action = settings["github.row.0"]["click_script"]
        result = subprocess.run(
            ["bash", "-c", action],
            env=self.env,
            cwd=self.root,
            capture_output=True,
            text=True,
            check=False,
            timeout=10,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            self.commands("open"), [["https://github.com/owner/project/pull/1"]]
        )
        self.assertFalse((self.root / "NOT_EXECUTED").exists())
        expected = (self.cache / "attention.json").read_text()
        self.data["attention"]["review"] = [pr(1, url="https://evil.test/'; touch bad")]
        settings = self.run_plugin()
        self.assertEqual(settings["github"]["label"], "1!")
        self.assertEqual((self.cache / "attention.json").read_text(), expected)


if __name__ == "__main__":
    unittest.main()
