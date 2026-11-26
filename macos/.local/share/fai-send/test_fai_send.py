import json
import plistlib
import subprocess
import tempfile
import unittest
from pathlib import Path

import install

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


FAI_SEND = install.ROOT.parents[3] / "utils/.local/bin/fai-send"
REX_BUNDLE = "com.superlogical.rex"

# Stubs for the commands fai-send runs, first on its PATH. They log each call
# to $LOG and answer from the FRONT, TAB_URL, SELECTION and CLIENTS environment
# variables. SELECTION_FAIL makes the JavaScript call fail, as it does when the
# browser's "Allow JavaScript from Apple Events" is off.
STUBS = {
    "osascript": """#!/bin/sh
echo "osascript $*" >>"$LOG"
case "$2" in
id\\ of\\ application*)
  # Rex is frontmost once `open -b` has brought it forward.
  if [ -e "$STATE/opened" ]; then echo com.superlogical.rex; else echo "$FRONT"; fi ;;
*[Jj]ava[Ss]cript*)
  [ -n "$SELECTION_FAIL" ] && exit 1
  printf '%s\\n' "$SELECTION" ;;
*) printf '%s\\n' "$TAB_URL" ;;
esac
""",
    "open": """#!/bin/sh
echo "open $*" >>"$LOG"
touch "$STATE/opened"
""",
    "rex": """#!/bin/sh
case "$*" in
*"client ls"*) printf '%s\\n' "$CLIENTS" ;;
*)
  echo "rex $*" >>"$LOG"
  cat >"$STATE/stdin"
  exit "${REX_EXIT:-0}" ;;
esac
""",
}


class LauncherTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.state = Path(temporary.name)
        stubs = self.state / "bin"
        stubs.mkdir()
        for name, body in STUBS.items():
            (stubs / name).write_text(body)
            (stubs / name).chmod(0o755)
        self.env = {
            "PATH": str(stubs) + ":/usr/bin:/bin",
            "HOME": str(self.state),
            "LOG": str(self.state / "log"),
            "STATE": str(self.state),
            "FRONT": "com.google.Chrome",
            "TAB_URL": "https://github.com/org/repo/pull/1",
            "SELECTION": "",
            "SELECTION_FAIL": "",
            "CLIENTS": clients(SESSION),
        }

    def run_fai_send(self, *args, stdin="", **env):
        return subprocess.run(
            [str(FAI_SEND), *args],
            input=stdin,
            capture_output=True,
            text=True,
            env={**self.env, **env},
            timeout=20,
            check=False,
        )

    def log(self):
        path = self.state / "log"
        return path.read_text().splitlines() if path.exists() else []

    def sent(self):
        return json.loads((self.state / "stdin").read_text())

    def test_sends_the_chrome_tab_url_on_stdin_after_activating_rex(self):
        url = "https://github.com/org/repo/pull/1?token=secret"
        result = self.run_fai_send(TAB_URL=url)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.sent(), {"url": url})
        log = self.log()
        self.assertIn(
            'osascript -e tell application id "com.google.Chrome" to get URL'
            " of active tab of front window",
            log,
        )
        opened = log.index("open -b " + REX_BUNDLE)
        sent = log.index("rex do -s " + SESSION + " fai --args -")
        self.assertLess(opened, sent)
        self.assertFalse(any(url in line for line in log))  # never in argv

    def test_reads_safari_from_its_front_document(self):
        result = self.run_fai_send(FRONT="com.apple.Safari")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(
            'osascript -e tell application id "com.apple.Safari" to get URL'
            " of front document",
            self.log(),
        )

    def test_sends_the_highlighted_text_with_the_url(self):
        url = "https://github.com/org/repo/pull/1"
        result = self.run_fai_send(SELECTION="  the error\r\nline 2 \n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.sent(), {"url": url, "text": "the error\nline 2"})
        self.assertIn(
            'osascript -e tell application id "com.google.Chrome" to execute'
            " active tab of front window javascript"
            ' "window.getSelection().toString()"',
            self.log(),
        )

    def test_reads_the_safari_selection_with_do_javascript(self):
        self.run_fai_send(FRONT="com.apple.Safari", SELECTION="words")
        self.assertEqual(self.sent()["text"], "words")
        self.assertIn(
            'osascript -e tell application id "com.apple.Safari" to do'
            ' JavaScript "window.getSelection().toString()" in front document',
            self.log(),
        )

    def test_sends_only_the_url_without_a_selection(self):
        url = "https://github.com/org/repo/pull/1"
        for env in (
            {"SELECTION": ""},
            {"SELECTION": " \n"},
            {"SELECTION": "missing value"},
            {"SELECTION": "text", "SELECTION_FAIL": "1"},
        ):
            (self.state / "opened").unlink(missing_ok=True)  # Rex in back again
            result = self.run_fai_send(**env)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(self.sent(), {"url": url}, env)

    def test_a_long_selection_is_cut_to_16_kib(self):
        self.run_fai_send(SELECTION="é" * 9000)
        text = self.sent()["text"]
        self.assertEqual(text, "é" * 8192)

    def test_refuses_an_app_that_is_not_a_supported_browser(self):
        for front in ("org.mozilla.firefox", "com.superlogical.rex"):
            result = self.run_fai_send(FRONT=front)
            self.assertEqual(result.returncode, 1)
            self.assertIn("Focus a Chrome", result.stderr)
            self.assertFalse((self.state / "stdin").exists())

    def test_url_validation(self):
        for url in (
            "https://github.com/org/repo/pull/1",
            "https://linear.app/acme/issue/ENG-7#comment",
            "about:blank",
        ):
            result = self.run_fai_send("--url", url, "--dry-run")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads(result.stdout.splitlines()[1]), {"url": url})
        for url in ("", "github.com/org/repo", "https://", "https://a b", "x\x01y"):
            result = self.run_fai_send("--url", url, "--dry-run")
            self.assertEqual(result.returncode, 1, url)
        result = self.run_fai_send(TAB_URL="")
        self.assertEqual(result.returncode, 1)
        self.assertIn("valid URL", result.stderr)

    def test_uses_the_session_the_app_shows(self):
        result = self.run_fai_send("--url", "https://example.com", "--dry-run")
        self.assertEqual(
            result.stdout.splitlines()[0], "rex do -s " + SESSION + " fai --args -"
        )

    def test_current_rex_session_wins(self):
        result = self.run_fai_send(
            "--url",
            "https://example.com",
            "--dry-run",
            CLIENTS=clients(SESSION, OTHER),
            REX_SESSION=OTHER,
        )
        self.assertIn(OTHER, result.stdout.splitlines()[0])

    def test_requires_a_connected_rex_app(self):
        for listing in (
            clients(SESSION, kind="tui"),
            clients(SESSION, state="disconnected"),
            "",
        ):
            result = self.run_fai_send("--url", "https://example.com", CLIENTS=listing)
            self.assertEqual(result.returncode, 1)
            self.assertIn("Rex app is not running", result.stderr)

    def test_rex_failure_is_reported(self):
        result = self.run_fai_send(REX_EXIT="1")
        self.assertEqual(result.returncode, 1)
        self.assertIn("Rex could not open fai", result.stderr)

    def test_dry_run_opens_nothing(self):
        result = self.run_fai_send("--dry-run", "--url", "https://example.com")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.log(), [])

    def test_selection_that_is_one_url_is_sent_as_a_url(self):
        url = "https://github.com/org/repo/pull/1"
        result = self.run_fai_send("--stdin", stdin=" " + url + "\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.sent(), {"url": url})

    def test_any_other_selection_is_sent_as_text(self):
        for text in (
            "see https://github.com/org/repo/pull/1",
            "Traceback (most recent call last):\n  File x",
            "github.com/org/repo",
            "word",
        ):
            result = self.run_fai_send("--stdin", stdin=text)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(self.sent(), {"text": text})

    def test_selection_is_trimmed_and_bounded(self):
        self.run_fai_send("--stdin", stdin="\n  a\nb  \n")
        self.assertEqual(self.sent(), {"text": "a\nb"})
        for text in ("", " \n\t"):
            result = self.run_fai_send("--stdin", stdin=text)
            self.assertEqual(result.returncode, 1)
            self.assertIn("No text", result.stderr)
        result = self.run_fai_send("--stdin", stdin="é" * 8193)
        self.assertEqual(result.returncode, 1)
        self.assertIn("16 KiB", result.stderr)


class WorkflowTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.home = Path(temporary.name)
        self.target = self.home / "Library/Services" / install.WORKFLOW

    def test_workflow_is_a_text_service_running_fai_send(self):
        contents = install.ROOT / install.WORKFLOW / "Contents"
        with (contents / "Info.plist").open("rb") as handle:
            (service,) = plistlib.load(handle)["NSServices"]
        self.assertEqual(service["NSMenuItem"], {"default": "Send to fai…"})
        self.assertEqual(service["NSSendTypes"], ["public.utf8-plain-text"])
        with (contents / "document.wflow").open("rb") as handle:
            (action,) = plistlib.load(handle)["actions"]
        parameters = action["action"]["ActionParameters"]
        self.assertEqual(parameters["inputMethod"], 0)  # stdin
        self.assertIn(
            '"$HOME/.local/bin/fai-send" --stdin', parameters["COMMAND_STRING"]
        )

    def test_installs_and_replaces_its_own_copy(self):
        self.assertEqual(install.install_workflow(self.home), self.target)
        (self.target / "Contents/stale").write_text("old")
        install.install_workflow(self.home)
        self.assertFalse((self.target / "Contents/stale").exists())
        self.assertTrue((self.target / "Contents/document.wflow").is_file())

    def test_keeps_a_different_workflow_of_the_same_name(self):
        (self.target / "Contents").mkdir(parents=True)
        mine = {"NSServices": [{"NSMenuItem": {"default": "Something else"}}]}
        (self.target / "Contents/Info.plist").write_bytes(plistlib.dumps(mine))
        with self.assertRaisesRegex(ValueError, "Refusing"):
            install.install_workflow(self.home)
        self.assertEqual(
            plistlib.loads((self.target / "Contents/Info.plist").read_bytes()), mine
        )

    def test_removes_only_what_agent_url_installed(self):
        bin_dir = self.home / ".local/bin"
        share = self.home / ".local/share"
        bin_dir.mkdir(parents=True)
        share.mkdir(parents=True)
        (share / "agent-url").symlink_to(install.ROOT)
        (bin_dir / "agent-url").write_text(
            'exec /usr/bin/python3 "$HOME/.local/share/agent-url/launch.py" "$@"\n'
        )
        install.remove_legacy(self.home)
        self.assertFalse((share / "agent-url").is_symlink())
        self.assertFalse((bin_dir / "agent-url").exists())
        (share / "agent-url").symlink_to(self.home)
        (bin_dir / "agent-url").write_text("#!/bin/sh\necho mine\n")
        install.remove_legacy(self.home)
        self.assertTrue((share / "agent-url").is_symlink())
        self.assertTrue((bin_dir / "agent-url").exists())


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.config = install.load_config()
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
        self.assertEqual(command["command"], 'exec "$HOME/.local/bin/fai-send"')

    def test_replaces_the_command_from_before_the_rename(self):
        old = {
            "id": "11111111-2222-3333-4444-555555555555",
            "name": "Mine now",
            "command": 'exec "$HOME/.local/bin/agent-url"',
        }
        self.original["customCommands"] = json.dumps([old]).encode()
        merged = install.configure(self.original, self.config)
        (command,) = self.commands(merged)
        self.assertEqual(command["command"], 'exec "$HOME/.local/bin/fai-send"')

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
