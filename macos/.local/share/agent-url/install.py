#!/usr/bin/python3
"""Build URL capture and safely merge the browser-URL → fai hotkey into Tinycast."""

import argparse
import json
import os
import plistlib
import subprocess
import tempfile
import time
import uuid
from datetime import datetime
from pathlib import Path

from launch import CACHE, ROOT, load_config

DOMAIN = "com.tinycast.app"
HYPER = 256 | 2048 | 4096  # Carbon cmdKey | optionKey | controlKey
SHIFT = 512
COMMAND_KEY = "fai"
# Every command this launcher owns is named with this prefix.
NAME_PREFIX = "Browser URL — "


def command_id(key):
    return str(uuid.uuid5(uuid.NAMESPACE_URL, "local:tinycast-agent-url:" + key))


def owned_ids(commands):
    """IDs (lowercase) of our commands: named "Browser URL — …" or running
    agent-url. A legacy preset's ID is not enough, since a command re-purposed
    in Tinycast Settings keeps its ID."""
    owned = {command_id(COMMAND_KEY)}
    owned |= {
        command["id"].lower()
        for command in commands
        if command.get("name", "").startswith(NAME_PREFIX)
        or "/.local/bin/agent-url" in command.get("command", "")
    }
    return owned


def configure(preferences, config):
    """Pure merge: replace our commands, never someone else's command or hotkey."""
    if preferences.get("hyperKeyPhysicalKey", "none") == "none":
        raise ValueError("Enable your Hyper key in Tinycast before installing.")
    updated = dict(preferences)
    commands = json.loads(preferences.get("customCommands", b"[]"))
    owned = owned_ids(commands)
    existing = [command for command in commands if command["id"].lower() not in owned]
    bound = {
        identifier
        for identifier in preferences.get("boundCustomCommandIDs", [])
        if identifier.lower() not in owned
    }
    for pref_key in preferences:
        if pref_key.startswith("hotkey.customCommand.") and (
            pref_key.removeprefix("hotkey.customCommand.").lower() in owned
        ):
            del updated[pref_key]
    identifier = command_id(COMMAND_KEY)
    binding_key = "hotkey.customCommand." + identifier
    modifiers = HYPER | (SHIFT if config["shift"] else 0)
    chord = {"carbonKeyCode": config["key_code"], "carbonModifiers": modifiers}
    for pref_key, value in updated.items():
        if not pref_key.startswith("hotkey."):
            continue
        try:
            assigned = json.loads(value).get("combo", {}).get("_0")
        except (TypeError, ValueError, AttributeError):
            continue
        if assigned == chord:
            raise ValueError("The shortcut is already assigned to " + pref_key)
    existing.append(
        {
            "id": identifier,
            "name": config["name"],
            "command": 'exec "$HOME/.local/bin/agent-url"',
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
    updated[binding_key] = json.dumps({"combo": {"_0": chord}}, separators=(",", ":"))
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


def import_preferences(preferences, remove=()):
    """Merge preferences into the domain (defaults import never deletes), then
    delete the keys in remove."""
    with tempfile.NamedTemporaryFile(suffix=".plist") as handle:
        handle.write(plistlib.dumps(preferences))
        handle.flush()
        subprocess.run(
            ["/usr/bin/defaults", "import", DOMAIN, handle.name],
            check=True,
            stdout=subprocess.DEVNULL,
        )
    for key in remove:
        subprocess.run(["/usr/bin/defaults", "delete", DOMAIN, key], check=True)


def is_running():
    return (
        subprocess.run(
            ["/usr/bin/pgrep", "-x", "Tinycast"],
            stdout=subprocess.DEVNULL,
            check=False,
        ).returncode
        == 0
    )


def build_helper():
    CACHE.mkdir(parents=True, exist_ok=True)
    binary = CACHE / "fai"
    source = ROOT / "fai.swift"
    if not binary.exists() or source.stat().st_mtime > binary.stat().st_mtime:
        temporary = CACHE / "fai.build"
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
        print("The shortcut is available (or already owned by agent-url).")
        return
    live = Path.home() / ".local/share/agent-url"
    if (live.exists() or live.is_symlink()) and live.resolve() != ROOT:
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
            import_preferences(updated, remove=sorted(original.keys() - updated.keys()))
            actual = export_preferences()
            for key in updated:
                if actual.get(key) != updated[key]:
                    raise ValueError("Preference verification failed: " + key)
            for key in original.keys() - updated.keys():
                if key in actual:
                    raise ValueError("Preference verification failed: " + key)
        except Exception:
            import_preferences(original)
            raise
        print("Installed the Tinycast command and hotkey: " + config["name"])
        print("Previous preferences: " + str(backup))
    finally:
        if was_running:
            subprocess.run(["/usr/bin/open", "-g", "-a", "Tinycast"], check=True)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        raise SystemExit("Install failed: " + str(error))
