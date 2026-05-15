import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Text, getKeybindings } from "@earendil-works/pi-tui";
import { Type } from "typebox";
import { Readability } from "@mozilla/readability";
import { parseHTML } from "linkedom";
import TurndownService from "turndown";
import { browserManager } from "../browser.js";

// Shared TurndownService instance — strip noisy elements before conversion
const td = new TurndownService({
  headingStyle: "atx",
  codeBlockStyle: "fenced",
  bulletListMarker: "-",
});
td.remove(["script", "style", "noscript", "iframe"]);

export type WaitUntil = "load" | "domcontentloaded" | "networkidle";

export interface FetchOptions {
  browser?: boolean;
  waitUntil?: WaitUntil;
}

/**
 * Convert raw HTML into clean Markdown via Readability + Turndown.
 * Shared by both the plain-fetch and browser paths.
 */
export function htmlToMarkdown(
  html: string,
  browserTitle?: string | null,
): { markdown: string; title: string | null } {
  const { document } = parseHTML(html);
  const reader = new Readability(document as unknown as Document);
  const article = reader.parse();

  const title = browserTitle ?? article?.title ?? null;

  let markdown: string;
  if (article?.content) {
    markdown = td.turndown(article.content);
    if (title) markdown = `# ${title}\n\n${markdown}`;
  } else {
    markdown = td.turndown(html);
  }

  return { markdown: markdown.trim(), title };
}

/**
 * Fetch a URL and convert to clean Markdown using Readability.
 *
 * When options.browser is true, a headless Chromium instance renders
 * the page so JS-generated content is included. Falls back to plain
 * HTTP fetch otherwise.
 *
 * Returns empty strings on any unrecoverable error so callers can
 * skip the page rather than aborting an entire crawl.
 */
export async function fetchPageContent(
  url: string,
  signal?: AbortSignal,
  options: FetchOptions = {},
): Promise<{ markdown: string; title: string | null; html: string | null }> {
  // ── browser path ──────────────────────────────────────────────────────────
  if (options.browser) {
    const { html, title: browserTitle } = await browserManager.fetchPage(url, {
      signal,
      waitUntil: options.waitUntil ?? "networkidle",
    });
    if (!html) return { markdown: "", title: null, html: null };
    const { markdown, title } = htmlToMarkdown(html, browserTitle);
    return { markdown, title, html };
  }

  // ── plain fetch path ──────────────────────────────────────────────────────
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 10000);

  signal?.addEventListener("abort", () => controller.abort());

  try {
    const resp = await fetch(url, {
      signal: controller.signal,
      headers: {
        "User-Agent": "Mozilla/5.0 (compatible; pi-agent/1.0)",
        Accept:
          "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
      },
    });

    if (!resp.ok) return { markdown: "", title: null, html: null };

    const contentType = resp.headers.get("content-type") ?? "";
    if (contentType.includes("application/json")) {
      return { markdown: await resp.text(), title: null, html: null };
    }

    const html = await resp.text();
    const { markdown, title } = htmlToMarkdown(html);
    return { markdown, title, html };
  } catch {
    return { markdown: "", title: null, html: null };
  } finally {
    clearTimeout(timer);
  }
}

export function registerFetchTool(pi: ExtensionAPI) {
  pi.registerTool({
    name: "fetch",
    label: "Fetch",
    description:
      "Fetch a URL and return its content as clean Markdown. " +
      "Uses Readability (Firefox Reader Mode algorithm) to extract the main " +
      "article content and strips nav, footers, ads, and boilerplate.",
    promptSnippet: "Fetch a URL and return clean Markdown content",
    promptGuidelines: [
      "Use fetch when the user provides a URL and wants to understand its content.",
      "Use fetch when you need to read documentation, articles, or web pages.",
      "Do NOT use fetch if the user wants raw HTML — use bash + curl instead.",
      "Do NOT use fetch for JSON APIs — use bash + curl with Accept: application/json.",
    ],
    parameters: Type.Object({
      url: Type.String({ description: "The URL to fetch" }),
      browser: Type.Optional(
        Type.Boolean({
          description:
            "Use headless Chromium to render the page. Required for JS-rendered pages " +
            "(SPAs, React, Vue, Angular, etc.). Default: false.",
        }),
      ),
      wait_until: Type.Optional(
        Type.Union(
          [
            Type.Literal("load"),
            Type.Literal("domcontentloaded"),
            Type.Literal("networkidle"),
          ],
          {
            description:
              "Browser only. When to consider navigation complete. " +
              "load: all resources loaded. " +
              "domcontentloaded: HTML parsed only. " +
              "networkidle: no pending requests for 500ms (default when browser: true).",
          },
        ),
      ),
    }),

    async execute(_toolCallId, params, signal, onUpdate, _ctx) {
      const mode = params.browser ? "headless browser" : "HTTP fetch";
      onUpdate?.({
        content: [
          { type: "text", text: `Fetching ${params.url} (${mode})...` },
        ],
        details: {},
      });

      const { markdown, title } = await fetchPageContent(params.url, signal, {
        browser: params.browser,
        waitUntil: params.wait_until,
      });

      if (!markdown) {
        throw new Error(`fetch returned empty content for: ${params.url}`);
      }

      return {
        content: [{ type: "text", text: markdown }],
        details: { url: params.url, title, browser: params.browser ?? false },
      };
    },

    renderResult(result, { expanded }, theme, context) {
      const raw = result.content
        .filter((c: any) => c.type === "text")
        .map((c: any) => c.text as string)
        .join("");
      const lines = raw.split("\n");
      const maxLines = expanded ? lines.length : 10;
      const displayLines = lines.slice(0, maxLines);
      const remaining = lines.length - maxLines;

      let text = `\n${displayLines.map((line) => theme.fg("toolOutput", line)).join("\n")}`;
      if (remaining > 0) {
        const keys = getKeybindings().getKeys("app.tools.expand").join("/");
        text +=
          theme.fg("muted", `\n... (${remaining} more lines,`) +
          " " +
          theme.fg("dim", keys) +
          theme.fg("muted", " to expand)");
      }

      const component = context.lastComponent ?? new Text("", 0, 0);
      (component as Text).setText(text);
      return component;
    },
  });
}
