import assert from "node:assert/strict";
import { mkdtemp, mkdir, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { after, test } from "node:test";
import {
  parseSnapshot,
  readSnapshots,
  selectSnapshots,
} from "../.pi/agent/extensions/gh-pr-status/cache.ts";

const now = 1_790_000_000;
const root = await mkdtemp(join(tmpdir(), "pi-gh-pr-status-"));
after(() => rm(root, { recursive: true, force: true }));

function snapshot(overrides: Record<string, unknown> = {}) {
  return {
    v: 1,
    repo: "owner/.dotfiles",
    branch: "feature/a",
    number: 10,
    url: "https://github.com/owner/.dotfiles/pull/10",
    state: "open",
    ci: "pass",
    ci_counts: { fail: 0, pending: 0 },
    review: "approved",
    threads: [],
    fetched_at: now - 100,
    interval: 60,
    watcher: { pi_session: "mine" },
    ...overrides,
  };
}

async function put(
  owner: string,
  repo: string,
  branch: string,
  number: number,
  value: unknown,
  base = root,
) {
  const dir = join(base, owner, repo, branch);
  await mkdir(dir, { recursive: true });
  await writeFile(join(dir, `${number}.json`), JSON.stringify(value));
}

void test("matches Pi session across repos and branch fallback without another agent's PRs", () => {
  assert.ok(parseSnapshot(snapshot(), "mine", undefined, undefined, now));
  assert.ok(
    parseSnapshot(
      snapshot({ watcher: { claude_session: "other" } }),
      "mine",
      "owner/.dotfiles",
      "feature/a",
      now,
    ),
  );
  assert.equal(
    parseSnapshot(
      snapshot({ watcher: { claude_session: "other" } }),
      "mine",
      "owner/.dotfiles",
      "main",
      now,
    ),
    undefined,
  );
  assert.equal(
    parseSnapshot(
      snapshot({ fetched_at: now - 901 }),
      "mine",
      undefined,
      undefined,
      now,
    ),
    undefined,
  );
  assert.equal(
    parseSnapshot(
      snapshot({ state: "merged" }),
      "mine",
      undefined,
      undefined,
      now,
    ),
    undefined,
  );
  assert.equal(
    parseSnapshot(snapshot({ v: 2 }), "mine", undefined, undefined, now),
    undefined,
  );
  assert.equal(
    parseSnapshot(
      snapshot({ url: "https://example.com/escape" }),
      "mine",
      undefined,
      undefined,
      now,
    ),
    undefined,
  );
});

void test("managed watches survive another agent overwriting snapshot attribution", async () => {
  const managedRoot = join(root, "managed");
  await put(
    "owner",
    "other",
    "branch-one",
    31,
    snapshot({
      repo: "owner/other",
      branch: "branch-one",
      number: 31,
      url: "https://github.com/owner/other/pull/31",
      watcher: { claude_session: "another-agent" },
    }),
    managedRoot,
  );
  await put(
    "owner",
    "other",
    "branch-two",
    32,
    snapshot({
      repo: "owner/other",
      branch: "branch-two",
      number: 32,
      url: "https://github.com/owner/other/pull/32",
      watcher: { pi_session: "mine" },
    }),
    managedRoot,
  );
  await put(
    "owner",
    "other",
    "branch-three",
    33,
    snapshot({
      repo: "owner/other",
      branch: "branch-three",
      number: 33,
      url: "https://github.com/owner/other/pull/33",
      watcher: { claude_session: "another-agent" },
    }),
    managedRoot,
  );
  const watched = new Set(["owner/other#31", "owner/other#32"]);
  const prs = await readSnapshots(
    managedRoot,
    "mine",
    undefined,
    undefined,
    now,
    watched,
  );
  assert.deepEqual(
    prs.map(({ number }) => number),
    [32, 31],
  );
  assert.ok(prs.every((pr) => pr.sessionMatch));
  assert.equal(
    parseSnapshot(
      snapshot({
        repo: "owner/other",
        number: 31,
        fetched_at: now - 901,
      }),
      "mine",
      undefined,
      undefined,
      now,
      watched,
    ),
    undefined,
  );
});

void test("deduplicates newest snapshot and orders by CI, review, threads, pending, then number", () => {
  const values = [
    snapshot({ number: 99, ci: "pending" }),
    snapshot({ number: 11, ci: "fail" }),
    snapshot({ number: 12, ci: "fail", fetched_at: now - 200 }),
    snapshot({ number: 12, ci: "pass", fetched_at: now - 10 }),
    snapshot({ number: 13, review: "changes" }),
    snapshot({ number: 14, threads: [{}] }),
  ].map((value) => parseSnapshot(value, "mine", undefined, undefined, now)!);
  const selected = selectSnapshots(values);
  assert.deepEqual(
    selected.map(({ number }) => number),
    [11, 13, 14, 99, 12],
  );
  assert.equal(
    selected.find(({ number }) => number === 12)?.fetchedAt,
    now - 10,
  );
});

void test("reads URI-encoded branch dirs, dotfile repos and skips broken/old files", async () => {
  await put("owner", ".dotfiles", "feature%2Fa", 10, snapshot());
  await put(
    "else",
    "other",
    "main",
    20,
    snapshot({ repo: "else/other", branch: "main", number: 20 }),
  );
  await put(
    "else",
    "other",
    "main",
    21,
    snapshot({
      repo: "else/other",
      branch: "main",
      number: 21,
      fetched_at: now - 1000,
    }),
  );
  await put("else", "other", "main", 22, "not a snapshot");
  const prs = await readSnapshots(
    root,
    "mine",
    "owner/.dotfiles",
    "feature/a",
    now,
  );
  assert.deepEqual(
    prs.map(({ number }) => number),
    [20, 10],
  );
  assert.equal(prs[1]?.repo, "owner/.dotfiles");
});
