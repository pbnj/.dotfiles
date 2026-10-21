"""Offline Wi-Fi dropdown tests; never change the real network or appearance."""

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
elif name == "ipconfig":
    if args != ["getifaddr", "en7"]:
        sys.exit("Must query the Wi-Fi address, not Ethernet/default route")
    if data.get("address_error"):
        sys.exit(1)
    print(data.get("address", "192.0.2.7"))
elif name == "sketchybar":
    if args == ["--query", "wifi"]:
        print(json.dumps({"popup": {"drawing": data.get("popup", "off")}}))
    else:
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
        for command in (
            "defaults",
            "networksetup",
            "ifconfig",
            "ipconfig",
            "sketchybar",
        ):
            executable = self.bin / command
            executable.write_text(MOCK)
            executable.chmod(0o755)
        self.data = {"appearance": "Dark"}

    def run_plugin(self, sender="routine"):
        (self.root / "fixture.json").write_text(json.dumps(self.data))
        for filename in ("calls.jsonl", "commands.jsonl"):
            (self.root / filename).unlink(missing_ok=True)
        result = subprocess.run(
            ["bash", str(CONFIG / "plugins/wifi.sh")],
            env={
                **os.environ,
                "PATH": f"{self.bin}:{os.environ['PATH']}",
                "FIXTURE": str(self.root),
                "CONFIG_DIR": str(CONFIG),
                "NAME": "wifi",
                "SENDER": sender,
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
        self.assertEqual(self.args[:2], ["--set", "wifi"])
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
        self.assertNotIn("wifi.network", settings)
        self.assertFalse(any("-getairportnetwork" in c for c in self.commands()))
        return settings

    def commands(self):
        return [
            json.loads(line)
            for line in (self.root / "commands.jsonl").read_text().splitlines()
        ]

    def test_states_follow_both_palettes(self):
        for appearance, green, yellow, dim in (
            ("Dark", "0xffc3e88d", "0xffffc777", "0xffa9b1d6"),
            ("Light", "0xff315c2b", "0xff6b4b16", "0xff3d4f7a"),
        ):
            for power, link, icon, color, status in (
                ("On", "active", "󰤨", green, "Connected"),
                ("On", "inactive", "󰤯", yellow, "Disconnected"),
                ("Off", "inactive", "󰤭", dim, "Off"),
            ):
                with self.subTest(appearance=appearance, power=power, link=link):
                    self.data = {
                        "appearance": appearance,
                        "power": power,
                        "link": link,
                    }
                    settings = self.run_plugin()
                    self.assertEqual(settings["wifi"]["icon"], icon)
                    self.assertEqual(settings["wifi"]["icon.color"], color)
                    self.assertEqual(settings["wifi"]["label.drawing"], "off")
                    self.assertEqual(
                        settings["wifi.status"]["label"], f"Status: {status}"
                    )

    def test_airport_hardware_port_is_supported(self):
        self.data["port"] = "AirPort"
        self.assertEqual(self.run_plugin()["wifi"]["icon"], "󰤨")

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
                    settings = self.run_plugin()
                    self.assertEqual(settings["wifi"]["icon"], "󰤭")
                    self.assertEqual(settings["wifi"]["icon.color"], red)
                    self.assertEqual(
                        settings["wifi.status"]["label"], "Status: Unavailable"
                    )

    def test_click_opens_dropdown_with_details_from_the_wifi_interface(self):
        settings = self.run_plugin("mouse.clicked")
        self.assertEqual(settings["wifi"]["popup.drawing"], "on")
        self.assertEqual(settings["wifi.address"]["label"], "IP address: 192.0.2.7")
        self.assertEqual(settings["wifi.interface"]["label"], "Interface: en7")
        self.assertNotIn("--add", self.args)
        self.assertNotIn("--remove", self.args)

    def test_click_closes_open_dropdown_without_querying_the_network(self):
        self.data["popup"] = "on"
        self.run_plugin("mouse.clicked")
        self.assertEqual(self.args, ["--set", "wifi", "popup.drawing=off"])
        self.assertFalse(
            {"networksetup", "ifconfig", "ipconfig"} & {c[0] for c in self.commands()}
        )

    def test_closed_refreshes_do_not_query_details_or_open_the_dropdown(self):
        for sender in ("routine", "theme_refresh", "wifi_change", "system_woke"):
            with self.subTest(sender=sender):
                settings = self.run_plugin(sender)
                self.assertNotIn("popup.drawing", settings["wifi"])
                self.assertNotIn("wifi.network", settings)
                self.assertNotIn("ipconfig", [c[0] for c in self.commands()])
                self.assertFalse(
                    any("-getairportnetwork" in c for c in self.commands())
                )

    def test_open_refreshes_update_existing_rows_without_toggling(self):
        self.data["popup"] = "on"
        for sender in ("routine", "theme_refresh", "wifi_change", "system_woke"):
            with self.subTest(sender=sender):
                self.data["address"] = "192.0.2.8"
                settings = self.run_plugin(sender)
                self.assertEqual(
                    settings["wifi.address"]["label"], "IP address: 192.0.2.8"
                )
                self.assertNotIn("popup.drawing", settings["wifi"])
                self.assertNotIn("--add", self.args)
                self.assertNotIn("--remove", self.args)

    def test_disconnect_and_power_off_clear_stale_details(self):
        self.data["popup"] = "on"
        self.run_plugin()
        for changes in (
            {"link": "inactive"},
            {"power": "Off"},
            {"has_wifi": False},
            {"link_error": True},
        ):
            with self.subTest(changes=changes):
                self.data = {"appearance": "Dark", "popup": "on", **changes}
                settings = self.run_plugin()
                self.assertEqual(
                    settings["wifi.address"]["label"], "IP address: Unavailable"
                )
                self.assertNotIn("ipconfig", [c[0] for c in self.commands()])

    def test_failed_address_query_does_not_preserve_stale_address(self):
        self.data.update(popup="on", address_error=True)
        settings = self.run_plugin()
        self.assertEqual(settings["wifi.address"]["label"], "IP address: Unavailable")
        self.assertEqual(settings["wifi.status"]["label"], "Status: Connected")

    def test_empty_ip_address_is_unavailable(self):
        self.data["address"] = ""
        settings = self.run_plugin("mouse.clicked")
        self.assertEqual(settings["wifi.address"]["label"], "IP address: Unavailable")


if __name__ == "__main__":
    unittest.main()
