/**
 * BrowserManager — lazy Chromium singleton with stealth patching.
 *
 * One browser process per session, shared across all fetch/crawl calls that
 * pass browser: true. The first such call triggers a launch; subsequent calls
 * reuse the same process. shutdown() must be called on session_shutdown.
 *
 * Concurrency is bounded by a semaphore so at most `poolSize` pages are open
 * simultaneously. Each page runs in an isolated BrowserContext (separate
 * cookies, storage, and network state) so crawl requests don't bleed state
 * into one another.
 */

import { chromium } from "playwright-extra";
import StealthPlugin from "puppeteer-extra-plugin-stealth";
import type { Browser } from "playwright-core";

// Apply stealth patches to the chromium launcher once at module load.
// This patches navigator.webdriver, window.chrome, canvas fingerprint, etc.
chromium.use(StealthPlugin());

const PAGE_TIMEOUT_MS = 20_000;

// Realistic desktop UA — avoids the "HeadlessChrome" string that many sites block.
const USER_AGENT =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " +
  "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36";

// ── Semaphore ─────────────────────────────────────────────────────────────────

class Semaphore {
  private slots: number;
  private readonly queue: Array<() => void> = [];

  constructor(concurrency: number) {
    this.slots = concurrency;
  }

  acquire(): Promise<void> {
    if (this.slots > 0) {
      this.slots--;
      return Promise.resolve();
    }
    return new Promise<void>((resolve) => this.queue.push(resolve));
  }

  release(): void {
    const next = this.queue.shift();
    if (next) {
      next();
    } else {
      this.slots++;
    }
  }
}

// ── BrowserManager ────────────────────────────────────────────────────────────

export interface PageResult {
  html: string;
  title: string | null;
}

export type WaitUntil = "load" | "domcontentloaded" | "networkidle";

export interface FetchPageOptions {
  signal?: AbortSignal;
  /**
   * When to consider navigation complete.
   *   "load"            – all resources loaded (good default for most SPAs)
   *   "domcontentloaded"– HTML parsed only; JS may not have run yet
   *   "networkidle"     – no pending requests for 500ms (most complete, slowest)
   * Default: "load"
   */
  waitUntil?: WaitUntil;
}

export class BrowserManager {
  private browser: Browser | null = null;
  private launching: Promise<Browser> | null = null;
  private readonly semaphore: Semaphore;

  constructor(poolSize = 3) {
    this.semaphore = new Semaphore(poolSize);
  }

  private async getBrowser(): Promise<Browser> {
    if (this.browser) return this.browser;
    if (this.launching) return this.launching;

    this.launching = (
      chromium.launch({
        headless: true,
        args: [
          "--no-sandbox",
          "--disable-setuid-sandbox",
          "--disable-dev-shm-usage",
          "--disable-gpu",
          // Suppress certificate errors that would stall navigation
          "--ignore-certificate-errors",
        ],
      }) as Promise<Browser>
    ).then((b) => {
      this.browser = b;
      this.launching = null;
      // On crash / unexpected close, reset so the next call re-launches.
      b.on("disconnected", () => {
        this.browser = null;
        this.launching = null;
      });
      return b;
    });

    return this.launching;
  }

  /**
   * Navigate to `url` in an isolated context, wait for the page to settle,
   * then return the fully-rendered HTML and document title.
   *
   * The context is closed after the call regardless of success or failure.
   */
  async fetchPage(
    url: string,
    options: FetchPageOptions = {},
  ): Promise<PageResult> {
    const { signal, waitUntil = "load" } = options;

    // Block if we're already at max concurrency
    await this.semaphore.acquire();

    const browser = await this.getBrowser();
    const context = await browser.newContext({
      userAgent: USER_AGENT,
      javaScriptEnabled: true,
      ignoreHTTPSErrors: true,
      // Disable resource types that are irrelevant to content extraction and
      // add latency (media, fonts, images still needed for some SPAs though,
      // so we only block known noise).
      // Route blocking is handled per-page below.
    });

    const page = await context.newPage();

    // Block media and font requests — they add latency without aiding extraction.
    await page.route("**/*", (route) => {
      const type = route.request().resourceType();
      if (type === "media" || type === "font") {
        route.abort().catch(() => {});
      } else {
        route.continue().catch(() => {});
      }
    });

    // Wire the external abort signal: close the context immediately on cancel.
    const onAbort = () => {
      void context.close().catch(() => {});
    };
    signal?.addEventListener("abort", onAbort, { once: true });

    try {
      await page.goto(url, { waitUntil, timeout: PAGE_TIMEOUT_MS });
      const html = await page.content();
      const title = await page.title().catch(() => null);
      return { html, title: title || null };
    } catch (err) {
      if (signal?.aborted) return { html: "", title: null };
      // Timeout or navigation error — return empty so callers can skip the page
      // rather than crashing the whole crawl.
      const msg = err instanceof Error ? err.message : String(err);
      if (
        msg.includes("ERR_") ||
        msg.includes("net::") ||
        msg.includes("Timeout")
      ) {
        return { html: "", title: null };
      }
      throw err;
    } finally {
      signal?.removeEventListener("abort", onAbort);
      await context.close().catch(() => {});
      this.semaphore.release();
    }
  }

  /**
   * Close the browser process. Safe to call when the browser was never launched.
   */
  async shutdown(): Promise<void> {
    const b = this.browser;
    this.browser = null;
    this.launching = null;
    if (b) await b.close().catch(() => {});
  }
}

// One instance for the lifetime of the extension session.
export const browserManager = new BrowserManager();
