import assert from "node:assert/strict";
import {
  chmod,
  mkdtemp,
  mkdir,
  readFile,
  rm,
  writeFile,
} from "node:fs/promises";
import { tmpdir } from "node:os";
import { delimiter, join } from "node:path";
import { after, test } from "node:test";
import {
  parseWatchArgs,
  WatchManager,
  type Notify,
} from "../.pi/agent/extensions/gh-pr-status/watch.ts";

const dir = await mkdtemp(join(tmpdir(), "pi-watch-pr-"));
const oldPath = process.env.PATH;
const oldWatch = process.env.GH_PR_WATCH;
const oldResult = process.env.WATCH_TEST_RESULT;
after(async () => {
  process.env.PATH = oldPath;
  if (oldWatch === undefined) delete process.env.GH_PR_WATCH;
  else process.env.GH_PR_WATCH = oldWatch;
  if (oldResult === undefined) delete process.env.WATCH_TEST_RESULT;
  else process.env.WATCH_TEST_RESULT = oldResult;
  await rm(dir, { recursive: true, force: true });
});

async function until(check: () => boolean, timeout = 2000): Promise<void> {
  const deadline = Date.now() + timeout;
  while (!check()) {
    assert.ok(Date.now() < deadline, "timed out waiting for watcher");
    await new Promise((resolve) => setTimeout(resolve, 15));
  }
}

void test("validates arguments and refuses extra options", () => {
  assert.deepEqual(parseWatchArgs(""), {
    pr: undefined,
    repo: undefined,
    fresh: false,
    autoFix: true,
  });
  assert.deepEqual(parseWatchArgs("-R owner/repo 42 --fresh"), {
    pr: "42",
    repo: "owner/repo",
    fresh: true,
    autoFix: true,
  });
  assert.deepEqual(parseWatchArgs("42 --notify-only"), {
    pr: "42",
    repo: undefined,
    fresh: false,
    autoFix: false,
  });
  assert.throws(() => parseWatchArgs("42 other"));
  assert.throws(() => parseWatchArgs("--interval 1"));
  assert.throws(() => parseWatchArgs("-R owner/repo -R other/repo 42"));
  assert.throws(() => parseWatchArgs("0"));
  assert.throws(() => parseWatchArgs("42;rm"));
});

void test("spawns multiple watchers, tracks both PRs, forwards lines, and stops them", async () => {
  const bin = join(dir, "bin");
  await mkdir(bin);
  const watcher = join(bin, "gh-pr-watch");
  const gh = join(bin, "gh");
  const result = join(dir, "result.json");
  await writeFile(
    watcher,
    `#!/usr/bin/env node
const fs = require('node:fs');
fs.writeFileSync(process.env.WATCH_TEST_RESULT, JSON.stringify({pid:process.pid,args:process.argv.slice(2),session:process.env.PI_SESSION_ID}));
process.stdout.write('CI fa');
setTimeout(() => process.stdout.write('il: check https://github.com/owner/repo/pull/42\\n'), 10);
process.on('SIGTERM', () => process.exit(0));
setInterval(() => {}, 1000);
`,
  );
  await writeFile(
    gh,
    `#!/usr/bin/env node
console.log('https://github.com/owner/repo/pull/42');
`,
  );
  await Promise.all([chmod(watcher, 0o755), chmod(gh, 0o755)]);
  process.env.PATH = `${bin}${delimiter}${oldPath}`;
  process.env.GH_PR_WATCH = watcher;
  process.env.WATCH_TEST_RESULT = result;

  const events: { text: string; level: string }[] = [];
  const actions: string[] = [];
  const renderStates: string[][] = [];
  const managerRef: { current?: WatchManager } = {};
  const notify: Notify = (text, level) => events.push({ text, level });
  const manager = new WatchManager(() => {
    const active = managerRef.current?.getActivePRs() ?? [];
    renderStates.push(active.map(({ repo, number }) => `${repo}#${number}`));
  });
  managerRef.current = manager;
  try {
    await manager.start(
      "42 -R owner/repo --fresh",
      dir,
      "pi-123",
      notify,
      (line) => {
        actions.push(line);
      },
    );
    assert.deepEqual(renderStates[0], ["owner/repo#42"]);
    await manager.start(
      "https://github.com/owner/repo/pull/42",
      dir,
      "pi-123",
      notify,
    );
    await until(() => events.some(({ text }) => text.includes("CI fail:")));
    const child = JSON.parse(await readFile(result, "utf8"));
    assert.deepEqual(child.args, ["-R", "owner/repo", "--fresh", "42"]);
    assert.equal(child.session, "pi-123");
    await manager.start(
      "https://github.com/owner/repo/pull/43 --notify-only",
      dir,
      "pi-123",
      notify,
      (line) => actions.push(line),
    );
    await until(() =>
      events.some(({ text }) => text.startsWith("owner/repo#43: CI fail:")),
    );
    const notifyOnlyChild = JSON.parse(await readFile(result, "utf8"));
    assert.deepEqual(notifyOnlyChild.args, ["-R", "owner/repo", "43"]);
    assert.ok(
      actions.some((line) => line.startsWith("owner/repo#42: CI fail:")),
    );
    assert.ok(!actions.some((line) => line.startsWith("owner/repo#43:")));
    assert.deepEqual([...manager.getWatchedPRs()].sort(), [
      "owner/repo#42",
      "owner/repo#43",
    ]);
    assert.deepEqual(manager.getActivePRs(), [
      {
        repo: "owner/repo",
        number: 43,
        url: "https://github.com/owner/repo/pull/43",
      },
      {
        repo: "owner/repo",
        number: 42,
        url: "https://github.com/owner/repo/pull/42",
      },
    ]);
    assert.ok(renderStates.length >= 4);
    assert.equal(
      events.filter(({ text }) => text.startsWith("Watching ")).length,
      2,
    );
    assert.ok(events.some(({ text }) => text.startsWith("Already watching ")));
    assert.ok(
      events.some(
        ({ text, level }) => text.includes("CI fail:") && level === "error",
      ),
    );
    await manager.stopAll();
    assert.equal(manager.getWatchedPRs().size, 0);
    assert.deepEqual(manager.getActivePRs(), []);
    assert.throws(() => process.kill(child.pid, 0), { code: "ESRCH" });
    assert.ok(!events.some(({ text }) => text.includes("watch stopped")));
  } finally {
    await manager.stopAll();
  }
});

void test("reports startup errors and allows another watch after exit", async () => {
  const failing = join(dir, "failing-watch");
  await writeFile(failing, "#!/bin/sh\necho 'gh auth failed' >&2\nexit 1\n");
  await chmod(failing, 0o755);
  process.env.GH_PR_WATCH = failing;
  const events: string[] = [];
  const manager = new WatchManager();
  try {
    const notify: Notify = (text) => {
      events.push(text);
    };
    await manager.start(
      "https://github.com/owner/repo/pull/42",
      dir,
      "pi-123",
      notify,
    );
    await until(() => events.some((text) => text.includes("watch stopped")));
    assert.match(events.at(-1)!, /gh auth failed/);
    assert.deepEqual(manager.getActivePRs(), []);
    await manager.start(
      "https://github.com/owner/repo/pull/42",
      dir,
      "pi-123",
      notify,
    );
    assert.equal(
      events.filter((text) => text.startsWith("Watching ")).length,
      2,
    );
  } finally {
    await manager.stopAll();
  }
});
