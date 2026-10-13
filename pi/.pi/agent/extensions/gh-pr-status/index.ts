import { execFile } from "node:child_process";
import { promisify } from "node:util";
import type {
  ExtensionAPI,
  ExtensionContext,
  Theme,
} from "@earendil-works/pi-coding-agent";
import {
  hyperlink,
  truncateToWidth,
  type Component,
} from "@earendil-works/pi-tui";
import {
  cacheDirectory,
  MAX_PRS,
  readSnapshots,
  type Snapshot,
} from "./cache.ts";
import {
  formatWatchActionMessage,
  WatchActionQueue,
  type WatchActionTask,
} from "./automation.ts";
import { WatchManager } from "./watch.ts";

const gitExec = promisify(execFile);
const WIDGET = "gh-pr-status";
const REFRESH_MS = 30_000;
const icons = {
  pass: "\uf42e",
  fail: "\uf467",
  pending: "\uf43a",
  approved: "\uf49e",
  changes: "\uf4d2",
  required: "\uf441",
  threads: "\uf442",
  draft: "\uf4dd",
  stale: "\uf46a",
  copilot: "\uf4b8",
  copilotWarn: "\uf4ba",
};

type RepoInfo = { slug?: string; branch?: string };

async function git(cwd: string, ...args: string[]): Promise<string> {
  try {
    const { stdout } = await gitExec(
      "git",
      ["--no-optional-locks", "-C", cwd, ...args],
      {
        timeout: 2000,
      },
    );
    return stdout.trim();
  } catch {
    return "";
  }
}

async function repoInfo(cwd: string): Promise<RepoInfo> {
  const [branch, remote] = await Promise.all([
    git(cwd, "branch", "--show-current"),
    git(cwd, "remote", "get-url", "origin"),
  ]);
  // Only an unambiguous GitHub origin can be used for the repo/branch fallback.
  const slug =
    /^(?:https:\/\/github\.com\/|git@github\.com:|ssh:\/\/git@github\.com\/)([^/\s]+\/[^/\s]+?)(?:\.git)?\/?$/.exec(
      remote,
    )?.[1];
  return { slug, branch: branch || undefined };
}

function separator(theme: Theme): string {
  return ` ${theme.fg("dim", "·")} `;
}

function prRow(pr: Snapshot, theme: Theme, now: number): string {
  const dim = (text: string) => theme.fg("dim", text);
  const green = (text: string) => theme.fg("success", text);
  const orange = (text: string) => theme.fg("warning", text);
  const red = (text: string) => theme.fg("error", text);
  const parts = [
    `${hyperlink(theme.bold(`#${pr.number}`), pr.url)} ${pr.repo.split("/")[1]}${pr.state === "draft" ? ` ${dim(icons.draft)}` : ""}`,
  ];
  if (pr.ci === "fail") parts.push(red(`${icons.fail} ${pr.ciCounts.fail}`));
  else if (pr.ci === "pending")
    parts.push(orange(`${icons.pending} ${pr.ciCounts.pending}`));
  else if (pr.ci === "pass") parts.push(green(icons.pass));

  if (pr.review === "changes") parts.push(red(icons.changes));
  else if (pr.review === "review") parts.push(orange(icons.required));
  else if (pr.review === "approved") parts.push(green(icons.approved));
  if (pr.threads > 0)
    parts.push(
      (pr.threads > 4 ? red : orange)(`${icons.threads} ${pr.threads}`),
    );
  if (pr.copilot) {
    const color = !pr.copilot.head
      ? dim
      : pr.copilot.verdict === "approve"
        ? green
        : pr.copilot.verdict === "changes"
          ? orange
          : (text: string) => theme.fg("accent", text);
    parts.push(
      hyperlink(
        color(
          pr.copilot.verdict === "changes" ? icons.copilotWarn : icons.copilot,
        ),
        pr.copilot.url,
      ),
    );
  }
  if (now - pr.fetchedAt > Math.max(3 * pr.interval, 60))
    parts.push(dim(icons.stale));
  return parts.join(separator(theme));
}

