import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { parseHTML } from "linkedom";
import { fetchPageContent } from "./fetch.js";

/** Strip fragment and normalize trailing slash so the same page isn't visited twice. */
export function normalizeUrl(rawUrl: string): string {
  try {
    const u = new URL(rawUrl);
    u.hash = "";
    // collapse duplicate slashes in path
    u.pathname = u.pathname.replace(/\/+/g, "/");
    return u.toString();
  } catch {
    return rawUrl;
  }
}

/** Extract all absolute HTTP(S) links from an HTML string relative to baseUrl. */
export function extractLinks(html: string, baseUrl: string): string[] {
  const { document } = parseHTML(html);
  const links: string[] = [];
  const anchors = document.querySelectorAll("a[href]");
  for (const a of anchors) {
    const href = (a as Element).getAttribute("href");
    if (!href || href.startsWith("javascript:") || href.startsWith("mailto:"))
      continue;
    try {
      const resolved = new URL(href, baseUrl);
      if (resolved.protocol === "http:" || resolved.protocol === "https:") {
        links.push(resolved.toString());
      }
    } catch {
      // ignore malformed hrefs
    }
  }
  return links;
}

/** Parse robots.txt for a given origin. Returns disallowed path prefixes for * and pi-agent. */
export async function fetchDisallowed(
  origin: string,
  signal?: AbortSignal,
): Promise<string[]> {
  const disallowed: string[] = [];
  try {
    const resp = await fetch(`${origin}/robots.txt`, {
      signal,
      headers: { "User-Agent": "Mozilla/5.0 (compatible; pi-agent/1.0)" },
    });
    if (!resp.ok) return disallowed;
    const text = await resp.text();
    let applicable = false;
    for (const raw of text.split("\n")) {
      const line = raw.trim();
      if (line.startsWith("User-agent:")) {
        const agent = line.slice("User-agent:".length).trim();
        applicable = agent === "*" || agent.toLowerCase().includes("pi-agent");
      } else if (applicable && line.startsWith("Disallow:")) {
        const path = line.slice("Disallow:".length).trim();
        if (path) disallowed.push(path);
      }
    }
  } catch {
    // robots.txt is optional
  }
  return disallowed;
}

export function robotsAllows(pathname: string, disallowed: string[]): boolean {
  return !disallowed.some((prefix) => pathname.startsWith(prefix));
}

