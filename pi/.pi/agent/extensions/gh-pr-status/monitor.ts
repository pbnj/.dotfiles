import { randomUUID } from "node:crypto";
import { lookup } from "node:dns/promises";
import { isIP } from "node:net";
import { spawn, type ChildProcess } from "node:child_process";
import { createInterface, type Interface } from "node:readline";
import type { PRReference } from "./cache.ts";

export const DEFAULT_MONITOR_TIMEOUT_MS = 5 * 60 * 1000;
export const MAX_MONITOR_TIMEOUT_MS = 30 * 60 * 1000;
export const MAX_NONINTERACTIVE_MONITOR_TIMEOUT_MS = 10 * 60 * 1000;
export const MAX_WEBSOCKET_MESSAGE_BYTES = 1024 * 1024;
export const MAX_MONITOR_LINE_CHARS = 8192;
const MAX_ACTIVE_MONITORS = 16;
const STOP_GRACE_MS = 2000;

export type MonitorWebSocketSource = {
  url: string;
  protocols?: string[];
};

export type MonitorInput = {
  command?: string;
  description?: string;
  timeout_ms?: number;
  ws?: MonitorWebSocketSource;
};

export type NormalizedMonitorInput =
  | {
      source: "command";
      command: string;
      description: string;
      timeoutMs: number;
    }
  | {
      source: "websocket";
      url: string;
      protocols?: string[];
      description: string;
      timeoutMs: number;
    };

export type MonitorInfo = {
  id: string;
  source: "command" | "websocket";
  description: string;
  startedAt: number;
  timeoutMs: number;
  pr?: PRReference;
};

export type MonitorEvent = {
  id: string;
  description: string;
  source: "stdout" | "stderr" | "websocket";
  line: string;
};

export type MonitorEnd = {
  id: string;
  description: string;
  reason: string;
  exitCode?: number;
};

type SocketEvent = { data?: unknown; code?: number; reason?: string };
type MonitorSocket = {
  addEventListener(type: string, listener: (event: SocketEvent) => void): void;
  close(code?: number, reason?: string): void;
};
type SocketConstructor = new (
  url: string,
  protocols?: string[],
) => MonitorSocket;

type MonitorRecord = {
  info: MonitorInfo;
  finished: boolean;
  stopReason?: string;
  child?: ChildProcess;
  socket?: MonitorSocket;
  opened?: boolean;
  timeout?: ReturnType<typeof setTimeout>;
  forceKill?: ReturnType<typeof setTimeout>;
  stdout?: Interface;
  stderr?: Interface;
  resolveFinished: () => void;
  finishedPromise: Promise<void>;
  eventCount: number;
};

export type MonitorManagerOptions = {
  onEvent: (event: MonitorEvent) => void;
  onEnd: (event: MonitorEnd) => void;
  onChange?: () => void;
  webSocketFactory?: (url: string, protocols?: string[]) => MonitorSocket;
  lookupHost?: (hostname: string) => Promise<string[]>;
};

function cleanLine(
  value: string,
  preserveNewlines = false,
  maxChars = MAX_MONITOR_LINE_CHARS,
): string {
  let safe = "";
  for (const char of value) {
    const code = char.charCodeAt(0);
    safe +=
      (preserveNewlines && (char === "\n" || char === "\t")) ||
      (code >= 32 && code !== 127)
        ? char
        : " ";
    if (safe.length >= maxChars) break;
  }
  const trimmed = preserveNewlines ? safe : safe.trim();
  return value.length > maxChars ? `${trimmed}…` : trimmed;
}

function prReference(
  repo: string | undefined,
  number: string | undefined,
): PRReference | undefined {
  if (
    !repo ||
    !number ||
    !/^[\w.-]+\/[\w.-]+$/.test(repo) ||
    !/^[1-9]\d*$/.test(number)
  )
    return undefined;
  const parsed = Number(number);
  if (!Number.isSafeInteger(parsed)) return undefined;
  return {
    repo,
    number: parsed,
    url: `https://github.com/${repo}/pull/${parsed}`,
  };
}

export function findPRReference(
  command: string | undefined,
  description: string | undefined,
): PRReference | undefined {
  const inDescription = /([\w.-]+\/[\w.-]+)#([1-9]\d*)\b/.exec(
    description ?? "",
  );
  if (inDescription) return prReference(inDescription[1], inDescription[2]);

  if (!command || !/gh-pr-watch(?:\s|$)/i.test(command)) return undefined;
  const inCommand =
    /(?:^|\s)(?:-R|--repo)(?:=|\s+)["']?([\w.-]+\/[\w.-]+)["']?\s+(?:--fresh\s+)?([1-9]\d*)\b/.exec(
      command,
    );
  return inCommand ? prReference(inCommand[1], inCommand[2]) : undefined;
}

