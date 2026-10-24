#!/usr/bin/python3
"""Build URL capture and safely merge native agent-url hotkeys into Tinycast."""

import argparse
from datetime import datetime
import json
import os
from pathlib import Path
import plistlib
import subprocess
import tempfile
import time
import uuid

from launch import CACHE, ROOT, load_config

DOMAIN = "com.tinycast.app"
HYPER = 256 | 2048 | 4096  # Carbon cmdKey | optionKey | controlKey
SHIFT = 512


def command_id(key):
    return str(uuid.uuid5(uuid.NAMESPACE_URL, "local:tinycast-agent-url:" + key))


def configure(preferences, config):
    """Pure merge: never overwrite someone else's command or hotkey."""
    if preferences.get("hyperKeyPhysicalKey", "none") == "none":
        raise ValueError("Enable your Hyper key in Tinycast before installing.")
    if preferences.get("hyperKeyIncludesShift", False):
        raise ValueError(
            "Tinycast Hyper must exclude Shift to distinguish Copilot hotkeys."
        )
    updated = dict(preferences)
    commands = json.loads(preferences.get("customCommands", b"[]"))
    owned = {command_id(key) for key in config["presets"]}
    existing = [command for command in commands if command["id"].lower() not in owned]
    names = {command["name"].casefold() for command in existing}
    bound = set(preferences.get("boundCustomCommandIDs", []))
    desired_chords = set()
    for key, preset in config["presets"].items():
        identifier = command_id(key)
        binding_key = "hotkey.customCommand." + identifier
        modifiers = HYPER | (SHIFT if preset["shift"] else 0)
        chord = {"carbonKeyCode": preset["key_code"], "carbonModifiers": modifiers}
        signature = (preset["key_code"], modifiers)
        if signature in desired_chords:
            raise ValueError("Duplicate shortcut in config.json: " + key)
        desired_chords.add(signature)
        for pref_key, value in preferences.items():
            if not pref_key.startswith("hotkey.") or pref_key == binding_key:
                continue
            # An old binding for one of our other presets will be replaced below.
            if pref_key.removeprefix("hotkey.customCommand.") in owned:
                continue
            try:
                assigned = json.loads(value).get("combo", {}).get("_0")
            except (TypeError, ValueError):
                continue
            if assigned == chord:
                raise ValueError(
                    "Shortcut for {} is already assigned to {}.".format(key, pref_key)
                )
        if preset["name"].casefold() in names:
            raise ValueError("A custom command already uses the name " + preset["name"])
        names.add(preset["name"].casefold())
        existing.append(
            {
                "id": identifier,
                "name": preset["name"],
                "command": 'exec "$HOME/.local/bin/agent-url" ' + key,
                "isEnabled": True,
                "showsInRootSearch": True,
                "loadsShellEnvironment": False,
                "requiresConfirmation": False,
                "showsConfirmation": False,
                "showsOutput": False,
                "arguments": [],
                "workingDirectory": "~",
                "iconSymbol": "terminal",
            }
        )
        updated[binding_key] = json.dumps(
            {"combo": {"_0": chord}}, separators=(",", ":")
        )
        bound.add(identifier)
    updated["customCommands"] = json.dumps(existing, separators=(",", ":")).encode()
    updated["boundCustomCommandIDs"] = sorted(bound)
    updated["customCommandsEnabled"] = True
    return updated


def export_preferences():
    result = subprocess.run(
        ["/usr/bin/defaults", "export", DOMAIN, "-"], capture_output=True, check=True
    )
    return plistlib.loads(result.stdout)


def import_preferences(preferences):
    with tempfile.NamedTemporaryFile(suffix=".plist") as handle:
        handle.write(plistlib.dumps(preferences))
        handle.flush()
        subprocess.run(
            ["/usr/bin/defaults", "import", DOMAIN, handle.name],
            check=True,
            stdout=subprocess.DEVNULL,
        )


def is_running():
    return (
        subprocess.run(
            ["/usr/bin/pgrep", "-x", "Tinycast"], stdout=subprocess.DEVNULL
        ).returncode
        == 0
    )


def build_helper():
    CACHE.mkdir(parents=True, exist_ok=True)
    binary = CACHE / "browser-url"
    source = ROOT / "browser-url.swift"
    if not binary.exists() or source.stat().st_mtime > binary.stat().st_mtime:
        temporary = CACHE / "browser-url.build"
        subprocess.run(
            [
                "/usr/bin/swiftc",
                "-O",
                "-module-cache-path",
                str(CACHE / "swift-modules"),
                str(source),
                "-o",
                str(temporary),
            ],
            check=True,
        )
        temporary.replace(binary)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="Check for conflicts without changing anything",
    )
    args = parser.parse_args()
    config = load_config()
    configure(
        export_preferences(), config
    )  # Preflight before building, quitting, or writing.
    if args.check:
        print(
            "All {} native shortcuts are available (or already owned by agent-url).".format(
                len(config["presets"])
            )
        )
        return
    live = Path.home() / ".local/share/agent-url"
    if live.exists() or live.is_symlink():
        if live.resolve() != ROOT:
            raise ValueError("Refusing to replace existing " + str(live))
    wrapper = Path.home() / ".local/bin/agent-url"
    if not wrapper.exists():
        raise ValueError("Install utils/.local/bin/agent-url into ~/.local/bin first.")
    wrapper.chmod(0o755)
    build_helper()
    if not live.exists():
        live.parent.mkdir(parents=True, exist_ok=True)
        live.symlink_to(ROOT, target_is_directory=True)
    was_running = is_running()
    if was_running:
        subprocess.run(
            [
                "/usr/bin/osascript",
                "-e",
                'tell application id "com.tinycast.app" to quit',
            ],
            check=True,
        )
        deadline = time.monotonic() + 10
        while is_running():
            if time.monotonic() > deadline:
                raise ValueError(
                    "Tinycast did not quit; preferences have not been changed."
                )
            time.sleep(0.1)
    try:
        # Quit first so Tinycast cannot overwrite the merge with an in-memory snapshot.
        original = export_preferences()
        updated = configure(original, config)
        if updated == original:
            print("Tinycast commands and hotkeys are already up to date.")
            return
        backups = Path.home() / ".local/state/agent-url"
        backups.mkdir(parents=True, exist_ok=True, mode=0o700)
        backup = backups / (
            "tinycast-" + datetime.now().strftime("%Y%m%d-%H%M%S-%f") + ".plist"
        )
        with backup.open("xb") as handle:
            os.fchmod(handle.fileno(), 0o600)
            handle.write(plistlib.dumps(original))
        try:
            import_preferences(updated)
            actual = export_preferences()
            for key in updated:
                if actual.get(key) != updated[key]:
                    raise ValueError("Preference verification failed: " + key)
        except Exception:
            import_preferences(original)
            raise
        print(
            "Installed {} Tinycast commands and hotkeys.".format(len(config["presets"]))
        )
        print("Previous preferences: " + str(backup))
    finally:
        if was_running:
            subprocess.run(["/usr/bin/open", "-g", "-a", "Tinycast"], check=True)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        raise SystemExit("Install failed: " + str(error))
