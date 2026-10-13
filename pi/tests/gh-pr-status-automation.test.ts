import assert from "node:assert/strict";
import { test } from "node:test";
import {
  formatWatchActionMessage,
  WatchActionQueue,
  type WatchActionTask,
} from "../.pi/agent/extensions/gh-pr-status/automation.ts";

async function until(check: () => boolean, timeout = 2000): Promise<void> {
  const deadline = Date.now() + timeout;
  while (!check()) {
    assert.ok(
      Date.now() < deadline,
      "timed out waiting for batched watch action",
    );
    await new Promise((resolve) => setTimeout(resolve, 10));
  }
}

void test("batches actionable CI and review events into bounded per-PR tasks", async () => {
  const tasks: WatchActionTask[] = [];
  const queue = new WatchActionQueue((task) => tasks.push(task), 10, 2);

  assert.equal(
    queue.enqueue(
      "owner/repo#42: Watching https://github.com/owner/repo/pull/42",
    ),
    false,
  );
  assert.equal(
    queue.enqueue("owner/repo#42: CI green: all checks passed"),
    false,
  );
  assert.equal(
    queue.enqueue("owner/repo#42: SCALR plan: prod/app Terraform plan"),
    false,
  );

  const failure =
    "owner/repo#42: CI fail: lint https://github.com/owner/repo/actions/runs/1";
  queue.enqueue(failure);
  queue.enqueue(failure);
  const finding =
    "THREAD 7 reviewer README.md:3: The PR description says this bumps security-operations from 1.0.4 to 1.0.5 and the marketplace from 1.14.0 to 1.14.1, but the actual diffs are 1.0.5 → 1.0.6 and 1.14.1 → 1.14.2. Update the description so its release-version summary matches the manifests. <file/line number> https://github.com/owner/repo/pull/42#discussion_r7";
  queue.enqueue(`owner/repo#42: ${finding}`);
  queue.enqueue(
    "owner/repo#42: REVIEW reviewer CHANGES_REQUESTED on abc123: adjust validation",
  );
  queue.enqueue(
    "other/repo#43: REPLY reviewer on src/lib.ts:8: add a check https://github.com/other/repo/pull/43#discussion_r9",
  );

  await until(() => tasks.length === 1);
  assert.equal(tasks[0]?.eventCount, 4);
  assert.deepEqual(
    tasks[0]?.groups.map(({ label, url, totalEvents, omitted }) => ({
      label,
      url,
      totalEvents,
      omitted,
    })),
    [
      {
        label: "owner/repo#42",
        url: "https://github.com/owner/repo/pull/42",
        totalEvents: 3,
        omitted: 1,
      },
      {
        label: "other/repo#43",
        url: "https://github.com/other/repo/pull/43",
        totalEvents: 1,
        omitted: 0,
      },
    ],
  );

  const message = formatWatchActionMessage(tasks[0]!);
  assert.equal(
    message,
    [
      "CI fail: lint https://github.com/owner/repo/actions/runs/1",
      finding,
      "REPLY reviewer on src/lib.ts:8: add a check https://github.com/other/repo/pull/43#discussion_r9",
    ].join("\n"),
  );
});

void test("cancels pending agent actions during session cleanup", async () => {
  const tasks: WatchActionTask[] = [];
  const queue = new WatchActionQueue((task) => tasks.push(task), 10);
  queue.enqueue(
    "owner/repo#42: CI fail: lint https://github.com/owner/repo/actions/runs/1",
  );
  queue.cancel();
  await new Promise((resolve) => setTimeout(resolve, 30));
  assert.deepEqual(tasks, []);
});
