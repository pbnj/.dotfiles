"""Offline agent fixtures plus an isolated tmux server; no real sessions touched."""

import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time
import unittest
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
                "TMUX_AGENT_CLAUDE_HELPER": str(self.root / "claude_sessions.sh"),
            },
        )
        self.env.start()
        self.addCleanup(self.env.stop)

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

    def test_claude_helper_gets_target_socket_and_only_yields_panes(self):
        helper = self.root / "claude_sessions.sh"
        helper.touch()
        records = [
            {"source": "native", "state": "working"},
            {"source": "mod", "state": "blocked"},
            {"source": "pane", "state": "idle", "pane": "%2", "socket": self.socket},
        ]
        output = "\n".join(json.dumps(record) for record in records) + "\ninvalid\n[]"
        result = subprocess.CompletedProcess([], 0, stdout=output)
        with patch.object(STATUS.subprocess, "run", return_value=result) as run:
            self.assertEqual(list(STATUS.claude_sessions(self.socket)), [records[2]])
        self.assertEqual(run.call_args.args[0], ["bash", str(helper)])
        self.assertEqual(run.call_args.kwargs["env"]["TMUX"], f"{self.socket},0,0")

    def test_missing_or_failing_claude_helper_does_not_invent_idle(self):
        self.assertEqual(list(STATUS.claude_sessions(self.socket)), [])
        (self.root / "claude_sessions.sh").touch()
        for error in (
            FileNotFoundError(),
            subprocess.CalledProcessError(1, "bash"),
            subprocess.TimeoutExpired("bash", 3),
        ):
            with self.subTest(error=error):
                with patch.object(STATUS.subprocess, "run", side_effect=error):
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
