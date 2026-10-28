"""Offline agent fixtures plus an isolated tmux server; no real sessions touched."""

import importlib.util
import json
import os
import re
import shutil
import subprocess
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import patch

CONFIG = Path(__file__).resolve().parents[1] / ".config/tmux"
SCRIPT = CONFIG / "scripts/agent-status.py"
SPEC = importlib.util.spec_from_file_location("agent_status", SCRIPT)
STATUS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(STATUS)


class AgentStatusTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.sessions = self.root / "pi-sessions"
        self.sessions.mkdir()
        self.socket = str(self.root / "tmux.sock")
        self.env = patch.dict(
            os.environ,
            {
                "HOME": str(self.root),
                "PI_SKETCHYBAR_SESSION_DIR": str(self.sessions),
                "CLAUDE_SKETCHYBAR_DIR": str(self.root / "claude-mods"),
                "CLAUDE_SESSION_DIR": str(self.root / "claude-registry"),
            },
        )
        self.env.start()
        self.addCleanup(self.env.stop)
        self.mods = self.root / "claude-mods/sessions"
        self.registry = self.root / "claude-registry"
        self.mods.mkdir(parents=True)
        self.registry.mkdir()

    def session(self, filename="pi", **extra):
        record = {
            "pid": os.getpid(),
            "state": "working",
            "updatedAt": time.time() * 1000,
            "tmux": {"socket": self.socket, "pane": "%1"},
            **extra,
        }
        (self.sessions / f"{filename}.json").write_text(json.dumps(record))

    def refresh(self, windows="@1\t\n@2\t\n", panes=None, claude=()):
        if panes is None:
            panes = "%1\t@1\tnode\n%2\t@2\tbash\n"
        with (
            patch.object(STATUS, "tmux", side_effect=[windows, panes, ""]) as tmux,
            patch.object(
                STATUS, "claude_sessions", return_value=iter(claude)
            ) as resolver,
        ):
            STATUS.refresh(self.socket)
        updates = {}
        if tmux.call_count == 3:
            args = list(tmux.call_args.args[1:])
            while args:
                end = args.index(";") if ";" in args else len(args)
                command, args = args[:end], args[end + 1 :]
                self.assertEqual(command[0], "set-option")
                updates[command[3]] = command[-1] if command[1] == "-w" else ""
        return updates, resolver.called

    def test_pi_states_are_window_local(self):
        for state in ("working", "idle", "blocked"):
            with self.subTest(state=state):
                self.session(state=state)
                updates, called = self.refresh()
                self.assertEqual(updates, {"@1": state})
                self.assertFalse(called)

    def test_multiple_agents_use_blocked_then_working_then_idle(self):
        for states, expected in (
            (("idle", "working"), "working"),
            (("blocked", "working", "idle"), "blocked"),
            (("idle", "idle"), "idle"),
        ):
            with self.subTest(states=states):
                for file in self.sessions.glob("*.json"):
                    file.unlink()
                for index, state in enumerate(states):
                    self.session(str(index), state=state)
                self.assertEqual(self.refresh()[0], {"@1": expected})

    def test_stale_dead_malformed_and_invalid_records_are_ignored(self):
        for extra in (
            {"updatedAt": (time.time() - 301) * 1000},
            {"updatedAt": "invalid"},
            {"updatedAt": float("nan")},
            {"pid": 2**30},
            {"pid": 2**100},
            {"pid": 0},
            {"pid": True},
            {"state": "unknown"},
            {"state": []},
            {"tmux": None},
            {"tmux": {"socket": self.socket, "pane": "%99"}},
            {"tmux": {"socket": self.socket + "-other", "pane": "%1"}},
            {"tmux": {"socket": "\\0", "pane": "%1"}},
        ):
            with self.subTest(extra=extra):
                self.session(**extra)
                self.assertEqual(self.refresh()[0], {})
        (self.sessions / "pi.json").write_text("not json")
        self.assertEqual(self.refresh()[0], {})
        (self.sessions / "pi.json").write_text("[]")
        self.assertEqual(self.refresh()[0], {})

    def test_finished_agent_clears_previous_badge(self):
        self.assertEqual(self.refresh(windows="@1\tworking\n")[0], {"@1": ""})

    def test_unchanged_windows_are_not_rewritten(self):
        self.session()
        self.assertEqual(self.refresh(windows="@1\tworking\n")[0], {})

    def test_agent_follows_its_pane_when_moved_to_another_window(self):
        self.session()
        self.assertEqual(
            self.refresh(
                windows="@1\tworking\n@2\t\n",
                panes="%1\t@2\tnode\n",
            )[0],
            {"@1": "", "@2": "working"},
        )

    def test_claude_resolver_is_combined_with_pi_and_scoped_to_server(self):
        self.session()
        record = {
            "source": "pane",
            "socket": self.socket,
            "pane": "%2",
            "state": "blocked",
        }
        updates, called = self.refresh(
            panes="%1\t@1\tnode\n%2\t@1\t2.1.304\n", claude=[record]
        )
        self.assertTrue(called)
        self.assertEqual(updates, {"@1": "blocked"})
        for extra in (
            {"socket": self.socket + "-other"},
            {"pane": "%99"},
            {"state": "unknown"},
            {"state": {}},
        ):
            with self.subTest(extra=extra):
                updates, _ = self.refresh(
                    panes="%1\t@1\tnode\n%2\t@2\tclaude\n",
                    claude=[{**record, **extra}],
                )
                self.assertEqual(updates, {"@1": "working"})

    def test_linked_window_is_updated_only_once(self):
        self.session()
        self.assertEqual(self.refresh(windows="@1\t\n@1\t\n")[0], {"@1": "working"})

    def claude(self, panes, screens=None):
        # panes: (pane, pid, command, title); screens: pane -> visible text.
        listing = "".join(
            "\x1f".join((self.socket, *map(str, pane))) + "\n" for pane in panes
        )

        def tmux(socket, *args):
            self.assertEqual(socket, self.socket)
            if args[0] == "list-panes":
                return listing
            return (screens or {}).get(args[-1], "")

        with patch.object(STATUS, "tmux", side_effect=tmux):
            return {
                record["pane"]: record["state"]
                for record in STATUS.claude_sessions(self.socket)
            }

    def test_claude_resolver_precedence(self):
        now = time.time() * 1000
        for name, state, updated in (
            ("blocked", "blocked", now),
            ("stale", "working", now - 301_000),
            ("idle", "idle", now - 3_600_000),
        ):
            (self.mods / f"{name}.json").write_text(
                json.dumps(
                    {
                        "state": state,
                        "updatedAt": updated,
                        "tmux": {"socket": self.socket, "pane": f"%{name}"},
                    }
                )
            )
        for pid, status, name in (
            (os.getpid(), "busy", "worker"),
            (2**30, "busy", "dead"),
        ):
            (self.registry / f"{pid}.json").write_text(
                json.dumps(
                    {"pid": pid, "status": status, "name": name, "updatedAt": now}
                )
            )
        panes = [
            ("%blocked", 1, "claude", "x"),
            ("%stale", 1, "claude", "x"),
            ("%idle", 1, "2.1.304", "x"),
            ("%owner", os.getpid(), "claude", "x"),
            ("%attached", 1, "claude", "✳ worker"),
            ("%dead", 1, "claude", "✳ dead"),
            ("%footer", 1, "claude", "x"),
            ("%waiting", 1, "claude", "x"),
            ("%shell", os.getpid(), "bash", "worker"),
        ]
        screens = {
            "%blocked": "  esc to interrupt\n",
            "%footer": "scrollback\n" + "  Thinking · esc to interrupt\n",
            "%waiting": "✻ Waiting for 2 background agents to finish\n",
            "%idle": "  esc to interrupt\n" + "\n" * 16,
        }
        self.assertEqual(
            self.claude(panes, screens),
            {
                "%blocked": "blocked",
                "%idle": "idle",
                "%owner": "working",
                "%attached": "working",
                "%footer": "working",
                "%waiting": "working",
            },
        )

    def test_claude_resolver_reports_pane_session_ids(self):
        (self.mods / "mod-session.json").write_text(
            json.dumps(
                {
                    "state": "idle",
                    "updatedAt": time.time() * 1000,
                    "tmux": {"socket": self.socket, "pane": "%1"},
                }
            )
        )
        (self.registry / "1.json").write_text(
            json.dumps(
                {"pid": os.getpid(), "status": "idle", "sessionId": "native-session"}
            )
        )
        listing = f"{self.socket}\x1f%1\x1f{os.getpid()}\x1fclaude\x1fx\n"
        with patch.object(
            STATUS,
            "tmux",
            side_effect=lambda socket, *args: (
                listing if args[0] == "list-panes" else ""
            ),
        ):
            (record,) = STATUS.claude_sessions(self.socket)
        self.assertEqual(record["sessions"], ["mod-session", "native-session"])

    def snapshot(self, number, session, **extra):
        directory = self.root / ".cache/gh-pr/owner/repo/feat%2Fx"
        directory.mkdir(parents=True, exist_ok=True)
        record = {
            "state": "open",
            "fetched_at": int(time.time()),
            "interval": 60,
            "watcher": {"claude_session": session},
            "url": f"https://github.com/owner/repo/pull/{number}",
            **extra,
        }
        (directory / f"{number}.json").write_text(json.dumps(record))

    def test_watched_prs_maps_sessions_to_live_pr_urls(self):
        now = int(time.time())
        self.snapshot(1, "a")
        self.snapshot(2, "a", state="merged")
        self.snapshot(3, "b", state="draft")
        for number, extra in enumerate(
            (
                {"fetched_at": now - 181},
                {"fetched_at": "now"},
                {"interval": "60"},
                {"state": "closed"},
                {"watcher": {"pi_session": "a"}},
                {"watcher": None},
                {"url": None},
                {"url": "https://github.com/owner/repo/pull/1#[fg=red]"},
                {"url": "https://example.com/owner/repo/pull/1"},
            ),
            start=10,
        ):
            self.snapshot(number, "a", **extra)
        (self.root / ".cache/gh-pr/owner/repo/feat%2Fx/99.json").write_text("{")
        with patch.dict(os.environ, {"XDG_CACHE_HOME": ""}):
            self.assertEqual(
                STATUS.watched_prs(now),
                {
                    "a": {
                        "https://github.com/owner/repo/pull/1",
                        "https://github.com/owner/repo/pull/2",
                    },
                    "b": {"https://github.com/owner/repo/pull/3"},
                },
            )

    def test_window_and_panes_get_linked_badges_for_their_prs(self):
        self.snapshot(1, "a")
        self.snapshot(2, "b")
        self.snapshot(3, "elsewhere")
        claude = [
            {"socket": self.socket, "pane": "%1", "state": "idle", "sessions": ["a"]},
            {"socket": self.socket, "pane": "%2", "state": "idle", "sessions": ["b"]},
        ]
        with (
            patch.object(
                STATUS,
                "tmux",
                side_effect=["@1\t\t\n", "%1\t@1\tclaude\n%2\t@1\tclaude\n", ""],
            ) as tmux,
            patch.object(STATUS, "claude_sessions", return_value=iter(claude)),
        ):
            STATUS.refresh(self.socket)
        self.assertEqual(
            tmux.call_args.args[1:],
            (
                "set-option",
                "-w",
                "-t",
                "@1",
                "@agent_state",
                "idle",
                ";",
                "set-option",
                "-w",
                "-t",
                "@1",
                "@agent_prs",
                "#[link=https://github.com/owner/repo/pull/1]\uf407#[nolink] #[link=https://github.com/owner/repo/pull/2]\uf407#[nolink]",
                ";",
                "set-option",
                "-p",
                "-t",
                "%1",
                "@pane_prs",
                "#[link=https://github.com/owner/repo/pull/1]\uf407#[nolink]",
                ";",
                "set-option",
                "-p",
                "-t",
                "%2",
                "@pane_prs",
                "#[link=https://github.com/owner/repo/pull/2]\uf407#[nolink]",
            ),
        )
        # Once the watches stop, the badges are cleared.
        with (
            patch.object(
                STATUS,
                "tmux",
                side_effect=["@1\tidle\tx\n", "%1\t@1\tclaude\tx\n", ""],
            ) as tmux,
            patch.object(STATUS, "claude_sessions", return_value=iter(claude[:1])),
            patch.object(STATUS, "watched_prs", return_value={}),
        ):
            STATUS.refresh(self.socket)
        self.assertEqual(
            tmux.call_args.args[1:],
            (
                "set-option",
                "-wu",
                "-t",
                "@1",
                "@agent_prs",
                ";",
                "set-option",
                "-pu",
                "-t",
                "%1",
                "@pane_prs",
            ),
        )

    def test_idle_session_with_background_tasks_is_idle(self):
        (self.registry / "1.json").write_text(
            json.dumps({"pid": os.getpid(), "status": "shell", "sessionId": "s"})
        )
        self.assertEqual(
            self.claude([("%1", os.getpid(), "2.1.312", "x")]), {"%1": "idle"}
        )

    def test_attached_worker_name_must_be_unique(self):
        for index in range(2):
            (self.registry / f"{index}.json").write_text(
                json.dumps({"pid": os.getpid(), "status": "idle", "name": "twin"})
            )
        self.assertEqual(self.claude([("%1", 1, "claude", "twin")]), {})

    def test_failing_tmux_does_not_invent_idle(self):
        for error in (
            FileNotFoundError(),
            subprocess.CalledProcessError(1, "tmux"),
            subprocess.TimeoutExpired("tmux", 3),
        ):
            with (
                self.subTest(error=error),
                patch.object(STATUS, "tmux", side_effect=error),
            ):
                self.assertEqual(list(STATUS.claude_sessions(self.socket)), [])

    @unittest.skipUnless(shutil.which("tmux"), "tmux is required")
    def test_real_tmux_config_badges_and_cleanup_on_isolated_server(self):
        # An empty HOME prevents sync-env.sh from sourcing the real work profile.
        config_home = self.root / ".config"
        config_home.mkdir()
        (config_home / "tmux").symlink_to(CONFIG)
        started = subprocess.run(
            [
                "tmux",
                "-S",
                self.socket,
                "-f",
                str(CONFIG / "tmux.conf"),
                "new-session",
                "-d",
                "-s",
                "agent-test",
                "sleep 300",
            ],
            capture_output=True,
            text=True,
            check=False,
            timeout=10,
        )
        self.assertEqual(started.returncode, 0, started.stderr)
        self.addCleanup(
            lambda: subprocess.run(
                ["tmux", "-S", self.socket, "kill-server"],
                capture_output=True,
                check=False,
                timeout=5,
            )
        )
        window, pane = (
            STATUS.tmux(
                self.socket, "display-message", "-p", "#{window_id}\t#{pane_id}"
            )
            .strip()
            .split("\t")
        )
        STATUS.tmux(self.socket, "rename-window", "-t", window, "agent-test")
        other = STATUS.tmux(
            self.socket, "new-window", "-d", "-P", "-F", "#{window_id}", "sleep 300"
        ).strip()
        STATUS.tmux(self.socket, "select-window", "-t", other)
        STATUS.tmux(self.socket, "select-window", "-t", window)
        for state, symbol, color in (
            ("working", "◐", "themeyellow"),
            ("idle", "○", "themelightgrey"),
            ("blocked", "!", "themered"),
        ):
            with self.subTest(state=state):
                self.session(state=state, tmux={"socket": self.socket, "pane": pane})
                STATUS.refresh(self.socket)
                self.assertEqual(
                    STATUS.tmux(
                        self.socket, "show-options", "-wv", "-t", window, "@agent_state"
                    ).strip(),
                    state,
                )
                inactive = STATUS.tmux(
                    self.socket,
                    "display-message",
                    "-p",
                    "-t",
                    window,
                    "#{E:window-status-format}",
                )
                current = STATUS.tmux(
                    self.socket,
                    "display-message",
                    "-p",
                    "-t",
                    window,
                    "#{E:window-status-current-format}",
                )
                self.assertIn(f"#[fg={color}]{symbol}", inactive)
                self.assertIn(f"agent-test* {symbol} ", current)
                self.assertNotIn("#[", current)
                # The last-window '-' flag must also remain beside the name,
                # never directly against the agent glyph.
                STATUS.tmux(self.socket, "select-window", "-t", other)
                last_window = STATUS.tmux(
                    self.socket,
                    "display-message",
                    "-p",
                    "-t",
                    window,
                    "#{E:window-status-format}",
                )
                plain_last = re.sub(r"#\[[^\]]*\]", "", last_window)
                self.assertIn(f"agent-test- {symbol} ", plain_last)
                STATUS.tmux(self.socket, "select-window", "-t", window)
                self.assertEqual(
                    STATUS.tmux(
                        self.socket,
                        "display-message",
                        "-p",
                        "-t",
                        window,
                        "#{window_name}",
                    ).strip(),
                    "agent-test",
                )
        (self.sessions / "pi.json").unlink()
        STATUS.refresh(self.socket)
        self.assertEqual(
            STATUS.tmux(
                self.socket, "show-options", "-wvq", "-t", window, "@agent_state"
            ).strip(),
            "",
        )
        normal = STATUS.tmux(
            self.socket,
            "display-message",
            "-p",
            "-t",
            window,
            "#{E:window-status-format}",
        )
        self.assertNotIn("◐", normal)
        self.assertNotIn("○", normal)
        self.assertNotIn("#[", normal)
        self.assertIn("agent-test* ", normal)
        status_left = STATUS.tmux(self.socket, "show-options", "-gv", "status-left")
        self.assertIn("agent-status.py", status_left)
        self.assertEqual(
            STATUS.tmux(
                self.socket, "show-options", "-gv", "status-left-length"
            ).strip(),
            "4",
        )


if __name__ == "__main__":
    unittest.main()
