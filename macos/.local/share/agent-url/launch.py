#!/usr/bin/python3
"""Open a coding agent with just the browser URL in an unsubmitted draft."""

import argparse
import fcntl
import hashlib
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parent
CACHE = Path.home() / "Library/Caches/agent-url"
# GUI-launched commands do not inherit the interactive shell's PATH or aliases.
SEARCH_PATH = os.pathsep.join(
    [
        str(Path.home() / ".pi/agent/bin"),
        str(Path.home() / ".local/bin"),
        # The Rex app installs its CLI here, off every default PATH.
        str(
            Path.home()
            / "Library/Application Support/com.superlogical.rex/RexServer/Versions/Current"
            / "Rex Server.app/Contents/MacOS"
        ),
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "/usr/bin",
        "/bin",
        "/usr/sbin",
        "/sbin",
        os.environ.get("PATH", ""),
    ]
)


LOCAL_CONFIG = Path.home() / ".config/agent-url/config.json"


def load_config():
    """config.json, with top-level keys overridden by the untracked LOCAL_CONFIG.

    Private settings (linear_teams naming work repos) live in LOCAL_CONFIG so
    they stay out of this public repository.
    """
    config = json.loads((ROOT / "config.json").read_text())
    if LOCAL_CONFIG.is_file():
        config.update(json.loads(LOCAL_CONFIG.read_text()))
    return config


def validate_url(value):
    if not value or len(value) > 65536 or re.search(r"[\x00-\x20\x7f]", value):
        raise ValueError("The browser did not provide a valid URL.")
    parsed = urlsplit(value)
    if not parsed.scheme or (
        parsed.scheme.lower() in ("http", "https", "ftp") and not parsed.netloc
    ):
        raise ValueError("The browser did not provide an absolute URL.")
    return value


# GitHub account/product pages are not org/repo URLs.
GITHUB_ROUTES = {
    "about",
    "account",
    "apps",
    "business",
    "codespaces",
    "collections",
    "contact",
    "customer-stories",
    "dashboard",
    "enterprise",
    "events",
    "explore",
    "features",
    "issues",
    "join",
    "login",
    "logout",
    "marketplace",
    "new",
    "notifications",
    "organizations",
    "orgs",
    "pricing",
    "pulls",
    "search",
    "security",
    "sessions",
    "settings",
    "signup",
    "site",
    "sponsors",
    "topics",
    "users",
}


def github_repository(url):
    parsed = urlsplit(validate_url(url))
    if parsed.scheme.lower() not in ("http", "https") or parsed.hostname not in (
        "github.com",
        "www.github.com",
    ):
        return None
    parts = parsed.path.strip("/").split("/")
    if len(parts) < 2 or parts[0].lower() in GITHUB_ROUTES:
        return None
    owner, repo = (unquote(part) for part in parts[:2])
    repo = repo.removesuffix(".git")
    for part in (owner, repo):
        if part in ("", ".", "..") or not re.fullmatch(r"[A-Za-z0-9_.-]+", part):
            raise ValueError("Invalid GitHub org/repo path.")
    if owner.startswith("-"):
        raise ValueError("Invalid GitHub organization name.")
    return owner + "/" + repo


LINEAR_ISSUE = re.compile(r"[A-Za-z][A-Za-z0-9]*-[0-9]+")


def linear_issue(url):
    """(workspace, ISSUE-ID) for a Linear issue URL, else None."""
    parsed = urlsplit(validate_url(url))
    host = (parsed.hostname or "").lower()
    parts = [unquote(part) for part in parsed.path.strip("/").split("/")]
    if (
        host in ("linear.app", "www.linear.app")
        and len(parts) >= 3
        and re.fullmatch(r"[A-Za-z0-9_-]+", parts[0])
        and parts[1] == "issue"
        and LINEAR_ISSUE.fullmatch(parts[2])
    ):
        return parts[0], parts[2].upper()
    return None


def repository(config, url):
    """org/repo for a GitHub URL or a Linear issue whose team maps to a repo."""
    spec = github_repository(url)
    if spec:
        return spec
    issue = linear_issue(url)
    if issue:
        team = issue[1].split("-")[0]
        mapped = config.get("linear_teams", {}).get(team)
        if mapped:
            # Validate the mapping exactly like a GitHub URL's org/repo.
            return github_repository("https://github.com/" + mapped)
    return None