function websocketDescription(value: string): string {
  try {
    const url = new URL(value);
    url.username = "";
    url.password = "";
    url.search = "";
    url.hash = "";
    return `WebSocket ${url.toString()}`;
  } catch {
    return "WebSocket monitor";
  }
}

export function normalizeMonitorInput(
  input: MonitorInput,
  maxTimeoutMs = MAX_MONITOR_TIMEOUT_MS,
): NormalizedMonitorInput {
  const hasCommand =
    typeof input.command === "string" && input.command.trim().length > 0;
  const hasWebSocket = input.ws !== undefined;
  if (hasCommand === hasWebSocket)
    throw new Error(
      "Provide exactly one of command or ws; they cannot be combined.",
    );
  if (input.command !== undefined && !hasCommand)
    throw new Error("Monitor command must not be empty.");
  if (
    hasWebSocket &&
    (!input.ws || typeof input.ws !== "object" || Array.isArray(input.ws))
  )
    throw new Error("ws must be an object with a url field.");

  const timeoutMs =
    input.timeout_ms ?? Math.min(DEFAULT_MONITOR_TIMEOUT_MS, maxTimeoutMs);
  if (!Number.isSafeInteger(timeoutMs) || timeoutMs <= 0)
    throw new Error("timeout_ms must be a positive integer.");
  if (timeoutMs > maxTimeoutMs)
    throw new Error(
      `timeout_ms cannot exceed ${maxTimeoutMs} for this session.`,
    );

  const description =
    typeof input.description === "string" && input.description.trim()
      ? input.description.trim().slice(0, 500)
      : hasWebSocket
        ? websocketDescription(input.ws!.url)
        : input.command!.trim().slice(0, 120);
  if (
    [...description].some(
      (char) => char.charCodeAt(0) < 32 || char.charCodeAt(0) === 127,
    )
  )
    throw new Error("Monitor description cannot contain control characters.");

  if (hasCommand) {
    if (input.command!.length > 64 * 1024)
      throw new Error("Monitor command is too long (maximum 64 KiB).");
    return {
      source: "command",
      command: input.command!,
      description,
      timeoutMs,
    };
  }

  const ws = input.ws!;
  if (typeof ws.url !== "string" || !ws.url)
    throw new Error("ws.url is required.");
  if (ws.protocols !== undefined && !Array.isArray(ws.protocols))
    throw new Error("ws.protocols must be an array of strings.");
  if (
    ws.protocols?.some(
      (protocol) =>
        typeof protocol !== "string" ||
        !/^[!#$%&'*+\-.^_`|~0-9A-Za-z]+$/.test(protocol),
    )
  )
    throw new Error("WebSocket protocols must be valid tokens.");
  if (ws.protocols && new Set(ws.protocols).size !== ws.protocols.length)
    throw new Error("WebSocket protocols cannot contain duplicates.");
  return {
    source: "websocket",
    url: ws.url,
    protocols: ws.protocols,
    description,
    timeoutMs,
  };
}

function inIpv4Range(address: string, range: string, prefix: number): boolean {
  const octets = address.split(".").map(Number);
  const base = range.split(".").map(Number);
  if (octets.length !== 4 || base.length !== 4) return true;
  const toNumber = (parts: number[]) =>
    parts.reduce((value, part) => ((value << 8) | part) >>> 0, 0);
  const mask = prefix === 0 ? 0 : (0xffffffff << (32 - prefix)) >>> 0;
  return (toNumber(octets) & mask) === (toNumber(base) & mask);
}

function isPublicIPv4(address: string): boolean {
  const denied: Array<[string, number]> = [
    ["0.0.0.0", 8],
    ["10.0.0.0", 8],
    ["100.64.0.0", 10],
    ["127.0.0.0", 8],
    ["169.254.0.0", 16],
    ["172.16.0.0", 12],
    ["192.0.0.0", 24],
    ["192.0.2.0", 24],
    ["192.168.0.0", 16],
    ["198.18.0.0", 15],
    ["198.51.100.0", 24],
    ["203.0.113.0", 24],
    ["224.0.0.0", 4],
    ["240.0.0.0", 4],
  ];
  return !denied.some(([range, prefix]) => inIpv4Range(address, range, prefix));
}

function isPublicIPv6(address: string): boolean {
  const normalized = address.toLowerCase().split("%")[0]!;
  // Only global-unicast 2000::/3 is accepted. This excludes unspecified,
  // loopback, link-local, unique-local, multicast, and IPv4-mapped addresses.
  const first = Number.parseInt(normalized.split(":")[0] || "0", 16);
  if (first < 0x2000 || first > 0x3fff) return false;
  if (
    normalized.startsWith("2001:db8:") ||
    normalized.startsWith("2001:0:") ||
    normalized.startsWith("2001:10:")
  )
    return false;
  return true;
}

async function defaultLookup(hostname: string): Promise<string[]> {
  return (await lookup(hostname, { all: true, verbatim: true })).map(
    ({ address }) => address,
  );
}

export async function validateWebSocketUrl(
  raw: string,
  lookupHost: (hostname: string) => Promise<string[]> = defaultLookup,
): Promise<string> {
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    throw new Error("ws.url must be a valid WebSocket URL.");
  }
  if (
    !["ws:", "wss:"].includes(url.protocol) ||
    url.username ||
    url.password ||
    /\s/.test(raw) ||
    [...raw].some((char) => char.charCodeAt(0) > 127)
  )
    throw new Error(
      "ws.url must be an ASCII ws:// or wss:// URL without embedded credentials or whitespace.",
    );

  const hostname = url.hostname.replace(/^\[|\]$/g, "").toLowerCase();
  if (
    hostname === "localhost" ||
    hostname.endsWith(".localhost") ||
    hostname.endsWith(".local") ||
    hostname.endsWith(".internal")
  )
    throw new Error(
      "WebSocket monitors cannot connect to local or internal hosts.",
    );

  let addresses: string[];
  if (isIP(hostname)) addresses = [hostname];
  else {
    try {
      addresses = await lookupHost(hostname);
    } catch {
      throw new Error("Could not resolve the WebSocket host.");
    }
  }
  if (
    addresses.length === 0 ||
    addresses.some((address) =>
      isIP(address) === 4
        ? !isPublicIPv4(address)
        : isIP(address) === 6
          ? !isPublicIPv6(address)
          : true,
    )
  )
    throw new Error(
      "WebSocket monitors cannot connect to private, link-local, or reserved IP addresses.",
    );
  return url.toString();
}

