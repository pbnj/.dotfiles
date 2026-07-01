/**
 * glean-chat — pi coding agent extension
 *
 * Two surfaces:
 *
 *   1. glean_chat tool  — LLM-callable; consults Glean mid-task.
 *                         Threads conversations via chatId across tool calls.
 *
 *   2. /glean command   — interactive query with no LLM round-trip.
 *                         Answer injected as a displayed session message.
 *                         /glean --new <question> resets the thread.
 *
 * Required env vars:
 *   GLEAN_API_TOKEN    — Glean Client API token (Bearer)
 *   GLEAN_BACKEND_URL  — e.g. https://mycompany-be.glean.com
 *                        (or set GLEAN_INSTANCE as fallback)
 *   GLEAN_INSTANCE     — instance name, e.g. "mycompany"
 *
 * Recommended: launch pi with `op run -- pi` so 1Password resolves
 * GLEAN_API_TOKEN at runtime without exposing the raw token in your env.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { Type } from "typebox";
import { Glean } from "@gleanwork/api-client";
import type { ChatMessage } from "@gleanwork/api-client/models/components";

// ── Client ────────────────────────────────────────────────────────────────────

/**
 * Resolve the Glean API token with the following precedence:
 *   1. Explicit argument (passed by the caller)
 *   2. GLEAN_API_TOKEN env var
 *   3. ~/.pi/agent/auth.json  glean.key  (if stored in local pi auth)
 */
function resolveGleanToken(explicit?: string): string {
  if (explicit) return explicit;
  if (process.env.GLEAN_API_TOKEN) return process.env.GLEAN_API_TOKEN;
  try {
    const authPath = join(homedir(), ".pi", "agent", "auth.json");
    const auth = JSON.parse(readFileSync(authPath, "utf-8")) as Record<
      string,
      unknown
    >;
    const glean = auth?.glean as Record<string, unknown> | undefined;
    if (
      glean?.type === "api_key" &&
      typeof glean?.key === "string" &&
      glean.key
    )
      return glean.key;
  } catch {
    // auth.json absent or unreadable — fall through
  }
  return "";
}

function makeClient(apiToken?: string): Glean {
  const token = resolveGleanToken(apiToken);
  const serverURL = process.env.GLEAN_BACKEND_URL;
  const instance = process.env.GLEAN_INSTANCE;
  return new Glean({
    apiToken: token,
    ...(serverURL ? { serverURL } : instance ? { instance } : {}),
  });
}

// Lazily created; reset on session_start so token/URL changes after /reload
// are picked up.
let _client: Glean | undefined;

function getClient(): Glean {
  return (_client ??= makeClient());
}

// ── Session state ─────────────────────────────────────────────────────────────

interface GleanState {
  chatId?: string; // tool + /glean command thread
}

let state: GleanState = {};

const STATE_ENTRY_TYPE = "glean-chat-state" as const;

// ── Response helpers ──────────────────────────────────────────────────────────

/**
 * Extract the last GLEAN_AI turn's text from a Glean messages array.
 * Joins all text fragments in the last non-USER message.
 */
function extractAiText(messages: ChatMessage[]): string {
  const aiMsgs = messages.filter((m) => m.author !== "USER");
  if (!aiMsgs.length) return "";
  const last = aiMsgs[aiMsgs.length - 1];
  return (last.fragments ?? []).map((f) => f.text ?? "").join("");
}

/**
 * Build a deduplicated markdown citations block.
 * Citations live on fragment.citation.sourceDocument (inline, current API)
 * and on the deprecated top-level message.citations array.
 */
function formatCitations(messages: ChatMessage[]): string {
  const seen = new Set<string>();
  const lines: string[] = [];

  function add(title: string | undefined, url: string | undefined) {
    if (url && !seen.has(url)) {
      seen.add(url);
      lines.push(`- [${title ?? url}](${url})`);
    }
  }

  for (const msg of messages) {
    // Inline citations (current API): fragment.citation.sourceDocument
    for (const frag of msg.fragments ?? []) {
      const doc = frag.citation?.sourceDocument;
      if (doc) add(doc.title, doc.url);
    }
    // Deprecated top-level citations (still populated for back-compat)
    for (const cit of msg.citations ?? []) {
      const doc = cit.sourceDocument;
      if (doc) add(doc.title, doc.url);
    }
  }

  return lines.length ? "\n\n**Sources:**\n" + lines.join("\n") : "";
}

// ── Extension entry point ─────────────────────────────────────────────────────

