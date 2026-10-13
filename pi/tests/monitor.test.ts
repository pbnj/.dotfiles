import assert from "node:assert/strict";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { after, test } from "node:test";
import {
  findPRReference,
  MAX_MONITOR_TIMEOUT_MS,
  MonitorManager,
  normalizeMonitorInput,
  validateWebSocketUrl,
} from "../.pi/agent/extensions/gh-pr-status/monitor.ts";
import type {
  MonitorEvent,
  MonitorEnd,
} from "../.pi/agent/extensions/gh-pr-status/monitor.ts";

const dir = await mkdtemp(join(tmpdir(), "pi-monitor-"));
after(() => rm(dir, { recursive: true, force: true }));

function shellQuote(value: string): string {
  return `'${value.replaceAll("'", `'\\''`)}'`;
}

async function until(
  check: () => boolean | Promise<boolean>,
  timeout = 2000,
): Promise<void> {
  const deadline = Date.now() + timeout;
  while (!(await check())) {
    assert.ok(Date.now() < deadline, "timed out waiting for monitor event");
    await new Promise((resolve) => setTimeout(resolve, 15));
  }
}

void test("validates command/WebSocket alternatives and Monitor timeouts", () => {
  assert.equal(
    normalizeMonitorInput({ command: "printf hello" }).timeoutMs,
    300_000,
  );
  assert.equal(
    normalizeMonitorInput(
      { command: "printf hello", timeout_ms: MAX_MONITOR_TIMEOUT_MS },
      MAX_MONITOR_TIMEOUT_MS,
    ).timeoutMs,
    MAX_MONITOR_TIMEOUT_MS,
  );
  assert.throws(() => normalizeMonitorInput({}), /exactly one/);
  assert.throws(
    () =>
      normalizeMonitorInput({
        command: "echo hi",
        ws: { url: "wss://example.com" },
      }),
    /exactly one/,
  );
  assert.throws(() => normalizeMonitorInput({ command: "  " }), /exactly one/);
  assert.throws(
    () => normalizeMonitorInput({ command: "echo hi", timeout_ms: 0 }),
    /positive integer/,
  );
  assert.throws(
    () =>
      normalizeMonitorInput(
        { command: "echo hi", timeout_ms: 600_001 },
        600_000,
      ),
    /cannot exceed/,
  );
  assert.throws(
    () =>
      normalizeMonitorInput({
        ws: { url: "wss://example.com", protocols: ["bad protocol"] },
      }),
    /valid tokens/,
  );
  assert.throws(
    () =>
      normalizeMonitorInput({
        ws: { url: "wss://example.com", protocols: ["chat", "chat"] },
      }),
    /duplicates/,
  );
});

void test("finds PR identities in descriptions and gh-pr-watch commands", () => {
  assert.deepEqual(
    findPRReference(undefined, "CI and reviews on owner/repo#42"),
    {
      repo: "owner/repo",
      number: 42,
      url: "https://github.com/owner/repo/pull/42",
    },
  );
  assert.deepEqual(
    findPRReference("/opt/gh-pr-watch -R owner/repo 42 --fresh", undefined),
    {
      repo: "owner/repo",
      number: 42,
      url: "https://github.com/owner/repo/pull/42",
    },
  );
  assert.equal(findPRReference("npm run watch", "watch service"), undefined);
});

void test("streams command output, keeps the PR visible, and stops at exit", async () => {
  const events: MonitorEvent[] = [];
  const endings: MonitorEnd[] = [];
  const manager = new MonitorManager({
    onEvent: (event) => events.push(event),
    onEnd: (event) => endings.push(event),
  });
  const script = [
    `process.stdout.write("CI fail: ");`,
    `setTimeout(() => process.stdout.write("lint\\n"), 10);`,
    `setTimeout(() => process.stderr.write("REVIEW reviewer\\n"), 20);`,
    `setTimeout(() => process.exit(0), 40);`,
  ].join(" ");
  try {
    const info = await manager.start(
      normalizeMonitorInput({
        command: `${shellQuote(process.execPath)} -e ${shellQuote(script)}`,
        description: "CI and reviews on owner/repo#42",
      }),
      dir,
      "pi-session",
    );
    assert.equal(info.source, "command");
    assert.equal(manager.getActivePRs()[0]?.number, 42);
    await assert.rejects(
      manager.start(
        normalizeMonitorInput({
          command: "printf duplicate",
          description: "CI and reviews on owner/repo#42",
        }),
        dir,
        "pi-session",
      ),
      /Already monitoring/,
    );
    await until(() => endings.some(({ id }) => id === info.id));
    assert.ok(events.some(({ line }) => line === "CI fail: lint"));
    assert.ok(
      events.some(
        ({ source, line }) => source === "stderr" && line === "REVIEW reviewer",
      ),
    );
    assert.equal(manager.getActive().length, 0);
    assert.deepEqual([...manager.getWatchedPRs()], ["owner/repo#42"]);
    await manager.stopAll();
    assert.deepEqual([...manager.getWatchedPRs()], []);
  } finally {
    await manager.stopAll();
  }
});

void test("cancels a running command and enforces its deadline", async () => {
  const endings: MonitorEnd[] = [];
  const manager = new MonitorManager({
    onEvent: () => {},
    onEnd: (event) => endings.push(event),
  });
  const pidFile = join(dir, "pid.txt");
  try {
    const code = `require('node:fs').writeFileSync(${JSON.stringify(pidFile)}, String(process.pid)); setInterval(() => {}, 1000);`;
    const info = await manager.start(
      normalizeMonitorInput({
        command: `${shellQuote(process.execPath)} -e ${shellQuote(code)}`,
        description: "long-running monitor",
      }),
      dir,
      "pi-session",
    );
    await until(async () => {
      try {
        return Boolean(await readFile(pidFile, "utf8"));
      } catch {
        return false;
      }
    });
    const pid = Number(await readFile(pidFile, "utf8"));
    assert.ok(await manager.stop(info.id));
    await until(() => endings.some(({ id }) => id === info.id));
    assert.throws(() => process.kill(pid, 0), { code: "ESRCH" });
    assert.equal(endings.find(({ id }) => id === info.id)?.reason, "cancelled");

    const timeoutInfo = await manager.start(
      normalizeMonitorInput({
        command: `${shellQuote(process.execPath)} -e ${shellQuote("setInterval(() => {}, 1000)")}`,
        description: "deadline test",
        timeout_ms: 50,
      }),
      dir,
      "pi-session",
    );
    await until(() => endings.some(({ id }) => id === timeoutInfo.id));
    assert.equal(
      endings.find(({ id }) => id === timeoutInfo.id)?.reason,
      "timed out",
    );
  } finally {
    await manager.stopAll();
  }
});

void test("rejects private WebSocket targets and delivers each frame as one event", async () => {
  await assert.rejects(validateWebSocketUrl("ws://127.0.0.1:8080"), /private/);
  await assert.rejects(
    validateWebSocketUrl("wss://user:pass@example.com"),
    /credentials/,
  );

  const events: MonitorEvent[] = [];
  const endings: MonitorEnd[] = [];
  const listeners = new Map<
    string,
    (event: { data?: unknown; code?: number; reason?: string }) => void
  >();
  const socket = {
    addEventListener(
      type: string,
      listener: (event: {
        data?: unknown;
        code?: number;
        reason?: string;
      }) => void,
    ) {
      listeners.set(type, listener);
    },
    close(code = 1000, reason = "") {
      listeners.get("close")?.({ code, reason });
    },
  };
  const manager = new MonitorManager({
    onEvent: (event) => events.push(event),
    onEnd: (event) => endings.push(event),
    lookupHost: async () => ["1.1.1.1"],
    webSocketFactory: () => socket,
  });
  const info = await manager.start(
    normalizeMonitorInput({
      ws: { url: "wss://events.example.com/feed", protocols: ["events"] },
    }),
    dir,
    "pi-session",
  );
  listeners.get("open")?.({});
  listeners.get("message")?.({ data: "first line\nsecond line" });
  listeners.get("message")?.({ data: new Uint8Array([1, 2, 3]) });
  await until(() => events.length === 2);
  assert.equal(events[0]?.line, "first line\nsecond line");
  assert.equal(events[1]?.line, "[binary frame, 3 bytes]");
  assert.ok(await manager.stop(info.id));
  assert.equal(endings[0]?.reason, "cancelled");
  await manager.stopAll();
});
