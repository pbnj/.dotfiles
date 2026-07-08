/**
 * Unit tests for the glean-chat extension.
 *
 * Run: node --test
 * (Node >= 23.6 strips types natively; no build step.)
 *
 * Covers:
 *   - buildGleanMessages: ordering (most-recent-first), author mapping,
 *     merging, system prompt / tool traffic dropping, trailing-USER guarantee
 *   - streamGlean: ND-JSON parsing, per-messageId fragment reassembly,
 *     thinking/text block interleaving, citations, errors, abort
 *
 * The extension module is imported once; registerProvider is captured via a
 * stub ExtensionAPI. A mock Glean backend (node:http) serves canned ND-JSON.
 */
import assert from "node:assert/strict";
import { createServer, type Server } from "node:http";
import { after, before, beforeEach, describe, it } from "node:test";

// ── Test doubles ──────────────────────────────────────────────────────────────

type Captured = {
  providerName?: string;
  providerConfig?: any;
};

const captured: Captured = {};

const piStub = {
  registerProvider: (name: string, cfg: any) => {
    captured.providerName = name;
    captured.providerConfig = cfg;
  },
  registerTool: () => {},
  registerCommand: () => {},
  on: () => {},
  appendEntry: () => {},
  sendMessage: () => {},
} as any;

// Mock Glean backend. Each test sets `respond` to control the ND-JSON body.
let server: Server;
let baseUrl: string;
let respond: (req: {
  body: any;
  res: import("node:http").ServerResponse;
}) => void;
let lastRequestBody: any;

function gleanMsg(
  id: string,
  messageType: string,
  text?: string,
  extra?: Record<string, unknown>,
) {
  return {
    messages: [
      {
        author: "GLEAN_AI",
        messageId: id,
        messageType,
        ...(text !== undefined ? { fragments: [{ text }] } : {}),
        ...extra,
      },
    ],
  };
}

/** Default responder: write ND-JSON lines then end. */
function ndjsonResponder(lines: unknown[]) {
  return ({ res }: { body: any; res: import("node:http").ServerResponse }) => {
    res.writeHead(200, { "Content-Type": "text/plain" });
    for (const l of lines) res.write(JSON.stringify(l) + "\n");
    res.end();
  };
}

async function runStream(
  context: any,
  options: any = { apiKey: "test-token" },
) {
  const model = {
    id: "glean-assistant",
    api: "glean-chat",
    provider: "glean",
    baseUrl,
  };
  const stream = captured.providerConfig.streamSimple(model, context, options);
  const events: string[] = [];
  let final: any;
  let error: any;
  for await (const ev of stream) {
    events.push(ev.type);
    if (ev.type === "done") final = ev.message;
    if (ev.type === "error") error = ev.error;
  }
  return { events, final, error };
}

const userMsg = (text: string) => ({
  role: "user",
  content: text,
  timestamp: 0,
});
const assistantMsg = (text: string) => ({
  role: "assistant",
  content: [{ type: "text", text }],
  api: "glean-chat",
  provider: "glean",
  model: "glean-assistant",
  usage: {
    input: 0,
    output: 0,
    cacheRead: 0,
    cacheWrite: 0,
    totalTokens: 0,
    cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 },
  },
  stopReason: "stop",
  timestamp: 0,
});

// ── Setup ─────────────────────────────────────────────────────────────────────

before(async () => {
  server = createServer((req, res) => {
    let body = "";
    req.on("data", (c) => (body += c));
    req.on("end", () => {
      lastRequestBody = body ? JSON.parse(body) : undefined;
      respond({ body: lastRequestBody, res });
    });
  });
  await new Promise<void>((r) => server.listen(0, "127.0.0.1", r));
  const addr = server.address() as { port: number };
  baseUrl = `http://127.0.0.1:${addr.port}`;

  // Env must be set before import so the model surface registers.
  process.env.GLEAN_BACKEND_URL = baseUrl;
  process.env.GLEAN_API_TOKEN = "test-token";
  const ext = await import("./index.ts");
  ext.default(piStub);
});

