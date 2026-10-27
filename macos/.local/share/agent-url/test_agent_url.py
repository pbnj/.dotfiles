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
        self.config = launch.load_config()
        environment = patch.dict("launch.os.environ", {"TMUX": "", "TMUX_PANE": ""})
        environment.start()
        self.addCleanup(environment.stop)

    def test_exact_presets(self):
        expected = {
            "haiku": ("claude", "haiku", "max", 4, False),
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
            patch(
                "launch.subprocess.run", side_effect=[missing, created, ok, ok]
            ) as run,
        ):
            launch.open_session(
                "pi", self.config["presets"]["pi"], url, Path("/tmp/a b")
            )
        new_session = run.call_args_list[1][0][0]
        self.assertIn("new-session", new_session)
        self.assertEqual(new_session[new_session.index("-c") + 1], "/tmp/a b")
        self.assertEqual(shlex.split(new_session[-1])[-2:], ["--url", url])
        # The launching URL is passed to tmux as argv data, never through a shell.
        self.assertEqual(run.call_args_list[2][0][0][-2:], ["@url", url])
        terminal = run.call_args_list[3][0][0]
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

    def test_window_names(self):
        cases = {
            "https://linear.app/acme/issue/ENG-123/fix-thing": "ENG-123",
            "https://linear.app/acme/issue/eng-7": "ENG-7",
            "https://github.com/acme/widget": "widget",
            "https://github.com/acme/widget/issues/9": "widget",
            "https://github.com/acme/widget/pull/123/files#diff": "widget#123",
            "https://linear.app/acme/project/foo": "tmp",
            "https://example.com/x": "tmp",
        }
        for url, expected in cases.items():
            with self.subTest(url=url):
                self.assertEqual(launch.window_name(url, Path("/tmp")), expected)

    def test_window_links(self):
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
                self.assertEqual(launch.window_link(url), expected)

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
                self.assertEqual(launch.window_link(url), expected)
                if expected:
                    self.assertLessEqual(len(expected), launch.TMUX_LINK_MAX)

    def test_new_window_is_linked_to_its_pr(self):
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
                Path("/tmp"),
            )
        self.assertEqual(
            run.call_args_list[3][0][0],
            [
                "/bin/tmux",
                "set-option",
                "-w",
                "-t",
                "@7",
                "@url",
                "https://github.com/acme/widget/pull/123",
            ],
        )

    def test_new_session_window_is_linked_to_its_issue(self):
        missing = subprocess.CompletedProcess([], 1, "", "no server")
        created = subprocess.CompletedProcess([], 0, "$0\n", "")
        ok = subprocess.CompletedProcess([], 0, "", "")
        with (
            patch("launch.shutil.which", return_value="/bin/tmux"),
            patch(
                "launch.subprocess.run", side_effect=[missing, created, ok, ok]
            ) as run,
        ):
            launch.open_session(
                "pi",
                self.config["presets"]["pi"],
                "https://linear.app/acme/issue/ENG-123/fix-thing",
                Path("/tmp"),
            )
        self.assertEqual(
            run.call_args_list[2][0][0],
            [
                "/bin/tmux",
                "set-option",
                "-w",
                "-t",
                "$0:",
                "@url",
                "https://linear.app/acme/issue/ENG-123",
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
                "https://github.com/acme/widget/pull/123",
                Path("/tmp"),
            )
        args = run.call_args_list[2][0][0]
        self.assertIn("new-window", args)
        self.assertEqual(args[args.index("-n") + 1], "widget##123")

    def test_existing_window_gets_a_split(self):
        sessions = subprocess.CompletedProcess([], 0, "$1\t1\t10\n", "")
        windows = subprocess.CompletedProcess(
            [], 0, "@1\tzsh\n@4\twidget#123\n@5\twidget\n", ""
        )
        ok = subprocess.CompletedProcess([], 0, "", "")
        with (
            patch("launch.shutil.which", return_value="/bin/tmux"),
            patch(
                "launch.subprocess.run", side_effect=[sessions, windows, ok, ok, ok]
            ) as run,
        ):
            launch.open_session(
                "pi",
                self.config["presets"]["pi"],
                "https://github.com/acme/widget/pull/123",
                Path("/tmp"),
            )
        split = run.call_args_list[2][0][0]
        self.assertEqual(split[:4], ["/bin/tmux", "split-window", "-t", "@4"])
        self.assertNotIn("new-window", [a for c in run.call_args_list for a in c[0][0]])
        self.assertEqual(
            run.call_args_list[3][0][0], ["/bin/tmux", "select-window", "-t", "@4"]
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
                "launch.schedule_prefill",
                side_effect=lambda *args: calls.append(("prefill", args)),
            ),
            patch(
                "launch.os.execvpe",
                side_effect=lambda *args: calls.append(("exec", args)),
            ),
        ):
            self.assertEqual(launch.main(), 0)
        self.assertEqual([entry[0] for entry in calls], ["prefill", "exec"])
        self.assertEqual(calls[0][1], ("/bin/tmux", "%4", self.url))
        self.assertEqual(
            calls[1][1][:2], ("/bin/pi", ["/bin/pi", "--name", "github.com"])
        )
        self.assertNotIn(self.url, calls[1][1][1])

    def test_run_outside_tmux_is_rejected_before_clone(self):
        with (
            patch("launch.sys.argv", ["agent-url", "pi", "--run", "--url", self.url]),
            patch.dict("launch.os.environ", {"TMUX": "", "TMUX_PANE": ""}),
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