def project_directory(config, url):
    spec = repository(config, url)
    root = Path(
        config["github_root"] if spec else config["working_directory"]
    ).expanduser()
    if not root.is_absolute():
        raise ValueError("Project directories must be absolute or ~/ paths.")
    directory = root.joinpath(*spec.split("/")) if spec else root
    if spec:
        try:
            directory.resolve().relative_to(root.resolve())
        except ValueError:
            raise ValueError("GitHub checkout path escapes github_root.") from None
    return directory, spec


def window_name(directory):
    """Windows are named after their directory, so similar URLs share one."""
    return directory.name


def pane_label(url):
    """Short label for a pane: ENG#7, repo#123, repo/pulls, repo, else the URL."""
    issue = linear_issue(url)
    if issue:
        return issue[1].replace("-", "#")
    spec = github_repository(url)
    if spec:
        repo = spec.split("/")[1]
        parts = [unquote(part) for part in urlsplit(url).path.strip("/").split("/")[2:]]
        parts = [part for part in parts if part]
        if len(parts) >= 2 and parts[0] in ("pull", "issues") and parts[1].isdigit():
            return repo + "#" + parts[1]
        return "/".join([repo] + parts)
    return url


# tmux drops a #[link=...] style longer than 255 bytes, including "link=".
TMUX_LINK_MAX = 250


def tmux_link(url):
    """URL made safe for a tmux #[link=...] style, or None if it cannot fit.

    validate_url already rejects spaces. A comma ends the style option and `]`
    ends the style, so percent-encode them (and `[` to match). Drop the fragment,
    then the query, to fit tmux's length limit.
    """
    parsed = urlsplit(url)
    candidates = (
        url,
        parsed._replace(fragment="").geturl(),
        parsed._replace(query="", fragment="").geturl(),
    )
    for candidate in candidates:
        safe = candidate.replace(",", "%2C").replace("[", "%5B").replace("]", "%5D")
        if len(safe) <= TMUX_LINK_MAX:
            return safe
    return None


def pane_link(url):
    """URL a pane's @url opens (prefix C-u), or None if it cannot fit.

    Linear issues and GitHub PRs link to their canonical URL, built from
    validated parts only; every other pane links to the URL that launched it.
    """
    issue = linear_issue(url)
    if issue:
        return "https://linear.app/" + issue[0] + "/issue/" + issue[1]
    spec = github_repository(url)
    parts = [unquote(part) for part in urlsplit(url).path.strip("/").split("/")]
    if spec and len(parts) >= 4 and parts[2] == "pull" and parts[3].isdigit():
        return "https://github.com/" + spec + "/pull/" + parts[3]
    return tmux_link(url)


def prepare_directory(directory, spec):
    if not spec:
        directory.mkdir(parents=True, exist_ok=True)
        return
    CACHE.mkdir(parents=True, exist_ok=True)
    lock_name = hashlib.sha256(spec.casefold().encode()).hexdigest() + ".clone.lock"
    with (CACHE / lock_name).open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if directory.is_dir() and (directory / ".git").exists():
            return  # Includes worktrees, whose .git is a file.
        if directory.exists() or directory.is_symlink():
            raise ValueError("Refusing to overwrite a non-Git path: " + str(directory))
        gh = shutil.which("gh", path=SEARCH_PATH)
        if not gh:
            raise ValueError("GitHub CLI (gh) is required to clone " + spec)
        directory.parent.mkdir(parents=True, exist_ok=True)
        # Stage beside the destination. Failed clones never leave a half-cloned
        # project at the expected path; simultaneous hotkeys serialize on the lock.
        with tempfile.TemporaryDirectory(
            prefix=".agent-url-", dir=directory.parent
        ) as temporary:
            checkout = Path(temporary) / "checkout"
            result = subprocess.run(
                [gh, "repo", "clone", spec, str(checkout)],
                stdin=subprocess.DEVNULL,
                capture_output=True,
                text=True,
                env=dict(
                    os.environ,
                    PATH=SEARCH_PATH,
                    GH_PROMPT_DISABLED="1",
                    GIT_TERMINAL_PROMPT="0",
                ),
                check=False,
            )
            if result.returncode or not (checkout / ".git").exists():
                detail = result.stderr.strip()[-4000:]
                raise ValueError(
                    "Could not clone " + spec + (": " + detail if detail else "")
                )
            if directory.exists():
                if directory.is_dir() and (directory / ".git").exists():
                    return  # Another tool completed the clone while gh ran.
                raise ValueError(
                    "Checkout destination appeared while cloning: " + str(directory)
                )
            checkout.rename(directory)