export default function ghPrStatus(pi: ExtensionAPI) {
  const watches = new WatchManager();
  let timer: ReturnType<typeof setInterval> | undefined;
  let generation = 0;
  let requestRender: (() => void) | undefined;
  let snapshots: Snapshot[] = [];
  let info: RepoInfo = {};
  let actionContext: ExtensionContext | undefined;
  let actionInFlight = false;
  const pendingActions: WatchActionTask[] = [];

  function dispatchNextAction() {
    const ctx = actionContext;
    if (!ctx || actionInFlight || pendingActions.length === 0) return;
    const task = pendingActions.shift()!;
    const message = formatWatchActionMessage(task);
    actionInFlight = true;
    try {
      pi.sendUserMessage(
        message,
        ctx.isIdle() ? undefined : { deliverAs: "followUp" },
      );
      const prs = task.groups.map((group) => group.label).join(", ");
      ctx.ui.notify(
        `watch-pr: agent queued ${task.eventCount} actionable event(s) for ${prs}`,
        "info",
      );
    } catch (error) {
      actionInFlight = false;
      ctx.ui.notify(
        `watch-pr: could not start agent task: ${error instanceof Error ? error.message : String(error)}`,
        "error",
      );
      dispatchNextAction();
    }
  }

  const actionQueue = new WatchActionQueue((task) => {
    pendingActions.push(task);
    dispatchNextAction();
  });

  function stop(ctx?: ExtensionContext) {
    generation++;
    if (timer) clearInterval(timer);
    timer = undefined;
    requestRender = undefined;
    snapshots = [];
    actionQueue.cancel();
    pendingActions.length = 0;
    actionInFlight = false;
    actionContext = undefined;
    if (ctx?.mode === "tui") ctx.ui.setWidget(WIDGET, undefined);
  }

  pi.registerCommand("watch-pr", {
    description:
      "Watch a PR; automatically investigate CI failures and review feedback",
    handler: async (args, ctx) => {
      if (ctx.mode !== "tui") return;
      try {
        await watches.start(
          args,
          ctx.cwd,
          ctx.sessionManager.getSessionId(),
          (message, level) => {
            ctx.ui.notify(message, level);
          },
          (message) => actionQueue.enqueue(message),
        );
      } catch (error) {
        ctx.ui.notify(
          `watch-pr: ${error instanceof Error ? error.message : String(error)}`,
          "error",
        );
      }
    },
  });

  pi.on("session_start", async (_event, ctx) => {
    stop(ctx);
    await watches.stopAll();
    if (ctx.mode !== "tui") return;
    actionContext = ctx;
    const current = generation;
    const session = ctx.sessionManager.getSessionId();
    info = {};
    ctx.ui.setWidget(
      WIDGET,
      (tui, theme): Component => {
        requestRender = () => tui.requestRender();
        return {
          invalidate() {},
          render(width: number): string[] {
            if (width <= 0) return [];
            const now = Date.now() / 1000;
            const rows = snapshots
              .slice(0, MAX_PRS)
              .map((pr) => prRow(pr, theme, now));
            if (snapshots.length > MAX_PRS)
              rows.push(theme.fg("dim", `+${snapshots.length - MAX_PRS} more`));
            return rows.map((row) => truncateToWidth(row, width, "…"));
          },
        };
      },
      { placement: "belowEditor" },
    );

    info = await repoInfo(ctx.cwd);
    if (generation !== current) return;
    let refreshing = false;
    const refresh = async () => {
      if (refreshing) return;
      refreshing = true;
      try {
        const loaded = await readSnapshots(
          cacheDirectory(),
          session,
          info.slug,
          info.branch,
          Date.now() / 1000,
          watches.getWatchedPRs(),
        );
        if (generation !== current) return;
        snapshots = loaded;
        requestRender?.();
      } finally {
        refreshing = false;
      }
    };
    await refresh();
    if (generation === current)
      timer = setInterval(() => {
        void refresh();
      }, REFRESH_MS);
  });

  pi.on("agent_end", () => requestRender?.());
  pi.on("agent_settled", () => {
    actionInFlight = false;
    dispatchNextAction();
    requestRender?.();
  });
  pi.on("session_shutdown", async (_event, ctx) => {
    stop(ctx);
    await watches.stopAll();
  });
}
