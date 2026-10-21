"""Offline battery dropdown tests; never query or change real power settings."""

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
    print("Dark")
elif name == "pmset":
    if data.get("error"):
        sys.exit(1)
    print(data["battery"])
elif name == "sketchybar":
    if args == ["--query", "battery"]:
        print(json.dumps({"popup": {"drawing": data.get("popup", "off")}}))
    else:
        with (root / "calls.jsonl").open("a") as log:
            log.write(json.dumps(args) + "\n")
"""


class BatteryTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for command in ("defaults", "sketchybar", "pmset"):
            executable = self.bin / command
            executable.write_text(MOCK)
            executable.chmod(0o755)
        self.data = {
            "battery": (
                "Now drawing from 'Battery Power'\n"
                " -InternalBattery-0 (id=123)\t68%; discharging; "
                "4:44 remaining present: true"
            )
        }

    def run_plugin(self, sender="routine"):
        (self.root / "fixture.json").write_text(json.dumps(self.data))
        for filename in ("calls.jsonl", "commands.jsonl"):
            (self.root / filename).unlink(missing_ok=True)
        result = subprocess.run(
            ["bash", str(CONFIG / "plugins/battery.sh")],
            env={
                **os.environ,
                "PATH": f"{self.bin}:{os.environ['PATH']}",
                "FIXTURE": str(self.root),
                "CONFIG_DIR": str(CONFIG),
                "SENDER": sender,
                "NAME": "battery",
            },
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, "")
        calls = [
            json.loads(line)
            for line in (self.root / "calls.jsonl").read_text().splitlines()
        ]
        self.assertEqual(len(calls), 1)
        self.args = calls[0]
        settings = {}
        for index, argument in enumerate(self.args):
            if argument != "--set":
                continue
            end = next(
                (
                    i
                    for i in range(index + 2, len(self.args))
                    if self.args[i].startswith("--")
                ),
                len(self.args),
            )
            settings.setdefault(self.args[index + 1], {}).update(
                arg.split("=", 1) for arg in self.args[index + 2 : end]
            )
        return settings

    def test_click_opens_dropdown_with_charge_source_status_and_time(self):
        settings = self.run_plugin("mouse.clicked")
        self.assertEqual(settings["battery"]["popup.drawing"], "on")
        self.assertEqual(settings["battery"]["label.drawing"], "off")
        self.assertEqual(settings["battery"]["label"], "")
        self.assertEqual(settings["battery.level"]["label"], "Charge: 68%")
        self.assertEqual(settings["battery.source"]["label"], "Power source: Battery")
        self.assertEqual(settings["battery.status"]["label"], "Status: Discharging")
        self.assertEqual(settings["battery.time"]["label"], "Time remaining: 4:44")
        self.assertNotIn("--add", self.args)
        self.assertNotIn("--remove", self.args)

    def test_click_closes_open_dropdown_without_querying_power(self):
        self.data["popup"] = "on"
        self.run_plugin("mouse.clicked")
        self.assertEqual(self.args, ["--set", "battery", "popup.drawing=off"])
        commands = [
            json.loads(line)[0]
            for line in (self.root / "commands.jsonl").read_text().splitlines()
        ]
        self.assertNotIn("pmset", commands)

    def test_refreshes_update_rows_without_opening_or_toggling(self):
        for popup in ("on", "off"):
            self.data["popup"] = popup
            for sender in (
                "routine",
                "theme_refresh",
                "system_woke",
                "power_source_change",
            ):
                with self.subTest(popup=popup, sender=sender):
                    settings = self.run_plugin(sender)
                    self.assertEqual(settings["battery.level"]["label"], "Charge: 68%")
                    self.assertNotIn("popup.drawing", settings["battery"])
                    self.assertNotIn("--add", self.args)
                    self.assertNotIn("--remove", self.args)

    def test_charging_shows_battery_with_bolt_and_reports_time_to_full(self):
        self.data["battery"] = (
            "Now drawing from 'AC Power'\n"
            " -InternalBattery-0 42%; charging; 1:23 remaining present: true"
        )
        settings = self.run_plugin("mouse.clicked")
        self.assertEqual(settings["battery"]["icon"], "󰂈")
        self.assertEqual(settings["battery.level"]["icon"], "")
        self.assertEqual(
            settings["battery.source"]["label"], "Power source: Power Adapter"
        )
        self.assertEqual(settings["battery.status"]["label"], "Status: Charging")
        self.assertEqual(settings["battery.time"]["label"], "Time to full: 1:23")

    def test_charging_icons_follow_each_ten_percent_boundary(self):
        for percentage, icon in (
            (0, "󰢟"),
            (9, "󰢟"),
            (10, "󰢜"),
            (19, "󰢜"),
            (20, "󰂆"),
            (29, "󰂆"),
            (30, "󰂇"),
            (39, "󰂇"),
            (40, "󰂈"),
            (49, "󰂈"),
            (50, "󰢝"),
            (59, "󰢝"),
            (60, "󰂉"),
            (69, "󰂉"),
            (70, "󰢞"),
            (79, "󰢞"),
            (80, "󰂊"),
            (89, "󰂊"),
            (90, "󰂋"),
            (99, "󰂋"),
            (100, "󰂅"),
        ):
            for state in ("charging", "finishing charge"):
                with self.subTest(percentage=percentage, state=state):
                    self.data["battery"] = (
                        "Now drawing from 'AC Power'\n"
                        f" -InternalBattery-0 {percentage}%; {state};"
                    )
                    settings = self.run_plugin()
                    self.assertEqual(settings["battery"]["icon"], icon)
                    self.assertEqual(
                        settings["battery.level"]["label"], f"Charge: {percentage}%"
                    )
                    self.assertNotIn("popup.drawing", settings["battery"])

    def test_held_and_fully_charged_states_do_not_show_a_false_time_estimate(self):
        for percentage, state, label in (
            (80, "not charging", "Not charging"),
            (100, "charged", "Fully charged"),
        ):
            with self.subTest(state=state):
                self.data["battery"] = (
                    f"Now drawing from 'AC Power'\n"
                    f" -InternalBattery-0 {percentage}%; {state}; 0:00 remaining"
                )
                settings = self.run_plugin()
                self.assertEqual(
                    settings["battery.status"]["label"], f"Status: {label}"
                )
                self.assertEqual(
                    settings["battery.time"]["label"], "Time estimate: Unavailable"
                )
                self.assertEqual(settings["battery"]["icon"], "")

    def test_power_transitions_update_icon_without_opening_dropdown(self):
        for source, state, icon in (
            ("AC Power", "charging", "󰂈"),
            ("AC Power", "finishing charge", "󰂈"),
            ("AC Power", "not charging", ""),
            ("AC Power", "discharging", ""),
            ("AC Power", "unknown", ""),
            ("Battery Power", "discharging", ""),
        ):
            with self.subTest(source=source, state=state):
                self.data["battery"] = (
                    f"Now drawing from '{source}'\n"
                    f" -InternalBattery-0 42%; {state}; 1:23 remaining"
                )
                settings = self.run_plugin("power_source_change")
                self.assertEqual(settings["battery"]["icon"], icon)
                self.assertEqual(settings["battery.level"]["icon"], "")
                self.assertNotIn("popup.drawing", settings["battery"])

    def test_no_estimate_is_reported_as_calculating(self):
        self.data["battery"] = (
            "Now drawing from 'Battery Power'\n"
            " -InternalBattery-0 50%; discharging; (no estimate) present: true"
        )
        settings = self.run_plugin()
        self.assertEqual(
            settings["battery.time"]["label"], "Time estimate: Calculating…"
        )

    def test_missing_invalid_and_failed_power_queries_clear_stale_charge(self):
        for output in (
            "",
            "Now drawing from 'AC Power'",
            "Now drawing from 'AC Power'\n101%; charging;",
            "Now drawing from 'AC Power'\ncharging;",
            "101%; charged;",
            "garbage",
        ):
            self.data["battery"] = output
            for error in (False, True):
                with self.subTest(output=output, error=error):
                    self.data["error"] = error
                    settings = self.run_plugin("mouse.clicked")
                    self.assertEqual(settings["battery"]["icon"], "")
                    self.assertEqual(
                        settings["battery.level"]["label"], "Charge: Unavailable"
                    )
                    self.assertEqual(settings["battery"]["popup.drawing"], "on")


if __name__ == "__main__":
    unittest.main()
