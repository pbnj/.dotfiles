import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { createServer } from "node:http";
import { mkdtemp, readFile, realpath, rm, stat } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { after, test } from "node:test";
import {
  MonitorDelivery,
  notificationText,
  type PendingNotice,
} from "../.pi/agent/extensions/monitor/delivery.ts";
import {
  MAX_TIMEOUT_MS,
  MonitorManager,
  normalizeInput,
  type CommandEnvironment,
  type MonitorNotice,
  type MonitorSocket,
} from "../.pi/agent/extensions/monitor/manager.ts";

const root = await mkdtemp(join(tmpdir(), "pi-monitor-tests-"));
after(() => rm(root, { recursive: true, force: true }));
const environment: CommandEnvironment = {
  cwd: root,
  shell: "/bin/bash",
  args: ["-c"],
};
const quote = (value: string) => `'${value.replaceAll("'", `'\\''`)}'`;
const node = (code: string) => `${quote(process.execPath)} -e ${quote(code)}`;
const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));
async function until(
  check: () => boolean | Promise<boolean>,
  timeout = 3000,
): Promise<void> {
  const deadline = Date.now() + timeout;
  while (!(await check())) {
    assert.ok(Date.now() < deadline, "timed out waiting for monitor");
    await sleep(10);
  }
}
function setup(
  options: {
    maxActive?: number;
    maxEventsPerMinute?: number;
    batchMs?: number;
  } = {},
) {
  const notices: MonitorNotice[] = [];
  const manager = new MonitorManager({
    ...options,
    logRoot: root,
    onNotice: (notice) => notices.push(notice),
  });
  return { manager, notices };
}
const lines = (notices: MonitorNotice[]) =>
  notices
    .filter((notice) => notice.kind === "events")
    .flatMap((notice) => notice.lines);

void test("requires a description, exactly one source, and a bounded timeout", () => {
  assert.equal(
    normalizeInput({ description: "watch", command: "echo hi" }).timeout_ms,
    300_000,
  );
  assert.equal(
    normalizeInput({
      description: "watch",
      command: "echo hi",
      timeout_ms: MAX_TIMEOUT_MS,
    }).timeout_ms,
    MAX_TIMEOUT_MS,
  );
  for (const input of [
    { description: "watch" },
    { description: "watch", command: "hi", ws: { url: "wss://example.com" } },
    { description: "watch", command: "" },
    { description: "", command: "true" },
    { description: "bad\nlabel", command: "true" },
    { description: "watch", command: "true", timeout_ms: 0 },
    { description: "watch", command: "true", timeout_ms: 1.5 },
    { description: "watch", command: "true", timeout_ms: MAX_TIMEOUT_MS + 1 },
    { description: "watch", ws: { url: "https://example.com" } },
    { description: "watch", ws: { url: "ws://user:pass@example.com" } },
    { description: "watch", ws: { url: "ws://example.com#fragment" } },
    {
      description: "watch",
      ws: { url: "ws://example.com", protocols: ["bad protocol"] },
    },
    {
      description: "watch",
      ws: { url: "ws://example.com", protocols: ["chat", "chat"] },
    },
  ])
    assert.throws(() => normalizeInput(input));
  assert.ok(
    normalizeInput({
      description: "local events",
      ws: { url: "ws://127.0.0.1:8080", protocols: ["chat"] },
    }),
  );
});

void test("returns immediately, batches stdout, logs stderr silently, and reports exit status", async () => {
  const { manager, notices } = setup();
  try {
    const info = manager.start(
      {
        description: "arbitrary producer",
        command: node(
          'process.stdout.write("first\\n"); process.stderr.write("diagnostic\\n"); setTimeout(() => { process.stdout.write("second\\n"); }, 30); setTimeout(() => { process.stdout.write("partial"); process.exitCode = 7; }, 400);',
        ),
      },
      environment,
    );
    assert.equal(info.status, "running");
    assert.equal(notices.length, 0);
    await until(() => notices.some((notice) => notice.kind === "events"));
    assert.deepEqual(notices[0]?.lines, ["first", "second"]);
    assert.equal(
      notices.some((notice) => notice.kind === "end"),
      false,
    );
    await until(() => notices.some((notice) => notice.kind === "end"));
    assert.deepEqual(lines(notices), ["first", "second", "partial"]);
    const end = notices.at(-1)!;
    assert.equal(end.monitor.exit_code, 7);
    assert.equal(end.monitor.event_count, 3);
    assert.equal(end.monitor.status, "ended");
    assert.equal(await readFile(info.stderr_path, "utf8"), "diagnostic\n");
    assert.equal(
      await readFile(info.stdout_path, "utf8"),
      "first\nsecond\npartial",
    );
    assert.equal((await stat(info.stderr_path)).mode & 0o777, 0o600);
    assert.equal(manager.list().length, 0);
    assert.equal(manager.list(true).length, 1);
    assert.equal(await manager.stop(info.monitor_id), false);
  } finally {
    await manager.stopAll();
  }
});

void test("supports Bash syntax, command prefixes, cwd and per-session environment", async () => {
  const { manager, notices } = setup();
  try {
    manager.start(
      {
        description: "environment",
        command:
          '[[ "$PREFIX" == yes ]] && printf "%s\\n%s\\n" "$PWD" "$PI_SESSION_ID"',
      },
      {
        ...environment,
        prefix: "export PREFIX=yes",
        env: { ...process.env, PI_SESSION_ID: "session-test" },
      },
    );
    await until(() => notices.some((notice) => notice.kind === "end"));
    assert.deepEqual(lines(notices), [await realpath(root), "session-test"]);
    assert.equal(notices.at(-1)?.monitor.exit_code, 0);
  } finally {
    await manager.stopAll();
  }
});

void test("multiple independent monitors have isolated IDs, timeouts, logs, and cancellation", async () => {
  const { manager, notices } = setup({ maxActive: 2 });
  try {
    const first = manager.start(
      { description: "same description", command: "printf 'one\\n'; sleep 30" },
      environment,
    );
    const second = manager.start(
      {
        description: "same description",
        command: "printf 'two\\n'; sleep 30",
        timeout_ms: 1500,
      },
      environment,
    );
    assert.notEqual(first.monitor_id, second.monitor_id);
    assert.notEqual(first.stderr_path, second.stderr_path);
    assert.equal(manager.list().length, 2);
    assert.throws(
      () =>
        manager.start({ description: "third", command: "true" }, environment),
      /At most 2/,
    );
    await until(() => lines(notices).includes("two"));
    assert.ok(await manager.stop(first.monitor_id));
    assert.equal(manager.list()[0]?.monitor_id, second.monitor_id);
    await until(() =>
      notices.some(
        (notice) =>
          notice.kind === "end" &&
          notice.monitor.monitor_id === second.monitor_id,
      ),
    );
    assert.equal(
      notices.find(
        (notice) =>
          notice.kind === "end" &&
          notice.monitor.monitor_id === first.monitor_id,
      )?.monitor.reason,
      "stopped",
    );
    assert.equal(notices.at(-1)?.monitor.reason, "timeout");
    assert.equal(notices.at(-1)?.monitor.event_count, 1);
  } finally {
    await manager.stopAll();
  }
});

void test("stopping kills descendants that ignore TERM, even after their parent shell exits", async () => {
  const { manager, notices } = setup();
  try {
    const info = manager.start(
      {
        description: "process tree",
        command: `${node('process.on("SIGTERM", () => {}); console.log(process.pid); setInterval(() => {}, 1000);')} & wait`,
      },
      environment,
    );
    await until(() => lines(notices).length > 0);
    const pid = Number(lines(notices)[0]);
    assert.ok(Number.isSafeInteger(pid));
    await manager.stop(info.monitor_id);
    await until(() => {
      try {
        process.kill(pid, 0);
        return false;
      } catch {
        return true;
      }
    });
    assert.equal(notices.filter((notice) => notice.kind === "end").length, 1);
  } finally {
    await manager.stopAll();
  }
});

void test("shell exit cleans up orphaned background children without waiting for inherited pipes", async () => {
  const { manager, notices } = setup();
  const pidFile = join(root, "orphan.pid");
  try {
    const code = `require("node:fs").writeFileSync(${JSON.stringify(pidFile)}, String(process.pid)); setInterval(() => {}, 1000);`;
    const info = manager.start(
      {
        description: "orphan",
        command: `${node(code)} & while [ ! -f ${quote(pidFile)} ]; do sleep 0.01; done; exit 0`,
      },
      environment,
    );
    await until(() => notices.some((notice) => notice.kind === "end"));
    const pid = Number(await readFile(pidFile, "utf8"));
    await until(() => {
      try {
        process.kill(pid, 0);
        return false;
      } catch {
        return true;
      }
    });
    assert.equal(notices.at(-1)?.monitor.monitor_id, info.monitor_id);
  } finally {
    await manager.stopAll();
  }
});

void test("flood protection stops only the offender and still sends its final notice", async () => {
  const { manager, notices } = setup({ maxEventsPerMinute: 3 });
  try {
    const quiet = manager.start(
      { description: "quiet", command: "sleep 30" },
      environment,
    );
    const noisy = manager.start(
      {
        description: "noisy",
        command: "printf 'a\\nb\\nc\\nd\\ne\\n'; sleep 30",
      },
      environment,
    );
    await until(() => notices.some((notice) => notice.kind === "end"));
    assert.equal(notices.at(-1)?.monitor.monitor_id, noisy.monitor_id);
    assert.match(notices.at(-1)!.monitor.reason!, /flood/);
    assert.deepEqual(lines(notices), ["a", "b", "c"]);
    assert.equal(manager.list()[0]?.monitor_id, quiet.monitor_id);
  } finally {
    await manager.stopAll();
  }
});

void test("bounds unterminated lines and stderr logs without sending stderr events", async () => {
  const { manager, notices } = setup();
  try {
    manager.start(
      {
        description: "long line",
        command: node(
          'process.stdout.write("x".repeat(70 * 1024)); setInterval(() => {}, 1000);',
        ),
      },
      environment,
    );
    await until(() => notices.some((notice) => notice.kind === "end"));
    assert.match(notices.at(-1)!.monitor.reason!, /unterminated stdout line/);
    assert.deepEqual(lines(notices), []);
    const stderr = manager.start(
      {
        description: "stderr flood",
        command: node(
          'process.stderr.write("x".repeat(11 * 1024 * 1024)); setInterval(() => {}, 1000);',
        ),
      },
      environment,
    );
    await until(() =>
      notices.some(
        (notice) =>
          notice.kind === "end" &&
          notice.monitor.monitor_id === stderr.monitor_id,
      ),
    );
    assert.match(notices.at(-1)!.monitor.reason!, /stderr log exceeded/);
    assert.equal((await stat(stderr.stderr_path)).size, 10 * 1024 * 1024);
    assert.deepEqual(lines(notices), []);
  } finally {
    await manager.stopAll();
  }
});

void test("decodes split UTF-8, handles CRLF/blank lines, and strips terminal escapes from notifications", async () => {
  const { manager, notices } = setup();
  try {
    manager.start(
      {
        description: "encoding",
        command: node(
          'const b = Buffer.from("😀\\r\\n\\n\\x1b[31mred\\x1b[0m\\n"); process.stdout.write(b.subarray(0, 2)); setTimeout(() => process.stdout.write(b.subarray(2)), 20);',
        ),
      },
      environment,
    );
    await until(() => notices.some((notice) => notice.kind === "end"));
    assert.deepEqual(lines(notices), ["😀", "", "red"]);
  } finally {
    await manager.stopAll();
  }
});

void test("native WebSocket client connects to a local server and receives a real frame", async () => {
  const { manager, notices } = setup();
  const server = createServer();
  const connections = new Set<import("node:stream").Duplex>();
  server.on("upgrade", (request, socket) => {
    connections.add(socket);
    socket.on("error", () => {});
    socket.on("close", () => connections.delete(socket));
    const accept = createHash("sha1")
      .update(
        `${request.headers["sec-websocket-key"]}258EAFA5-E914-47DA-95CA-C5AB0DC85B11`,
      )
      .digest("base64");
    socket.write(
      `HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: ${accept}\r\n\r\n`,
    );
    const message = Buffer.from("local event");
    socket.write(Buffer.concat([Buffer.from([0x81, message.length]), message]));
    socket.end(Buffer.from([0x88, 0x02, 0x03, 0xe8]));
  });
  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
  try {
    const address = server.address();
    assert.ok(address && typeof address !== "string");
    manager.start(
      {
        description: "real socket",
        ws: { url: `ws://127.0.0.1:${address.port}` },
      },
      environment,
    );
    await until(() => notices.some((notice) => notice.kind === "end"));
    assert.deepEqual(lines(notices), ["local event"]);
    assert.equal(notices.at(-1)?.monitor.close_code, 1000);
  } finally {
    await manager.stopAll();
    for (const connection of connections) connection.destroy();
    await new Promise<void>((resolve) => server.close(() => resolve()));
  }
});

