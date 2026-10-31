import { execFile } from "node:child_process";
import { homedir } from "node:os";
import { join } from "node:path";
import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";

interface HookResult {
  hookSpecificOutput?: { additionalContext?: string };
  decision?: string;
  reason?: string;
}

/** Adapt the shared Claude hook protocol to Pi's native lifecycle events. */
export default function ghPrWatchExtension(pi: ExtensionAPI) {
  let lifetime = new AbortController();
  let pending = Promise.resolve();
  let stopBlocked = false;

  const enabled = (ctx: ExtensionContext) =>
    (ctx.mode === "tui" || ctx.mode === "rpc") &&
    pi.getActiveTools().includes("Monitor");

  function reset() {
    lifetime.abort();
    lifetime = new AbortController();
    pending = Promise.resolve();
    stopBlocked = false;
  }

  // Tool results can arrive in parallel, including nested codemode calls. The
  // shell hook updates per-session files, so serialize its read/modify/writes.
  function invoke(
    mode: "post-tool-use" | "stop",
    payload: Record<string, unknown>,
    ctx: ExtensionContext,
  ): Promise<HookResult | undefined> {
    const current = lifetime;
    const task = pending.then(async () => {
      if (current.signal.aborted || ctx.signal?.aborted) return;
      try {
        const stdout = await new Promise<string>((resolve, reject) => {
          const child = execFile(
            join(homedir(), ".local/bin/gh-pr-watch-hook"),
            ["--agent", "pi", mode],
            {
              cwd: ctx.cwd,
              env: {
                ...process.env,
                PI_SESSION_ID: ctx.sessionManager.getSessionId(),
              },
              signal: ctx.signal
                ? AbortSignal.any([current.signal, ctx.signal])
                : current.signal,
              timeout: mode === "stop" ? 30_000 : 15_000,
              maxBuffer: 256 * 1024,
              encoding: "utf8",
            },
            (error, output) => (error ? reject(error) : resolve(output)),
          );
          child.stdin?.on("error", () => {
            // An early exit is reported by execFile's callback, not EPIPE.
          });
          child.stdin?.end(
            JSON.stringify({
              ...payload,
              session_id: ctx.sessionManager.getSessionId(),
              cwd: ctx.cwd,
            }),
          );
        });
        if (current.signal.aborted || ctx.signal?.aborted) return;
        return stdout.trim() ? (JSON.parse(stdout) as HookResult) : undefined;
      } catch (error) {
        if (!current.signal.aborted && !ctx.signal?.aborted)
          ctx.ui.notify(`gh-pr-watch hook failed: ${String(error)}`, "warning");
        return undefined;
      }
    });
    pending = task.then(() => undefined);
    return task;
  }

  pi.on("session_start", reset);
  pi.on("session_shutdown", () => lifetime.abort());
  pi.on("before_agent_start", () => {
    // A boundary continuation does not fire before_agent_start. Allow only one
    // stop intervention per user/custom run, just like stop_hook_active.
    stopBlocked = false;
  });

  pi.on("tool_result", async (event, ctx) => {
    if (!enabled(ctx) || event.isError) return;
    const tool = event.toolName === "bash" ? "Bash" : event.toolName;
    if (
      tool !== "Bash" &&
      tool !== "Monitor" &&
      !/^mcp__.*create_pull_request$/.test(tool)
    )
      return;
    const command = String(event.input.command ?? "");
    if (tool === "Bash" && !/gh-pr-open|gh pr create|git.*push/.test(command))
      return;
    if (tool === "Monitor" && !command.includes("gh-pr-watch")) return;

    const result = await invoke(
      "post-tool-use",
      {
        tool_name: tool,
        tool_input: event.input,
        tool_response: {
          stdout: event.content
            .filter((block) => block.type === "text")
            .map((block) => block.text)
            .join("\n"),
          structuredContent: event.structuredContent,
          details: event.details,
        },
      },
      ctx,
    );
    const content = result?.hookSpecificOutput?.additionalContext;
    if (content) {
      // A custom context message survives codemode filtering of nested tool
      // results. Do not alter the tool's content, details, or structuredContent.
      // Pi defers this until the tool batch is complete to preserve ordering.
      pi.sendMessage(
        {
          customType: "gh-pr-watch-hook",
          content,
          display: false,
        },
        { triggerTurn: false },
      );
    }
  });

  pi.on("agent_before_settle", async (event, ctx) => {
    if (
      !enabled(ctx) ||
      stopBlocked ||
      event.continue ||
      event.outcome !== "completed" ||
      !event.context.canContinue
    )
      return;
    const result = await invoke("stop", { stop_hook_active: false }, ctx);
    if (result?.decision !== "block" || !result.reason) return;
    stopBlocked = true;
    return {
      entries: [
        ...event.entries,
        {
          type: "custom_message" as const,
          customType: "gh-pr-watch-hook",
          content: result.reason,
          display: false,
        },
      ],
      continue: true,
    };
  });
}
