/**
 * Agent Pane Status
 *
 * Publishes this session's model, thinking level, repo/branch, context usage,
 * and session token counts to the surrounding workspace manager's pane
 * decoration - tmux pane borders and the herdr sidebar - so a window full of
 * agent panes is legible at a glance instead of every border reading "node".
 *
 * The rendering and the writes live in ~/.local/bin/agent-status, shared with
 * the claude status line, so both agents produce identical decorations. This
 * extension only feeds it a JSON envelope on stdin.
 *
 * Inert outside a managed pane and outside the TUI: without $TMUX_PANE or
 * $HERDR_PANE_ID there is no pane to annotate, and `pi --print` / rpc runs have
 * nothing to draw on.
 */

import { execFile } from "node:child_process";
import { homedir } from "node:os";
import { join } from "node:path";
import type { Usage } from "@earendil-works/pi-ai";
import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";

const WRITER = join(homedir(), ".local", "bin", "agent-status");

// Streaming turns emit a message_end per tool round-trip. Throttling those keeps
// the decoration fresh mid-turn without one subprocess per message; state changes
// (model, thinking level, session, turn boundaries) always publish immediately.
const THROTTLE_MS = 800;

type Totals = {
  input: number;
  output: number;
  cacheRead: number;
  cacheWrite: number;
};

function emptyTotals(): Totals {
  return { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 };
}

function add(totals: Totals, usage: Usage | undefined): void {
  if (!usage) return;
  totals.input += usage.input ?? 0;
  totals.output += usage.output ?? 0;
  totals.cacheRead += usage.cacheRead ?? 0;
  totals.cacheWrite += usage.cacheWrite ?? 0;
}

export default function agentPaneStatusExtension(pi: ExtensionAPI) {
  // Session totals rather than the last response: per-turn numbers on a border
  // read as if they described the session, which is the one thing they don't.
  let totals = emptyTotals();
  let lastPublish = 0;
  let timer: NodeJS.Timeout | undefined;

  // agent-status decides which transports to write; this only checks whether
  // any pane exists to annotate, so the common case costs no subprocess.
  function enabled(ctx: ExtensionContext): boolean {
    const managed =
      Boolean(process.env.TMUX && process.env.TMUX_PANE) ||
      Boolean(process.env.HERDR_PANE_ID);
    return managed && ctx.mode === "tui";
  }

  // Fire-and-forget: a missing writer or a transport hiccup must never surface
  // in the session, so failures are swallowed rather than notified.
  function run(args: string[], stdin?: string): void {
    const child = execFile(WRITER, args, () => {});
    child.on("error", () => {});
    if (stdin !== undefined) {
      child.stdin?.on("error", () => {});
      child.stdin?.end(stdin);
    }
  }

  function publishNow(ctx: ExtensionContext): void {
    if (!enabled(ctx)) return;
    lastPublish = Date.now();

    const contextUsage = ctx.getContextUsage();
    // All-zero totals (a session before its first response) are dropped by
    // tmux-agent-status, so they need no special case here.
    const envelope = {
      agent: "pi",
      model: ctx.model?.id ?? null,
      effort: ctx.thinkingLevel ?? null,
      cwd: ctx.cwd,
      ctx_pct: contextUsage?.percent ?? null,
      input: totals.input,
      output: totals.output,
      cache_read: totals.cacheRead,
      cache_write: totals.cacheWrite,
    };

    run([], JSON.stringify(envelope));
  }

  function publish(ctx: ExtensionContext): void {
    if (timer) {
      clearTimeout(timer);
      timer = undefined;
    }
    publishNow(ctx);
  }

  function publishThrottled(ctx: ExtensionContext): void {
    if (!enabled(ctx)) return;
    const elapsed = Date.now() - lastPublish;
    if (elapsed >= THROTTLE_MS) {
      publish(ctx);
      return;
    }
    // Trailing edge, so the final state of a burst is always the one displayed.
    if (timer) return;
    timer = setTimeout(() => {
      timer = undefined;
      publishNow(ctx);
    }, THROTTLE_MS - elapsed);
    timer.unref?.();
  }

  // Seeded from the session's existing entries, so `pi --continue` and /resume
  // report what the session has spent overall instead of restarting at zero.
  // session_start also fires after /new and /fork, hence the reset first.
  pi.on("session_start", async (_event, ctx) => {
    totals = emptyTotals();
    for (const entry of ctx.sessionManager.getEntries()) {
      const record = entry as { message?: { usage?: Usage }; usage?: Usage };
      // Compaction and branch-summary entries carry usage at the top level;
      // their summarization work is real spend and counts.
      add(totals, record.message?.usage ?? record.usage);
    }
    publish(ctx);
  });

  pi.on("model_select", async (_event, ctx) => publish(ctx));
  pi.on("thinking_level_select", async (_event, ctx) => publish(ctx));
  pi.on("turn_end", async (_event, ctx) => publish(ctx));
  pi.on("agent_settled", async (_event, ctx) => publish(ctx));

  pi.on("message_end", async (event, ctx) => {
    if (event.message.role === "assistant") {
      add(totals, event.message.usage);
    }
    publishThrottled(ctx);
  });

  // Idempotent: also fires on /new, /resume and /fork, where session_start
  // republishes straight after.
  pi.on("session_shutdown", async (_event, ctx) => {
    if (timer) {
      clearTimeout(timer);
      timer = undefined;
    }
    if (!enabled(ctx)) return;
    run(["--clear"]);
  });
}