after(() => server.close());

beforeEach(() => {
  lastRequestBody = undefined;
  respond = ndjsonResponder([gleanMsg("m1", "CONTENT", "ok")]);
});

// ── Provider registration ─────────────────────────────────────────────────────

describe("provider registration", () => {
  it("registers the glean provider with the glean-assistant model", () => {
    assert.equal(captured.providerName, "glean");
    assert.equal(captured.providerConfig.baseUrl, baseUrl);
    assert.deepEqual(
      captured.providerConfig.models.map((m: any) => m.id),
      ["glean-assistant"],
    );
    assert.equal(typeof captured.providerConfig.streamSimple, "function");
  });
});

// ── Request building ──────────────────────────────────────────────────────────

describe("request building", () => {
  it("orders messages most-recent-first with CONTENT type", async () => {
    await runStream({
      systemPrompt: "system prompt to drop",
      messages: [
        userMsg("hi"),
        assistantMsg("hi there"),
        userMsg("who are you?"),
      ],
    });
    const sent = lastRequestBody.messages;
    assert.equal(sent.length, 3);
    assert.deepEqual(
      sent.map((m: any) => [
        m.author,
        m.fragments.map((f: any) => f.text).join(""),
      ]),
      [
        ["USER", "who are you?"],
        ["GLEAN_AI", "hi there"],
        ["USER", "hi"],
      ],
    );
    for (const m of sent) assert.equal(m.messageType, "CONTENT");
    assert.equal(lastRequestBody.stream, true);
  });

  it("drops system prompt and tool traffic", async () => {
    await runStream({
      systemPrompt: "SYSTEM",
      messages: [
        userMsg("run a command"),
        {
          ...assistantMsg("running"),
          content: [
            { type: "text", text: "running" },
            { type: "toolCall", id: "t1", name: "bash", arguments: {} },
          ],
        },
        {
          role: "toolResult",
          toolCallId: "t1",
          toolName: "bash",
          content: [{ type: "text", text: "TOOL OUTPUT" }],
          isError: false,
          timestamp: 0,
        },
        userMsg("thanks"),
      ],
    });
    const all = JSON.stringify(lastRequestBody);
    assert.ok(!all.includes("SYSTEM"));
    assert.ok(!all.includes("TOOL OUTPUT"));
    assert.ok(!all.includes("toolCall"));
  });

  it("merges consecutive same-author messages", async () => {
    await runStream({
      messages: [userMsg("part one"), userMsg("part two")],
    });
    const sent = lastRequestBody.messages;
    assert.equal(sent.length, 1);
    assert.equal(sent[0].author, "USER");
    assert.equal(
      sent[0].fragments.map((f: any) => f.text).join(""),
      "part one\n\npart two",
    );
  });

  it("appends (continue) when history ends with assistant", async () => {
    await runStream({
      messages: [userMsg("hi"), assistantMsg("hello")],
    });
    const sent = lastRequestBody.messages;
    assert.equal(sent[0].author, "USER");
    assert.equal(sent[0].fragments[0].text, "(continue)");
  });

  it("sends thinking blocks nowhere (assistant text only)", async () => {
    await runStream({
      messages: [
        userMsg("q"),
        {
          ...assistantMsg("answer"),
          content: [
            { type: "thinking", thinking: "SECRET THINKING" },
            { type: "text", text: "answer" },
          ],
        },
        userMsg("follow up"),
      ],
    });
    assert.ok(!JSON.stringify(lastRequestBody).includes("SECRET THINKING"));
  });
});

// ── Stream parsing ────────────────────────────────────────────────────────────

