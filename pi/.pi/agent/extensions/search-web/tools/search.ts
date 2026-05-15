import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { search as ddgSearch, SafeSearchType } from "duck-duck-scrape";

const SEARXNG_DEFAULT_URL = "http://localhost:8888";
const SEARCH_TIMEOUT_MS = 5000;
const SAFESEARCH_STRICT = 2;

export interface SearchResult {
  title: string;
  href: string;
  body: string;
}

export async function searchSearXNG(
  query: string,
  baseUrl: string,
  num: number,
  region: string,
  page: number,
): Promise<SearchResult[]> {
  const params = new URLSearchParams({
    q: query,
    format: "json",
    language: region,
    safesearch: String(SAFESEARCH_STRICT),
    pageno: String(page),
  });

  const url = `${baseUrl.replace(/\/$/, "")}/search?${params}`;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), SEARCH_TIMEOUT_MS);

  try {
    const resp = await fetch(url, { signal: controller.signal });
    if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
    const data = (await resp.json()) as {
      results?: Array<{ title?: string; url?: string; content?: string }>;
    };
    return (data.results ?? []).slice(0, num).map((r) => ({
      title: r.title ?? "",
      href: r.url ?? "",
      body: r.content ?? "",
    }));
  } finally {
    clearTimeout(timer);
  }
}

export async function searchDDG(
  query: string,
  num: number,
  region: string,
  page: number,
): Promise<SearchResult[]> {
  const results = await ddgSearch(query, {
    safeSearch: SafeSearchType.STRICT,
    locale: region,
    offset: (page - 1) * num,
  });
  return results.results.slice(0, num).map((r) => ({
    title: r.title ?? "",
    href: r.url ?? "",
    body: r.description ?? "",
  }));
}

function renderMarkdown(results: SearchResult[]): string {
  return results
    .map((r, i) => {
      const parts: string[] = [];
      parts.push(`## ${i + 1}. [${r.title}](${r.href})`);
      if (r.body) parts.push(r.body);
      return parts.join("\n");
    })
    .join("\n\n");
}

export function registerSearchTool(pi: ExtensionAPI) {
  pi.registerTool({
    name: "search",
    label: "Search",
    description:
      "Search the web via a local SearXNG instance (http://localhost:8888) with automatic " +
      "fallback to DuckDuckGo. Optionally fetches full page content (static HTML only — " +
      "JS-rendered pages may be incomplete). Returns JSON by default.",
    promptSnippet:
      "Search the web via SearXNG (local) with DuckDuckGo fallback",
    promptGuidelines: [
      "Use search when the user asks to look something up, find documentation, check " +
        "latest news, or research any topic online — even if they say 'look up', 'find info " +
        "about', 'what is X', or 'latest news on'. Use proactively when you lack current knowledge.",
      "When you need the full content of a result, call fetch with its URL rather than " +
        "fetching all results at once.",
    ],
    parameters: Type.Object({
      query: Type.String({ description: "Search query" }),
      num: Type.Optional(
        Type.Number({
          description: "Number of results to return (1-50). Default: 10.",
          minimum: 1,
          maximum: 50,
        }),
      ),
      site: Type.Optional(
        Type.String({
          description: "Restrict results to this domain, e.g. github.com",
        }),
      ),
      region: Type.Optional(
        Type.String({
          description: "Geographic region code, e.g. wt-wt (default), us-en",
        }),
      ),
      page: Type.Optional(
        Type.Number({
          description: "Page number (1-indexed). Default: 1.",
          minimum: 1,
        }),
      ),
      output: Type.Optional(
        Type.Union([Type.Literal("json"), Type.Literal("markdown")], {
          description: "Output format: json (default) or markdown.",
        }),
      ),
      searxng_url: Type.Optional(
        Type.String({
          description: `Override SearXNG base URL. Defaults to SEARXNG_URL env var or ${SEARXNG_DEFAULT_URL}.`,
        }),
      ),
    }),

    async execute(_toolCallId, params, _signal, onUpdate) {
      const num = params.num ?? 10;
      const region = params.region ?? "wt-wt";
      const page = params.page ?? 1;
      const outputFmt = params.output ?? "json";
      const baseUrl =
        params.searxng_url ?? process.env.SEARXNG_URL ?? SEARXNG_DEFAULT_URL;

      let query = params.query;
      if (params.site) query = `site:${params.site} ${query}`;

      let results: SearchResult[] = [];
      let engine = "unknown";

      try {
        results = await searchSearXNG(query, baseUrl, num, region, page);
        engine = "SearXNG";
      } catch (err) {
        onUpdate?.({
          content: [
            {
              type: "text",
              text: `SearXNG unavailable (${(err as Error).message}), falling back to DuckDuckGo...`,
            },
          ],
          details: {},
        });
      }

      if (results.length === 0) {
        results = await searchDDG(query, num, region, page);
        engine = "DuckDuckGo";
      }

      const output =
        outputFmt === "markdown"
          ? renderMarkdown(results)
          : JSON.stringify(results, null, 2);

      return {
        content: [{ type: "text", text: output }],
        details: { engine, query, num: results.length },
      };
    },
  });
}
