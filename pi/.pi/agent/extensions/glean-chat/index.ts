/**
 * glean-chat — pi coding agent extension
 *
 * Three surfaces:
 *
 *   1. glean_chat tool  — LLM-callable; consults Glean mid-task.
 *                         Threads conversations via chatId across tool calls.
 *
 *   2. /glean command   — interactive query with no LLM round-trip.
 *                         Answer injected as a displayed session message.
 *                         /glean --new <question> resets the thread.
 *
 *   3. glean model      — "glean / Glean Assistant" selectable via /model.
 *                         Streams via ND-JSON (stream: true). No tool calling,
 *                         no system prompt, no usage data. Disable with
 *                         GLEAN_ENABLE_MODEL_SURFACE=0.
 *
 * Required env vars:
 *   GLEAN_BACKEND_URL  — e.g. https://mycompany-be.glean.com
 *                        (or set GLEAN_INSTANCE as fallback)
 *   GLEAN_INSTANCE     — instance name, e.g. "mycompany"
 *
 * Token: store via /login glean (persisted as glean.key in
 * ~/.pi/agent/auth.json), or export GLEAN_API_TOKEN.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
  type Api,
  type AssistantMessage,
  type AssistantMessageEventStream,
  type Context,
  createAssistantMessageEventStream,
  type Model,
  type SimpleStreamOptions,
} from "@earendil-works/pi-ai";
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

// ── Model surface (provider) ──────────────────────────────────────────────────
//
// Registers `glean / Glean Assistant` as a selectable pi model. Routes the
// conversation through Glean Chat (/rest/api/v1/chat, stream: true, ND-JSON).
//
// Limitations (inherent to the Glean Chat API):
//   - No tool calling: Glean never emits toolUse; agentic loop is unavailable.
//   - System prompt, tool schemas, and tool results are stripped from context.
//   - No token usage data; cost stays zero.

/** Resolve the Glean backend base URL from env, normalized (no trailing /). */
function resolveGleanBaseUrl(): string | undefined {
  let url = process.env.GLEAN_BACKEND_URL;
  if (!url && process.env.GLEAN_INSTANCE)
    url = `https://${process.env.GLEAN_INSTANCE}-be.glean.com`;
  if (!url) return undefined;
  url = url.replace(/\/+$/, "");
  url = url.replace(/\/rest\/api\/v1$/, "");
  return url;
}

interface RawSourceDocument {
  title?: string;
  url?: string;
}
interface RawFragment {
  text?: string;
  citation?: { sourceDocument?: RawSourceDocument };
}
interface RawGleanMessage {
  author?: string;
  messageId?: string;
  messageType?: string;
  fragments?: RawFragment[];
  citations?: { sourceDocument?: RawSourceDocument }[];
}
interface RawGleanChatResponse {
  messages?: RawGleanMessage[];
}

/**
 * Map pi Context → Glean ChatMessage[].
 * Only user/assistant text survives; system prompt and tool traffic dropped.
 * Consecutive same-author messages are merged (Glean expects alternation).
 * Returned array is ordered MOST RECENT FIRST — the Glean Chat API contract
 * is "a list of chat messages, from most recent to least recent".
 */
function buildGleanMessages(context: Context): {
  author: "USER" | "GLEAN_AI";
  messageType: "CONTENT";
  fragments: { text: string }[];
}[] {
  const out: {
    author: "USER" | "GLEAN_AI";
    messageType: "CONTENT";
    fragments: { text: string }[];
  }[] = [];

  function push(author: "USER" | "GLEAN_AI", text: string) {
    if (!text.trim()) return;
    const last = out[out.length - 1];
    if (last && last.author === author) {
      last.fragments.push({ text: "\n\n" + text });
    } else {
      out.push({ author, messageType: "CONTENT", fragments: [{ text }] });
    }
  }

  for (const msg of context.messages) {
    if (msg.role === "user") {
      const text =
        typeof msg.content === "string"
          ? msg.content
          : msg.content
              .filter((c) => c.type === "text")
              .map((c) => (c as { text: string }).text)
              .join("\n");
      push("USER", text);
    } else if (msg.role === "assistant") {
      const text = msg.content
        .filter((c) => c.type === "text")
        .map((c) => (c as { text: string }).text)
        .join("\n");
      push("GLEAN_AI", text);
    }
    // toolResult messages are dropped — Glean has no tool concept.
  }

  // Glean expects a USER-authored current question. Chronologically that is
  // the last message; ensure it exists, then reverse to most-recent-first.
  if (!out.length || out[out.length - 1].author !== "USER")
    push("USER", "(continue)");

  return out.reverse();
}

