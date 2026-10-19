import assert from "node:assert/strict";
import { existsSync, statSync } from "node:fs";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import sketchybarStatusExtension from "../.pi/agent/extensions/sketchybar-status.ts";

type Handler = (event: unknown, ctx: ExtensionContext) => unknown;
type PiStatus = {
  pid: number;
  state: "idle" | "working" | "blocked";
  startedAt: number;
  updatedAt: number;
  sessionId: string;
  sessionName?: string;
  cwd: string;
  tmux?: { socket: string; pane: string };
};

test("publishes Pi lifecycle state and removes the sidecar on shutdown", async () => {
  const directory = await mkdtemp(join(tmpdir(), "pi-sketchybar-test-"));
  const previousDirectory = process.env.PI_SKETCHYBAR_SESSION_DIR;
  const previousTmux = process.env.TMUX;
  const previousPane = process.env.TMUX_PANE;
  process.env.PI_SKETCHYBAR_SESSION_DIR = directory;
  process.env.TMUX = "/tmp/tmux-test.sock,123,0";
  process.env.TMUX_PANE = "%7";

  const handlers = new Map<string, Handler[]>();
  const pi = {
    on(event: string, handler: Handler) {
      const registered = handlers.get(event) ?? [];
      registered.push(handler);
      handlers.set(event, registered);
      return () => undefined;
    },
  } as unknown as ExtensionAPI;
  let sessionName: string | undefined = "SketchyBar task";
  const ctx = {
    mode: "tui",
    cwd: "/tmp/pi-project",
    sessionManager: {
      getSessionId: () => "session-123",
      getSessionName: () => sessionName,
    },
  } as unknown as ExtensionContext;
  const emit = async (type: string, fields: Record<string, unknown> = {}) => {
    for (const handler of handlers.get(type) ?? [])
      await handler({ type, ...fields }, ctx);
  };
  const statusFile = join(directory, `${process.pid}.json`);
  const readStatus = async () =>
    JSON.parse(await readFile(statusFile, "utf8")) as PiStatus;

  try {
    sketchybarStatusExtension(pi);
    await emit("session_start", { reason: "startup" });

    const idle = await readStatus();
    assert.equal(idle.state, "idle");
    assert.equal(idle.pid, process.pid);
    assert.equal(idle.sessionId, "session-123");
    assert.equal(idle.sessionName, "SketchyBar task");
    assert.deepEqual(idle.tmux, {
      socket: "/tmp/tmux-test.sock",
      pane: "%7",
    });
    assert.equal(statSync(statusFile).mode & 0o777, 0o600);

    await emit("before_agent_start");
    assert.equal((await readStatus()).state, "working");

    await emit("ui_prompt_start", { kind: "confirm", title: "Allow tool?" });
    assert.equal((await readStatus()).state, "blocked");
    await emit("ui_prompt_end", { kind: "confirm", title: "Allow tool?" });
    assert.equal((await readStatus()).state, "working");

    await emit("agent_settled", { aborted: false });
    assert.equal((await readStatus()).state, "idle");

    sessionName = "Renamed task";
    await emit("session_info_changed", { name: sessionName });
    assert.equal((await readStatus()).sessionName, "Renamed task");

    await emit("session_shutdown", { reason: "quit" });
    assert.equal(existsSync(statusFile), false);
  } finally {
    await emit("session_shutdown", { reason: "quit" });
    if (previousDirectory === undefined)
      delete process.env.PI_SKETCHYBAR_SESSION_DIR;
    else process.env.PI_SKETCHYBAR_SESSION_DIR = previousDirectory;
    if (previousTmux === undefined) delete process.env.TMUX;
    else process.env.TMUX = previousTmux;
    if (previousPane === undefined) delete process.env.TMUX_PANE;
    else process.env.TMUX_PANE = previousPane;
    await rm(directory, { recursive: true, force: true });
  }
});