describe("stream parsing", () => {
  it("reassembles token fragments of the same messageId with no separator", async () => {
    respond = ndjsonResponder([
      gleanMsg("c1", "CONTENT", "I"),
      gleanMsg("c1", "CONTENT", "'m"),
      gleanMsg("c1", "CONTENT", " Glean"),
      gleanMsg("c1", "CONTENT", "."),
    ]);
    const { final } = await runStream({ messages: [userMsg("q")] });
    const text = final.content.filter((b: any) => b.type === "text");
    assert.equal(text.length, 1);
    assert.equal(text[0].text, "I'm Glean.");
  });

  it("separates distinct CONTENT messages with a paragraph break", async () => {
    respond = ndjsonResponder([
      gleanMsg("c1", "CONTENT", "First message."),
      gleanMsg("c2", "CONTENT", "Second message."),
    ]);
    const { final } = await runStream({ messages: [userMsg("q")] });
    const text = final.content.find((b: any) => b.type === "text");
    assert.equal(text.text, "First message.\n\nSecond message.");
  });

  it("reassembles HEADING tokens into thinking without mid-word newlines", async () => {
    respond = ndjsonResponder([
      gleanMsg("h1", "HEADING", "Answer"),
      gleanMsg("h1", "HEADING", "ing"),
      gleanMsg("h1", "HEADING", " simple"),
      gleanMsg("h1", "HEADING", " questions"),
      gleanMsg("c1", "CONTENT", "Done."),
    ]);
    const { final } = await runStream({ messages: [userMsg("q")] });
    const thinking = final.content.find((b: any) => b.type === "thinking");
    assert.equal(thinking.thinking, "Answering simple questions");
  });

  it("separates distinct thinking messages with a newline", async () => {
    respond = ndjsonResponder([
      gleanMsg("h1", "HEADING", "Step one"),
      gleanMsg("h2", "UPDATE", "Step two"),
      gleanMsg("c1", "CONTENT", "Done."),
    ]);
    const { final } = await runStream({ messages: [userMsg("q")] });
    const thinking = final.content.find((b: any) => b.type === "thinking");
    assert.equal(thinking.thinking, "Step one\nStep two");
  });

  it("preserves chronological interleaving of thinking and text blocks", async () => {
    respond = ndjsonResponder([
      gleanMsg("h1", "HEADING", "Searching"),
      gleanMsg("c1", "CONTENT", "Found it."),
      gleanMsg("h2", "HEADING", "Inspecting"),
      gleanMsg("c2", "CONTENT", "All done."),
    ]);
    const { final, events } = await runStream({ messages: [userMsg("q")] });
    assert.deepEqual(
      final.content.map((b: any) => b.type),
      ["thinking", "text", "thinking", "text"],
    );
    assert.equal(
      events.filter((e) => e === "thinking_start").length,
      events.filter((e) => e === "thinking_end").length,
    );
    assert.equal(
      events.filter((e) => e === "text_start").length,
      events.filter((e) => e === "text_end").length,
    );
  });

  it("ignores fragment-less status UPDATEs and CONTROL messages", async () => {
    respond = ndjsonResponder([
      gleanMsg("u0", "UPDATE", undefined, {
        stepId: "X",
        isStepComplete: true,
      }),
      gleanMsg("c1", "CONTENT", "Answer."),
      gleanMsg("u1", "UPDATE"),
      gleanMsg("ctrl", "CONTROL"),
    ]);
    const { final } = await runStream({ messages: [userMsg("q")] });
    assert.deepEqual(
      final.content.map((b: any) => b.type),
      ["text"],
    );
    assert.equal(final.content[0].text, "Answer.");
  });

  it("skips USER-authored echo messages", async () => {
    respond = ndjsonResponder([
      {
        messages: [
          {
            author: "USER",
            messageType: "CONTENT",
            fragments: [{ text: "echo" }],
          },
        ],
      },
      gleanMsg("c1", "CONTENT", "Reply."),
    ]);
    const { final } = await runStream({ messages: [userMsg("q")] });
    assert.equal(
      final.content.find((b: any) => b.type === "text").text,
      "Reply.",
    );
  });

  it("tolerates non-JSON keep-alive lines", async () => {
    respond = ({ res }) => {
      res.writeHead(200, { "Content-Type": "text/plain" });
      res.write("not json\n");
      res.write(JSON.stringify(gleanMsg("c1", "CONTENT", "Fine.")) + "\n");
      res.end();
    };
    const { final, error } = await runStream({ messages: [userMsg("q")] });
    assert.equal(error, undefined);
    assert.equal(final.content[0].text, "Fine.");
  });

  it("collects citations into a Sources block, deduplicated", async () => {
    respond = ndjsonResponder([
      {
        messages: [
          {
            author: "GLEAN_AI",
            messageId: "c1",
            messageType: "CONTENT",
            fragments: [
              {
                text: "See policy.",
                citation: {
                  sourceDocument: { title: "PTO", url: "https://w/pto" },
                },
              },
            ],
          },
        ],
      },
      {
        messages: [
          {
            author: "GLEAN_AI",
            messageId: "c1",
            messageType: "CONTENT",
            fragments: [
              {
                text: " More.",
                citation: {
                  sourceDocument: { title: "PTO", url: "https://w/pto" },
                },
              },
            ],
            citations: [
              { sourceDocument: { title: "Handbook", url: "https://w/hb" } },
            ],
          },
        ],
      },
    ]);
    const { final } = await runStream({ messages: [userMsg("q")] });
    const text = final.content.find((b: any) => b.type === "text").text;
    assert.ok(text.includes("See policy. More."));
    assert.ok(text.includes("**Sources:**"));
    assert.equal(text.match(/https:\/\/w\/pto/g)?.length, 1);
    assert.ok(text.includes("[Handbook](https://w/hb)"));
  });

  it("returns (no response) for an empty stream", async () => {
    respond = ndjsonResponder([gleanMsg("ctrl", "CONTROL")]);
    const { final } = await runStream({ messages: [userMsg("q")] });
    assert.equal(final.content[0].text, "(no response)");
  });
});