function streamGlean(
  model: Model<Api>,
  context: Context,
  options?: SimpleStreamOptions,
): AssistantMessageEventStream {
  const stream = createAssistantMessageEventStream();

  (async () => {
    const output: AssistantMessage = {
      role: "assistant",
      content: [],
      api: model.api,
      provider: model.provider,
      model: model.id,
      usage: {
        input: 0,
        output: 0,
        cacheRead: 0,
        cacheWrite: 0,
        totalTokens: 0,
        cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 },
      },
      stopReason: "stop",
      timestamp: Date.now(),
    };

    // Block state: Glean streams fragments as per-token deltas scoped to a
    // messageId; a change of messageId marks a new message. Thinking blocks
    // hold UPDATE/HEADING progress; one text block accumulates all CONTENT.
    let thinkingIndex = -1;
    let textIndex = -1;
    let thinkingMsgId: string | undefined;
    let textMsgId: string | undefined;
    const citations = new Map<string, string>(); // url -> title

    function collectCitations(msg: RawGleanMessage) {
      for (const frag of msg.fragments ?? []) {
        const doc = frag.citation?.sourceDocument;
        if (doc?.url && !citations.has(doc.url))
          citations.set(doc.url, doc.title ?? doc.url);
      }
      for (const cit of msg.citations ?? []) {
        const doc = cit.sourceDocument;
        if (doc?.url && !citations.has(doc.url))
          citations.set(doc.url, doc.title ?? doc.url);
      }
    }

    function endThinking() {
      if (thinkingIndex < 0) return;
      const block = output.content[thinkingIndex];
      if (block.type === "thinking") {
        stream.push({
          type: "thinking_end",
          contentIndex: thinkingIndex,
          content: block.thinking,
          partial: output,
        });
      }
      thinkingIndex = -1;
      thinkingMsgId = undefined;
    }

    function pushThinkingDelta(delta: string) {
      if (!delta) return;
      endText(); // keep blocks in chronological order when interleaved
      if (thinkingIndex < 0) {
        output.content.push({ type: "thinking", thinking: "" });
        thinkingIndex = output.content.length - 1;
        stream.push({
          type: "thinking_start",
          contentIndex: thinkingIndex,
          partial: output,
        });
      }
      const block = output.content[thinkingIndex];
      if (block.type === "thinking") block.thinking += delta;
      stream.push({
        type: "thinking_delta",
        contentIndex: thinkingIndex,
        delta,
        partial: output,
      });
    }

    function pushTextDelta(delta: string) {
      if (!delta) return;
      endThinking();
      if (textIndex < 0) {
        output.content.push({ type: "text", text: "" });
        textIndex = output.content.length - 1;
        stream.push({
          type: "text_start",
          contentIndex: textIndex,
          partial: output,
        });
      }
      const block = output.content[textIndex];
      if (block.type === "text") block.text += delta;
      stream.push({
        type: "text_delta",
        contentIndex: textIndex,
        delta,
        partial: output,
      });
    }

    function endText() {
      if (textIndex < 0) return;
      const block = output.content[textIndex];
      if (block.type === "text") {
        stream.push({
          type: "text_end",
          contentIndex: textIndex,
          content: block.text,
          partial: output,
        });
      }
      textIndex = -1;
    }

    function processLine(line: string) {
      let parsed: RawGleanChatResponse;
      try {
        parsed = JSON.parse(line) as RawGleanChatResponse;
      } catch {
        return; // tolerate keep-alives / non-JSON lines
      }
      for (const msg of parsed.messages ?? []) {
        if (msg.author === "USER") continue;
        collectCitations(msg);
        const mt = msg.messageType ?? "CONTENT";
        const text = (msg.fragments ?? []).map((f) => f.text ?? "").join("");
        if (mt === "ERROR") {
          throw new Error(text || "Glean returned an error message");
        } else if (mt === "UPDATE" || mt === "HEADING") {
          if (!text) continue;
          // New message (or first): separate from previous thinking content.
          const isNew =
            thinkingIndex < 0 ||
            (msg.messageId !== undefined && msg.messageId !== thinkingMsgId);
          pushThinkingDelta(isNew && thinkingIndex >= 0 ? "\n" + text : text);
          if (msg.messageId !== undefined) thinkingMsgId = msg.messageId;
        } else if (mt === "CONTENT") {
          if (!text) continue;
          // New CONTENT message: paragraph break from previous content.
          const isNew =
            textIndex >= 0 &&
            msg.messageId !== undefined &&
            msg.messageId !== textMsgId;
          pushTextDelta(isNew ? "\n\n" + text : text);
          if (msg.messageId !== undefined) textMsgId = msg.messageId;
        }
        // CONTROL_*, DEBUG*, WARNING, CONTEXT, SERVER_TOOL — ignored
      }
    }

    try {
      stream.push({ type: "start", partial: output });

      const token = options?.apiKey ?? resolveGleanToken();
      if (!token)
        throw new Error(
          "No Glean API token. Set GLEAN_API_TOKEN or store glean.key in ~/.pi/agent/auth.json",
        );

      const baseUrl = (model.baseUrl ?? resolveGleanBaseUrl() ?? "").replace(
        /\/+$/,
        "",
      );
      if (!baseUrl)
        throw new Error(
          "No Glean backend URL. Set GLEAN_BACKEND_URL or GLEAN_INSTANCE",
        );

      const response = await fetch(`${baseUrl}/rest/api/v1/chat`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({
          messages: buildGleanMessages(context),
          stream: true,
        }),
        signal: options?.signal ?? null,
      });

      if (!response.ok) {
        const body = await response.text().catch(() => "");
        const hint =
          response.status === 401
            ? " (check GLEAN_API_TOKEN is a valid Client token with CHAT scope)"
            : "";
        throw new Error(
          `Glean API error ${response.status}${hint}: ${body.slice(0, 500)}`,
        );
      }
      if (!response.body) throw new Error("Glean API returned no body");

      // ND-JSON: one ChatResponse per line.
      const reader = response.body.getReader();
      const decoder = new TextDecoder();
      let buffer = "";
      for (;;) {
        const { done, value } = await reader.read();
        if (done) break;
        buffer += decoder.decode(value, { stream: true });
        let nl: number;
        while ((nl = buffer.indexOf("\n")) >= 0) {
          const line = buffer.slice(0, nl).trim();
          buffer = buffer.slice(nl + 1);
          if (line) processLine(line);
        }
      }
      buffer += decoder.decode();
      if (buffer.trim()) processLine(buffer.trim());

      endThinking();

      // Append citations as a trailing Sources block.
      if (citations.size) {
        const sources =
          "\n\n**Sources:**\n" +
          [...citations.entries()]
            .map(([url, title]) => `- [${title}](${url})`)
            .join("\n");
        pushTextDelta(sources);
      }
      endText();

      if (!output.content.length)
        output.content.push({ type: "text", text: "(no response)" });

      stream.push({ type: "done", reason: "stop", message: output });
      stream.end();
    } catch (error) {
      endThinking();
      endText();
      output.stopReason = options?.signal?.aborted ? "aborted" : "error";
      output.errorMessage =
        error instanceof Error ? error.message : String(error);
      stream.push({
        type: "error",
        reason: output.stopReason as "aborted" | "error",
        error: output,
      });
      stream.end();
    }
  })();

  return stream;
}

// ── Extension entry point ─────────────────────────────────────────────────────

export default function (pi: ExtensionAPI) {
  // Model surface: glean / Glean Assistant. Registered only when a backend
  // URL is configured; disable explicitly with GLEAN_ENABLE_MODEL_SURFACE=0.
  const modelBaseUrl = resolveGleanBaseUrl();
  if (process.env.GLEAN_ENABLE_MODEL_SURFACE !== "0" && modelBaseUrl) {
    pi.registerProvider("glean", {
      name: "Glean",
      baseUrl: modelBaseUrl,
      apiKey: "$GLEAN_API_TOKEN",
      api: "glean-chat" as Api,
      models: [
        {
          id: "glean-assistant",
          name: "Glean Assistant",
          reasoning: false,
          input: ["text"],
          cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
          contextWindow: 128000,
          maxTokens: 8192,
        },
      ],
      streamSimple: streamGlean,
    });
  }

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
          details: {},
          isError: true,
        };
      }

      if (params.new_conversation) state.chatId = undefined;

      onUpdate?.({
        content: [{ type: "text", text: "Querying Glean..." }],
        details: {},
      });

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
          details: {},
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
