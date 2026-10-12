import { readFile, readdir, stat } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";

export type Snapshot = {
  repo: string;
  branch: string;
  number: number;
  url: string;
  state: "open" | "draft";
  ci: string;
  ciCounts: { fail: number; pending: number };
  review: string;
  threads: number;
  copilot?: { verdict: string; head: boolean; url: string };
  fetchedAt: number;
  interval: number;
  sessionMatch: boolean;
};

export const MAX_AGE_SECONDS = 900;
export const MAX_PRS = 5;
const MAX_SNAPSHOT_BYTES = 512 * 1024;

export function cacheDirectory(): string {
  return join(process.env.XDG_CACHE_HOME || join(homedir(), ".cache"), "gh-pr");
}

function record(value: unknown): Record<string, unknown> | undefined {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : undefined;
}

function count(value: unknown): number {
  return typeof value === "number" && Number.isFinite(value) && value >= 0
    ? value
    : 0;
}

function hasControls(value: string): boolean {
  for (const char of value) {
    if (char.charCodeAt(0) < 32 || char.charCodeAt(0) === 127) return true;
  }
  return false;
}

function safeUrl(value: unknown): string | undefined {
  if (typeof value !== "string" || hasControls(value)) return undefined;
  try {
    const url = new URL(value);
    return url.protocol === "https:" && url.hostname === "github.com"
      ? value
      : undefined;
  } catch {
    return undefined;
  }
}

export function parseSnapshot(
  value: unknown,
  session: string,
  repo: string | undefined,
  branch: string | undefined,
  now: number,
): Snapshot | undefined {
  const data = record(value);
  if (
    !data ||
    data.v !== 1 ||
    typeof data.repo !== "string" ||
    data.repo.split("/").length !== 2 ||
    data.repo.split("/").some((part) => !part || hasControls(part)) ||
    typeof data.branch !== "string" ||
    !Number.isSafeInteger(data.number) ||
    (data.number as number) <= 0 ||
    (data.state !== "open" && data.state !== "draft") ||
    typeof data.fetched_at !== "number" ||
    !Number.isFinite(data.fetched_at) ||
    now - data.fetched_at > MAX_AGE_SECONDS
  )
    return undefined;

  const watcher = record(data.watcher);
  const sessionMatch = !!session && watcher?.pi_session === session;
  if (
    !sessionMatch &&
    !(repo && branch && data.repo === repo && data.branch === branch)
  )
    return undefined;
  const url = safeUrl(data.url);
  if (!url) return undefined;
  const counts = record(data.ci_counts);
  const copilot = record(data.copilot);
  const copilotUrl = safeUrl(copilot?.url);
  return {
    repo: data.repo,
    branch: data.branch,
    number: data.number as number,
    url,
    state: data.state,
    ci: typeof data.ci === "string" ? data.ci : "",
    ciCounts: { fail: count(counts?.fail), pending: count(counts?.pending) },
    review: typeof data.review === "string" ? data.review : "",
    threads: Array.isArray(data.threads) ? data.threads.length : 0,
    copilot:
      copilotUrl && typeof copilot?.verdict === "string"
        ? {
            verdict: copilot.verdict,
            head: copilot.head === true,
            url: copilotUrl,
          }
        : undefined,
    fetchedAt: data.fetched_at,
    interval: count(data.interval) || 60,
    sessionMatch,
  };
}

function urgency(pr: Snapshot): number[] {
  return [
    Number(pr.ci === "fail"),
    Number(pr.review === "changes"),
    Number(pr.threads > 0),
    Number(pr.ci === "pending"),
    Number(pr.review === "review"),
    pr.number,
  ];
}

export function selectSnapshots(snapshots: Snapshot[]): Snapshot[] {
  const unique = new Map<string, Snapshot>();
  for (const pr of snapshots) {
    const key = `${pr.repo}#${pr.number}`;
    const previous = unique.get(key);
    if (
      !previous ||
      pr.fetchedAt > previous.fetchedAt ||
      (pr.fetchedAt === previous.fetchedAt &&
        pr.sessionMatch &&
        !previous.sessionMatch)
    ) {
      unique.set(key, pr);
    }
  }
  return [...unique.values()].sort((a, b) => {
    const left = urgency(a);
    const right = urgency(b);
    for (let i = 0; i < left.length; i++) {
      if (left[i] !== right[i]) return right[i]! - left[i]!;
    }
    return a.repo.localeCompare(b.repo);
  });
}

async function directories(path: string): Promise<string[]> {
  try {
    return (await readdir(path, { withFileTypes: true }))
      .filter((entry) => entry.isDirectory())
      .map((entry) => join(path, entry.name));
  } catch {
    return [];
  }
}

export async function readSnapshots(
  root: string,
  session: string,
  repo: string | undefined,
  branch: string | undefined,
  now = Date.now() / 1000,
): Promise<Snapshot[]> {
  const snapshots: Snapshot[] = [];
  for (const owner of await directories(root)) {
    for (const name of await directories(owner)) {
      for (const head of await directories(name)) {
        let files;
        try {
          files = await readdir(head, { withFileTypes: true });
        } catch {
          continue;
        }
        for (const file of files) {
          if (!file.isFile() || !/^\d+\.json$/.test(file.name)) continue;
          try {
            const path = join(head, file.name);
            if ((await stat(path)).size > MAX_SNAPSHOT_BYTES) continue;
            const pr = parseSnapshot(
              JSON.parse(await readFile(path, "utf8")),
              session,
              repo,
              branch,
              now,
            );
            if (pr) snapshots.push(pr);
          } catch {
            // Cache is best-effort; a deleted, unreadable, or partial file is not fatal.
          }
        }
      }
    }
  }
  return selectSnapshots(snapshots);
}