def agent_command(preset, name):
    """Agent argv; name labels the session (the tmux pane label)."""
    agent = preset["agent"]
    executable = shutil.which(agent, path=SEARCH_PATH)
    if not executable:
        raise ValueError(f"Cannot find the {agent} executable.")
    command = [executable]
    if preset.get("model"):
        command += ["--model", preset["model"]]
    if agent == "claude":
        if preset.get("effort"):
            command += ["--effort", preset["effort"]]
        command += [
            "--dangerously-skip-permissions",
            "--name",
            name,
            "--remote-control",
            name,
        ]
    elif agent == "copilot":
        if preset.get("effort"):
            command += ["--reasoning-effort", preset["effort"]]
        # Never use -i/--interactive or -p: those submit a prompt immediately.
        command += ["--yolo", "--mode", "interactive", "--name", name]
    elif agent == "pi":
        command += ["--name", name]
    else:
        raise ValueError("Unsupported agent: " + agent)
    return command


def prefill_runner():
    """Reuse fzf-tmux-project's generic --prefill worker, not an agent API."""
    helper = Path.home() / ".local/bin/fzf-tmux-project"
    if not helper.is_file():
        raise ValueError("URL prefill requires ~/.local/bin/fzf-tmux-project.")
    bash = shutil.which("bash", path=SEARCH_PATH)
    if not bash:
        raise ValueError("Cannot find bash to run fzf-tmux-project.")
    # The tmux server may have a minimal/old PATH. The shared worker calls tmux
    # itself and uses Bash 4+ syntax, so use the same explicit GUI-safe PATH.
    return ["/usr/bin/env", "PATH=" + SEARCH_PATH, bash, str(helper)]


def schedule_prefill(tmux, pane, url):
    validate_url(url)
    if not re.fullmatch(r"%[0-9]+", pane):
        raise ValueError("Agent runner must start inside a tmux pane.")
    worker = prefill_runner() + ["--prefill", pane, url]
    # run-shell expands tmux formats before executing the shell command. Escape
    # hashes as well as shell quoting so URL fragments stay literal data.
    shell_command = shlex.join(worker).replace("#", "##")
    subprocess.run(
        [tmux, "run-shell", "-b", "-t", pane, shell_command],
        check=True,
    )


def label_pane(tmux, pane, label, link):
    """Set the pane border's label (pane-border-format) and its prefix C-u URL.

    A pane option, not the pane title: agents overwrite the title themselves.
    """
    options = [("@pane_label", label)] + ([("@url", link)] if link else [])
    for name, value in options:
        subprocess.run(
            [tmux, "set-option", "-p", "-t", pane, name, value],
            capture_output=True,
            check=False,
        )


