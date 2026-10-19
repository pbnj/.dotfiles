/** Publishes minimal Pi TUI lifecycle metadata for the SketchyBar indicator. */
import { mkdirSync, renameSync, unlinkSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";

type PiState = "idle" | "working" | "blocked";

type TrackedSession = {
  ctx: ExtensionContext;
  directory: string;
  file: string;
  startedAt: number;
  agentActive: boolean;
  blockingPrompts: number;
  heartbeat?: ReturnType<typeof setInterval>;
  exitHandler?: () => void;
};

const HEARTBEAT_MS = 60_000;

function currentState(session: TrackedSession): PiState {
  if (session.blockingPrompts > 0) return "blocked";
  return session.agentActive ? "working" : "idle";
}

export default function sketchybarStatusExtension(pi: ExtensionAPI) {
  let session: TrackedSession | undefined;

  function stopSession(): void {
    const previous = session;
    session = undefined;
    if (!previous) return;

    if (previous.heartbeat) clearInterval(previous.heartbeat);
    if (previous.exitHandler)
      process.removeListener("exit", previous.exitHandler);
    try {
      unlinkSync(previous.file);
    } catch {
      // The status file may already have been removed by SketchyBar.
    }
  }

  function publish(ctx?: ExtensionContext): void {
    if (!session) return;
    if (ctx) session.ctx = ctx;

    const tmuxSocket = process.env.TMUX?.split(",")[0];
    const tmuxPane = process.env.TMUX_PANE;
    const status = {
      pid: process.pid,
      state: currentState(session),
      startedAt: session.startedAt,
      updatedAt: Date.now(),
      sessionId: session.ctx.sessionManager.getSessionId(),
      sessionName: session.ctx.sessionManager.getSessionName(),
      cwd: session.ctx.cwd,
      tmux:
        tmuxSocket && tmuxPane
          ? { socket: tmuxSocket, pane: tmuxPane }
          : undefined,
    };
    const temporaryFile = `${session.file}.tmp`;

    try {
      mkdirSync(session.directory, { recursive: true, mode: 0o700 });
      writeFileSync(temporaryFile, `${JSON.stringify(status)}\n`, {
        mode: 0o600,
      });
      renameSync(temporaryFile, session.file);
    } catch {
      try {
        unlinkSync(temporaryFile);
      } catch {
        // Ignore a missing or unwriteable temporary file.
      }
    }
  }

  pi.on("session_start", (_event, ctx) => {
    stopSession();
    if (ctx.mode !== "tui") return;

    const directory =
      process.env.PI_SKETCHYBAR_SESSION_DIR ||
      join(homedir(), ".cache", "pi-sketchybar", "sessions");
    const tracked: TrackedSession = {
      ctx,
      directory,
      file: join(directory, `${process.pid}.json`),
      startedAt: Date.now(),
      agentActive: false,
      blockingPrompts: 0,
    };
    session = tracked;
    const exitHandler = () => stopSession();
    tracked.exitHandler = exitHandler;
    process.once("exit", exitHandler);
    tracked.heartbeat = setInterval(() => publish(), HEARTBEAT_MS);
    tracked.heartbeat.unref?.();
    publish(ctx);
  });

  // before_agent_start includes work Pi does before the first model call; keep
  // the indicator active until agent_settled, after retries and queued turns.
  pi.on("before_agent_start", (_event, ctx) => {
    if (!session) return;
    session.agentActive = true;
    publish(ctx);
  });
  pi.on("agent_start", (_event, ctx) => {
    if (!session) return;
    session.agentActive = true;
    publish(ctx);
  });
  pi.on("agent_settled", (_event, ctx) => {
    if (!session) return;
    session.agentActive = false;
    publish(ctx);
  });

  // A blocking extension prompt (for example, a tool approval) is distinct
  // from Pi's ordinary idle editor, which remains an idle session.
  pi.on("ui_prompt_start", (_event, ctx) => {
    if (!session) return;
    session.blockingPrompts++;
    publish(ctx);
  });
  pi.on("ui_prompt_end", (_event, ctx) => {
    if (!session) return;
    session.blockingPrompts = Math.max(0, session.blockingPrompts - 1);
    publish(ctx);
  });

  pi.on("session_info_changed", (_event, ctx) => publish(ctx));
  pi.on("session_shutdown", stopSession);
}
