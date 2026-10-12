import { spawn, execFile, type ChildProcess } from "node:child_process";
import { access, constants } from "node:fs/promises";
import { homedir } from "node:os";
import { isAbsolute, join } from "node:path";
import { createInterface } from "node:readline";
import { promisify } from "node:util";

const exec = promisify(execFile);
const REPO = /^[\w.-]+\/[\w.-]+$/;
const NUMBER = /^[1-9]\d*$/;
const MAX_LINE = 700;

type Severity = "info" | "warning" | "error";
export type Notify = (text: string, severity: Severity) => void;
export type WatchArgs = { pr?: string; repo?: string; fresh: boolean };
type Watch = { child: ChildProcess; stopped: boolean };

export function parseWatchArgs(raw: string): WatchArgs {
  const parts = raw.trim().split(/\s+/).filter(Boolean);
  let pr: string | undefined;
  let repo: string | undefined;
  let fresh = false;
  for (let i = 0; i < parts.length; i++) {
    const part = parts[i]!;
    if (part === "-R" || part === "--repo") {
      if (repo) throw new Error("Specify -R only once");
      repo = parts[++i];
      if (!repo || !REPO.test(repo))
        throw new Error(
          "Usage: /watch-pr [PR number|URL|branch] [-R owner/repo] [--fresh]",
        );
    } else if (part === "--fresh") {
      fresh = true;
    } else if (part.startsWith("-") || pr) {
      throw new Error(
        "Usage: /watch-pr [PR number|URL|branch] [-R owner/repo] [--fresh]",
      );
    } else {
      pr = part;
    }
  }
  if (
    pr &&
    !NUMBER.test(pr) &&
    (/^\d+$/.test(pr) || (!pr.startsWith("https://") && !/^[\w./-]+$/.test(pr)))
  ) {
    throw new Error("PR must be a number, GitHub URL, or branch name");
  }
  return { pr, repo, fresh };
}

function prUrl(value: string): string {
  const url = new URL(value);
  const match = /^\/([^/]+)\/([^/]+)\/pull\/([1-9]\d*)\/?$/.exec(url.pathname);
  if (
    url.protocol !== "https:" ||
    url.hostname !== "github.com" ||
    url.username ||
    url.password ||
    url.search ||
    !match ||
    !REPO.test(`${match[1]}/${match[2]}`)
  ) {
    throw new Error("Expected a GitHub pull request URL");
  }
  return `https://github.com/${match[1]}/${match[2]}/pull/${match[3]}`;
}

async function resolvePr(args: WatchArgs, cwd: string): Promise<string> {
  if (args.pr?.startsWith("https://")) return prUrl(args.pr);
  const ghArgs = [
    "pr",
    "view",
    ...(args.pr ? [args.pr] : []),
    ...(args.repo ? ["-R", args.repo] : []),
    "--json",
    "url",
    "--jq",
    ".url",
  ];
  try {
    const { stdout } = await exec("gh", ghArgs, { cwd, timeout: 15_000 });
    return prUrl(stdout.trim());
  } catch (error) {
    throw new Error(
      `Could not resolve PR: ${error instanceof Error ? error.message : String(error)}`,
    );
  }
}

async function watcherPath(): Promise<string> {
  if (process.env.GH_PR_WATCH && !isAbsolute(process.env.GH_PR_WATCH)) {
    throw new Error("GH_PR_WATCH must be an absolute path");
  }
  const candidates = process.env.GH_PR_WATCH
    ? [process.env.GH_PR_WATCH]
    : [
        join(homedir(), ".local/bin/gh-pr-watch"),
        join(
          homedir(),
          "Projects/github.com/komodohealth/security-automation/plugins/security-dev/skills/gh/scripts/gh-pr-watch/gh-pr-watch",
        ),
      ];
  for (const path of candidates) {
    try {
      await access(path, constants.X_OK);
      return path;
    } catch {
      /* Try the next location. */
    }
  }
  throw new Error(
    "gh-pr-watch not executable; set GH_PR_WATCH to its absolute path",
  );
}

function clean(text: string): string {
  let safe = "";
  for (const char of text) {
    const code = char.charCodeAt(0);
    safe += code < 32 || code === 127 ? " " : char;
    if (safe.length >= MAX_LINE) break;
  }
  return safe.trim();
}