function fakeSocket() {
  const listeners = new Map<
    string,
    (event: { data?: unknown; code?: number }) => void
  >();
  const socket: MonitorSocket = {
    binaryType: "blob",
    addEventListener(type, handler) {
      listeners.set(type, handler);
    },
    close(code = 1000) {
      listeners.get("close")?.({ code });
    },
  };
  return {
    socket,
    emit: (type: string, data: { data?: unknown; code?: number } = {}) =>
      listeners.get(type)?.(data),
  };
}

void test("WebSocket text messages stay intact, binary messages report sizes, and close codes are delivered", async () => {
  const fake = fakeSocket();
  const notices: MonitorNotice[] = [];
  const manager = new MonitorManager({
    logRoot: root,
    onNotice: (notice) => notices.push(notice),
    socketFactory: (url, protocols) => {
      assert.equal(url, "ws://localhost:9999");
      assert.deepEqual(protocols, ["events"]);
      return fake.socket;
    },
  });
  try {
    const info = manager.start(
      {
        description: "local socket",
        ws: { url: "ws://localhost:9999", protocols: ["events"] },
      },
      environment,
    );
    assert.equal(fake.socket.binaryType, "arraybuffer");
    fake.emit("message", { data: "first\nsecond" });
    fake.emit("message", { data: new Uint8Array([1, 2, 3]).buffer });
    fake.emit("close", { code: 1001 });
    assert.deepEqual(lines(notices), [
      "first\nsecond",
      "[binary frame, 3 bytes]",
    ]);
    assert.equal(notices.at(-1)?.monitor.close_code, 1001);
    assert.equal(notices.at(-1)?.monitor.event_count, 2);
    assert.equal(await manager.stop(info.monitor_id), false);
  } finally {
    await manager.stopAll();
  }
});