def capture_url():
    helper = CACHE / "browser-url"
    if not helper.is_file():
        raise ValueError("URL capture helper is missing. Run install.py first.")
    # Serialize captures so two hotkeys cannot interfere with browser focus.
    CACHE.mkdir(parents=True, exist_ok=True)
    with (CACHE / "capture.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        result = subprocess.run(
            [str(helper)],
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
    if result.returncode:
        raise ValueError(result.stderr.strip() or "Could not capture the browser URL.")
    return validate_url(result.stdout.strip())


REX_BUNDLE = "com.superlogical.rex"
REX_ID = re.compile(r"(session|window|block):[0-9A-Fa-f-]+")
SHELL_NAMES = re.compile(r"-?(bash|zsh|fish|sh)")


def rex_target():
    """(rex, session_id) to open the agent in Rex, or None to use tmux.

    Rex counts as present only while its app is connected, so a server left
    running with no app to show the window does not swallow the agent. A launch
    from a Rex terminal uses that terminal's session; otherwise the session the
    app is showing.
    """
    rex = shutil.which("rex", path=SEARCH_PATH)
    if not rex:
        return None
    try:
        result = subprocess.run(
            [rex, "--autostart=false", "client", "ls", "--json"],
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
        clients = (
            json.loads(result.stdout).get("clients", [])
            if not result.returncode
            else []
        )
    except (OSError, subprocess.SubprocessError, ValueError, AttributeError):
        return None
    sessions = [
        session
        for client in clients
        if (client.get("info") or {}).get("kind") == "app"
        and client.get("connection_state") == "connected"
        for session in client.get("session_ids") or []
    ]
    current = os.environ.get("REX_SESSION", "")
    session = current if current in sessions else next(iter(sessions), None)
    if not session or not REX_ID.fullmatch(session):
        return None
    return rex, session


def rex_window_label(directory):
    """window_name, kept from reading as a flag where rex takes it positionally."""
    label = window_name(directory)
    return "_" + label if label.startswith("-") else label


def open_rex_session(rex, session, preset_key, url, directory):
    """Rex counterpart of open_session: a new window named after the directory,
    or a split in the existing one, then shown in the Rex app."""
    child = [sys.executable, str(ROOT / "launch.py"), preset_key, "--run", "--url", url]
    label = rex_window_label(directory)
    windows = subprocess.run(
        [rex, "window", "ls", "-s", session, "--json"],
        capture_output=True,
        text=True,
        check=False,
    )
    try:
        existing = next(
            (
                window["window_id"]
                for window in json.loads(windows.stdout).get("windows", [])
                if window.get("label") == label
            ),
            None,
        )
    except (ValueError, AttributeError, KeyError):
        existing = None
    if existing:
        # A window for this directory is already open: add a block to it.
        command = [rex, "split", "-s", session, "-w", existing, "-c", str(directory)]
    else:
        command = [
            rex,
            "window",
            "new",
            "-s",
            session,
            label,
            "-c",
            str(directory),
            "--json",
        ]
    result = subprocess.run(
        command + ["--", *child], capture_output=True, text=True, check=False
    )
    if result.returncode:
        raise ValueError(
            "Rex could not open the agent window: " + result.stderr.strip()
        )
    window = existing
    if not window:
        try:
            window = json.loads(result.stdout).get("window_id")
        except (ValueError, AttributeError):
            window = None
    if window:
        # The app keeps its own selected tab; it takes this only with Remote
        # Control on (Settings > Rex Server), and the window opens either way.
        subprocess.run(
            [
                rex,
                "do",
                "session.select",
                "session_id=" + session,
                "window_id=" + window,
            ],
            capture_output=True,
            check=False,
        )
    subprocess.run(["/usr/bin/open", "-b", REX_BUNDLE], check=False)


def label_rex_block(rex, block, label):
    """Rex counterpart of label_pane: the block's label (Rex has no @url)."""
    subprocess.run(
        [rex, "block", "rename", "--", block, label], capture_output=True, check=False
    )


def schedule_rex_prefill(block, url):
    """Start rex_prefill detached, so it outlives this runner's exec."""
    validate_url(url)
    if not (block.startswith("block:") and REX_ID.fullmatch(block)):
        raise ValueError("Agent runner must start inside a Rex block.")
    subprocess.Popen(
        [sys.executable, str(ROOT / "launch.py"), "--rex-prefill", block, url],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
        env=dict(os.environ, PATH=SEARCH_PATH),
    )


def rex_prefill(block, url, attempts=60, interval=0.5):
    """Rex counterpart of fzf-tmux-project --prefill, with the same heuristic.

    Waits for a non-shell foreground program and a nonempty screen unchanged
    across two samples, skips screens containing "trust", then types the URL
    with rex send, without Enter. Quietly gives up when the block closes or
    never settles (about 30 seconds).
    """
    validate_url(url)
    rex = shutil.which("rex", path=SEARCH_PATH)
    if not rex:
        return
    previous = None
    for _ in range(attempts):
        time.sleep(interval)
        process = subprocess.run(
            [rex, "block", "call", "-b", block, "process"],
            capture_output=True,
            text=True,
            check=False,
        )
        if process.returncode:
            return  # The block is gone.
        try:
            foreground = json.loads(process.stdout).get("foreground") or {}
        except (ValueError, AttributeError):
            foreground = {}
        name = os.path.basename(foreground.get("argv0") or foreground.get("name") or "")
        if not name or SHELL_NAMES.fullmatch(name):
            continue
        screen = subprocess.run(
            [rex, "capture", "-b", block], capture_output=True, text=True, check=False
        )
        if screen.returncode:
            return
        if (
            screen.stdout.strip()
            and screen.stdout == previous
            and "trust" not in screen.stdout.lower()
        ):
            subprocess.run(
                [rex, "send", "-b", block, "--", url], capture_output=True, check=False
            )
            return
        previous = screen.stdout


def open_session(preset_key, preset, url, directory, spec=None):
    # Only this quoted command string crosses a shell boundary. The validated URL
    # is data for the draft, never a shell command or an automatically sent message.
    child = [sys.executable, str(ROOT / "launch.py"), preset_key, "--run", "--url", url]
    shell_command = "exec " + shlex.join(child)
    tmux = shutil.which("tmux", path=SEARCH_PATH)
    if not tmux:
        raise ValueError("tmux is required. Install it with brew install tmux.")
    sessions = subprocess.run(
        [
            tmux,
            "list-sessions",
            "-F",
            "#{session_id}\t#{session_attached}\t#{session_activity}",
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    candidates = []
    for line in sessions.stdout.splitlines():
        fields = line.split("\t")
        if len(fields) == 3 and fields[1].isdigit() and fields[2].isdigit():
            candidates.append((int(fields[1]) > 0, int(fields[2]), fields[0]))
    current = None
    if os.environ.get("TMUX") and os.environ.get("TMUX_PANE"):
        result = subprocess.run(
            [
                tmux,
                "display-message",
                "-p",
                "-t",
                os.environ["TMUX_PANE"],
                "#{session_id}",
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode == 0:
            current = result.stdout.strip()
    selected = next((row for row in candidates if row[2] == current), None)
    if selected is None and candidates:
        selected = max(candidates)  # Attached first, then most recently active.
    label = window_name(directory)
    # A window's tab links to its repo; each pane keeps its own @url.
    link = "https://github.com/" + spec if spec else None
    if selected:
        attached, _, target = selected
        windows = subprocess.run(
            [tmux, "list-windows", "-t", target, "-F", "#{window_id}\t#{window_name}"],
            capture_output=True,
            text=True,
            check=False,
        )
        existing = next(
            (
                fields[0]
                for fields in (
                    line.split("\t", 1) for line in windows.stdout.splitlines()
                )
                if len(fields) == 2 and fields[1] == label
            ),
            None,
        )
        if existing:
            # A window for this directory is already open: add a pane to it.
            result = subprocess.run(
                [
                    tmux,
                    "split-window",
                    "-t",
                    existing,
                    "-c",
                    str(directory),
                    shell_command,
                ],
                capture_output=True,
                text=True,
                check=False,
            )
            if result.returncode == 0:
                subprocess.run(
                    [tmux, "select-layout", "-t", existing, "tiled"], check=False
                )
                subprocess.run([tmux, "select-window", "-t", existing], check=False)
        else:
            result = subprocess.run(
                [
                    tmux,
                    "new-window",
                    "-t",
                    target + ":",
                    "-c",
                    str(directory),
                    "-n",
                    # tmux expands formats in -n; keep names literal.
                    label.replace("#", "##"),
                    "-P",
                    "-F",
                    "#{window_id}",
                    shell_command,
                ],
                capture_output=True,
                text=True,
                check=False,
            )
            window = result.stdout.strip()
            if result.returncode == 0 and link and window:
                subprocess.run(
                    [tmux, "set-option", "-w", "-t", window, "@url", link],
                    capture_output=True,
                    check=False,
                )
    else:
        attached = False
        result = subprocess.run(
            [
                tmux,
                "new-session",
                "-d",
                "-s",
                "agent-url",
                "-c",
                str(directory),
                "-n",
                label.replace("#", "##"),
                "-P",
                "-F",
                "#{session_id}",
                shell_command,
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        target = result.stdout.strip()
        if result.returncode == 0 and link and target:
            # The new session's only window.
            subprocess.run(
                [tmux, "set-option", "-w", "-t", target + ":", "@url", link],
                capture_output=True,
                check=False,
            )
    if result.returncode:
        raise ValueError(
            "tmux could not open the agent window: " + result.stderr.strip()
        )
    if attached:
        subprocess.run(["/usr/bin/open", "-a", "Ghostty"], check=True)
    else:
        attach = "exec " + shlex.join([tmux, "attach-session", "-t", target])
        subprocess.run(
            [
                "/usr/bin/open",
                "-na",
                "Ghostty",
                "--args",
                "--working-directory=" + str(directory),
                "-e",
                "/bin/sh",
                "-c",
                attach,
            ],
            check=True,
        )


def main():
    if len(sys.argv) == 4 and sys.argv[1] == "--rex-prefill":
        rex_prefill(sys.argv[2], sys.argv[3])
        return 0
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("preset", choices=load_config()["presets"])
    parser.add_argument(
        "--url", help="Use an explicit URL instead of capturing the browser"
    )
    parser.add_argument(
        "--dry-run", action="store_true", help="Print argv without starting an agent"
    )
    parser.add_argument("--run", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args()
    config = load_config()
    preset = config["presets"][args.preset]
    url = validate_url(args.url) if args.url is not None else capture_url()
    directory, spec = project_directory(config, url)
    label = pane_label(url)
    # Never put a raw URL (query strings, tokens) in argv or a Remote Control name.
    command = agent_command(preset, window_name(directory) if label == url else label)
    if args.dry_run:
        print(
            json.dumps(
                {
                    "cwd": str(directory),
                    "github_repo": spec,
                    "window": window_name(directory),
                    "pane": label,
                    "argv": command,
                    "prefill": url,
                    "prefill_method": "detached worker types into the Rex block or tmux pane",
                    "submit": False,
                },
                indent=2,
            )
        )
        return 0
    pane = os.environ.get("TMUX_PANE", "")
    block = os.environ.get("REX_BLOCK", "")
    # tmux first: a tmux started inside Rex inherits REX_BLOCK too.
    in_tmux = bool(os.environ.get("TMUX")) and bool(re.fullmatch(r"%[0-9]+", pane))
    in_rex = (
        not in_tmux and block.startswith("block:") and bool(REX_ID.fullmatch(block))
    )
    if args.run and not (in_tmux or in_rex):
        raise ValueError("Agent runner must start inside a tmux pane or a Rex block.")
    # Rex when its app is running, else tmux. Checked before cloning.
    target = None if args.run else rex_target()
    if (args.run and in_rex) or target:
        rex = target[0] if target else shutil.which("rex", path=SEARCH_PATH)
        if not rex:
            raise ValueError("Cannot find the rex executable.")
    else:
        tmux = shutil.which("tmux", path=SEARCH_PATH)
        if not tmux:
            raise ValueError("tmux is required. Install it with brew install tmux.")
        prefill_runner()  # Check the shared worker before cloning/opening a window.
    prepare_directory(directory, spec)
    if args.run:
        os.chdir(directory)
        if in_tmux:
            label_pane(tmux, pane, label, pane_link(url))
            schedule_prefill(tmux, pane, url)
        else:
            label_rex_block(rex, block, label)
            schedule_rex_prefill(block, url)
        # Replace this runner with the agent. Its argv contains no URL or initial
        # prompt; the detached worker types the URL after the terminal settles.
        os.execvpe(command[0], command, dict(os.environ, PATH=SEARCH_PATH))
        return 0
    if target:
        open_rex_session(target[0], target[1], args.preset, url, directory)
    else:
        open_session(args.preset, preset, url, directory, spec)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        print("Browser URL: " + str(error), file=sys.stderr)
        sys.exit(1)
