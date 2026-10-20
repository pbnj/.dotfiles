"""Offline Wi-Fi tests; never change the real network or system appearance."""

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
if name == "defaults":
    if data["appearance"] == "Dark":
        print("Dark")
    else:
        sys.exit(1)
elif name == "networksetup":
    if data.get("networksetup_error"):
        sys.exit(1)
    if args == ["-listallhardwareports"]:
        print("Hardware Port: Ethernet\nDevice: en0\n")
        if data.get("has_wifi", True):
            print("Hardware Port: " + data.get("port", "Wi-Fi") + "\nDevice: en7\n")
    elif args == ["-getairportpower", "en7"]:
        if data.get("power_error"):
            sys.exit(1)
        print("Wi-Fi Power (en7): " + data.get("power", "On"))
    else:
        sys.exit("Unexpected networksetup arguments: " + repr(args))
elif name == "ifconfig":
    if args != ["en7"]:
        sys.exit("Must inspect the Wi-Fi interface, not Ethernet/default route")
    if data.get("link_error"):
        sys.exit(1)
    print("\tstatus: " + data.get("link", "active"))
elif name == "sketchybar":
    with (root / "calls.jsonl").open("a") as log:
        log.write(json.dumps(args) + "\n")
"""


class WifiTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for command in ("defaults", "networksetup", "ifconfig", "sketchybar"):
            executable = self.bin / command
            executable.write_text(MOCK)
            executable.chmod(0o755)
        self.data = {"appearance": "Dark"}

    def run_plugin(self):
        (self.root / "fixture.json").write_text(json.dumps(self.data))
        log = self.root / "calls.jsonl"
        log.unlink(missing_ok=True)
        result = subprocess.run(
            ["sh", str(CONFIG / "plugins/wifi.sh")],
            env={
                **os.environ,
                "PATH": f"{self.bin}:{os.environ['PATH']}",
                "FIXTURE": str(self.root),
                "CONFIG_DIR": str(CONFIG),
                "NAME": "wifi",
            },
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, "")
        calls = [json.loads(line) for line in log.read_text().splitlines()]
        self.assertEqual(len(calls), 1)
        self.assertEqual(calls[0][:2], ["--set", "wifi"])
        return calls[0][2:]

    def test_states_follow_both_palettes(self):
        for appearance, green, yellow, dim in (
            ("Dark", "0xffc3e88d", "0xffffc777", "0xffa9b1d6"),
            ("Light", "0xff315c2b", "0xff6b4b16", "0xff3d4f7a"),
        ):
            for power, link, icon, color in (
                ("On", "active", "󰤨", green),
                ("On", "inactive", "󰤯", yellow),
                ("Off", "inactive", "󰤭", dim),
            ):
                with self.subTest(appearance=appearance, power=power, link=link):
                    self.data = {
                        "appearance": appearance,
                        "power": power,
                        "link": link,
                    }
                    self.assertEqual(
                        self.run_plugin(), [f"icon={icon}", f"icon.color={color}"]
                    )

    def test_airport_hardware_port_is_supported(self):
        self.data["port"] = "AirPort"
        self.assertIn("icon=󰤨", self.run_plugin())

    def test_missing_interface_and_power_errors_are_unavailable(self):
        for appearance, red in (
            ("Dark", "0xffff757f"),
            ("Light", "0xff982346"),
        ):
            for failure in (
                {"has_wifi": False},
                {"networksetup_error": True},
                {"power_error": True},
                {"power": "Unknown"},
                {"link_error": True},
            ):
                with self.subTest(appearance=appearance, failure=failure):
                    self.data = {"appearance": appearance, **failure}
                    self.assertEqual(self.run_plugin(), ["icon=󰤭", f"icon.color={red}"])


if __name__ == "__main__":
    unittest.main()