function socketConstructor(): SocketConstructor {
  const WebSocketImpl = (
    globalThis as typeof globalThis & {
      WebSocket?: SocketConstructor;
    }
  ).WebSocket;
  if (!WebSocketImpl)
    throw new Error("This Node runtime does not provide a WebSocket client.");
  return WebSocketImpl;
}

async function websocketMessage(data: unknown): Promise<{
  binary: boolean;
  bytes: number;
  text?: string;
}> {
  if (typeof data === "string")
    return { binary: false, bytes: Buffer.byteLength(data), text: data };
  if (Buffer.isBuffer(data)) return { binary: true, bytes: data.byteLength };
  if (data instanceof ArrayBuffer)
    return { binary: true, bytes: data.byteLength };
  if (ArrayBuffer.isView(data)) return { binary: true, bytes: data.byteLength };
  if (
    data !== null &&
    typeof data === "object" &&
    "arrayBuffer" in data &&
    typeof data.arrayBuffer === "function"
  ) {
    const buffer = await data.arrayBuffer();
    return { binary: true, bytes: buffer.byteLength };
  }
  return { binary: true, bytes: 0 };
}

export class MonitorManager {
  private readonly active = new Map<string, MonitorRecord>();
  private readonly watchedPRs = new Map<string, PRReference>();
  private readonly options: MonitorManagerOptions;

  constructor(options: MonitorManagerOptions) {
    this.options = options;
  }

  getActive(): MonitorInfo[] {
    return [...this.active.values()].map(({ info }) => info).reverse();
  }

  getActivePRs(): PRReference[] {
    const unique = new Map<string, PRReference>();
    for (const monitor of this.active.values()) {
      if (monitor.info.pr)
        unique.set(
          `${monitor.info.pr.repo}#${monitor.info.pr.number}`,
          monitor.info.pr,
        );
    }
    return [...unique.values()].reverse();
  }

  getWatchedPRs(): ReadonlySet<string> {
    return new Set(this.watchedPRs.keys());
  }