// ── Error handling ────────────────────────────────────────────────────────────

describe("error handling", () => {
  it("surfaces ERROR messages as stream errors", async () => {
    respond = ndjsonResponder([gleanMsg("e1", "ERROR", "quota exceeded")]);
    const { error } = await runStream({ messages: [userMsg("q")] });
    assert.equal(error.stopReason, "error");
    assert.match(error.errorMessage, /quota exceeded/);
  });

  it("surfaces HTTP errors with status and hint", async () => {
    respond = ({ res }) => {
      res.writeHead(401, { "Content-Type": "text/plain" });
      res.end("bad token");
    };
    const { error } = await runStream({ messages: [userMsg("q")] });
    assert.equal(error.stopReason, "error");
    assert.match(error.errorMessage, /401/);
    assert.match(error.errorMessage, /GLEAN_API_TOKEN/);
  });

  it("errors when no token is available", async () => {
    // resolveGleanToken falls back to ~/.pi/agent/auth.json; point HOME at an
    // empty dir so a real auth.json on the test machine cannot satisfy it.
    const savedToken = process.env.GLEAN_API_TOKEN;
    const savedHome = process.env.HOME;
    delete process.env.GLEAN_API_TOKEN;
    process.env.HOME = "/nonexistent-glean-test";
    try {
      const { error } = await runStream({ messages: [userMsg("q")] }, {});
      assert.equal(error.stopReason, "error");
      assert.match(error.errorMessage, /token/i);
    } finally {
      process.env.GLEAN_API_TOKEN = savedToken;
      process.env.HOME = savedHome;
    }
  });

  it("reports aborted when the signal fires mid-stream", async () => {
    const controller = new AbortController();
    respond = ({ res }) => {
      res.writeHead(200, { "Content-Type": "text/plain" });
      res.write(JSON.stringify(gleanMsg("c1", "CONTENT", "partial")) + "\n");
      // Keep the connection open; abort will terminate it.
      setTimeout(() => controller.abort(), 50);
      setTimeout(() => res.end(), 5000).unref();
    };
    const { error } = await runStream(
      { messages: [userMsg("q")] },
      {
        apiKey: "test-token",
        signal: controller.signal,
      },
    );
    assert.equal(error.stopReason, "aborted");
  });
});