export function registerCrawlTool(pi: ExtensionAPI) {
  pi.registerTool({
    name: "crawl",
    label: "Crawl",
    description:
      "Recursively crawl a website starting from a seed URL. Follows links within the same " +
      "domain (or a path prefix) and returns clean Markdown for each page. " +
      "Respects robots.txt by default. Uses plain HTTP — JS-rendered pages may be incomplete.",
    promptSnippet:
      "Crawl a website and return clean Markdown for each discovered page",
    promptGuidelines: [
      "Use crawl when the user wants to index, summarize, or read an entire site or section.",
      "Use crawl with path_prefix to restrict crawling to a docs subdirectory, e.g. /docs.",
      "Prefer fetch for single pages; use crawl only when multiple pages are needed.",
    ],
    parameters: Type.Object({
      url: Type.String({ description: "Seed URL to start crawling from" }),
      max_pages: Type.Optional(
        Type.Number({
          description: "Maximum pages to crawl. Default: 20.",
          minimum: 1,
          maximum: 200,
        }),
      ),
      max_depth: Type.Optional(
        Type.Number({
          description: "Maximum link depth from seed. Default: 3.",
          minimum: 1,
        }),
      ),
      path_prefix: Type.Optional(
        Type.String({
          description:
            "Only follow links whose path starts with this prefix, e.g. /docs",
        }),
      ),
      exclude: Type.Optional(
        Type.Array(Type.String(), {
          description:
            'Skip URLs containing any of these substrings, e.g. ["/tag/", "/author/"]',
        }),
      ),
      concurrency: Type.Optional(
        Type.Number({
          description: "Parallel fetches per batch. Default: 3.",
          minimum: 1,
          maximum: 10,
        }),
      ),
      delay_ms: Type.Optional(
        Type.Number({
          description:
            "Delay in ms between batches for politeness. Default: 300.",
          minimum: 0,
        }),
      ),
      ignore_robots: Type.Optional(
        Type.Boolean({
          description: "Skip robots.txt checks. Default: false.",
        }),
      ),
      output: Type.Optional(
        Type.Union([Type.Literal("markdown"), Type.Literal("json")], {
          description:
            "Output format. markdown: pages joined with separators. json: array of page objects. Default: markdown.",
        }),
      ),
      browser: Type.Optional(
        Type.Boolean({
          description:
            "Use headless Chromium to render each page. Required for JS-rendered sites (SPAs, React, Vue, etc.). " +
            "Significantly slower than plain HTTP. Default: false.",
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
              "load: all resources loaded (default). " +
              "domcontentloaded: HTML parsed only. " +
              "networkidle: no pending requests for 500ms (most complete, slowest).",
          },
        ),
      ),
    }),

    async execute(_toolCallId, params, signal, onUpdate) {
      const maxPages = params.max_pages ?? 20;
      const maxDepth = params.max_depth ?? 3;
      const concurrency = params.concurrency ?? 3;
      const delayMs = params.delay_ms ?? 300;
      const excludes = params.exclude ?? [];
      const outputFmt = params.output ?? "markdown";
      const ignoreRobots = params.ignore_robots ?? false;

      const seed = normalizeUrl(params.url);
      const seedOrigin = new URL(seed).origin;
      const pathPrefix = params.path_prefix ?? null;

      // Fetch robots.txt once for the seed origin
      const disallowed = ignoreRobots
        ? []
        : await fetchDisallowed(seedOrigin, signal);

      const visited = new Set<string>([seed]);
      // Queue entries: [url, depth]
      const queue: Array<[string, number]> = [[seed, 0]];

      interface CrawledPage {
        url: string;
        title: string | null;
        depth: number;
        markdown: string;
        links: number;
      }

      const pages: CrawledPage[] = [];

      /** Decide whether a candidate URL should be enqueued. */
      function shouldVisit(candidate: string, depth: number): boolean {
        if (depth >= maxDepth) return false;
        if (visited.has(candidate)) return false;
        try {
          const u = new URL(candidate);
          if (u.origin !== seedOrigin) return false;
          if (pathPrefix && !u.pathname.startsWith(pathPrefix)) return false;
          if (excludes.some((ex) => candidate.includes(ex))) return false;
          if (!ignoreRobots && !robotsAllows(u.pathname, disallowed))
            return false;
        } catch {
          return false;
        }
        return true;
      }

      while (queue.length > 0 && pages.length < maxPages && !signal?.aborted) {
        // Take the next batch
        const batch = queue.splice(0, concurrency);

        // Fetch all pages in the batch in parallel
        const results = await Promise.all(
          batch.map(async ([url, depth]) => {
            onUpdate?.({
              content: [
                {
                  type: "text",
                  text: `[${pages.length + 1}/${maxPages}] ${url}`,
                },
              ],
              details: { crawled: pages.length, queued: queue.length },
            });
            const { markdown, title, html } = await fetchPageContent(
              url,
              signal,
              {
                browser: params.browser,
                waitUntil:
                  params.wait_until ?? (params.browser ? "load" : undefined),
              },
            );
            const links: string[] = [];
            if (html) {
              for (const raw of extractLinks(html, url)) {
                const norm = normalizeUrl(raw);
                if (shouldVisit(norm, depth + 1) && !visited.has(norm)) {
                  visited.add(norm);
                  links.push(norm);
                }
              }
            }
            return { url, title, depth, markdown, links };
          }),
        );

        for (const { url, title, depth, markdown, links } of results) {
          if (markdown) {
            pages.push({ url, title, depth, markdown, links: links.length });
          }
          // Enqueue discovered links (only if we still have budget)
          for (const link of links) {
            if (pages.length + queue.length < maxPages) {
              queue.push([link, depth + 1]);
            }
          }
        }

        // Polite delay between batches
        if (queue.length > 0 && delayMs > 0 && !signal?.aborted) {
          await new Promise((resolve) => setTimeout(resolve, delayMs));
        }
      }

      if (pages.length === 0) {
        throw new Error(`crawl returned no content from ${params.url}`);
      }

      let output: string;
      if (outputFmt === "json") {
        output = JSON.stringify(
          pages.map(({ url, title, depth, markdown, links }) => ({
            url,
            title,
            depth,
            markdown,
            links,
          })),
          null,
          2,
        );
      } else {
        output = pages
          .map(
            ({ url, title, depth, markdown }) =>
              `<!-- url: ${url} | depth: ${depth} | title: ${title ?? "(no title)"} -->\n\n${markdown}`,
          )
          .join("\n\n---\n\n");
      }

      return {
        content: [{ type: "text", text: output }],
        details: {
          seed: params.url,
          pages_crawled: pages.length,
          max_pages: maxPages,
          truncated: pages.length >= maxPages,
        },
      };
    },
  });
}
