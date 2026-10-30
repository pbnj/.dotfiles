import json
import shlex
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import install
import launch


class LauncherTests(unittest.TestCase):
    def setUp(self):
        local = patch("launch.LOCAL_CONFIG", Path("/nonexistent/agent-url.json"))
        local.start()
        self.addCleanup(local.stop)
        self.config = launch.load_config()
        environment = patch.dict(
            "launch.os.environ",
            {"TMUX": "", "TMUX_PANE": "", "REX_BLOCK": "", "REX_SESSION": ""},
        )
        environment.start()
        self.addCleanup(environment.stop)

    def test_exact_presets(self):
        expected = {
            "haiku": ("claude", "haiku", "high", 4, False),
            "opus": ("claude", "opus", "medium", 31, False),
            "sonnet": ("claude", "sonnet", "medium", 1, False),
            "sol": ("copilot", "gpt-6.1-sol", "high", 1, True),
            "auto": ("copilot", "auto", None, 5, True),
            "luna": ("copilot", "gpt-6-luna", "max", 37, True),
            "pi": ("pi", None, None, 35, False),
        }
        self.assertEqual(set(self.config["presets"]), set(expected))
        for key, values in expected.items():
            preset = self.config["presets"][key]
            self.assertEqual(
                tuple(
                    preset.get(k)
                    for k in ("agent", "model", "effort", "key_code", "shift")
                ),
                values,
            )

    def test_agent_flags_never_auto_submit(self):
        url = "https://example.com/?x=';$(id)&y=2"
        with patch(
            "launch.shutil.which", side_effect=lambda name, **kw: "/bin/" + name
        ):
            for preset in self.config["presets"].values():
                command = launch.agent_command(preset, "widget#123")
                self.assertNotIn(url, command)
                for flag in (
                    "-i",
                    "--interactive",
                    "-p",
                    "--prompt",
                    "--",
                    "--prefill",
                    "--extension",
                    "--agent-url-prefill",
                ):
                    self.assertNotIn(flag, command)
                if preset["agent"] == "claude":
                    self.assertIn("--dangerously-skip-permissions", command)
                    self.assertIn("--remote-control", command)
                    self.assertEqual(
                        command[-4:],
                        ["--name", "widget#123", "--remote-control", "widget#123"],
                    )
                elif preset["agent"] == "copilot":
                    self.assertIn("--yolo", command)
                    self.assertNotIn(url, command)
                    self.assertEqual(
                        command[-4:], ["--mode", "interactive", "--name", "widget#123"]
                    )
                else:
                    self.assertEqual(command, ["/bin/pi", "--name", "widget#123"])

    def test_url_validation(self):
        for value in (
            "https://example.com/a?b=1#c",
            "file:///tmp/a",
            "about:blank",
            "https://example.com/?x=';$()&a=2",
            "brave://settings",
        ):
            self.assertEqual(launch.validate_url(value), value)
        for value in (
            "",
            "not-a-url",
            "https://",
            "https://example.com/\nignore",
            "https://example.com/\x00",
            "https://example.com/has space",
        ):
            with self.assertRaises(ValueError):
                launch.validate_url(value)

    def test_boilerplate_removed(self):
        self.assertNotIn("prompt_file", self.config)
        self.assertFalse((launch.ROOT / "prompt.md").exists())

    def test_missing_executable(self):
        with (
            patch("launch.shutil.which", return_value=None),
            self.assertRaisesRegex(ValueError, "Cannot find"),
        ):
            launch.agent_command(self.config["presets"]["pi"], "widget")

    def test_creates_tmux_session_and_ghostty_attach_when_none_exist(self):
        url = "https://example.com/?x=';$(touch%20/tmp/nope)&a=2"
        missing = subprocess.CompletedProcess([], 1, "", "no server")
        created = subprocess.CompletedProcess([], 0, "$0\n", "")
        ok = subprocess.CompletedProcess([], 0, "", "")
        with (
            patch("launch.shutil.which", return_value="/bin/tmux"),
            patch("launch.subprocess.run", side_effect=[missing, created, ok]) as run,
        ):
            launch.open_session(
                "pi", self.config["presets"]["pi"], url, Path("/tmp/a b")
            )
        new_session = run.call_args_list[1][0][0]
        self.assertIn("new-session", new_session)
        self.assertEqual(new_session[new_session.index("-c") + 1], "/tmp/a b")
        self.assertEqual(new_session[new_session.index("-n") + 1], "a b")
        # The URL reaches the pane runner as argv data, never through a shell.
        self.assertEqual(shlex.split(new_session[-1])[-2:], ["--url", url])
        terminal = run.call_args_list[2][0][0]
        self.assertEqual(terminal[:4], ["/usr/bin/open", "-na", "Ghostty", "--args"])
        self.assertEqual(
            shlex.split(terminal[-1]),
            ["exec", "/bin/tmux", "attach-session", "-t", "$0"],
        )

    def test_requires_tmux(self):
        with (
            patch("launch.shutil.which", return_value=None),
            self.assertRaisesRegex(ValueError, "tmux is required"),
        ):
            launch.open_session(
                "pi",
                self.config["presets"]["pi"],
                "https://example.com",
                Path("/tmp"),
            )

    def test_tmux_selects_most_recent_attached_session(self):
        sessions = subprocess.CompletedProcess(
            [], 0, "$0\t0\t999\n$1\t1\t10\n$2\t2\t20\n", ""
        )
        ok = subprocess.CompletedProcess([], 0, "", "")
        with (
            patch("launch.shutil.which", return_value="/bin/tmux"),
            patch("launch.subprocess.run", side_effect=[sessions, ok, ok, ok]) as run,
        ):
            launch.open_session(
                "pi", self.config["presets"]["pi"], "https://example.com", Path("/tmp")
            )
        self.assertIn("list-windows", run.call_args_list[1][0][0])
        args = run.call_args_list[2][0][0]
        self.assertEqual(args[args.index("-t") + 1], "$2:")
        self.assertEqual(args[args.index("-n") + 1], "tmp")

    def test_tmux_failure_does_not_launch_duplicate(self):
        sessions = subprocess.CompletedProcess([], 0, "$1\t1\t10\n", "")
        windows = subprocess.CompletedProcess([], 0, "", "")
        failed = subprocess.CompletedProcess([], 1, "", "test failure")
        with (
            patch("launch.shutil.which", return_value="/bin/tmux"),
            patch(
                "launch.subprocess.run", side_effect=[sessions, windows, failed]
            ) as run,
            self.assertRaisesRegex(ValueError, "tmux could not"),
        ):
            launch.open_session(
                "pi",
                self.config["presets"]["pi"],
                "https://example.com",
                Path("/tmp"),
            )
        self.assertEqual(run.call_count, 3)

    def test_current_tmux_session_wins_over_another_attached_session(self):
        sessions = subprocess.CompletedProcess([], 0, "$0\t1\t10\n$1\t1\t999\n", "")
        current = subprocess.CompletedProcess([], 0, "$0\n", "")
        ok = subprocess.CompletedProcess([], 0, "", "")
        with (
            patch.dict("launch.os.environ", {"TMUX": "socket,1,0", "TMUX_PANE": "%1"}),
            patch("launch.shutil.which", return_value="/bin/tmux"),
            patch(
                "launch.subprocess.run", side_effect=[sessions, current, ok, ok, ok]
            ) as run,
        ):
            launch.open_session(
                "pi", self.config["presets"]["pi"], "https://example.com", Path("/tmp")
            )
        args = run.call_args_list[3][0][0]
        self.assertEqual(args[args.index("-t") + 1], "$0:")

    def test_unattached_session_is_opened_in_ghostty(self):
        sessions = subprocess.CompletedProcess([], 0, "$2\t0\t20\n", "")
        ok = subprocess.CompletedProcess([], 0, "", "")
        with (
            patch("launch.shutil.which", return_value="/bin/tmux"),
            patch("launch.subprocess.run", side_effect=[sessions, ok, ok, ok]) as run,
        ):
            launch.open_session(
                "pi", self.config["presets"]["pi"], "https://example.com", Path("/tmp")
            )
        self.assertIn("attach-session", run.call_args_list[3][0][0][-1])

    def test_window_names_follow_the_directory(self):
        config = {
            "github_root": "/p/github.com",
            "working_directory": "/p",
            "linear_teams": {"ENG": "acme/widget"},
        }
        cases = {
            "https://github.com/acme/widget": "widget",
            "https://github.com/acme/widget/pulls": "widget",
            "https://github.com/acme/widget/pull/123/files#diff": "widget",
            "https://linear.app/acme/issue/ENG-111/fix-thing": "widget",
            "https://linear.app/acme/issue/OPS-7": "p",
            "https://example.com/x": "p",
        }
        for url, expected in cases.items():
            with self.subTest(url=url):
                directory, _ = launch.project_directory(config, url)
                self.assertEqual(launch.window_name(directory), expected)

    def test_pane_labels(self):
        cases = {
            "https://linear.app/acme/issue/ENG-111/fix-thing": "ENG#111",
            "https://linear.app/acme/issue/eng-7": "ENG#7",
            "https://github.com/acme/widget": "widget",
            "https://github.com/acme/widget/": "widget",
            "https://github.com/acme/widget/pulls": "widget/pulls",
            "https://github.com/acme/widget/pull/123/files#diff": "widget#123",
            "https://github.com/acme/widget/issues/9": "widget#9",
            "https://github.com/acme/widget/blob/main/a.py": "widget/blob/main/a.py",
            "https://linear.app/acme/project/foo": "https://linear.app/acme/project/foo",
            "https://example.com/x?y=1#z": "https://example.com/x?y=1#z",
        }
        for url, expected in cases.items():
            with self.subTest(url=url):
                self.assertEqual(launch.pane_label(url), expected)

    def test_pane_links(self):
        cases = {
            "https://linear.app/acme/issue/eng-123/fix-thing": "https://linear.app/acme/issue/ENG-123",
            "https://github.com/acme/widget/pull/123/files#diff": "https://github.com/acme/widget/pull/123",
            "https://github.com/acme/widget": "https://github.com/acme/widget",
            "https://github.com/acme/widget/issues/9": "https://github.com/acme/widget/issues/9",
            "https://linear.app/acme/project/foo": "https://linear.app/acme/project/foo",
            "https://linear.app/a,b/issue/ENG-1": "https://linear.app/a%2Cb/issue/ENG-1",
            "https://example.com/x?a=1,2&b=[3]#top": "https://example.com/x?a=1%2C2&b=%5B3%5D#top",
            "https://example.com/x": "https://example.com/x",
        }
        for url, expected in cases.items():
            with self.subTest(url=url):
                self.assertEqual(launch.pane_link(url), expected)

    def test_long_window_links_fit_tmux_style_limit(self):
        path = "https://example.com/" + "p" * 150
        query = "?q=" + "x" * 40
        cases = {
            path + query: path + query,
            path + query + "#" + "f" * 40: path + query,
            path + "?q=" + "x" * 100 + "#f": path,
            "https://example.com/" + "p" * 300: None,
        }
        for url, expected in cases.items():
            with self.subTest(url=url[:40]):
                self.assertEqual(launch.pane_link(url), expected)
                if expected:
                    self.assertLessEqual(len(expected), launch.TMUX_LINK_MAX)

    def test_new_window_is_linked_to_its_repo(self):
        sessions = subprocess.CompletedProcess([], 0, "$1\t1\t10\n", "")
        created = subprocess.CompletedProcess([], 0, "@7\n", "")
        ok = subprocess.CompletedProcess([], 0, "", "")
        with (
            patch("launch.shutil.which", return_value="/bin/tmux"),
            patch(
                "launch.subprocess.run", side_effect=[sessions, ok, created, ok, ok]
            ) as run,
        ):
            launch.open_session(
                "pi",
                self.config["presets"]["pi"],
                "https://github.com/acme/widget/pull/123",
                Path("/p/acme/widget"),
                "acme/widget",
            )
        new_window = run.call_args_list[2][0][0]
        self.assertEqual(new_window[new_window.index("-n") + 1], "widget")
        self.assertEqual(
            run.call_args_list[3][0][0],
            [
                "/bin/tmux",
                "set-option",
                "-w",
                "-t",
                "@7",
                "@url",
                "https://github.com/acme/widget",
            ],
        )

    def test_new_window_name_escapes_tmux_formats(self):
        sessions = subprocess.CompletedProcess([], 0, "$1\t1\t10\n", "")
        ok = subprocess.CompletedProcess([], 0, "", "")
        with (
            patch("launch.shutil.which", return_value="/bin/tmux"),
            patch("launch.subprocess.run", side_effect=[sessions, ok, ok, ok]) as run,
        ):
            launch.open_session(
                "pi",
                self.config["presets"]["pi"],
                "https://example.com/x#y",
                Path("/p/a#b"),
            )
        args = run.call_args_list[2][0][0]
        self.assertIn("new-window", args)
        self.assertEqual(args[args.index("-n") + 1], "a##b")

    def test_existing_window_gets_a_split(self):
        sessions = subprocess.CompletedProcess([], 0, "$1\t1\t10\n", "")
        windows = subprocess.CompletedProcess(
            [], 0, "@1\tzsh\n@4\twidget\n@5\twidget#123\n", ""
        )
        ok = subprocess.CompletedProcess([], 0, "", "")
        with (
            patch("launch.shutil.which", return_value="/bin/tmux"),
            patch(
                "launch.subprocess.run",
                side_effect=[sessions, windows, ok, ok, ok, ok],
            ) as run,
        ):
            launch.open_session(
                "pi",
                self.config["presets"]["pi"],
                "https://github.com/acme/widget/pull/123",
                Path("/p/acme/widget"),
                "acme/widget",
            )
        split = run.call_args_list[2][0][0]
        self.assertEqual(split[:4], ["/bin/tmux", "split-window", "-t", "@4"])
        self.assertNotIn("new-window", [a for c in run.call_args_list for a in c[0][0]])
        self.assertEqual(
            run.call_args_list[3][0][0],
            ["/bin/tmux", "select-layout", "-t", "@4", "tiled"],
        )
        self.assertEqual(
            run.call_args_list[4][0][0], ["/bin/tmux", "select-window", "-t", "@4"]
        )


class ProjectTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.config = {
            "github_root": str(self.root / "github.com"),
            "working_directory": str(self.root / "default"),
        }
        cache = patch("launch.CACHE", self.root / "cache")
        cache.start()
        self.addCleanup(cache.stop)

    def test_github_deep_links_and_clone_urls(self):
        for suffix in (
            "",
            "/",
            ".git",
            ".git/",
            "/pull/123?x=1#diff",
            "/issues/4",
            "/blob/main/file.py",
            "/actions/runs/123",
        ):
            url = "https://github.com/Org/Repo" + suffix
            directory, spec = launch.project_directory(self.config, url)
            self.assertEqual(spec, "Org/Repo")
            self.assertEqual(directory, self.root / "github.com/Org/Repo")
        self.assertEqual(
            launch.github_repository("https://www.github.com/Org/Repo/pull/1"),
            "Org/Repo",
        )

    def test_local_config_overrides_top_level_keys(self):
        local = self.root / "local.json"
        local.write_text('{"linear_teams": {"ENG": "Org/widget"}}')
        with patch("launch.LOCAL_CONFIG", local):
            config = launch.load_config()
        self.assertEqual(config["linear_teams"], {"ENG": "Org/widget"})
        self.assertIn("presets", config)

    def test_mapped_linear_teams_use_their_repo(self):
        self.config["linear_teams"] = {"ENG": "Org/widget", "BAD": "../x"}
        directory, spec = launch.project_directory(
            self.config, "https://linear.app/org/issue/eng-111/title"
        )
        self.assertEqual(spec, "Org/widget")
        self.assertEqual(directory, self.root / "github.com/Org/widget")
        directory, spec = launch.project_directory(
            self.config, "https://linear.app/org/issue/OPS-1"
        )
        self.assertEqual((directory, spec), (self.root / "default", None))
        with self.assertRaises(ValueError):
            launch.project_directory(self.config, "https://linear.app/o/issue/BAD-1")

    def test_non_repo_urls_use_default_without_cloning(self):
        for url in (
            "https://example.com/a/b",
            "https://github.com/Org",
            "https://github.com/settings/profile",
            "https://github.com/orgs/Org/projects",
            "https://github.com.evil.test/Org/Repo",
        ):
            directory, spec = launch.project_directory(self.config, url)
            self.assertEqual(directory, self.root / "default")
            self.assertIsNone(spec)

    def test_path_traversal_and_option_injection_are_rejected(self):
        for path in (
            "../repo",
            "org/..",
            "org/%2e%2e",
            "org/a%2fb",
            "-flag/repo",
            "org/.git",
        ):
            with self.assertRaises(ValueError):
                launch.project_directory(self.config, "https://github.com/" + path)

    def test_symlink_escape_is_rejected(self):
        root = self.root / "github.com"
        root.mkdir()
        outside = self.root / "outside"
        outside.mkdir()
        (root / "Org").symlink_to(outside, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, "escapes"):
            launch.project_directory(self.config, "https://github.com/Org/Repo")

    def test_existing_git_checkout_and_worktree_are_not_cloned(self):
        for name, git_file in (("repo", False), ("worktree", True)):
            directory = self.root / name
            directory.mkdir()
            if git_file:
                (directory / ".git").write_text("gitdir: /somewhere")
            else:
                (directory / ".git").mkdir()
            with patch("launch.subprocess.run") as run:
                launch.prepare_directory(directory, "org/" + name)
            run.assert_not_called()

    def test_clone_is_staged_and_installed_atomically(self):
        directory = self.root / "github.com/Org/Repo"

        def clone(args, **kwargs):
            self.assertEqual(args[:4], ["/bin/gh", "repo", "clone", "Org/Repo"])
            checkout = Path(args[4])
            self.assertNotEqual(checkout, directory)
            checkout.mkdir()
            (checkout / ".git").mkdir()
            return subprocess.CompletedProcess(args, 0, "", "")

        with (
            patch("launch.shutil.which", return_value="/bin/gh"),
            patch("launch.subprocess.run", side_effect=clone),
        ):
            launch.prepare_directory(directory, "Org/Repo")
        self.assertTrue((directory / ".git").is_dir())
        self.assertFalse(list(directory.parent.glob(".agent-url-*")))

    def test_failed_clone_never_opens_agent_or_leaves_half_checkout(self):
        directory = self.root / "github.com/Org/Repo"
        failed = subprocess.CompletedProcess([], 1, "", "not found")
        with (
            patch("launch.shutil.which", return_value="/bin/gh"),
            patch("launch.subprocess.run", return_value=failed),
            self.assertRaisesRegex(ValueError, "Could not clone"),
        ):
            launch.prepare_directory(directory, "Org/Repo")
        self.assertFalse(directory.exists())
        self.assertFalse(list(directory.parent.glob(".agent-url-*")))

    def test_clone_path_with_real_local_git_repository(self):
        upstream = self.root / "upstream.git"
        subprocess.run(
            ["/usr/bin/git", "init", "--bare", str(upstream)],
            check=True,
            capture_output=True,
        )
        destination = self.root / "github.com/Org/Repo"
        real_run = subprocess.run

        def clone_from_local_fixture(args, **kwargs):
            self.assertEqual(args[1:4], ["repo", "clone", "Org/Repo"])
            return real_run(["/usr/bin/git", "clone", str(upstream), args[4]], **kwargs)

        with (
            patch("launch.shutil.which", return_value="/bin/gh"),
            patch("launch.subprocess.run", side_effect=clone_from_local_fixture),
        ):
            launch.prepare_directory(destination, "Org/Repo")
        result = real_run(
            ["/usr/bin/git", "-C", str(destination), "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
            check=True,
        )
        self.assertEqual(Path(result.stdout.strip()).resolve(), destination.resolve())

    def test_clone_failure_stops_before_opening_a_window(self):
        with (
            patch(
                "launch.sys.argv",
                ["agent-url", "pi", "--url", "https://github.com/Org/Repo/pull/1"],
            ),
            patch("launch.shutil.which", return_value="/bin/placeholder"),
            patch(
                "launch.project_directory",
                return_value=(self.root / "Repo", "Org/Repo"),
            ),
            patch("launch.prepare_directory", side_effect=ValueError("clone failed")),
            patch("launch.open_session") as open_session,
            self.assertRaisesRegex(ValueError, "clone failed"),
        ):
            launch.main()
        open_session.assert_not_called()

    def test_dry_run_does_not_clone_or_open_windows(self):
        with (
            patch(
                "launch.sys.argv",
                [
                    "agent-url",
                    "pi",
                    "--dry-run",
                    "--url",
                    "https://github.com/Org/Repo/pull/1",
                ],
            ),
            patch("launch.shutil.which", return_value="/bin/pi"),
            patch(
                "launch.project_directory",
                return_value=(self.root / "Repo", "Org/Repo"),
            ),
            patch("launch.prepare_directory") as prepare,
            patch("launch.open_session") as open_session,
            patch("builtins.print") as output,
        ):
            self.assertEqual(launch.main(), 0)
        prepare.assert_not_called()
        open_session.assert_not_called()
        plan = json.loads(output.call_args[0][0])
        self.assertEqual(plan["prefill"], "https://github.com/Org/Repo/pull/1")
        self.assertEqual(plan["github_repo"], "Org/Repo")
        self.assertFalse(plan["submit"])

    def test_existing_non_git_directory_is_never_overwritten(self):
        directory = self.root / "Repo"
        directory.mkdir()
        marker = directory / "keep.txt"
        marker.write_text("important")
        with (
            patch("launch.subprocess.run") as run,
            self.assertRaisesRegex(ValueError, "Refusing to overwrite"),
        ):
            launch.prepare_directory(directory, "Org/Repo")
        run.assert_not_called()
        self.assertEqual(marker.read_text(), "important")


class SharedPrefillTests(unittest.TestCase):
    def setUp(self):
        self.url = "https://example.com/?x=';$(id)&y=2"
        environment = patch.dict(
            "launch.os.environ", {"REX_BLOCK": "", "REX_SESSION": ""}
        )
        environment.start()
        self.addCleanup(environment.stop)

    def test_reuses_reference_worker_in_detached_tmux_job(self):
        runner = [
            "/usr/bin/env",
            "PATH=/test/bin",
            "/test/bin/bash",
            "/home/test/.local/bin/fzf-tmux-project",
        ]
        with (
            patch("launch.prefill_runner", return_value=runner),
            patch("launch.subprocess.run") as run,
        ):
            launch.schedule_prefill("/test/bin/tmux", "%4", self.url)
        args = run.call_args[0][0]
        self.assertEqual(len(args), 6)
        self.assertEqual(args[:5], ["/test/bin/tmux", "run-shell", "-b", "-t", "%4"])
        self.assertEqual(shlex.split(args[-1]), runner + ["--prefill", "%4", self.url])
        self.assertNotIn("Enter", shlex.split(args[-1]))
        self.assertTrue(run.call_args[1]["check"])

    def test_tmux_formats_in_url_are_escaped(self):
        url = "https://example.com/draft#{pane_id}#(false)"
        with (
            patch("launch.prefill_runner", return_value=["worker"]),
            patch("launch.subprocess.run") as run,
        ):
            launch.schedule_prefill("/bin/tmux", "%4", url)
        command = run.call_args[0][0][-1]
        self.assertIn("##{pane_id}##(false)", command)
        self.assertEqual(shlex.split(command.replace("##", "#"))[-1], url)

    def test_invalid_pane_or_url_is_rejected_before_scheduling(self):
        for pane, url in (
            ("", self.url),
            ("other-pane", self.url),
            ("%4", self.url + "\n"),
        ):
            with (
                patch("launch.subprocess.run") as run,
                self.assertRaises(ValueError),
            ):
                launch.schedule_prefill("/bin/tmux", pane, url)
            run.assert_not_called()

    def test_reference_worker_is_required(self):
        with (
            patch("launch.Path.is_file", return_value=False),
            self.assertRaisesRegex(
                ValueError, "requires ~/.local/bin/fzf-tmux-project"
            ),
        ):
            launch.prefill_runner()

    def test_bash_is_required(self):
        with (
            patch("launch.Path.is_file", return_value=True),
            patch("launch.shutil.which", return_value=None),
            self.assertRaisesRegex(ValueError, "Cannot find bash"),
        ):
            launch.prefill_runner()

    def test_run_schedules_worker_before_replacing_runner_with_agent(self):
        calls = []
        with (
            patch("launch.sys.argv", ["agent-url", "pi", "--run", "--url", self.url]),
            patch.dict("launch.os.environ", {"TMUX": "socket,1,0", "TMUX_PANE": "%4"}),
            patch("launch.shutil.which", side_effect=lambda name, **kw: "/bin/" + name),
            patch("launch.prefill_runner", return_value=["worker"]),
            patch("launch.prepare_directory"),
            patch("launch.os.chdir"),
            patch(
                "launch.label_pane",
                side_effect=lambda *args: calls.append(("label", args)),
            ),
            patch(
                "launch.schedule_prefill",
                side_effect=lambda *args: calls.append(("prefill", args)),
            ),
            patch(
                "launch.os.execvpe",
                side_effect=lambda *args: calls.append(("exec", args)),
            ),
        ):
            self.assertEqual(launch.main(), 0)
        self.assertEqual([entry[0] for entry in calls], ["label", "prefill", "exec"])
        self.assertEqual(calls[0][1][:3], ("/bin/tmux", "%4", self.url))
        self.assertEqual(calls[1][1], ("/bin/tmux", "%4", self.url))
        # An unrecognized URL labels the pane, but the session takes the directory.
        self.assertEqual(
            calls[2][1][:2], ("/bin/pi", ["/bin/pi", "--name", "Projects"])
        )
        self.assertNotIn(self.url, calls[2][1][1])

    def test_run_outside_tmux_is_rejected_before_clone(self):
        with (
            patch("launch.sys.argv", ["agent-url", "pi", "--run", "--url", self.url]),
            patch.dict(
                "launch.os.environ",
                {"TMUX": "", "TMUX_PANE": "", "REX_BLOCK": "", "REX_SESSION": ""},
            ),
            patch("launch.shutil.which", return_value="/bin/tool"),
            patch("launch.prefill_runner", return_value=["worker"]),
            patch("launch.prepare_directory") as prepare,
            self.assertRaisesRegex(ValueError, "inside a tmux pane"),
        ):
            launch.main()
        prepare.assert_not_called()

    def test_agent_specific_prefill_modules_removed(self):
        self.assertFalse((launch.ROOT / "pi-prefill.js").exists())
        self.assertFalse((launch.ROOT / "copilot_prefill.py").exists())


SESSION = "session:0000-1111"
BLOCK = "block:aaaa-bbbb"


def completed(stdout="", returncode=0, stderr=""):
    return subprocess.CompletedProcess([], returncode, stdout, stderr)


def clients_json(*sessions, kind="app", state="connected"):
    return json.dumps(
        {
            "clients": [
                {"client_id": "client:cli"},
                {
                    "client_id": "client:app",
                    "info": {"kind": kind},
                    "connection_state": state,
                    "session_ids": list(sessions),
                },
            ]
        }
    )


class RexTests(unittest.TestCase):
    def setUp(self):
        local = patch("launch.LOCAL_CONFIG", Path("/nonexistent/agent-url.json"))
        local.start()
        self.addCleanup(local.stop)
        environment = patch.dict(
            "launch.os.environ",
            {"TMUX": "", "TMUX_PANE": "", "REX_BLOCK": "", "REX_SESSION": ""},
        )
        environment.start()
        self.addCleanup(environment.stop)
        self.url = "https://github.com/acme/widget/pull/123?x=';$(id)"

    def test_rex_is_used_while_its_app_is_connected(self):
        with (
            patch("launch.shutil.which", return_value="/bin/rex"),
            patch(
                "launch.subprocess.run", return_value=completed(clients_json(SESSION))
            ) as run,
        ):
            self.assertEqual(launch.rex_target(), ("/bin/rex", SESSION))
        # Never starts a Rex server just to look for one.
        self.assertEqual(
            run.call_args[0][0],
            ["/bin/rex", "--autostart=false", "client", "ls", "--json"],
        )

    def test_current_rex_session_wins(self):
        other = "session:2222-3333"
        with (
            patch.dict("launch.os.environ", {"REX_SESSION": other}),
            patch("launch.shutil.which", return_value="/bin/rex"),
            patch(
                "launch.subprocess.run",
                return_value=completed(clients_json(SESSION, other)),
            ),
        ):
            self.assertEqual(launch.rex_target(), ("/bin/rex", other))

    def test_falls_back_to_tmux_without_a_usable_rex(self):
        cases = (
            (None, completed(clients_json(SESSION))),  # no rex CLI
            ("/bin/rex", completed("", 1, "no server")),  # no server
            ("/bin/rex", completed(clients_json(SESSION, state="disconnected"))),
            ("/bin/rex", completed(clients_json(SESSION, kind="cli"))),  # no app
            ("/bin/rex", completed(clients_json())),  # app shows no session
            ("/bin/rex", completed("not json")),
            ("/bin/rex", completed(clients_json("session:$(id)"))),
        )
        for rex, result in cases:
            with (
                patch("launch.shutil.which", return_value=rex),
                patch("launch.subprocess.run", return_value=result),
            ):
                self.assertIsNone(launch.rex_target(), (rex, result))
        with (
            patch("launch.shutil.which", return_value="/bin/rex"),
            patch("launch.subprocess.run", side_effect=OSError("missing")),
        ):
            self.assertIsNone(launch.rex_target())

    def test_new_rex_window_runs_the_runner_and_is_shown(self):
        windows = completed(
            json.dumps({"windows": [{"window_id": "window:1", "label": "zsh"}]})
        )
        created = completed(json.dumps({"window_id": "window:9", "block_ids": [BLOCK]}))
        with patch(
            "launch.subprocess.run",
            side_effect=[windows, created, completed(), completed()],
        ) as run:
            launch.open_rex_session(
                "/bin/rex", SESSION, "pi", self.url, Path("/p/acme/widget")
            )
        new = run.call_args_list[1][0][0]
        self.assertEqual(
            new[:9],
            [
                "/bin/rex",
                "window",
                "new",
                "-s",
                SESSION,
                "widget",
                "-c",
                "/p/acme/widget",
                "--json",
            ],
        )
        # The URL reaches the runner as argv data after --, never through a shell.
        self.assertEqual(new[9], "--")
        self.assertEqual(new[-4:], ["pi", "--run", "--url", self.url])
        self.assertEqual(
            run.call_args_list[2][0][0],
            [
                "/bin/rex",
                "do",
                "session.select",
                "session_id=" + SESSION,
                "window_id=window:9",
            ],
        )
        self.assertEqual(
            run.call_args_list[3][0][0], ["/usr/bin/open", "-b", "com.superlogical.rex"]
        )

    def test_existing_rex_window_gets_a_split(self):
        windows = completed(
            json.dumps({"windows": [{"window_id": "window:4", "label": "widget"}]})
        )
        with patch(
            "launch.subprocess.run",
            side_effect=[windows, completed(), completed(), completed()],
        ) as run:
            launch.open_rex_session(
                "/bin/rex", SESSION, "pi", self.url, Path("/p/acme/widget")
            )
        split = run.call_args_list[1][0][0]
        self.assertEqual(
            split[:8],
            [
                "/bin/rex",
                "split",
                "-s",
                SESSION,
                "-w",
                "window:4",
                "-c",
                "/p/acme/widget",
            ],
        )
        self.assertIn("window_id=window:4", run.call_args_list[2][0][0])

    def test_rex_window_label_never_reads_as_a_flag(self):
        self.assertEqual(launch.rex_window_label(Path("/p/acme/-rf")), "_-rf")

    def test_rex_failure_raises_without_showing_a_window(self):
        with (
            patch(
                "launch.subprocess.run",
                side_effect=[completed("{}"), completed("", 1, "boom")],
            ) as run,
            self.assertRaisesRegex(ValueError, "Rex could not open"),
        ):
            launch.open_rex_session("/bin/rex", SESSION, "pi", self.url, Path("/p/x"))
        self.assertEqual(run.call_count, 2)

    def test_main_prefers_rex_and_skips_the_tmux_worker_check(self):
        with (
            patch("launch.sys.argv", ["agent-url", "pi", "--url", self.url]),
            patch("launch.shutil.which", side_effect=lambda name, **kw: "/bin/" + name),
            patch("launch.rex_target", return_value=("/bin/rex", SESSION)),
            patch("launch.prefill_runner") as worker,
            patch("launch.prepare_directory"),
            patch("launch.open_rex_session") as open_rex,
            patch("launch.open_session") as open_tmux,
        ):
            self.assertEqual(launch.main(), 0)
        worker.assert_not_called()
        open_tmux.assert_not_called()
        self.assertEqual(
            open_rex.call_args[0][:4], ("/bin/rex", SESSION, "pi", self.url)
        )

    def test_main_falls_back_to_tmux(self):
        with (
            patch("launch.sys.argv", ["agent-url", "pi", "--url", self.url]),
            patch("launch.shutil.which", side_effect=lambda name, **kw: "/bin/" + name),
            patch("launch.rex_target", return_value=None),
            patch("launch.prefill_runner") as worker,
            patch("launch.prepare_directory"),
            patch("launch.open_rex_session") as open_rex,
            patch("launch.open_session") as open_tmux,
        ):
            self.assertEqual(launch.main(), 0)
        worker.assert_called_once()
        open_rex.assert_not_called()
        open_tmux.assert_called_once()

    def test_run_in_rex_block_labels_prefills_then_execs(self):
        calls = []
        with (
            patch("launch.sys.argv", ["agent-url", "pi", "--run", "--url", self.url]),
            patch.dict("launch.os.environ", {"REX_BLOCK": BLOCK}),
            patch("launch.shutil.which", side_effect=lambda name, **kw: "/bin/" + name),
            patch("launch.prefill_runner") as worker,
            patch("launch.prepare_directory"),
            patch("launch.os.chdir"),
            patch(
                "launch.label_rex_block",
                side_effect=lambda *a: calls.append(("label", a)),
            ),
            patch(
                "launch.schedule_rex_prefill",
                side_effect=lambda *a: calls.append(("prefill", a)),
            ),
            patch("launch.label_pane") as tmux_label,
            patch(
                "launch.os.execvpe", side_effect=lambda *a: calls.append(("exec", a))
            ),
        ):
            self.assertEqual(launch.main(), 0)
        worker.assert_not_called()
        tmux_label.assert_not_called()
        self.assertEqual([c[0] for c in calls], ["label", "prefill", "exec"])
        self.assertEqual(calls[0][1], ("/bin/rex", BLOCK, "widget#123"))
        self.assertEqual(calls[1][1], (BLOCK, self.url))
        self.assertNotIn(self.url, calls[2][1][1])

    def test_tmux_inside_rex_stays_with_tmux(self):
        with (
            patch("launch.sys.argv", ["agent-url", "pi", "--run", "--url", self.url]),
            patch.dict(
                "launch.os.environ",
                {"TMUX": "socket,1,0", "TMUX_PANE": "%4", "REX_BLOCK": BLOCK},
            ),
            patch("launch.shutil.which", side_effect=lambda name, **kw: "/bin/" + name),
            patch("launch.prefill_runner", return_value=["worker"]),
            patch("launch.prepare_directory"),
            patch("launch.os.chdir"),
            patch("launch.label_pane"),
            patch("launch.schedule_prefill") as tmux_prefill,
            patch("launch.schedule_rex_prefill") as rex_prefill,
            patch("launch.os.execvpe"),
        ):
            launch.main()
        tmux_prefill.assert_called_once()
        rex_prefill.assert_not_called()

    def test_rex_prefill_is_detached_and_validated(self):
        with patch("launch.subprocess.Popen") as popen:
            launch.schedule_rex_prefill(BLOCK, self.url)
        args, kwargs = popen.call_args
        self.assertEqual(args[0][-3:], ["--rex-prefill", BLOCK, self.url])
        self.assertTrue(kwargs["start_new_session"])
        for block, url in (
            ("", self.url),
            ("%4", self.url),
            ("block:$(id)", self.url),
            (BLOCK, self.url + "\n"),
        ):
            with (
                patch("launch.subprocess.Popen") as popen,
                self.assertRaises(ValueError),
            ):
                launch.schedule_rex_prefill(block, url)
            popen.assert_not_called()

    def run_prefill(self, responses):
        """rex_prefill against scripted (process, capture) responses."""
        sent = []

        def run(argv, **kwargs):
            if argv[1:3] == ["block", "call"]:
                return responses["process"].pop(0)
            if argv[1] == "capture":
                return responses["capture"].pop(0)
            sent.append(argv)
            return completed()

        with (
            patch("launch.shutil.which", return_value="/bin/rex"),
            patch("launch.time.sleep"),
            patch("launch.subprocess.run", side_effect=run),
        ):
            launch.rex_prefill(BLOCK, self.url, attempts=10)
        return sent

    def test_rex_prefill_waits_for_a_settled_agent_and_never_presses_enter(self):
        shell = completed(json.dumps({"foreground": {"argv0": "-bash"}}))
        agent = completed(json.dumps({"foreground": {"argv0": "claude"}}))
        sent = self.run_prefill(
            {
                "process": [shell, agent, agent, agent],
                "capture": [completed("loading"), completed("> "), completed("> ")],
            }
        )
        self.assertEqual(sent, [["/bin/rex", "send", "-b", BLOCK, "--", self.url]])

    def test_rex_prefill_skips_trust_dialogs_and_gives_up_when_the_block_closes(self):
        agent = completed(json.dumps({"foreground": {"argv0": "claude"}}))
        sent = self.run_prefill(
            {
                "process": [agent, agent, completed("", 1, "not found")],
                "capture": [
                    completed("Trust this folder?"),
                    completed("Trust this folder?"),
                ],
            }
        )
        self.assertEqual(sent, [])


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.config = launch.load_config()
        self.original = {
            "hyperKeyPhysicalKey": "capsLock",
            "hyperKeyIncludesShift": False,
            "unrelated": b"preserve me",
            "customCommands": b"[]",
        }

    def test_merge_is_idempotent_and_preserves_existing_data(self):
        old = {
            "id": "56f12d08-ae5f-4ab7-809c-e7f87551cbb1",
            "name": "Existing",
            "command": "true",
        }
        self.original["customCommands"] = json.dumps([old]).encode()
        self.original["boundCustomCommandIDs"] = [old["id"]]
        merged = install.configure(self.original, self.config)
        self.assertEqual(install.configure(merged, self.config), merged)
        self.assertEqual(json.loads(merged["customCommands"])[0], old)
        self.assertEqual(merged["unrelated"], b"preserve me")
        total = len(self.config["presets"]) + 1
        self.assertEqual(len(json.loads(merged["customCommands"])), total)
        self.assertEqual(len(merged["boundCustomCommandIDs"]), total)
        self.assertEqual(self.original["customCommands"], json.dumps([old]).encode())

    def test_carbon_modifiers(self):
        merged = install.configure(self.original, self.config)
        for key, preset in self.config["presets"].items():
            binding = json.loads(
                merged["hotkey.customCommand." + install.command_id(key)]
            )["combo"]["_0"]
            self.assertEqual(
                binding["carbonModifiers"], 6912 if preset["shift"] else 6400
            )

    def test_conflict_is_not_overwritten(self):
        self.original["hotkey.app.test"] = json.dumps(
            {"combo": {"_0": {"carbonKeyCode": 4, "carbonModifiers": 6400}}}
        )
        with self.assertRaisesRegex(ValueError, "already assigned"):
            install.configure(self.original, self.config)

    def test_duplicate_command_name_is_not_overwritten(self):
        self.original["customCommands"] = json.dumps(
            [
                {
                    "id": "56f12d08-ae5f-4ab7-809c-e7f87551cbb1",
                    "name": self.config["presets"]["pi"]["name"],
                    "command": "true",
                }
            ]
        ).encode()
        with self.assertRaisesRegex(ValueError, "already uses"):
            install.configure(self.original, self.config)

    def test_hyper_without_shift_required(self):
        for key, value in (
            ("hyperKeyIncludesShift", True),
            ("hyperKeyPhysicalKey", "none"),
        ):
            prefs = dict(self.original, **{key: value})
            with self.assertRaises(ValueError):
                install.configure(prefs, self.config)


if __name__ == "__main__":
    unittest.main()