  async start(
    input: NormalizedMonitorInput,
    cwd: string,
    session: string,
  ): Promise<MonitorInfo> {
    if (this.active.size >= MAX_ACTIVE_MONITORS)
      throw new Error(
        `At most ${MAX_ACTIVE_MONITORS} monitors can run at once.`,
      );

    const pr =
      input.source === "command"
        ? findPRReference(input.command, input.description)
        : findPRReference(undefined, input.description);
    if (
      pr &&
      [...this.active.values()].some(
        (monitor) =>
          monitor.info.pr?.repo === pr.repo &&
          monitor.info.pr.number === pr.number,
      )
    )
      throw new Error(`Already monitoring ${pr.repo}#${pr.number}.`);

    const id = randomUUID();
    const info: MonitorInfo = {
      id,
      source: input.source,
      description: input.description,
      startedAt: Date.now(),
      timeoutMs: input.timeoutMs,
      pr,
    };
    const wsUrl =
      input.source === "websocket"
        ? await validateWebSocketUrl(input.url, this.options.lookupHost)
        : undefined;
    let resolveFinished: (() => void) | undefined;
    const finishedPromise = new Promise<void>((resolve) => {
      resolveFinished = resolve;
    });
    const record: MonitorRecord = {
      info,
      finished: false,
      resolveFinished: () => resolveFinished?.(),
      finishedPromise,
      eventCount: 0,
    };

    this.active.set(id, record);
    if (pr) this.watchedPRs.set(`${pr.repo}#${pr.number}`, pr);
    this.options.onChange?.();
    record.timeout = setTimeout(() => {
      this.requestStop(record, "timed out");
    }, info.timeoutMs);
    try {
      if (input.source === "command")
        this.startCommand(record, input.command, cwd, session);
      else this.startWebSocket(record, wsUrl!, input.protocols);
    } catch (error) {
      this.finish(
        record,
        `failed to start: ${error instanceof Error ? error.message : String(error)}`,
      );
      throw error;
    }
    return info;
  }

  private startCommand(
    record: MonitorRecord,
    command: string,
    cwd: string,
    session: string,
  ): void {
    const shell =
      process.platform === "win32"
        ? process.env.ComSpec || "cmd.exe"
        : process.env.SHELL || "/bin/sh";
    const args =
      process.platform === "win32"
        ? ["/d", "/s", "/c", command]
        : ["-c", command];
    const child = spawn(shell, args, {
      cwd,
      detached: process.platform !== "win32",
      env: { ...process.env, PI_SESSION_ID: session },
      stdio: ["ignore", "pipe", "pipe"],
      windowsHide: true,
    });
    record.child = child;
    record.stdout = createInterface({
      input: child.stdout!,
      crlfDelay: Infinity,
    });
    record.stderr = createInterface({
      input: child.stderr!,
      crlfDelay: Infinity,
    });
    record.stdout.on("line", (line) => this.emitLine(record, "stdout", line));
    record.stderr.on("line", (line) => this.emitLine(record, "stderr", line));
    child.on("error", (error: Error) => {
      this.finish(record, `failed to start: ${error.message}`);
    });
    child.on("close", (code, signal) => {
      const reason =
        record.stopReason ??
        (code === 0
          ? "completed"
          : `exited with code ${code ?? signal ?? "unknown"}`);
      this.finish(record, reason, code ?? undefined);
    });
  }

  private startWebSocket(
    record: MonitorRecord,
    url: string,
    protocols?: string[],
  ): void {
    const socket = this.options.webSocketFactory
      ? this.options.webSocketFactory(url, protocols)
      : (() => {
          const WebSocketImpl = socketConstructor();
          return protocols?.length
            ? new WebSocketImpl(url, protocols)
            : new WebSocketImpl(url);
        })();
    record.socket = socket;
    socket.addEventListener("open", () => {
      record.opened = true;
      this.options.onChange?.();
    });
    socket.addEventListener("message", (event) => {
      void this.emitWebSocketMessage(record, event.data);
    });
    socket.addEventListener("error", () => {
      if (!record.opened) {
        try {
          socket.close(1011, "connection failed");
        } catch {
          // Finalize below even if the socket implementation also rejects close.
        }
        this.finish(record, "failed to start: WebSocket connection failed");
      } else this.requestStop(record, "WebSocket connection error");
    });
    socket.addEventListener("close", (event) => {
      this.finish(
        record,
        record.stopReason ??
          `WebSocket closed (${event.code ?? 1000}${event.reason ? `: ${cleanLine(event.reason)}` : ""})`,
      );
    });
  }

