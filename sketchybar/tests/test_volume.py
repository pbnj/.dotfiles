"""Offline audio popup tests; never query or change real audio devices."""

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
if name == "osascript":
    if data.get("volume_error"):
        sys.exit(1)
    print(data.get("volume", 63), str(data.get("muted", False)).lower(), sep="|")
elif name == "system_profiler":
    if data.get("audio_error"):
        print("invalid json")
        sys.exit(1)
    print(json.dumps(data.get("audio", {})))
elif name == "sketchybar":
    if args == ["--query", "volume"]:
        print(json.dumps({"popup": {"drawing": data.get("popup", "off")}}))
    else:
        with (root / "calls.jsonl").open("a") as log:
            log.write(json.dumps(args) + "\n")
"""


class VolumeTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for command in ("sketchybar", "osascript", "system_profiler"):
            executable = self.bin / command
            executable.write_text(MOCK)
            executable.chmod(0o755)
        self.data = {
            "audio": {
                "SPAudioDataType": [
                    {
                        "_items": [
                            {
                                "_name": "System alerts only",
                                "coreaudio_default_audio_system_device": "spaudio_yes",
                            },
                            {
                                "_name": "Headphones",
                                "coreaudio_default_audio_output_device": "spaudio_yes",
                            },
                            {
                                "_name": "Desk microphone",
                                "coreaudio_default_audio_input_device": "spaudio_yes",
                            },
                        ]
                    }
                ]
            }
        }

    def run_plugin(self, sender="routine", info=""):
        (self.root / "fixture.json").write_text(json.dumps(self.data))
        for filename in ("calls.jsonl", "commands.jsonl"):
            (self.root / filename).unlink(missing_ok=True)
        result = subprocess.run(
            ["bash", str(CONFIG / "plugins/volume.sh")],
            env={
                **os.environ,
                "PATH": f"{self.bin}:{os.environ['PATH']}",
                "FIXTURE": str(self.root),
                "CONFIG_DIR": str(CONFIG),
                "SENDER": sender,
                "INFO": info,
                "NAME": "volume",
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

    def commands(self):
        return [
            json.loads(line)[0]
            for line in (self.root / "commands.jsonl").read_text().splitlines()
        ]

    def test_icon_tracks_volume_but_percentage_only_appears_in_popup(self):
        for volume, icon in (
            (0, "󰖁"),
            (1, "󰕿"),
            (29, "󰕿"),
            (30, "󰖀"),
            (59, "󰖀"),
            (60, "󰕾"),
            (100, "󰕾"),
        ):
            with self.subTest(volume=volume):
                self.data["volume"] = volume
                settings = self.run_plugin("volume_change", str(volume))
                self.assertEqual(settings["volume"]["icon"], icon)
                self.assertEqual(settings["volume"]["label.drawing"], "off")
                self.assertNotIn("label", settings["volume"])
                self.assertEqual(
                    settings["volume.level"]["label"], f"Volume: {volume}%"
                )
                self.assertNotIn("system_profiler", self.commands())

    def test_click_opens_popup_with_current_input_and_output(self):
        settings = self.run_plugin("mouse.clicked")
        self.assertEqual(settings["volume"]["popup.drawing"], "on")
        self.assertEqual(settings["volume.output"]["label"], "Output: Headphones")
        self.assertEqual(settings["volume.input"]["label"], "Input: Desk microphone")
        self.assertEqual(settings["volume.level"]["label"], "Volume: 63%")
        self.assertNotIn("--add", self.args)
        self.assertNotIn("--remove", self.args)

    def test_click_closes_open_popup_without_querying_audio(self):
        self.data["popup"] = "on"
        self.run_plugin("mouse.clicked")
        self.assertEqual(self.args, ["--set", "volume", "popup.drawing=off"])
        self.assertNotIn("osascript", self.commands())
        self.assertNotIn("system_profiler", self.commands())

    def test_open_popup_refreshes_device_names_without_toggling(self):
        self.data["popup"] = "on"
        devices = self.data["audio"]["SPAudioDataType"][0]["_items"]
        for name in ("Headphones", 'Monitor\'s "speakers"; $(not-a-command)'):
            devices[1]["_name"] = name
            settings = self.run_plugin()
            self.assertEqual(settings["volume.output"]["label"], f"Output: {name}")
            self.assertNotIn("popup.drawing", settings["volume"])
            self.assertNotIn("--add", self.args)
            self.assertNotIn("--remove", self.args)

    def test_refreshes_do_not_open_a_closed_popup(self):
        for sender in ("routine", "theme_refresh", "system_woke"):
            with self.subTest(sender=sender):
                settings = self.run_plugin(sender)
                self.assertNotIn("popup.drawing", settings["volume"])
                self.assertNotIn("system_profiler", self.commands())

    def test_muted_output_keeps_percentage_and_uses_mute_icon(self):
        self.data["muted"] = True
        settings = self.run_plugin()
        self.assertEqual(settings["volume"]["icon"], "󰖁")
        self.assertEqual(settings["volume.level"]["label"], "Volume: 63% (muted)")

    def test_volume_query_failure_uses_valid_event_or_unavailable(self):
        self.data["volume_error"] = True
        settings = self.run_plugin("volume_change", "42")
        self.assertEqual(settings["volume.level"]["label"], "Volume: 42%")
        for info in ("", "-1", "101", "invalid"):
            with self.subTest(info=info):
                settings = self.run_plugin("volume_change", info)
                self.assertEqual(
                    settings["volume.level"]["label"], "Volume: Unavailable"
                )

    def test_missing_devices_and_query_failure_clear_old_source_names(self):
        self.data["popup"] = "on"
        self.run_plugin()
        for audio_error in (False, True):
            with self.subTest(audio_error=audio_error):
                self.data["audio"] = {"SPAudioDataType": []}
                self.data["audio_error"] = audio_error
                settings = self.run_plugin()
                self.assertEqual(
                    settings["volume.output"]["label"], "Output: Unavailable"
                )
                self.assertEqual(
                    settings["volume.input"]["label"], "Input: Unavailable"
                )


if __name__ == "__main__":
    unittest.main()
