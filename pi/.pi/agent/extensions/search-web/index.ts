/**
 * search-web extension
 *
 * Registers three tools:
 *
 *   search  - searches via a local SearXNG instance with automatic
 *             fallback to DuckDuckGo. Returns titles, URLs, and
 *             snippets. Call fetch on individual results for full
 *             page content.
 *
 *   fetch   - fetches a single URL and returns clean Markdown using
 *             the Readability (Firefox Reader Mode) algorithm.
 *             Pass browser: true for JS-rendered pages.
 *
 *   crawl   - recursively crawls a website starting from a seed URL,
 *             following links within the same domain. Returns clean
 *             Markdown for each page. Respects robots.txt by default.
 *             Pass browser: true for JS-rendered sites.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { browserManager } from "./browser.js";
import { registerSearchTool } from "./tools/search.js";
import { registerFetchTool } from "./tools/fetch.js";
import { registerCrawlTool } from "./tools/crawl.js";

export default function searchExtension(pi: ExtensionAPI) {
  pi.on("session_shutdown", async () => {
    await browserManager.shutdown();
  });

  registerSearchTool(pi);
  registerFetchTool(pi);
  registerCrawlTool(pi);
}
