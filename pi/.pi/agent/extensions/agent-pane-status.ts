/**
 * Agent Pane Status
 *
 * Publishes the pull request for this session's branch - number, draft/merged
 * state, CI rollup and review decision - to the herdr sidebar, so a pane whose
 * PR is waiting on checks or review says so beside the agent.
 *
 * The PR lookup and the writes live in ~/.local/bin/agent-status, shared with
 * the claude status line, so both agents produce identical sidebar rows. This
 * extension only feeds it a JSON envelope on stdin; agent-status caches the `gh`
 * lookup, so publishing on every turn costs a network call at most once a
 * minute.
 *
 * Inert outside a herdr pane and outside the TUI: without $HERDR_PANE_ID there
 * is no pane to annotate, and `pi --print` / rpc runs have nothing to draw on.
 */

import { execFile } from "node:child_process";
import { homedir } from "node:os";
import { join } from "node:path";
import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";

const WRITER = join(homedir(), ".local", "bin", "agent-status");

export default function agentPaneStatusExtension(pi: ExtensionAPI) {
  // agent-status decides what to write; this only checks whether a pane exists
  // to annotate, so the common case costs no subprocess.
  function enabled(ctx: ExtensionContext): boolean {
    return Boolean(process.env.HERDR_PANE_ID) && ctx.mode === "tui";
  }

  // Fire-and-forget: a missing writer, a slow `gh` or a transport hiccup must
  // never surface in the session, so failures are swallowed rather than notified.
  function run(args: string[], stdin?: string): void {
    const child = execFile(WRITER, args, () => {});
    child.on("error", () => {});
    if (stdin !== undefined) {
      child.stdin?.on("error", () => {});
      child.stdin?.end(stdin);
    }
  }

  function publish(ctx: ExtensionContext): void {
    if (!enabled(ctx)) return;
    run([], JSON.stringify({ agent: "pi", cwd: ctx.cwd }));
  }

  // Turn boundaries are where a branch gets pushed or a PR opened, so they are
  // where the PR is worth re-checking. session_start also fires after /new,
  // /resume and /fork.
  pi.on("session_start", async (_event, ctx) => publish(ctx));
  pi.on("turn_end", async (_event, ctx) => publish(ctx));
  pi.on("agent_settled", async (_event, ctx) => publish(ctx));

  // Idempotent: also fires on /new, /resume and /fork, where session_start
  // republishes straight after.
  pi.on("session_shutdown", async (_event, ctx) => {
    if (!enabled(ctx)) return;
    run(["--clear"]);
  });
}
