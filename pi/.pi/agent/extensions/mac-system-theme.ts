/**
 * Auto-toggles pi theme between dark/light based on macOS system appearance.
 * Polls every 2s and switches only when the appearance actually changes.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

async function getSystemTheme(pi: ExtensionAPI): Promise<"dark" | "light"> {
  try {
    const result = await pi.exec("osascript", [
      "-e",
      'tell application "System Events" to tell appearance preferences to return dark mode',
    ]);
    return result.stdout.trim() === "true" ? "dark" : "light";
  } catch {
    return "dark";
  }
}

export default function (pi: ExtensionAPI) {
  let intervalId: ReturnType<typeof setInterval> | null = null;

  function stopPolling() {
    if (intervalId !== null) {
      clearInterval(intervalId);
      intervalId = null;
    }
  }

  pi.on("session_start", async (_event, ctx) => {
    // Clear any stale interval from a previous session (fork/new/reload).
    stopPolling();

    let current = await getSystemTheme(pi);
    ctx.ui.setTheme(current);

    intervalId = setInterval(async () => {
      const next = await getSystemTheme(pi);
      if (next !== current) {
        current = next;
        ctx.ui.setTheme(current);
      }
    }, 2000);
  });

  pi.on("session_shutdown", () => {
    stopPolling();
  });
}
