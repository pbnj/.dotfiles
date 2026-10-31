import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import {
  mkdir,
  mkdtemp,
  readFile,
  rm,
  symlink,
  writeFile,
} from "node:fs/promises";
import { homedir, tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { test, type TestContext } from "node:test";
import { fileURLToPath, pathToFileURL } from "node:url";
import type {
  ExtensionAPI,
  ExtensionContext,
  ToolResultEvent,
} from "@earendil-works/pi-coding-agent";
import ghPrWatchExtension from "../.pi/agent/extensions/gh-pr-watch/index.ts";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const sharedHook = join(root, "utils/.local/bin/gh-pr-watch-hook");
const installedAgent = join(homedir(), ".pi/agent");
const url = "https://github.com/acme/widgets/pull/42";

async function setup(t: TestContext) {
  const dir = await mkdtemp(join(tmpdir(), "pi-pr-watch-"));
  const originalEnv = { ...process.env };
  const home = join(dir, "home with spaces");
  const bin = join(home, ".local/bin");
  await mkdir(bin, { recursive: true });
  const hook = join(bin, "gh-pr-watch-hook");
  await symlink(sharedHook, hook);
  await writeFile(
    join(bin, "gh"),
    `#!/bin/sh
printf '%s\\n' "$*" >> "$GH_TEST_LOG"
[ "\${GH_TEST_FAIL:-}" != 1 ] || exit 1
case "$*" in
  *'--json url,state'*) [ "$GH_TEST_STATE" != OPEN ] || printf '%s\\n' "$GH_TEST_URL" ;;
  *'--json state'*) printf '%s\\n' "$GH_TEST_STATE" ;;
  *'--json url'*) printf '%s\\n' "$GH_TEST_URL" ;;
  *) exit 1 ;;
esac
`,
    { mode: 0o755 },
  );
  Object.assign(process.env, {
    HOME: home,
    PATH: `${bin}:${process.env.PATH}`,
    XDG_STATE_HOME: join(dir, "state"),
    XDG_CACHE_HOME: join(dir, "cache"),
    GH_TEST_LOG: join(dir, "gh.log"),
    GH_TEST_URL: url,
    GH_TEST_STATE: "OPEN",
    // The adapter must use its context, not either inherited agent identity.
    PI_SESSION_ID: "wrong-pi-session",
    CLAUDE_CODE_SESSION_ID: "outer-claude-session",
  });
  delete process.env.GH_TEST_FAIL;
  const handlers = new Map<
    string,
    ((event: any, ctx: ExtensionContext) => any)[]
  >();
  const messages: { message: any; options: any }[] = [];
  const warnings: string[] = [];
  let tools = ["Monitor"];
  ghPrWatchExtension({
    on: (name: string, handler: any) => {
      handlers.set(name, [...(handlers.get(name) ?? []), handler]);
    },
    getActiveTools: () => tools,
    sendMessage: (message: any, options: any) =>
      messages.push({ message, options }),
  } as unknown as ExtensionAPI);
  const ctx = {
    cwd: dir,
    mode: "tui",
    hasUI: true,
    sessionManager: { getSessionId: () => "test-session" },
    ui: { notify: (message: string) => warnings.push(message) },
  } as unknown as ExtensionContext;
  async function emit(name: string, extra: Record<string, unknown> = {}) {
    let result;
    for (const handler of handlers.get(name) ?? [])
      result = await handler({ type: name, ...extra }, ctx);
    return result;
  }
  t.after(async () => {
    await emit("session_shutdown");
    for (const key of Object.keys(process.env))
      if (!(key in originalEnv)) delete process.env[key];
    Object.assign(process.env, originalEnv);
    await rm(dir, { recursive: true, force: true });
  });
  await emit("session_start");
  await emit("before_agent_start");
  function tool(
    name = "bash",
    command = "gh pr create --title test",
    overrides: Record<string, unknown> = {},
  ) {
    return emit("tool_result", {
      toolCallId: "call-1",
      toolName: name,
      input: { command },
      content: [{ type: "text", text: url }],
      details: undefined,
      isError: false,
      ...overrides,
    });
  }
  function settle(overrides: Record<string, unknown> = {}) {
    return emit("agent_before_settle", {
      entries: [],
      continue: false,
      outcome: "completed",
      context: { canContinue: true },
      ...overrides,
    });
  }
  function shell(
    args: string[],
    input?: object,
    env: Record<string, string> = {},
  ) {
    const result = spawnSync(sharedHook, args, {
      cwd: dir,
      env: { ...process.env, ...env },
      input: input ? JSON.stringify(input) : undefined,
      encoding: "utf8",
    });
    assert.equal(result.status, 0, result.stderr);
    return result.stdout.trim() ? JSON.parse(result.stdout) : undefined;
  }
  const state = join(dir, "state/gh-pr-watch-hook/test-session");
  return {
    dir,
    home,
    hook,
    state,
    ctx,
    messages,
    warnings,
    emit,
    tool,
    settle,
    shell,
    setTools: (names: string[]) => {
      tools = names;
    },
  };
}

void test("PR creation injects shared watch instructions as safe custom context", async (t) => {
  const s = await setup(t);
  await s.tool("bash", "gh-pr-open --draft");
  assert.equal(s.messages.length, 1);
  const { message, options } = s.messages[0]!;
  assert.equal(message.customType, "gh-pr-watch-hook");
  assert.equal(message.display, false);
  assert.deepEqual(options, { triggerTurn: false });
  assert.match(message.content, /acme\/widgets#42/);
  assert.match(message.content, /42 --fresh/);
  assert.match(message.content, /timeout_ms:\s+1800000/);
  assert.match(message.content, /Never run scalr confirm-run unasked/);
  assert.match(message.content, /gh-pr-watch-hook --agent pi ignore/);
  assert.equal(
    await readFile(join(s.state, "prs"), "utf8"),
    "acme/widgets\t42\n",
  );
  assert.equal(
    existsSync(join(s.dir, "state/gh-pr-watch-hook/wrong-pi-session")),
    false,
  );
  assert.deepEqual(s.warnings, []);
});

void test("pushes, MCP creation, and nested codemode results are detected without rewriting results", async (t) => {
  const s = await setup(t);
  await s.tool("bash", "git -C /some/repo push origin HEAD", {
    parentToolCallId: "codemode-1",
  });
  assert.equal(s.messages.length, 1);
  const structuredContent = {
    html_url: "https://github.com/acme/widgets/pull/43",
  };
  const details = { original: true };
  const content = [{ type: "text", text: "created" }];
  const event = {
    type: "tool_result",
    toolName: "mcp__github__create_pull_request",
    toolCallId: "codemode-2/1",
    parentToolCallId: "codemode-2",
    input: { title: "test" },
    content,
    structuredContent,
    details,
    isError: false,
  } as ToolResultEvent;
  const before = structuredClone(event);
  assert.equal(await s.emit("tool_result", event), undefined);
  assert.deepEqual(event, before);
  assert.equal(s.messages.length, 2);
  assert.match(s.messages[1]!.message.content, /widgets#43/);
  await s.tool("Bash", "gh pr create");
  assert.equal(s.messages.length, 3);
});

void test("Monitor arms suppress duplicates; expired watches rearm without --fresh", async (t) => {
  const s = await setup(t);
  await s.tool();
  await s.tool("Monitor", "gh-pr-watch -R acme/widgets 42 --fresh");
  assert.equal(s.messages.length, 1);
  assert.ok(existsSync(join(s.state, "armed/acme-widgets-42")));
  await s.tool("bash", "git push");
  assert.equal(s.messages.length, 1);
  assert.equal(await s.settle(), undefined);
  await writeFile(join(s.state, "armed/acme-widgets-42"), "1\n");
  const blocked = await s.settle();
  assert.equal(blocked.continue, true);
  assert.doesNotMatch(blocked.entries[0].content, /42 --fresh/);
  assert.deepEqual(s.warnings, []);
});

void test("settlement preserves other entries and intervenes only once, resetting for the next run", async (t) => {
  const s = await setup(t);
  await s.tool();
  const prior = { type: "custom", customType: "another-extension", data: 1 };
  const result = await s.settle({ entries: [prior] });
  assert.equal(result.continue, true);
  assert.deepEqual(result.entries[0], prior);
  assert.match(result.entries[1].content, /Arm one now/);
  assert.equal(await s.settle(), undefined);
  await s.emit("before_agent_start");
  assert.equal((await s.settle()).continue, true);
  await s.emit("before_agent_start");
  for (const state of ["MERGED", "CLOSED"]) {
    process.env.GH_TEST_STATE = state;
    assert.equal(await s.settle(), undefined);
    assert.equal(await readFile(join(s.state, "prs"), "utf8"), "");
  }
});

void test("settlement respects aborts, errors, prior continuations, and unavailable continuation", async (t) => {
  const s = await setup(t);
  await s.tool();
  for (const overrides of [
    { outcome: "aborted" },
    { outcome: "error" },
    { continue: true },
    { context: { canContinue: false } },
  ])
    assert.equal(await s.settle(overrides), undefined);
  process.env.GH_TEST_FAIL = "1";
  assert.equal(await s.settle(), undefined);
  assert.match(await readFile(join(s.state, "prs"), "utf8"), /42/);
  delete process.env.GH_TEST_FAIL;
  assert.equal((await s.settle()).continue, true);
});

void test("live snapshots must belong to this Pi session; ignored PRs stay ignored", async (t) => {
  const s = await setup(t);
  const cacheDir = join(s.dir, "cache/gh-pr/acme/widgets/feature%2Ftest");
  await mkdir(cacheDir, { recursive: true });
  const snapshot = join(cacheDir, "42.json");
  async function cache(
    watcher: object,
    fetched_at = Math.floor(Date.now() / 1000),
  ) {
    await writeFile(
      snapshot,
      JSON.stringify({ watcher, fetched_at, interval: 60 }),
    );
  }
  await cache({ pi_session: "test-session" });
  await s.tool();
  assert.equal(s.messages.length, 0);
  assert.equal(await s.settle(), undefined);
  await cache({ claude_session: "test-session" });
  await s.tool();
  assert.equal(s.messages.length, 1);
  await cache({ pi_session: "other-session" });
  await s.tool();
  assert.equal(s.messages.length, 2);
  await cache({ pi_session: "test-session" }, 1);
  await s.tool();
  assert.equal(s.messages.length, 3);
  const ignored = spawnSync(
    sharedHook,
    ["--agent", "pi", "ignore", "-R", "acme/widgets", "42"],
    {
      env: { ...process.env, PI_SESSION_ID: "test-session" },
      encoding: "utf8",
    },
  );
  assert.equal(ignored.status, 0, ignored.stderr);
  assert.match(ignored.stdout, /not nudging/);
  await s.tool();
  assert.equal(s.messages.length, 3);
  assert.equal(await s.settle(), undefined);
});

void test("parallel tool results serialize session file updates and Monitor arming", async (t) => {
  const s = await setup(t);
  await Promise.all(
    Array.from({ length: 5 }, (_, i) =>
      s.tool("bash", "gh pr create", {
        content: [
          {
            type: "text",
            text: `https://github.com/acme/widgets/pull/${42 + i}`,
          },
        ],
      }),
    ),
  );
  const prs = (await readFile(join(s.state, "prs"), "utf8")).trim().split("\n");
  assert.equal(new Set(prs).size, 5);
  const results = await Promise.all([
    s.tool("Monitor", "gh-pr-watch -R acme/widgets 42"),
    s.tool("bash", "git push"),
  ]);
  assert.deepEqual(results, [undefined, undefined]);
  assert.equal(s.messages.length, 5);
});

void test("failed, unrelated, short-lived, and Monitor-disabled calls do not invoke hooks", async (t) => {
  const s = await setup(t);
  await s.tool("bash", "gh pr create", { isError: true });
  await s.tool("Monitor", "gh-pr-watch -R acme/widgets 42", { isError: true });
  await s.tool("bash", "ls");
  await s.tool("read", "gh pr create");
  await s.tool("Monitor", "tail -f app.log");
  for (const mode of ["print", "json"]) {
    (s.ctx as any).mode = mode;
    await s.tool();
    assert.equal(await s.settle(), undefined);
  }
  (s.ctx as any).mode = "tui";
  s.setTools([]);
  await s.tool();
  assert.equal(await s.settle(), undefined);
  assert.equal(existsSync(s.state), false);
  assert.equal(existsSync(join(s.dir, "gh.log")), false);
  assert.deepEqual(s.messages, []);
});

void test("Claude's default protocol, ignore, and stop guard remain unchanged", async (t) => {
  const s = await setup(t);
  const input = {
    session_id: "test-session",
    cwd: s.dir,
    tool_name: "Bash",
    tool_input: { command: "gh pr create" },
    tool_response: { stdout: url },
  };
  const result = s.shell(["post-tool-use"], input);
  assert.match(
    result.hookSpecificOutput.additionalContext,
    /gh-pr-watch-hook ignore/,
  );
  assert.doesNotMatch(
    result.hookSpecificOutput.additionalContext,
    /--agent pi/,
  );
  const state = join(s.dir, "state/gh-pr-watch-hook/test-session");
  assert.ok(existsSync(join(state, "prs")));
  assert.equal(
    s.shell(["stop"], { session_id: "test-session", stop_hook_active: true }),
    undefined,
  );
  assert.equal(
    s.shell(["stop"], { session_id: "test-session" }).decision,
    "block",
  );
  const ignored = spawnSync(
    sharedHook,
    ["ignore", "-R", "acme/widgets", "42"],
    {
      env: { ...process.env, CLAUDE_CODE_SESSION_ID: "test-session" },
      encoding: "utf8",
    },
  );
  assert.equal(ignored.status, 0, ignored.stderr);
  assert.ok(existsSync(join(state, "ignored/acme-widgets-42")));
  assert.equal(s.shell(["post-tool-use"], input), undefined);
});

void test("hook failures are visible but do not alter results or force continuations", async (t) => {
  const s = await setup(t);
  await rm(s.hook);
  await s.tool();
  assert.equal(s.messages.length, 0);
  assert.match(s.warnings[0]!, /gh-pr-watch hook failed/);
  assert.equal(await s.settle(), undefined);
  await writeFile(s.hook, "#!/bin/sh\nprintf 'not json'\n", { mode: 0o755 });
  await s.tool();
  assert.match(s.warnings.at(-1)!, /SyntaxError/);
  assert.equal(s.messages.length, 0);
});

void test("shutdown and session replacement cancel pending hooks without leaking context", async (t) => {
  const s = await setup(t);
  await rm(s.hook);
  const ready = join(s.dir, "ready");
  await writeFile(
    s.hook,
    `#!/usr/bin/env node
require('node:fs').writeFileSync(${JSON.stringify(ready)}, 'ready');
setTimeout(() => console.log(JSON.stringify({hookSpecificOutput: {additionalContext: 'old session'}})), 10000);
`,
    { mode: 0o755 },
  );
  for (const event of ["session_start", "session_shutdown"]) {
    await rm(ready, { force: true });
    const pending = s.tool();
    const queued = s.tool();
    const deadline = Date.now() + 3000;
    while (!existsSync(ready)) {
      assert.ok(Date.now() < deadline, "hook did not start");
      await new Promise((resolve) => setTimeout(resolve, 10));
    }
    await s.emit(event);
    await Promise.all([pending, queued]);
    assert.deepEqual(s.messages, []);
    assert.deepEqual(s.warnings, []);
  }
});

void test("installed Pi host discovers the extension without runtime dependencies", async (t) => {
  const version = await readFile(
    join(installedAgent, "install/current-version"),
    "utf8",
  ).catch(() => "");
  const host =
    process.env.PI_GH_PR_WATCH_TEST_PI_PACKAGE ??
    join(
      installedAgent,
      "install/releases",
      version.trim(),
      "node_modules/@earendil-works/pi-coding-agent",
    );
  const loader = join(host, "dist/core/extensions/loader.js");
  if (!existsSync(loader)) {
    t.skip(
      "Pi host not installed; set PI_GH_PR_WATCH_TEST_PI_PACKAGE to its package directory",
    );
    return;
  }
  const { loadExtensions } = await import(pathToFileURL(loader).href);
  const loaded = await loadExtensions(
    [join(root, "pi/.pi/agent/extensions/gh-pr-watch/index.ts")],
    root,
  );
  assert.deepEqual(loaded.errors, []);
  assert.equal(loaded.extensions.length, 1);
  assert.ok(loaded.extensions[0].handlers.has("tool_result"));
  assert.ok(loaded.extensions[0].handlers.has("agent_before_settle"));
});
