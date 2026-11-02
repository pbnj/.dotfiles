import json
import subprocess
import unittest
from unittest.mock import patch

import install
import launch

SESSION = "session:01a198a3-0f90-7576-9158-0e763e09afed"
OTHER = "session:01a198a3-0f90-7576-9158-0e763e09afee"


def clients(*sessions, kind="app", state="connected"):
    return json.dumps(
        {
            "clients": [
                {
                    "info": {"kind": kind},
                    "connection_state": state,
                    "session_ids": list(sessions),
                }
            ]
        }
    )


class LauncherTests(unittest.TestCase):
    def setUp(self):
        environment = patch.dict("launch.os.environ", {"REX_SESSION": ""})
        environment.start()
        self.addCleanup(environment.stop)
        which = patch("launch.shutil.which", return_value="/bin/rex")
        which.start()
        self.addCleanup(which.stop)

    def ls(self, stdout, returncode=0):
        return patch(
            "launch.subprocess.run",
            return_value=subprocess.CompletedProcess([], returncode, stdout, ""),
        )

    def test_url_validation(self):
        for url in (
            "https://github.com/org/repo/pull/1",
            "https://linear.app/acme/issue/ENG-7#comment",
            "about:blank",
        ):
            self.assertEqual(launch.validate_url(url), url)
        for url in ("", "github.com/org/repo", "https://", "https://a b", "x\x00"):
            with self.assertRaises(ValueError):
                launch.validate_url(url)

    def test_uses_the_session_the_app_shows(self):
        with self.ls(clients(SESSION)):
            self.assertEqual(launch.rex_target(), ("/bin/rex", SESSION))

    def test_current_rex_session_wins(self):
        with (
            patch.dict("launch.os.environ", {"REX_SESSION": OTHER}),
            self.ls(clients(SESSION, OTHER)),
        ):
            self.assertEqual(launch.rex_target(), ("/bin/rex", OTHER))

    def test_requires_a_connected_rex_app(self):
        for stdout, code in (
            (clients(SESSION, state="disconnected"), 0),
            (clients(SESSION, kind="cli"), 0),
            (clients(), 0),
            ("not json", 0),
            ("", 1),
        ):
            with (
                self.ls(stdout, code),
                self.assertRaisesRegex(ValueError, "not running"),
            ):
                launch.rex_target()

    def test_requires_rex(self):
        with (
            patch("launch.shutil.which", return_value=None),
            self.assertRaisesRegex(ValueError, "rex executable"),
        ):
            launch.rex_target()

    def test_open_fai_sends_the_url_on_stdin_and_shows_rex(self):
        url = "https://github.com/org/repo/pull/1?token=secret"
        with self.ls("") as run:
            launch.open_fai("/bin/rex", SESSION, url)
        action, show = run.call_args_list
        argv = action.args[0]
        self.assertEqual(argv, ["/bin/rex", "do", "-s", SESSION, "fai", "--args", "-"])
        self.assertNotIn(url, " ".join(argv))
        self.assertEqual(json.loads(action.kwargs["input"]), {"url": url})
        self.assertEqual(show.args[0], ["/usr/bin/open", "-b", launch.REX_BUNDLE])

    def test_open_fai_failure_raises_without_showing_rex(self):
        failed = subprocess.CompletedProcess([], 1, "", "no action named fai")
        with (
            patch("launch.subprocess.run", return_value=failed) as run,
            self.assertRaisesRegex(ValueError, "no action named fai"),
        ):
            launch.open_fai("/bin/rex", SESSION, "https://example.com")
        self.assertEqual(run.call_count, 1)

    def test_dry_run_opens_nothing(self):
        argv = ["agent-url", "--dry-run", "--url", "https://example.com"]
        with (
            patch("sys.argv", argv),
            self.ls(clients(SESSION)) as run,
            patch("builtins.print") as printed,
        ):
            self.assertEqual(launch.main(), 0)
        self.assertEqual(run.call_count, 1)  # only `rex client ls`
        self.assertEqual(
            json.loads(printed.call_args.args[0])["args"],
            {"url": "https://example.com"},
        )


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.config = launch.load_config()
        self.original = {
            "hyperKeyPhysicalKey": "capsLock",
            "unrelated": b"preserve me",
            "customCommands": b"[]",
        }

    def commands(self, prefs):
        return json.loads(prefs["customCommands"])

    def test_hyper_a(self):
        merged = install.configure(self.original, self.config)
        binding = json.loads(
            merged["hotkey.customCommand." + install.command_id("fai")]
        )["combo"]["_0"]
        self.assertEqual(binding, {"carbonKeyCode": 0, "carbonModifiers": 6400})
        (command,) = self.commands(merged)
        self.assertEqual(command["command"], 'exec "$HOME/.local/bin/agent-url"')

    def test_merge_is_idempotent_and_preserves_existing_data(self):
        old = {"id": "56f12d08-ae5f-4ab7-809c-e7f87551cbb1", "name": "Mine"}
        self.original["customCommands"] = json.dumps([old]).encode()
        self.original["boundCustomCommandIDs"] = [old["id"]]
        merged = install.configure(self.original, self.config)
        self.assertEqual(install.configure(merged, self.config), merged)
        self.assertEqual(self.commands(merged)[0], old)
        self.assertEqual(merged["unrelated"], b"preserve me")
        self.assertEqual(len(merged["boundCustomCommandIDs"]), 2)

    def test_replaces_per_agent_commands_and_their_hotkeys(self):
        legacy = install.command_id("opus")
        renamed = "5EF4DF56-EE18-4F65-979C-125C3C9D3130"  # re-created by hand
        self.original["customCommands"] = json.dumps(
            [
                {"id": legacy, "name": "Browser URL — Claude Opus"},
                {"id": renamed, "name": "Browser URL — Copilot Auto"},
            ]
        ).encode()
        self.original["boundCustomCommandIDs"] = [legacy, renamed]
        for identifier, key in ((legacy, 31), (renamed, 8)):
            self.original["hotkey.customCommand." + identifier] = json.dumps(
                {"combo": {"_0": {"carbonKeyCode": key, "carbonModifiers": 6400}}}
            )
        merged = install.configure(self.original, self.config)
        self.assertEqual(
            [c["name"] for c in self.commands(merged)], ["Browser URL — fai"]
        )
        self.assertNotIn(legacy.lower(), install.owned_ids([]))
        self.assertEqual(merged["boundCustomCommandIDs"], [install.command_id("fai")])
        for identifier in (legacy, renamed):
            self.assertNotIn("hotkey.customCommand." + identifier, merged)

    def test_repurposed_legacy_command_is_kept(self):
        mine = {"id": install.command_id("auto"), "name": "GitHubAttention"}
        self.original["customCommands"] = json.dumps([mine]).encode()
        self.original["boundCustomCommandIDs"] = [mine["id"]]
        binding = "hotkey.customCommand." + mine["id"]
        self.original[binding] = json.dumps(
            {"combo": {"_0": {"carbonKeyCode": 5, "carbonModifiers": 6400}}}
        )
        merged = install.configure(self.original, self.config)
        self.assertEqual(self.commands(merged)[0], mine)
        self.assertEqual(merged[binding], self.original[binding])
        self.assertIn(mine["id"], merged["boundCustomCommandIDs"])

    def test_conflict_is_not_overwritten(self):
        self.original["hotkey.app.test"] = json.dumps(
            {"combo": {"_0": {"carbonKeyCode": 0, "carbonModifiers": 6400}}}
        )
        with self.assertRaisesRegex(ValueError, "already assigned"):
            install.configure(self.original, self.config)

    def test_hyper_required(self):
        prefs = dict(self.original, hyperKeyPhysicalKey="none")
        with self.assertRaises(ValueError):
            install.configure(prefs, self.config)


if __name__ == "__main__":
    unittest.main()
