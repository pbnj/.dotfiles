import assert from "node:assert/strict";
import { existsSync } from "node:fs";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { test } from "node:test";
import { fileURLToPath, pathToFileURL } from "node:url";
import type {
  ExtensionToolContext,
  LoadExtensionsResult,
} from "@earendil-works/pi-coding-agent";

const piRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const install = join(piRoot, ".pi/agent/install");
const version = await readFile(join(install, "current-version"), "utf8").catch(
  () => "",
);
const host =
  process.env.PI_MONITOR_TEST_PI_PACKAGE ??
  join(
    install,
    "releases",
    version.trim(),
    "node_modules/@earendil-works/pi-coding-agent",
  );
const loaderPath = join(host, "dist/core/extensions/loader.js");
const skip = existsSync(loaderPath)
  ? false
  : "Pi host not installed; set PI_MONITOR_TEST_PI_PACKAGE to its package directory";

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));
async function until(check: () => boolean): Promise<void> {
  const deadline = Date.now() + 3000;
  while (!check()) {
    assert.ok(
      Date.now() < deadline,
      "timed out waiting for extension notification",
    );
    await sleep(10);
  }
}

async function setup() {
  const { loadExtensions } = await import(pathToFileURL(loaderPath).href);
  const loaded = (await loadExtensions(
    [join(piRoot, ".pi/agent/extensions/monitor/index.ts")],
    piRoot,
  )) as LoadExtensionsResult;
  assert.deepEqual(loaded.errors, []);
  const extension = loaded.extensions[0]!;
  const messages: {
    message: { customType: string; content: unknown };
    options: unknown;
  }[] = [];
  const notifications: string[] = [];
  const statuses: (string | undefined)[] = [];
  loaded.runtime.sendMessage = (message, options) => {
    messages.push({ message, options });
  };
  loaded.runtime.getSettings = () => ({
    shellCommandPrefix: "export MONITOR_TEST_PREFIX=ready",
  });
  const dir = await mkdtemp(join(tmpdir(), "pi-monitor-extension-"));
  const ctx = {
    mode: "tui",
    hasUI: true,
    cwd: dir,
    ui: {
      setStatus: (_key: string, value: string | undefined) =>
        statuses.push(value),
      notify: (message: string) => notifications.push(message),
      confirm: async () => true,
    },
    sessionManager: {
      getSessionId: () => "test-session",
      getSessionFile: () => undefined,
    },
  } as unknown as ExtensionToolContext;
  const emit = async (type: string) => {
    for (const handler of extension.handlers.get(type) ?? [])
      await handler({ type }, ctx);
  };
  const call = async (
    name: string,
    params: Record<string, unknown>,
    context = ctx,
    signal?: AbortSignal,
  ) => {
    const tool = extension.tools.get(name)!.definition;
    return tool.execute("test-call", params, signal, undefined, context);
  };
  await emit("session_start");
  return {
    loaded,
    extension,
    messages,
    notifications,
    statuses,
    ctx,
    emit,
    call,
    cleanup: async () => {
      await emit("session_shutdown");
      await rm(dir, { recursive: true, force: true });
    },
  };
}

void test(
  "Pi loads the standalone tools and sends custom follow-ups, not synthetic user messages",
  { skip },
  async () => {
    const s = await setup();
    try {
      assert.deepEqual(
        [...s.extension.tools.keys()],
        ["Monitor", "MonitorStop", "MonitorList"],
      );
      const started = await s.call("Monitor", {
        description: "generic shell source",
        command: 'printf "%s\\n%s\\n" "$MONITOR_TEST_PREFIX" "$PI_SESSION_ID"',
      });
      const info = started.structuredContent as {
        monitor_id: string;
        stdout_path: string;
      };
      assert.ok(info.monitor_id);
      await until(() => s.messages.length === 1);
      assert.equal(s.messages[0]!.message.customType, "monitor-event");
      assert.deepEqual(s.messages[0]!.options, {
        triggerTurn: true,
        deliverAs: "followUp",
      });
      assert.match(String(s.messages[0]!.message.content), /ready/);
      assert.match(String(s.messages[0]!.message.content), /test-session/);
      assert.match(String(s.messages[0]!.message.content), /untrusted data/);
      const result = await s.call("MonitorList", { include_ended: true });
      const listing = result.structuredContent as {
        monitors: { monitor_id: string; status: string }[];
      };
      assert.equal(listing.monitors[0]?.monitor_id, info.monitor_id);
      assert.equal(listing.monitors[0]?.status, "ended");
      assert.ok(s.statuses.includes("Monitor: 1 active"));
      assert.equal(s.statuses.at(-1), undefined);
      const stopped = await s.call("MonitorStop", {
        monitor_id: info.monitor_id,
      });
      assert.deepEqual(stopped.structuredContent, {
        monitor_id: info.monitor_id,
        stopped: false,
      });
    } finally {
      await s.cleanup();
    }
  },
);

void test(
  "Pi session replacement cancels old watchers and never sends their events to the new session",
  { skip },
  async () => {
    const s = await setup();
    try {
      await s.call("Monitor", {
        description: "old session",
        command: "sleep 30",
      });
      await s.emit("session_start");
      await sleep(250);
      assert.equal(s.messages.length, 0);
      const result = await s.call("MonitorList", { include_ended: true });
      assert.deepEqual(result.structuredContent, { monitors: [] });
    } finally {
      await s.cleanup();
    }
  },
);

void test(
  "Pi rejects short-lived modes and aborted starts; confirmation is opt-in and race-safe",
  { skip },
  async () => {
    const s = await setup();
    try {
      const input = { description: "guard", command: "sleep 30" };
      await assert.rejects(
        s.call("Monitor", input, { ...s.ctx, mode: "print", hasUI: false }),
        /long-lived/,
      );
      await assert.rejects(
        s.call("Monitor", input, s.ctx, AbortSignal.abort()),
        /cancelled/,
      );
      s.loaded.runtime.flagValues.set("monitor-confirm", true);
      s.ctx.ui.confirm = async () => false;
      await assert.rejects(s.call("Monitor", input), /declined/);
      let approve: (value: boolean) => void = () =>
        assert.fail("confirmation not started");
      s.ctx.ui.confirm = () =>
        new Promise((resolve) => {
          approve = resolve;
        });
      const pending = s.call("Monitor", input);
      await s.emit("session_start");
      approve(true);
      await assert.rejects(pending, /session changed/);
      assert.deepEqual((await s.call("MonitorList", {})).structuredContent, {
        monitors: [],
      });
    } finally {
      await s.cleanup();
    }
  },
);
