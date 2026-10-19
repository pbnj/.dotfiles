import { spawn, type ChildProcess } from "node:child_process";
import { randomUUID } from "node:crypto";
import { closeSync, mkdtempSync, openSync, writeSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { StringDecoder } from "node:string_decoder";
import { stripVTControlCharacters } from "node:util";

export const DEFAULT_TIMEOUT_MS = 300_000;
export const MAX_TIMEOUT_MS = 1_800_000;
export const MAX_ACTIVE_MONITORS = 16;
export const MAX_EVENT_CHARS = 8192;
const MAX_LINE_BYTES = 64 * 1024;
const MAX_FRAME_BYTES = 1024 * 1024;
const MAX_LOG_BYTES = 10 * 1024 * 1024;
const STOP_GRACE_MS = 500;

export type MonitorInput = {
  description: string;
  timeout_ms?: number;
  command?: string;
  ws?: { url: string; protocols?: string[] };
};
export type MonitorState = "running" | "stopping" | "ended";
export type MonitorInfo = {
  monitor_id: string;
  description: string;
  source: "command" | "websocket";
  status: MonitorState;
  started_at: number;
  timeout_ms: number;
  event_count: number;
  stdout_path: string;
  stderr_path: string;
  reason?: string;
  exit_code?: number;
  signal?: string;
  close_code?: number;
};
export type MonitorNotice = {
  kind: "events" | "end";
  monitor: MonitorInfo;
  lines: string[];
};
type SocketEvent = { data?: unknown; code?: number };
export type MonitorSocket = {
  binaryType: string;
  addEventListener(type: string, listener: (event: SocketEvent) => void): void;
  close(code?: number, reason?: string): void;
};
export type CommandEnvironment = {
  cwd: string;
  shell: string;
  args: string[];
  commandTransport?: "argv" | "stdin";
  prefix?: string;
  env?: NodeJS.ProcessEnv;
};
type RecordState = {
  info: MonitorInfo;
  stdout: number;
  stderr: number;
  logBytes: { stdout: number; stderr: number };
  child?: ChildProcess;
  socket?: MonitorSocket;
  decoder: StringDecoder;
  partial: string;
  rate: number[];
  lines: string[];
  batchBytes: number;
  batchTimer?: ReturnType<typeof setTimeout>;
  timeout?: ReturnType<typeof setTimeout>;
  killTimer?: ReturnType<typeof setTimeout>;
  drainTimer?: ReturnType<typeof setTimeout>;
  done: Promise<void>;
  resolveDone: () => void;
};
export type ManagerOptions = {
  onNotice: (notice: MonitorNotice) => void;
  onChange?: () => void;
  logRoot?: string;
  socketFactory?: (url: string, protocols?: string[]) => MonitorSocket;
  maxActive?: number;
  maxEventsPerMinute?: number;
  batchMs?: number;
};

export function safeText(text: string): string {
  // Terminal output is intentionally filtered for control characters.
  return stripVTControlCharacters(text).replace(
    // eslint-disable-next-line no-control-regex
    /[\x00-\x08\x0b-\x1f\x7f-\x9f\u202a-\u202e\u2066-\u2069\ufff9-\ufffb]/g,
    "",
  );
}

export function normalizeInput(
  input: MonitorInput,
): MonitorInput & { timeout_ms: number } {
  if (typeof input.description !== "string" || !input.description.trim())
    throw new Error("description is required.");
  if (
    input.description.length > 500 ||
    // eslint-disable-next-line no-control-regex
    /[\x00-\x1f\x7f]/.test(input.description)
  )
    throw new Error(
      "description must be at most 500 characters without control characters.",
    );
  if ((input.command !== undefined) === (input.ws !== undefined))
    throw new Error("Provide exactly one of command or ws.");
  const timeout = input.timeout_ms ?? DEFAULT_TIMEOUT_MS;
  if (!Number.isSafeInteger(timeout) || timeout < 1 || timeout > MAX_TIMEOUT_MS)
    throw new Error(
      `timeout_ms must be an integer from 1 to ${MAX_TIMEOUT_MS}.`,
    );
  if (input.command !== undefined) {
    if (
      typeof input.command !== "string" ||
      !input.command.trim() ||
      Buffer.byteLength(input.command) > 64 * 1024 ||
      input.command.includes("\0")
    )
      throw new Error(
        "command must be nonempty, at most 64 KiB, and contain no NUL bytes.",
      );
  } else {
    const ws = input.ws;
    if (!ws || typeof ws.url !== "string")
      throw new Error("ws.url is required.");
    let url: URL;
    try {
      url = new URL(ws.url);
    } catch {
      throw new Error("ws.url must be a valid ws:// or wss:// URL.");
    }
    if (
      !["ws:", "wss:"].includes(url.protocol) ||
      url.username ||
      url.password ||
      url.hash ||
      /\s/.test(ws.url)
    )
      throw new Error(
        "ws.url must use ws:// or wss:// without credentials, fragments, or whitespace.",
      );
    if (
      ws.protocols !== undefined &&
      (!Array.isArray(ws.protocols) ||
        ws.protocols.some(
          (p) =>
            typeof p !== "string" || !/^[!#$%&'*+\-.^_`|~0-9A-Za-z]+$/.test(p),
        ))
    )
      throw new Error("ws.protocols must contain valid protocol tokens.");
    if (new Set(ws.protocols).size !== (ws.protocols?.length ?? 0))
      throw new Error("ws.protocols cannot contain duplicates.");
  }
  return {
    ...input,
    description: input.description.trim(),
    timeout_ms: timeout,
  };
}

export class MonitorManager {
  private readonly active = new Map<string, RecordState>();
  private readonly history: MonitorInfo[] = [];
  private readonly options: ManagerOptions;

  constructor(options: ManagerOptions) {
    this.options = options;
  }

  list(includeEnded = false): MonitorInfo[] {
    return [
      ...[...this.active.values()].map((record) => ({ ...record.info })),
      ...(includeEnded ? this.history.map((info) => ({ ...info })) : []),
    ];
  }

  start(raw: MonitorInput, environment: CommandEnvironment): MonitorInfo {
    const input = normalizeInput(raw);
    if (this.active.size >= (this.options.maxActive ?? MAX_ACTIVE_MONITORS))
      throw new Error(
        `At most ${this.options.maxActive ?? MAX_ACTIVE_MONITORS} monitors can run at once.`,
      );
    const dir = mkdtempSync(
      join(this.options.logRoot ?? tmpdir(), "pi-monitor-"),
    );
    const info: MonitorInfo = {
      monitor_id: randomUUID(),
      description: input.description,
      source: input.command !== undefined ? "command" : "websocket",
      status: "running",
      started_at: Date.now(),
      timeout_ms: input.timeout_ms,
      event_count: 0,
      stdout_path: join(dir, "stdout.log"),
      stderr_path: join(dir, "stderr.log"),
    };
    const stdout = openSync(info.stdout_path, "wx", 0o600);
    let stderr: number;
    try {
      stderr = openSync(info.stderr_path, "wx", 0o600);
    } catch (error) {
      closeSync(stdout);
      throw error;
    }
    let resolveDone!: () => void;
    const done = new Promise<void>((resolve) => {
      resolveDone = resolve;
    });
    const record: RecordState = {
      info,
      stdout,
      stderr,
      logBytes: { stdout: 0, stderr: 0 },
      decoder: new StringDecoder("utf8"),
      partial: "",
      rate: [],
      lines: [],
      batchBytes: 0,
      done,
      resolveDone,
    };
    this.active.set(info.monitor_id, record);
    record.timeout = setTimeout(
      () => this.requestStop(record, "timeout"),
      input.timeout_ms,
    );
    try {
      if (input.command !== undefined)
        this.startCommand(record, input.command, environment);
      else this.startSocket(record, input.ws!);
    } catch (error) {
      this.finish(
        record,
        `error: ${error instanceof Error ? error.message : String(error)}`,
      );
      throw error;
    }
    this.options.onChange?.();
    return { ...info };
  }

  private startCommand(
    record: RecordState,
    command: string,
    environment: CommandEnvironment,
  ): void {
    const script = environment.prefix
      ? `${environment.prefix}\n${command}`
      : command;
    const stdin = environment.commandTransport === "stdin";
    const child = spawn(
      environment.shell,
      stdin ? environment.args : [...environment.args, script],
      {
        cwd: environment.cwd,
        env: environment.env ?? process.env,
        detached: process.platform !== "win32",
        windowsHide: true,
        stdio: [stdin ? "pipe" : "ignore", "pipe", "pipe"],
      },
    );
    record.child = child;
    if (stdin) {
      child.stdin?.on("error", () => {});
      child.stdin?.end(script);
    }
    child.stdout!.on("data", (chunk: Buffer) => {
      if (record.info.status !== "running") return;
      if (!this.log(record, "stdout", chunk)) return;
      this.consume(record, record.decoder.write(chunk));
    });
    child.stderr!.on("data", (chunk: Buffer) => {
      if (record.info.status !== "ended") this.log(record, "stderr", chunk);
    });
    child.stdout!.on("end", () => {
      if (record.info.status !== "running") return;
      this.consume(record, record.decoder.end());
      if (record.partial) {
        this.event(record, record.partial);
        record.partial = "";
      }
    });
    child.on("error", (error) =>
      this.finish(record, `error: ${error.message}`),
    );
    child.on("exit", (code, signal) => {
      if (record.info.status === "ended") return;
      record.info.exit_code = code ?? undefined;
      record.info.signal = signal ?? undefined;
      // A monitor owns its process group, even if the shell exits before a child.
      this.kill(record, "SIGKILL");
      record.drainTimer = setTimeout(
        () => this.finish(record, record.info.reason ?? "exited"),
        STOP_GRACE_MS,
      );
    });
    child.on("close", () =>
      this.finish(record, record.info.reason ?? "exited"),
    );
  }

  private consume(record: RecordState, text: string): void {
    const parts = (record.partial + text).split("\n");
    record.partial = parts.pop()!;
    for (const line of parts) {
      if (record.info.status !== "running") return;
      if (Buffer.byteLength(line) > MAX_LINE_BYTES) {
        this.requestStop(record, "output limit: stdout line exceeded 64 KiB");
        return;
      }
      this.event(record, line.endsWith("\r") ? line.slice(0, -1) : line);
    }
    if (Buffer.byteLength(record.partial) > MAX_LINE_BYTES)
      this.requestStop(
        record,
        "output limit: unterminated stdout line exceeded 64 KiB",
      );
  }

  private startSocket(
    record: RecordState,
    source: NonNullable<MonitorInput["ws"]>,
  ): void {
    const socket = this.options.socketFactory
      ? this.options.socketFactory(source.url, source.protocols)
      : (new WebSocket(source.url, source.protocols) as MonitorSocket);
    record.socket = socket;
    socket.binaryType = "arraybuffer";
    socket.addEventListener("message", ({ data }) => {
      if (record.info.status !== "running") return;
      const bytes =
        typeof data === "string"
          ? Buffer.byteLength(data)
          : data instanceof ArrayBuffer || ArrayBuffer.isView(data)
            ? data.byteLength
            : 0;
      if (bytes > MAX_FRAME_BYTES) {
        this.requestStop(
          record,
          "output limit: WebSocket frame exceeded 1 MiB",
        );
        return;
      }
      const line =
        typeof data === "string" ? data : `[binary frame, ${bytes} bytes]`;
      if (this.log(record, "stdout", Buffer.from(`${line}\n`)))
        this.event(record, line);
    });
    socket.addEventListener("error", () =>
      this.requestStop(record, "error: WebSocket connection failed"),
    );
    socket.addEventListener("close", ({ code }) => {
      if (record.info.status === "ended") return;
      record.info.close_code = code;
      this.finish(record, record.info.reason ?? "socket closed");
    });
  }

  private log(
    record: RecordState,
    stream: "stdout" | "stderr",
    data: Buffer,
  ): boolean {
    if (record.info.status === "ended") return false;
    const remaining = MAX_LOG_BYTES - record.logBytes[stream];
    try {
      if (remaining > 0) {
        const chunk = data.subarray(0, remaining);
        let written = 0;
        while (written < chunk.length)
          written += writeSync(record[stream], chunk.subarray(written));
        record.logBytes[stream] += written;
      }
    } catch {
      this.requestStop(record, `error: could not write ${stream} log`);
      return false;
    }
    if (data.length > remaining) {
      this.requestStop(record, `output limit: ${stream} log exceeded 10 MiB`);
      return false;
    }
    return true;
  }

  private event(record: RecordState, raw: string): void {
    if (record.info.status !== "running") return;
    record.info.event_count++;
    const now = Date.now();
    record.rate = record.rate.filter((at) => now - at < 60_000);
    record.rate.push(now);
    if (record.rate.length > (this.options.maxEventsPerMinute ?? 100)) {
      this.requestStop(record, "flood: event rate limit exceeded");
      return;
    }
    const clean = safeText(raw);
    const line =
      clean.length > MAX_EVENT_CHARS
        ? `${clean.slice(0, MAX_EVENT_CHARS)}… [truncated; read stdout_path]`
        : clean;
    record.lines.push(line);
    record.batchBytes += Buffer.byteLength(line);
    if (record.batchBytes >= 32 * 1024) this.flush(record);
    else if (!record.batchTimer)
      record.batchTimer = setTimeout(
        () => this.flush(record),
        this.options.batchMs ?? 200,
      );
  }

  private flush(record: RecordState): void {
    if (record.batchTimer) clearTimeout(record.batchTimer);
    record.batchTimer = undefined;
    if (!record.lines.length) return;
    const lines = record.lines.splice(0);
    record.batchBytes = 0;
    this.notice({ kind: "events", monitor: { ...record.info }, lines });
  }

  private notice(notice: MonitorNotice): void {
    try {
      this.options.onNotice(notice);
    } catch {
      /* An observer must not strand a child or socket. */
    }
  }

  stop(id: string, reason = "stopped"): Promise<boolean> {
    const record = this.active.get(id);
    if (!record) return Promise.resolve(false);
    this.requestStop(record, reason);
    return record.done.then(() => true);
  }

  async stopAll(reason = "stopped"): Promise<void> {
    await Promise.all(
      [...this.active.keys()].map((id) => this.stop(id, reason)),
    );
  }

  /** Last-resort synchronous cleanup when Node itself is exiting. */
  dispose(): void {
    for (const record of this.active.values())
      this.finish(record, "process exit");
  }

  private requestStop(record: RecordState, reason: string): void {
    if (record.info.status !== "running") return;
    record.info.status = "stopping";
    record.info.reason = reason;
    // Install the fallback first: a fake or failed socket may close synchronously.
    record.killTimer = setTimeout(() => {
      this.kill(record, "SIGKILL");
      this.finish(record, reason);
    }, STOP_GRACE_MS);
    if (record.socket) {
      try {
        record.socket.close(1000, "Monitor stopped");
      } catch {
        this.finish(record, reason);
      }
    } else this.kill(record, "SIGTERM");
    this.options.onChange?.();
  }

  private kill(record: RecordState, signal: NodeJS.Signals): void {
    const child = record.child;
    if (!child?.pid) return;
    if (process.platform === "win32") {
      const taskkill = spawn(
        join(
          process.env.SystemRoot ?? "C:\\Windows",
          "System32",
          "taskkill.exe",
        ),
        ["/F", "/T", "/PID", String(child.pid)],
        { stdio: "ignore", windowsHide: true },
      );
      taskkill.on("error", () => {});
    } else {
      try {
        process.kill(-child.pid, signal);
      } catch {
        try {
          child.kill(signal);
        } catch {
          /* Already gone. */
        }
      }
    }
  }

  private finish(record: RecordState, reason: string): void {
    if (record.info.status === "ended") return;
    record.info.status = "ended";
    record.info.reason = reason;
    for (const timer of [record.timeout, record.killTimer, record.drainTimer])
      if (timer) clearTimeout(timer);
    this.kill(record, "SIGKILL");
    record.child?.stdout?.destroy();
    record.child?.stderr?.destroy();
    // Closing a socket is idempotent, and prevents an error-only socket leaking.
    try {
      record.socket?.close();
    } catch {
      /* Already closed or connecting. */
    }
    closeSync(record.stdout);
    closeSync(record.stderr);
    this.active.delete(record.info.monitor_id);
    this.history.unshift({ ...record.info });
    this.history.length = Math.min(this.history.length, 50);
    this.flush(record);
    this.notice({ kind: "end", monitor: { ...record.info }, lines: [] });
    record.resolveDone();
    this.options.onChange?.();
  }
}