export default function (pi: ExtensionAPI) {
  // Restore conversation state from session; reset client so token/URL
  // changes take effect after /reload.
  pi.on("session_start", async (_event, ctx) => {
    _client = undefined;
    state = { chatId: undefined };
    for (const entry of ctx.sessionManager.getEntries()) {
      if (
        entry.type === "custom" &&
        (entry as any).customType === STATE_ENTRY_TYPE
      ) {
        Object.assign(state, (entry as any).data ?? {});
      }
    }
  });

  // ── Tool: glean_chat ────────────────────────────────────────────────────────

  pi.registerTool({
    name: "glean_chat",
    label: "Glean Chat",
    description:
      "Query Glean AI for internal company knowledge: documentation, runbooks, " +
      "policies, ADRs, Jira tickets, Confluence pages, Slack discussions, and " +
      "anything else indexed in Glean. Conversations are threaded — follow-up " +
      "calls continue the same chat session unless new_conversation is true.",
    promptSnippet:
      "Query Glean AI for internal company knowledge and documentation",
    promptGuidelines: [
      "Use glean_chat for questions about internal company docs, runbooks, " +
        "policies, ADRs, Jira tickets, Confluence pages, or internal processes.",
      "Use glean_chat when the user asks what the wiki or internal docs say " +
        "about a topic, or when you need company-specific context not available " +
        "in your training data.",
    ],
    parameters: Type.Object({
      message: Type.String({
        description: "The question to ask Glean AI.",
      }),
      new_conversation: Type.Optional(
        Type.Boolean({
          description:
            "Start a fresh conversation thread (clears chatId). Default false.",
        }),
      ),
    }),

    async execute(_toolCallId, params, _signal, onUpdate) {
      const token = resolveGleanToken();
      if (!token) {
        return {
          content: [
            {
              type: "text",
              text:
                "GLEAN_API_TOKEN is not set. " +
                "Launch pi with `op run -- pi` or export the token, " +
                "or store a glean.key in ~/.pi/agent/auth.json.",
            },
          ],
          isError: true,
        };
      }

      if (params.new_conversation) state.chatId = undefined;

      onUpdate?.({ content: [{ type: "text", text: "Querying Glean..." }] });

      try {
        const response = await getClient().client.chat.create(
          {
            messages: [
              { author: "USER", fragments: [{ text: params.message }] },
            ],
            ...(state.chatId ? { chatId: state.chatId } : {}),
          },
          undefined, // locale
          undefined, // timezoneOffset
        );

        if (response.chatId) {
          state.chatId = response.chatId;
          pi.appendEntry(STATE_ENTRY_TYPE, { chatId: response.chatId });
        }

        const messages = response.messages ?? [];
        const text = extractAiText(messages);
        const citations = formatCitations(messages);

        return {
          content: [
            { type: "text", text: text + citations || "(no response)" },
          ],
          details: {
            chatId: response.chatId,
            followUpPrompts: response.followUpPrompts ?? [],
          },
        };
      } catch (err: any) {
        const status: number | undefined = err?.statusCode;
        const message: string = err?.message ?? String(err);
        const hint =
          status === 401
            ? " Check that GLEAN_API_TOKEN is a valid Client token."
            : status === 429
              ? " Rate limited — retry shortly."
              : "";
        return {
          content: [
            {
              type: "text",
              text: `Glean error${status ? ` (${status})` : ""}: ${message}${hint}`,
            },
          ],
          isError: true,
        };
      }
    },
  });

  // ── Command: /glean ─────────────────────────────────────────────────────────

  pi.registerCommand("glean", {
    description:
      "Query Glean AI. Usage: /glean <question>  |  /glean --new <question>",
    handler: async (args, ctx) => {
      const raw = args?.trim() ?? "";
      if (!raw) {
        ctx.ui.notify(
          "Usage: /glean <question>  |  /glean --new <question>",
          "info",
        );
        return;
      }

      let message = raw;
      let forceNew = false;
      if (message.startsWith("--new ")) {
        forceNew = true;
        message = message.slice(6).trim();
      }
      if (!message) {
        ctx.ui.notify("Provide a question after /glean [--new]", "info");
        return;
      }

      const token = resolveGleanToken();
      if (!token) {
        ctx.ui.notify(
          "GLEAN_API_TOKEN is not set (no env var or auth.json key)",
          "error",
        );
        return;
      }

      if (forceNew) state.chatId = undefined;

      ctx.ui.setStatus("glean", "Querying Glean...");
      try {
        const response = await getClient().client.chat.create(
          {
            messages: [{ author: "USER", fragments: [{ text: message }] }],
            ...(state.chatId ? { chatId: state.chatId } : {}),
          },
          undefined, // locale
          undefined, // timezoneOffset
        );

        if (response.chatId) {
          state.chatId = response.chatId;
          pi.appendEntry(STATE_ENTRY_TYPE, { chatId: response.chatId });
        }

        const messages = response.messages ?? [];
        const text = extractAiText(messages);
        const citations = formatCitations(messages);
        const fullText = text + citations || "(no response)";

        // Inject the answer as a displayed session message so the LLM
        // (and the user in the conversation view) can read it.
        pi.sendMessage(
          {
            customType: "glean-response",
            content: `**Glean answer to:** ${message}\n\n${fullText}`,
            display: true,
          },
          { triggerTurn: false },
        );
      } catch (err: any) {
        ctx.ui.notify(
          `Glean error: ${(err?.message as string) ?? String(err)}`,
          "error",
        );
      } finally {
        ctx.ui.setStatus("glean", "");
      }
    },
  });
}