function severity(line: string): Severity {
  if (/^(CI fail:|CI cancel:|CONFLICT:|SCALR errored:)/.test(line))
    return "error";
  if (
    /^(WATCH |SCALR approval:|SCALR policy:|SCALR no run:|SCALR cannot watch:)/.test(
      line,
    ) ||
    /^REVIEW .*CHANGES_REQUESTED/.test(line)
  )
    return "warning";
  return "info";
}

function kill(watch: Watch, signal: NodeJS.Signals): void {
  if (watch.child.exitCode !== null || watch.child.signalCode !== null) return;
  try {
    // Detached on Unix: kill Bash and the gh/scalr/sleep subprocess it is waiting for.
    if (process.platform !== "win32" && watch.child.pid)
      process.kill(-watch.child.pid, signal);
    else watch.child.kill(signal);
  } catch {
    watch.child.kill(signal);
  }
}

export class WatchManager {
  private readonly watches = new Map<string, Watch>();
  private readonly starting = new Set<string>();
  // Other agents can overwrite the same PR's single cache file, including its
  // watcher attribution. Keep our own watched PRs until this session ends.
  private readonly watched = new Set<string>();
  private generation = 0;

  getWatchedPRs(): ReadonlySet<string> {
    return new Set(this.watched);
  }

  async start(
    raw: string,
    cwd: string,
    session: string,
    notify: Notify,
  ): Promise<void> {
    const generation = this.generation;
    const args = parseWatchArgs(raw);
    const url = await resolvePr(args, cwd);
    if (generation !== this.generation) return;
    if (this.watches.has(url) || this.starting.has(url)) {
      notify(`Already watching ${url}`, "info");
      return;
    }
    this.starting.add(url);
    try {
      const executable = await watcherPath();
      if (generation !== this.generation) return;
      const label = url
        .slice("https://github.com/".length)
        .replace("/pull/", "#");
      const command = [
        "-R",
        label.split("#")[0]!,
        ...(args.fresh ? ["--fresh"] : []),
        label.split("#")[1]!,
      ];
      const child = spawn(executable, command, {
        cwd,
        env: { ...process.env, PI_SESSION_ID: session },
        stdio: ["ignore", "pipe", "pipe"],
        detached: process.platform !== "win32",
      });
      const watch: Watch = { child, stopped: false };
      this.watches.set(url, watch);
      this.watched.add(label);
      let error: string | undefined;
      const stderr: string[] = [];
      createInterface({ input: child.stdout!, crlfDelay: Infinity }).on(
        "line",
        (line) => {
          const message = clean(line);
          if (!watch.stopped && generation === this.generation && message) {
            notify(`${label}: ${message}`, severity(message));
          }
        },
      );
      createInterface({ input: child.stderr!, crlfDelay: Infinity }).on(
        "line",
        (line) => {
          if (line.trim()) stderr.push(clean(line));
          if (stderr.length > 3) stderr.shift();
        },
      );
      child.on("error", (cause: Error) => {
        error = cause.message;
      });
      child.on("close", (code, signal) => {
        if (this.watches.get(url) === watch) this.watches.delete(url);
        if (
          !watch.stopped &&
          generation === this.generation &&
          (code !== 0 || error)
        ) {
          const reason = error || stderr.join("; ") || `exit ${code ?? signal}`;
          notify(`${label}: watch stopped (${reason})`, "error");
        }
      });
      notify(`Watching ${url}${args.fresh ? " (fresh)" : ""}`, "info");
    } finally {
      this.starting.delete(url);
    }
  }

  async stopAll(): Promise<void> {
    this.generation++;
    this.starting.clear();
    this.watched.clear();
    const pending = [...this.watches.values()];
    this.watches.clear();
    await Promise.all(
      pending.map(async (watch) => {
        watch.stopped = true;
        if (watch.child.exitCode !== null || watch.child.signalCode !== null)
          return;
        await new Promise<void>((resolve) => {
          let finished = false;
          const done = () => {
            if (finished) return;
            finished = true;
            clearTimeout(timeout);
            resolve();
          };
          const timeout = setTimeout(() => {
            kill(watch, "SIGKILL");
            done();
          }, 2000);
          watch.child.once("close", done);
          kill(watch, "SIGTERM");
        });
      }),
    );
  }
}