void test("WebSocket errors, oversized messages and never-closing sockets cannot leak monitors", async () => {
  for (const scenario of ["error", "oversized", "timeout"] as const) {
    const fake = fakeSocket();
    fake.socket.close = () => {};
    const notices: MonitorNotice[] = [];
    const manager = new MonitorManager({
      logRoot: root,
      onNotice: (notice) => notices.push(notice),
      socketFactory: () => fake.socket,
    });
    try {
      manager.start(
        {
          description: scenario,
          ws: { url: "ws://localhost:9999" },
          timeout_ms: scenario === "timeout" ? 20 : 1000,
        },
        environment,
      );
      if (scenario === "error") fake.emit("error");
      if (scenario === "oversized")
        fake.emit("message", { data: "x".repeat(1024 * 1024 + 1) });
      await until(() => notices.some((notice) => notice.kind === "end"));
      assert.equal(manager.list().length, 0);
      assert.match(
        notices.at(-1)!.monitor.reason!,
        scenario === "error"
          ? /connection failed/
          : scenario === "oversized"
            ? /frame exceeded/
            : /timeout/,
      );
      fake.emit("message", { data: "late event" });
      assert.deepEqual(lines(notices), []);
    } finally {
      await manager.stopAll();
    }
  }
});

void test("spawn errors free slots, observers cannot strand processes, and dispose is idempotent", async () => {
  const { manager, notices } = setup();
  manager.start(
    { description: "bad shell", command: "true" },
    { ...environment, shell: "/missing/pi-shell" },
  );
  await until(() => notices.some((notice) => notice.kind === "end"));
  assert.match(notices.at(-1)!.monitor.reason!, /error:/);
  manager.start({ description: "cleanup", command: "sleep 30" }, environment);
  manager.dispose();
  manager.dispose();
  await manager.stopAll();
  assert.equal(manager.list().length, 0);
  const broken = new MonitorManager({
    logRoot: root,
    onNotice: () => {
      throw new Error("observer");
    },
  });
  broken.start({ description: "observer", command: "true" }, environment);
  await until(() => broken.list().length === 0);
});