  private async emitWebSocketMessage(
    record: MonitorRecord,
    data: unknown,
  ): Promise<void> {
    if (record.finished) return;
    let message: Awaited<ReturnType<typeof websocketMessage>>;
    try {
      message = await websocketMessage(data);
    } catch (error) {
      this.requestStop(
        record,
        `WebSocket message could not be read: ${error instanceof Error ? error.message : String(error)}`,
      );
      return;
    }
    if (message.bytes > MAX_WEBSOCKET_MESSAGE_BYTES) {
      this.requestStop(record, "WebSocket message exceeded 1 MiB");
      return;
    }
    this.emitLine(
      record,
      "websocket",
      message.binary
        ? `[binary frame, ${message.bytes} bytes]`
        : (message.text ?? ""),
    );
  }

  private emitLine(
    record: MonitorRecord,
    source: MonitorEvent["source"],
    value: string,
  ): void {
    if (record.finished || record.stopReason) return;
    const line = cleanLine(
      value,
      source === "websocket",
      source === "websocket"
        ? MAX_WEBSOCKET_MESSAGE_BYTES
        : MAX_MONITOR_LINE_CHARS,
    );
    if (!line) return;
    record.eventCount++;
    if (record.eventCount > 20_000) {
      this.requestStop(record, "event limit exceeded");
      return;
    }
    try {
      this.options.onEvent({
        id: record.info.id,
        description: record.info.description,
        source,
        line,
      });
    } catch {
      // Observer failures must not strand the monitored process.
    }
  }

  private requestStop(record: MonitorRecord, reason: string): void {
    if (record.finished || record.stopReason) return;
    record.stopReason = reason;
    if (record.socket) {
      record.forceKill = setTimeout(
        () => this.finish(record, reason),
        STOP_GRACE_MS,
      );
      try {
        record.socket.close(1000, reason.slice(0, 100));
      } catch {
        this.finish(record, reason);
      }
      return;
    }
    this.signal(record, "SIGTERM");
    record.forceKill = setTimeout(() => {
      this.signal(record, "SIGKILL");
      record.forceKill = setTimeout(
        () => this.finish(record, reason),
        STOP_GRACE_MS,
      );
    }, STOP_GRACE_MS);
  }

  private signal(record: MonitorRecord, signal: NodeJS.Signals): void {
    const child = record.child;
    if (!child || child.exitCode !== null || child.signalCode !== null) return;
    try {
      if (process.platform !== "win32" && child.pid)
        process.kill(-child.pid, signal);
      else child.kill(signal);
    } catch {
      child.kill(signal);
    }
  }

  private finish(
    record: MonitorRecord,
    reason: string,
    exitCode?: number,
  ): void {
    if (record.finished) return;
    record.finished = true;
    if (record.timeout) clearTimeout(record.timeout);
    if (record.forceKill) clearTimeout(record.forceKill);
    record.stdout?.close();
    record.stderr?.close();
    if (this.active.get(record.info.id) === record)
      this.active.delete(record.info.id);
    if (reason.startsWith("failed to start") && record.info.pr) {
      const key = `${record.info.pr.repo}#${record.info.pr.number}`;
      if (
        ![...this.active.values()].some(
          (active) =>
            active.info.pr?.repo === record.info.pr?.repo &&
            active.info.pr?.number === record.info.pr?.number,
        )
      )
        this.watchedPRs.delete(key);
    }
    record.resolveFinished();
    this.options.onChange?.();
    try {
      this.options.onEnd({
        id: record.info.id,
        description: record.info.description,
        reason,
        exitCode,
      });
    } catch {
      // Observer failures must not strand other monitors.
    }
  }

  async stop(id: string): Promise<boolean> {
    const record = this.active.get(id);
    if (!record) return false;
    this.requestStop(record, "cancelled");
    let timer: ReturnType<typeof setTimeout> | undefined;
    await Promise.race([
      record.finishedPromise,
      new Promise<void>((resolve) => {
        timer = setTimeout(resolve, STOP_GRACE_MS * 2);
      }),
    ]);
    if (timer) clearTimeout(timer);
    if (!record.finished) this.finish(record, "cancelled");
    return true;
  }

  async stopAll(): Promise<void> {
    const records = [...this.active.values()];
    await Promise.all(records.map((record) => this.stop(record.info.id)));
    this.watchedPRs.clear();
  }
}
