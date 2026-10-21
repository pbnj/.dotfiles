"""Offline theme tests: mock macOS, SketchyBar and tmux; never change appearance."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest

CONFIG = Path(__file__).resolve().parents[1] / ".config/sketchybar"
PALETTE_KEYS = [
    "THEME",
    "BG",
    "BAR_BG",
    "FG",
    "ITEM_BG",
    "SELECTED_BG",
    "APPS_BG",
    "FOCUSED_BG",
    "ACCENT",
    "DIM",
    "GREEN",
    "ORANGE",
    "YELLOW",
    "RED",
]

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
        sys.exit(1)  # macOS has no AppleInterfaceStyle key in light mode.
elif name == "sketchybar":
    if "--query" in args:
        item = args[args.index("--query") + 1]
        print(json.dumps({"popup": {
            "drawing": data.get(item + "_popup", "off"),
            "items": data.get(item + "_items", []),
        }}))
    else:
        with (root / "calls.jsonl").open("a") as log:
            log.write(json.dumps(args) + "\n")
elif name == "aerospace":
    if args[0] == "list-workspaces":
        print("W" if "--focused" in args else "T\nW")
    elif args[0] == "list-windows":
        print("W|Brave Browser")
elif name == "pmset":
    print(data.get("battery", "Now drawing from 'Battery Power'\n -InternalBattery-0 100%; charged;"))
elif name == "scutil":
    print("(" + data.get("vpn", "Connected") + ") com.twingate")
elif name == "tmux":
    if "display-message" in args:
        print("test:1.0")
elif name == "swiftc":
    sys.exit("Unexpected attempt to compile an Accessibility helper in an offline test")
"""


def luminance(color):
    rgb = color[-6:]
    channels = [int(rgb[i : i + 2], 16) / 255 for i in (0, 2, 4)]
    linear = [
        value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4
        for value in channels
    ]
    return sum(
        value * weight for value, weight in zip(linear, (0.2126, 0.7152, 0.0722))
    )


def contrast(foreground, background):
    a, b = luminance(foreground), luminance(background)
    return (max(a, b) + 0.05) / (min(a, b) + 0.05)


class ThemeTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for command in (
            "defaults",
            "sketchybar",
            "aerospace",
            "pmset",
            "scutil",
            "tmux",
            "swiftc",
        ):
            executable = self.bin / command
            executable.write_text(MOCK)
            executable.chmod(0o755)
        config = self.root / "config"
        (config / "helpers/bin").mkdir(parents=True)
        # Config startup must not compile a real Accessibility helper.
        helper = config / "helpers/bin/twingate_menu"
        helper.touch()
        helper.chmod(0o755)
        (config / "colors.sh").symlink_to(CONFIG / "colors.sh")
        (config / "plugins").symlink_to(CONFIG / "plugins")
        self.sessions = self.root / "pi-sessions"
        self.sessions.mkdir()
        self.data = {"appearance": "Dark", "pi_popup": "off", "pi_items": []}
        self.env = {
            **os.environ,
            "PATH": f"{self.bin}:{os.environ['PATH']}",
            "HOME": str(self.root),
            "FIXTURE": str(self.root),
            "CONFIG_DIR": str(config),
            "PI_SKETCHYBAR_SESSION_DIR": str(self.sessions),
            "SENDER": "theme_refresh",
            "NAME": "pi",
        }

    def run_command(self, command, **env):
        (self.root / "fixture.json").write_text(json.dumps(self.data))
        result = subprocess.run(
            command,
            env={**self.env, **env},
            capture_output=True,
            text=True,
            check=False,
            timeout=10,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, "")
        return result.stdout

    def plugin(self, name, **env):
        return self.run_command(["bash", str(CONFIG / "plugins" / name)], **env)

    def palette(self):
        variables = " ".join('"$' + name + '"' for name in PALETTE_KEYS)
        output = self.run_command(
            [
                "sh",
                "-c",
                '. "$CONFIG_DIR/colors.sh"; printf "%s\\n" ' + variables,
            ]
        )
        return dict(zip(PALETTE_KEYS, output.splitlines()))

    def calls(self):
        log = self.root / "calls.jsonl"
        return (
            [json.loads(line) for line in log.read_text().splitlines()]
            if log.exists()
            else []
        )

    def clear_calls(self):
        (self.root / "calls.jsonl").unlink(missing_ok=True)

    def session(self, state="working"):
        (self.sessions / "live.json").write_text(
            json.dumps(
                {
                    "pid": os.getpid(),
                    "state": state,
                    "updatedAt": int(time.time() * 1000),
                    "cwd": "/tmp/project",
                    "sessionName": "Theme test",
                }
            )
        )

    def test_startup_centers_all_content_shapes(self):
        self.run_command(["bash", str(CONFIG / "sketchybarrc")])
        defaults = {"icon.drawing": "on", "label.drawing": "on"}
        items = {}

        def properties(call, start):
            end = next(
                (i for i in range(start, len(call)) if call[i].startswith("--")),
                len(call),
            )
            return dict(
                argument.split("=", 1)
                for argument in call[start:end]
                if "=" in argument
            )

        for call in self.calls():
            for index, argument in enumerate(call):
                if argument == "--default":
                    defaults.update(properties(call, index + 1))
                elif argument == "--add" and call[index + 1] == "item":
                    items[call[index + 2]] = defaults.copy()
                elif argument == "--set" and call[index + 1] in items:
                    items[call[index + 1]].update(properties(call, index + 2))

        # Include icon-only, paired, label-only, grouped, workspace and popup items,
        # including temporarily hidden items that can be revealed by plugins.
        for name in (
            "apple.logo",
            "clock",
            "twingate",
            "wifi",
            "wifi.status",
            "wifi.address",
            "wifi.interface",
            "wifi.settings",
            "battery",
            "battery.level",
            "battery.source",
            "battery.status",
            "battery.time",
            "battery.settings",
            "copilot",
            "volume",
            "volume.level",
            "volume.output",
            "volume.input",
            "volume.settings",
            "docker",
            "github",
            "cpu",
            "memory",
            "disk",
            "claude",
            "claude.usage",
            "pi",
            "front_app",
            "space.W",
            "apple.prefs",
            "docker.containers",
        ):
            self.assertIn(name, items)
        grouped_edges = {
            "cpu": ("8", "2"),
            "memory": ("2", "2"),
            "disk": ("2", "8"),
        }
        for name, item in items.items():
            with self.subTest(item=name):
                icon = item["icon.drawing"] == "on"
                label = item["label.drawing"] == "on"
                if not icon and not label:
                    continue
                left = item["icon.padding_left" if icon else "label.padding_left"]
                right = item["label.padding_right" if label else "icon.padding_right"]
                self.assertEqual((left, right), grouped_edges.get(name, ("8", "8")))
                self.assertEqual(item["padding_left"], item["padding_right"])
        self.assertEqual(items["battery"]["label.drawing"], "off")
        self.assertEqual(items["battery"]["icon.padding_left"], "8")
        self.assertEqual(items["battery"]["icon.padding_right"], "8")
        self.assertEqual(items["battery"]["padding_left"], "4")
        self.assertEqual(
            items["battery"]["background.color"], self.palette()["ITEM_BG"]
        )
        self.assertEqual(items["battery"].get("background.drawing", "on"), "on")
        self.assertNotIn("click_script", items["battery"])
        self.assertIn("Battery-Settings", items["battery.settings"]["click_script"])
        self.assertEqual(items["copilot"]["drawing"], "off")
        self.assertEqual(items["copilot"]["label.drawing"], "off")
        self.assertEqual(items["copilot"]["icon"], "")
        self.assertEqual(items["copilot"]["update_freq"], "5")
        self.assertEqual(items["wifi"]["label.drawing"], "off")
        self.assertNotIn("click_script", items["wifi"])
        self.assertNotIn("wifi.network", items)
        self.assertIn("wifi-settings-extension", items["wifi.settings"]["click_script"])
        self.assertEqual(items["volume"]["label.drawing"], "off")
        self.assertEqual(items["volume"]["update_freq"], "5")
        self.assertEqual(items["clock"]["icon.padding_right"], "2")
        self.assertEqual(items["clock"]["label.padding_left"], "2")
        self.assertEqual(items["space.W"]["label.padding_left"], "8")
        self.assertEqual(items["claude"]["label.drawing"], "off")
        self.assertEqual(items["claude"]["padding_left"], "4")
        self.assertEqual(items["claude"].get("background.drawing", "on"), "on")
        for name in grouped_edges:
            with self.subTest(grouped_item=name):
                self.assertEqual(items[name]["background.drawing"], "off")
                self.assertEqual(items[name]["padding_left"], "0")
                self.assertEqual(items[name]["padding_right"], "0")
        for left, right in (("cpu", "memory"), ("memory", "disk")):
            self.assertEqual(
                int(items[left]["label.padding_right"])
                + int(items[right]["icon.padding_left"]),
                4,
            )
        for name in (*grouped_edges, "clock"):
            if items[name]["label.drawing"] == "off":
                continue
            self.assertEqual(
                int(items[name]["icon.padding_right"])
                + int(items[name]["label.padding_left"]),
                4,
            )

    def test_stats_group_has_adjacent_members_in_display_order(self):
        self.run_command(["bash", str(CONFIG / "sketchybarrc")])
        order = []
        members = []
        for call in self.calls():
            for index, argument in enumerate(call):
                if argument != "--add":
                    continue
                if call[index + 1] == "item":
                    order.append(call[index + 2])
                elif call[index + 1 : index + 3] == ["bracket", "stats"]:
                    end = next(
                        (
                            i
                            for i in range(index + 3, len(call))
                            if call[i].startswith("--")
                        ),
                        len(call),
                    )
                    members = call[index + 3 : end]
        self.assertEqual(members, ["cpu", "memory", "disk"])
        positions = sorted(order.index(name) for name in members)
        self.assertEqual(positions, list(range(positions[0], positions[0] + 3)))
        self.assertEqual([order[i] for i in positions], list(reversed(members)))

    def test_claude_usage_is_one_row_inside_the_dropdown(self):
        self.run_command(["bash", str(CONFIG / "sketchybarrc")])
        positions = {}
        for call in self.calls():
            self.assertNotIn("claude_group", call)
            for index, argument in enumerate(call):
                if argument == "--add" and call[index + 1] == "item":
                    positions[call[index + 2]] = call[index + 3]
        self.assertEqual(positions["claude"], "right")
        self.assertEqual(positions["claude.usage"], "popup.claude")
        self.assertNotIn("claude.5h", positions)
        self.assertNotIn("claude.7d", positions)

    def test_palette_follows_dark_and_missing_light_preference(self):
        self.assertEqual(self.palette()["THEME"], "moon")
        self.assertEqual(self.palette()["BG"], "0xff222436")
        self.data["appearance"] = "Light"
        self.assertEqual(self.palette()["THEME"], "day")
        self.assertEqual(self.palette()["BG"], "0xffe1e2e7")

    def test_bar_and_pill_transparency_leave_popup_menus_opaque(self):
        for appearance in ("Dark", "Light"):
            with self.subTest(appearance=appearance):
                self.data["appearance"] = appearance
                colors = self.palette()
                self.assertEqual(colors["BAR_BG"], "0x80" + colors["BG"][-6:])
                self.assertTrue(colors["BG"].startswith("0xff"))
                self.assertTrue(colors["ITEM_BG"].startswith("0xa6"))
                self.clear_calls()
                self.run_command(["bash", str(CONFIG / "sketchybarrc")])
                bar = next(call for call in self.calls() if call[0] == "--bar")
                self.assertIn("color=" + colors["BAR_BG"], bar)
                defaults = next(call for call in self.calls() if call[0] == "--default")
                self.assertIn("background.color=" + colors["ITEM_BG"], defaults)

    def test_base_palette_text_and_state_colors_have_aa_contrast(self):
        # Check base RGB colors; translucent pill contrast depends on the wallpaper.
        for appearance in ("Dark", "Light"):
            self.data["appearance"] = appearance
            colors = self.palette()
            for background in ("BG", "ITEM_BG", "APPS_BG", "FOCUSED_BG"):
                alpha = "0xa6" if background == "ITEM_BG" else "0xff"
                self.assertTrue(colors[background].startswith(alpha))
                for foreground in (
                    "FG",
                    "ACCENT",
                    "DIM",
                    "GREEN",
                    "ORANGE",
                    "YELLOW",
                    "RED",
                ):
                    with self.subTest(
                        appearance=appearance, fg=foreground, bg=background
                    ):
                        ratio = contrast(colors[foreground], colors[background])
                        self.assertGreaterEqual(ratio, 4.5)

    def test_updater_changes_existing_colors_then_refreshes_state(self):
        for appearance in ("Dark", "Light"):
            self.data["appearance"] = appearance
            colors = self.palette()
            self.clear_calls()
            self.plugin("theme.sh")
            calls = self.calls()
            self.assertEqual(len(calls), 2)
            self.assertIn("color=" + colors["BAR_BG"], calls[0])
            self.assertIn("icon.color=" + colors["ACCENT"], calls[0])
            self.assertIn("popup.background.color=" + colors["BG"], calls[0])
            self.assertEqual(calls[1], ["--trigger", "theme_refresh"])
            for call in calls:
                self.assertFalse(set(call) & {"--reload", "--remove", "--add"})
                self.assertFalse(
                    any(arg.startswith(("drawing=", "popup.drawing=")) for arg in call)
                )

    def test_updater_preserves_transparent_items_and_explicit_accents(self):
        colors = self.palette()
        self.plugin("theme.sh")
        args = self.calls()[0]
        settings = {}
        for index, argument in enumerate(args):
            if argument != "--set":
                continue
            end = next(
                (i for i in range(index + 2, len(args)) if args[i].startswith("--")),
                len(args),
            )
            settings.setdefault(args[index + 1], []).extend(args[index + 2 : end])
        self.assertEqual(
            settings["/.*/"],
            ["icon.color=" + colors["FG"], "label.color=" + colors["FG"]],
        )
        for item in (
            "cpu",
            "memory",
            "disk",
            "docker",
            "copilot",
        ):
            self.assertIn("icon.color=" + colors["ACCENT"], settings[item])
        for item, properties in settings.items():
            if any(prop.startswith("background.color=") for prop in properties):
                self.assertIn(
                    item,
                    (
                        "spaces",
                        "stats",
                        "claude",
                        "clock",
                        "twingate",
                        "wifi",
                        "volume",
                        "battery",
                        "docker",
                        "github",
                        "copilot",
                        "pi",
                    ),
                )
        self.assertIn("popup.background.color=" + colors["BG"], settings["volume"])
        self.assertIn("popup.background.color=" + colors["BG"], settings["wifi"])
        self.assertIn("background.color=" + colors["ITEM_BG"], settings["battery"])
        self.assertIn("popup.background.color=" + colors["BG"], settings["battery"])
        self.assertIn("background.color=" + colors["ITEM_BG"], settings["claude"])
        self.assertIn("background.color=" + colors["ITEM_BG"], settings["docker"])
        self.assertNotIn("claude_group", settings)
        self.assertIn("/space[.].*/", settings)

    def test_startup_registers_events_before_subscribing(self):
        self.run_command(["bash", str(CONFIG / "sketchybarrc")])
        registered = set()
        subscriptions = {}
        for call in self.calls():
            for index, argument in enumerate(call):
                if argument == "--add" and call[index + 1] == "event":
                    registered.add(call[index + 2])
                if argument == "--subscribe":
                    end = next(
                        (
                            i
                            for i in range(index + 2, len(call))
                            if call[i].startswith("--")
                        ),
                        len(call),
                    )
                    events = call[index + 2 : end]
                    for event in events:
                        if event.startswith("theme_"):
                            self.assertIn(event, registered)
                    subscriptions[call[index + 1]] = events
        self.assertIn(
            [
                "--add",
                "event",
                "theme_refresh",
                "--add",
                "event",
                "theme_change",
                "AppleInterfaceThemeChangedNotification",
            ],
            self.calls(),
        )
        self.assertEqual(
            subscriptions["theme_watcher"], ["theme_change", "system_woke"]
        )
        for item in (
            "space_windows",
            "battery",
            "twingate",
            "wifi",
            "volume",
            "claude",
            "github",
            "copilot",
            "pi",
        ):
            self.assertIn("theme_refresh", subscriptions[item])
        self.assertEqual(
            subscriptions["wifi"],
            ["wifi_change", "mouse.clicked", "system_woke", "theme_refresh"],
        )
        self.assertEqual(
            subscriptions["volume"],
            ["volume_change", "mouse.clicked", "system_woke", "theme_refresh"],
        )
        self.assertIn("mouse.clicked", subscriptions["battery"])

    def test_battery_charge_thresholds_follow_both_palettes(self):
        charging_icons = (
            "󰢟",
            "󰢜",
            "󰂆",
            "󰂇",
            "󰂈",
            "󰢝",
            "󰂉",
            "󰢞",
            "󰂊",
            "󰂋",
            "󰂅",
        )
        for appearance in ("Dark", "Light"):
            self.data["appearance"] = appearance
            colors = self.palette()
            for percentage, token, icon in (
                (0, "RED", ""),
                (9, "RED", ""),
                (10, "RED", ""),
                (29, "RED", ""),
                (30, "RED", ""),
                (33, "RED", ""),
                (34, "YELLOW", ""),
                (59, "YELLOW", ""),
                (60, "YELLOW", ""),
                (66, "YELLOW", ""),
                (67, "FG", ""),
                (89, "FG", ""),
                (90, "FG", ""),
                (99, "FG", ""),
                (100, "GREEN", ""),
            ):
                for source, state in (
                    ("Battery Power", "discharging"),
                    ("AC Power", "charging"),
                    ("AC Power", "finishing charge"),
                    ("AC Power", "not charging"),
                    ("AC Power", "charged"),
                ):
                    with self.subTest(
                        appearance=appearance,
                        percentage=percentage,
                        source=source,
                        state=state,
                    ):
                        self.data["battery"] = (
                            f"Now drawing from '{source}'\n"
                            f" -InternalBattery-0 {percentage}%; {state};"
                        )
                        self.clear_calls()
                        self.plugin("battery.sh", NAME="battery")
                        self.assertEqual(len(self.calls()), 1)
                        args = self.calls()[0]
                        self.assertIn("icon.color=" + colors[token], args)
                        self.assertIn("label.drawing=off", args)
                        self.assertIn("label=", args)
                        pill_args = args[2 : args.index("--set", 2)]
                        self.assertFalse(any("%" in arg for arg in pill_args))
                        if state in ("charging", "finishing charge"):
                            bar_icon = charging_icons[percentage // 10]
                        elif source == "AC Power":
                            bar_icon = ""
                        else:
                            bar_icon = icon
                        self.assertIn("icon=" + bar_icon, pill_args)
                        self.assertIn("icon=" + icon, args[len(pill_args) + 2 :])
                        self.assertIn(f"label=Charge: {percentage}%", args)

    def test_battery_without_percentage_reports_unavailable(self):
        self.data["battery"] = "Now drawing from 'AC Power'"
        self.plugin("battery.sh", NAME="battery")
        self.assertIn("label=Charge: Unavailable", self.calls()[0])
        self.assertIn("icon=", self.calls()[0])

    def test_vpn_state_colors_follow_both_palettes(self):
        for appearance in ("Dark", "Light"):
            self.data["appearance"] = appearance
            colors = self.palette()
            for status, token in (
                ("Connected", "GREEN"),
                ("Connecting", "YELLOW"),
                ("Disconnected", "RED"),
            ):
                self.data["vpn"] = status
                self.clear_calls()
                self.plugin("twingate.sh", NAME="twingate")
                self.assertIn("icon.color=" + colors[token], self.calls()[-1])

    def test_workspaces_keep_focus_and_use_palette_backgrounds(self):
        for appearance in ("Dark", "Light"):
            self.data["appearance"] = appearance
            colors = self.palette()
            self.clear_calls()
            self.plugin("aerospace.sh")
            args = self.calls()[-1]
            focused = args[args.index("space.W") :]
            self.assertIn("icon.highlight=on", focused)
            self.assertIn("label.background.color=" + colors["FOCUSED_BG"], focused)
            self.assertIn("label.background.color=" + colors["APPS_BG"], args)

    def test_pi_theme_refresh_reuses_open_rows_without_toggling_popup(self):
        self.data.update(pi_popup="on", pi_items=["pi.row.0"])
        self.session()
        for appearance in ("Dark", "Light"):
            self.data["appearance"] = appearance
            colors = self.palette()
            self.clear_calls()
            self.plugin("pi_click.sh")
            args = self.calls()[-1]
            self.assertIn("icon.color=" + colors["ORANGE"], args)
            self.assertIn("label.color=" + colors["FG"], args)
            self.assertIn("icon.padding_left=8", args)
            self.assertIn("label.padding_right=8", args)
            self.assertNotIn("--add", args)
            self.assertNotIn("--remove", args)
            self.assertFalse(any(arg.startswith("popup.drawing=") for arg in args))

    def test_pi_refresh_does_not_open_a_closed_popup(self):
        self.plugin("pi_click.sh")
        self.assertEqual(self.calls(), [])

    def test_pi_click_still_opens_and_closes_popup(self):
        self.session()
        self.plugin("pi_click.sh", SENDER="mouse.clicked")
        self.assertEqual(self.calls()[-1][-3:], ["--set", "pi", "popup.drawing=on"])
        self.data["pi_popup"] = "on"
        self.clear_calls()
        self.plugin("pi_click.sh", SENDER="mouse.clicked")
        self.assertEqual(self.calls(), [["--set", "pi", "popup.drawing=off"]])

    def test_pi_theme_event_refreshes_icon_and_open_popup_for_each_state(self):
        self.data.update(pi_popup="on", pi_items=["pi.row.0"])
        for appearance in ("Dark", "Light"):
            self.data["appearance"] = appearance
            colors = self.palette()
            for state, token in (
                ("idle", "DIM"),
                ("working", "ORANGE"),
                ("blocked", "RED"),
            ):
                self.session(state)
                self.clear_calls()
                self.plugin("pi.sh")
                calls = self.calls()
                self.assertEqual(len(calls), 2)
                for call in calls:
                    self.assertIn("icon.color=" + colors[token], call)
                    self.assertFalse(
                        any(arg.startswith("popup.drawing=") for arg in call)
                    )


if __name__ == "__main__":
    unittest.main()