void test("delivery coalesces multiple monitors and permits only one outstanding continuation", async () => {
  const { manager, notices } = setup();
  const sent: PendingNotice[][] = [];
  const delivery = new MonitorDelivery({
    send: (batch) => sent.push(batch),
    onOverflow: () => assert.fail("overflow"),
    onError: (error) => assert.fail(String(error)),
  });
  try {
    manager.start({ description: "first", command: "echo first" }, environment);
    manager.start(
      { description: "second", command: "echo second" },
      environment,
    );
    await until(
      () => notices.filter((notice) => notice.kind === "end").length === 2,
    );
    for (const notice of notices) delivery.enqueue(notice);
    await until(() => sent.length === 1);
    assert.equal(sent[0]?.length, 2);
    const event = notices[0]!;
    delivery.enqueue(event);
    delivery.enqueue(event);
    await sleep(20);
    assert.equal(sent.length, 1);
    delivery.settled();
    await until(() => sent.length === 2);
    assert.ok(notificationText(sent[0]!).includes("untrusted data"));
    delivery.dispose();
    delivery.enqueue(event);
    delivery.settled();
    await sleep(20);
    assert.equal(sent.length, 2);
  } finally {
    delivery.dispose();
    await manager.stopAll();
  }
});

void test("delivery bounds its backlog, stops the offender once, and preserves final status", async () => {
  const { manager, notices } = setup();
  manager.start(
    { description: "producer", command: "echo hello" },
    environment,
  );
  await until(() => notices.some((notice) => notice.kind === "end"));
  const info = notices.at(-1)!.monitor;
  const sent: PendingNotice[][] = [];
  const stopped: string[] = [];
  const delivery = new MonitorDelivery({
    send: (batch) => sent.push(batch),
    onOverflow: (id) => stopped.push(id),
    onError: (error) => assert.fail(String(error)),
  });
  try {
    delivery.enqueue({ kind: "events", monitor: info, lines: ["initial"] });
    await until(() => sent.length === 1);
    for (let i = 0; i < 200; i++)
      delivery.enqueue({
        kind: "events",
        monitor: info,
        lines: ["x".repeat(2000)],
      });
    delivery.enqueue({
      kind: "end",
      monitor: { ...info, reason: "flood" },
      lines: [],
    });
    delivery.enqueue({
      kind: "events",
      monitor: { ...info, monitor_id: "quiet-monitor", description: "quiet" },
      lines: ["important quiet event"],
    });
    assert.deepEqual(stopped, [info.monitor_id]);
    delivery.settled();
    await until(() => sent.length === 2);
    assert.ok(sent[1]![0]!.omitted_events > 0);
    assert.equal(sent[1]![0]!.ended, true);
    assert.equal(sent[1]![0]!.monitor.reason, "flood");
    assert.deepEqual(sent[1]![1]!.lines, ["important quiet event"]);
    assert.ok(Buffer.byteLength(JSON.stringify(sent[1])) < 70_000);
  } finally {
    delivery.dispose();
    await manager.stopAll();
  }
});
