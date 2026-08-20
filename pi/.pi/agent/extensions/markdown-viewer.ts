import { readFile, readdir, realpath, stat } from "node:fs/promises";
import { homedir } from "node:os";
import { pathToFileURL } from "node:url";
import {
  basename,
  dirname,
  extname,
  isAbsolute,
  join,
  relative,
  resolve,
  sep,
} from "node:path";
import {
  CONFIG_DIR_NAME,
  getAgentDir,
  getMarkdownTheme,
  getPackageDir,
  type ExtensionAPI,
  type ExtensionCommandContext,
  type ExtensionContext,
  type Theme,
} from "@earendil-works/pi-coding-agent";
import {
  fuzzyFilter,
  Input,
  Marked,
  Key,
  Markdown,
  matchesKey,
  type AutocompleteItem,
  type Component,
  type KeybindingsManager,
  type SelectItem,
  SelectList,
  Text,
  truncateToWidth,
  visibleWidth,
} from "@earendil-works/pi-tui";

const MARKDOWN_PREVIEW_ENTRY_TYPE = "markdown-preview";
const MAX_PREVIEW_BYTES = 1024 * 1024;
const MAX_PICKER_FILES = 10_000;
const MAX_COMPLETIONS = 200;
const MARKDOWN_EXTENSIONS = new Set([".md", ".markdown", ".mdx"]);
const SKIPPED_DIRECTORIES = new Set([
  ".cache",
  ".git",
  ".next",
  ".venv",
  ".yarn",
  "build",
  "coverage",
  "dist",
  "node_modules",
  "target",
  "tmp",
  "vendor",
]);
const PI_GENERATED_DIRECTORIES = new Set([
  "backups",
  "git",
  "npm",
  "sessions",
  "tmp",
]);

class MarkdownViewerError extends Error {}

type MarkdownFile = {
  path: string;
  content: string;
};

type MarkdownCandidate = SelectItem & {
  path: string;
};

type MarkdownPreviewEntry = {
  path: string;
  content: string;
  mermaidRenderingMode: MermaidRenderingMode;
};

type PreviewDestination = "inline" | "popup";

type MermaidRenderingMode = "off" | "final" | "streaming";

type MermaidToken = {
  type?: string;
  lang?: string;
  text?: string;
  raw: string;
};

type MermaidSpan = {
  text: string;
  cls: "border" | "text" | "edge" | "edgeLabel" | "title" | "none";
};

type MermaidRenderer = (source: string) => {
  styled: MermaidSpan[][];
  width: number;
  warnings: string[];
} | null;

const mermaidParser = new Marked();

function isMarkdownPath(path: string): boolean {
  return MARKDOWN_EXTENSIONS.has(extname(path).toLowerCase());
}

function expandHome(path: string): string {
  if (path === "~") return homedir();
  if (path.startsWith(`~${sep}`) || path.startsWith("~/")) {
    return join(homedir(), path.slice(2));
  }
  return path;
}

function normalizePathArgument(argument: string): string {
  const trimmed = argument.trim();
  return trimmed.startsWith("@") ? trimmed.slice(1) : trimmed;
}

function displayPath(path: string, cwd: string): string {
  const projectRelative = relative(cwd, path);
  return projectRelative &&
    !projectRelative.startsWith(`..${sep}`) &&
    projectRelative !== ".."
    ? projectRelative.split(sep).join("/")
    : path;
}

function shouldSkipDirectory(path: string, cwd: string): boolean {
  const name = basename(path);
  if (SKIPPED_DIRECTORIES.has(name)) return true;

  const parentSegments = relative(cwd, dirname(path)).split(sep);
  return parentSegments.includes(".pi") && PI_GENERATED_DIRECTORIES.has(name);
}

function isMermaidRenderingMode(value: unknown): value is MermaidRenderingMode {
  return value === "off" || value === "final" || value === "streaming";
}

async function readMermaidRenderingMode(
  settingsPath: string,
): Promise<MermaidRenderingMode | undefined> {
  try {
    const settings = JSON.parse(await readFile(settingsPath, "utf8")) as {
      markdown?: { mermaid?: unknown };
    };
    const mode = settings.markdown?.mermaid;
    return isMermaidRenderingMode(mode) ? mode : undefined;
  } catch {
    return undefined;
  }
}

async function getMermaidRenderingMode(
  ctx: ExtensionCommandContext,
): Promise<MermaidRenderingMode> {
  let mode = await readMermaidRenderingMode(
    join(getAgentDir(), "settings.json"),
  );

  if (ctx.isProjectTrusted()) {
    mode =
      (await readMermaidRenderingMode(
        join(ctx.cwd, CONFIG_DIR_NAME, "settings.json"),
      )) ?? mode;
  }

  return mode ?? "streaming";
}

function formatError(error: unknown, requestedPath: string): string {
  if (error instanceof MarkdownViewerError) return error.message;

  const errno = error as NodeJS.ErrnoException;
  if (errno.code === "ENOENT") return `File not found: ${requestedPath}`;
  if (errno.code === "EACCES") return `Cannot read: ${requestedPath}`;

  const message = error instanceof Error ? error.message : String(error);
  return `Could not open ${requestedPath}: ${message}`;
}

async function loadMarkdownFile(
  argument: string,
  cwd: string,
): Promise<MarkdownFile> {
  const requestedPath = normalizePathArgument(argument);
  if (!requestedPath) throw new MarkdownViewerError("Usage: /md <path>");

  const resolvedPath = isAbsolute(expandHome(requestedPath))
    ? expandHome(requestedPath)
    : resolve(cwd, expandHome(requestedPath));
  const canonicalPath = await realpath(resolvedPath);
  const fileStat = await stat(canonicalPath);

  if (!fileStat.isFile()) {
    throw new MarkdownViewerError(`Not a regular file: ${requestedPath}`);
  }
  if (fileStat.size > MAX_PREVIEW_BYTES) {
    throw new MarkdownViewerError(
      `Refusing to preview ${requestedPath}: files larger than 1 MiB are not rendered.`,
    );
  }

  const content = await readFile(canonicalPath);
  if (content.includes(0)) {
    throw new MarkdownViewerError(
      `Refusing to preview binary file: ${requestedPath}`,
    );
  }

  return { path: canonicalPath, content: content.toString("utf8") };
}

async function discoverMarkdownFiles(cwd: string): Promise<{
  candidates: MarkdownCandidate[];
  truncated: boolean;
}> {
  const candidates: MarkdownCandidate[] = [];
  const directories = [cwd];

  while (directories.length > 0 && candidates.length < MAX_PICKER_FILES) {
    const directory = directories.pop()!;
    let entries;
    try {
      entries = await readdir(directory, { withFileTypes: true });
    } catch {
      // An unreadable directory should not make the rest of the project unusable.
      continue;
    }

    for (const entry of entries) {
      if (candidates.length >= MAX_PICKER_FILES) break;

      const fullPath = join(directory, entry.name);
      if (entry.isDirectory()) {
        if (!shouldSkipDirectory(fullPath, cwd)) directories.push(fullPath);
        continue;
      }

      // Do not traverse symlinked directories or offer non-regular files. A manually
      // supplied file symlink is still accepted by loadMarkdownFile() after realpath().
      if (!entry.isFile() || !isMarkdownPath(entry.name)) continue;

      const projectRelativePath = displayPath(fullPath, cwd);
      candidates.push({
        value: projectRelativePath,
        label: projectRelativePath,
        path: fullPath,
      });
    }
  }

  candidates.sort((left, right) => left.label.localeCompare(right.label));
  return {
    candidates,
    truncated: candidates.length >= MAX_PICKER_FILES || directories.length > 0,
  };
}

function frameLines(lines: string[], width: number, theme: Theme): string[] {
  if (width < 4) return lines.map((line) => truncateToWidth(line, width, ""));

  const innerWidth = width - 2;
  const border = (text: string) => theme.fg("border", text);
  const frameLine = (line: string) => {
    const truncated = truncateToWidth(line, innerWidth, "");
    return `${border("│")}${truncated}${" ".repeat(
      Math.max(0, innerWidth - visibleWidth(truncated)),
    )}${border("│")}`;
  };

  return [
    border(`╭${"─".repeat(innerWidth)}╮`),
    ...lines.map(frameLine),
    border(`╰${"─".repeat(innerWidth)}╯`),
  ];
}

function getWheelDirection(data: string): -1 | 1 | undefined {
  const sgr = data.startsWith("\x1b")
    ? /^\[<(\d+);\d+;\d+[Mm]$/.exec(data.slice(1))
    : undefined;
  if (sgr) {
    const button = Number.parseInt(sgr[1]!, 10);
    if ((button & 64) === 0) return undefined;
    const direction = button & 3;
    return direction === 0 ? -1 : direction === 1 ? 1 : undefined;
  }

  if (data.length === 6 && data.startsWith("\x1b[M")) {
    const button = data.charCodeAt(3) - 32;
    if ((button & 64) === 0) return undefined;
    const direction = button & 3;
    return direction === 0 ? -1 : direction === 1 ? 1 : undefined;
  }

  return undefined;
}

function isMermaidToken(token: MermaidToken): boolean {
  return (
    token.type === "code" &&
    token.lang?.trim().split(/\s+/, 1)[0]?.toLowerCase() === "mermaid"
  );
}

function codeSpan(line: string): string {
  // Inline code preserves box drawing, leading spaces, and blank diagram rows.
  const content = line || "\u00a0";
  const longestBacktickRun = Math.max(
    0,
    ...Array.from(content.matchAll(/`+/g), (match) => match[0].length),
  );
  const fence = "`".repeat(longestBacktickRun + 1);
  const padding = content.startsWith("`") || content.endsWith("`") ? " " : "";
  return `${fence}${padding}${content}${padding}${fence}`;
}

function styleMermaidSpan(span: MermaidSpan, theme: Theme): string {
  switch (span.cls) {
    case "border":
      return theme.fg("borderMuted", span.text);
    case "text":
      return theme.fg("text", span.text);
    case "edge":
      return theme.fg("accent", span.text);
    case "edgeLabel":
      return theme.fg("muted", span.text);
    case "title":
      return theme.fg("accent", theme.bold(span.text));
    case "none":
      return span.text;
  }
}

function renderMermaidMarkdown(
  markdown: string,
  availableWidth: number,
  theme: Theme,
  mode: MermaidRenderingMode,
  renderer: MermaidRenderer | undefined,
): string {
  if (mode === "off" || !renderer) return markdown;

  return (mermaidParser.lexer(markdown) as MermaidToken[])
    .map((token) => {
      if (!isMermaidToken(token)) return token.raw;

      const art = renderer(token.text ?? "");
      if (!art) return token.raw;
      if (art.width > availableWidth) {
        const warning = `Mermaid diagram needs ${art.width} columns; preview has ${availableWidth}.`;
        return `${token.raw}\n${codeSpan(theme.fg("warning", warning))}  \n`;
      }

      // Match Pi's final-message behavior: a warning means the source was only
      // partially understood, so retain the original Mermaid for correction.
      if (art.warnings.length > 0) {
        const suffix =
          art.warnings.length > 1 ? ` (+${art.warnings.length - 1} more)` : "";
        const warning = `Mermaid diagram not rendered: ${art.warnings[0]}${suffix}`;
        return `${token.raw}\n${codeSpan(theme.fg("warning", warning))}  \n`;
      }

      const lines = art.styled.map((row) =>
        row.map((span) => styleMermaidSpan(span, theme)).join(""),
      );
      // Markdown hard breaks retain each Unicode-art row independently.
      return `${lines.map(codeSpan).join("  \n")}\n`;
    })
    .join("");
}

class MarkdownPreview implements Component {
  private readonly markdown: Markdown;
  private renderedWidth: number | undefined;
  private lines: string[] = [];
  private offset = 0;

  constructor(
    private readonly file: MarkdownFile,
    private readonly cwd: string,
    private readonly tui: { terminal: { rows: number }; requestRender(): void },
    private readonly theme: Theme,
    private readonly keybindings: KeybindingsManager,
    private readonly mermaidRenderingMode: MermaidRenderingMode,
    private readonly mermaidRenderer: MermaidRenderer | undefined,
    private readonly done: () => void,
  ) {
    this.markdown = new Markdown(
      file.content,
      1,
      0,
      getMarkdownTheme(),
      undefined,
      {
        transform: (markdown, availableWidth) =>
          renderMermaidMarkdown(
            markdown,
            availableWidth,
            this.theme,
            this.mermaidRenderingMode,
            this.mermaidRenderer,
          ),
      },
    );
  }

  private get maxRows(): number {
    const terminalRows = this.tui.terminal.rows;
    return Math.max(
      6,
      Math.min(Math.max(6, terminalRows - 2), Math.floor(terminalRows * 0.9)),
    );
  }

  private get bodyHeight(): number {
    // Frame, title, path, two dividers, help, and closing frame consume seven rows.
    return Math.max(1, this.maxRows - 7);
  }

  private getLines(width: number): string[] {
    if (this.renderedWidth !== width) {
      this.lines = this.markdown.render(width);
      this.renderedWidth = width;
    }
    return this.lines;
  }

  private clampOffset(totalLines: number): void {
    this.offset = Math.max(
      0,
      Math.min(this.offset, Math.max(0, totalLines - this.bodyHeight)),
    );
  }

  private scrollBy(lines: number): void {
    this.offset += lines;
    this.clampOffset(this.lines.length);
    this.tui.requestRender();
  }

  handleInput(data: string): void {
    const wheelDirection = getWheelDirection(data);
    if (wheelDirection) {
      this.scrollBy(wheelDirection * 3);
      return;
    }

    if (
      this.keybindings.matches(data, "tui.select.cancel") ||
      matchesKey(data, Key.escape) ||
      matchesKey(data, Key.ctrl("c")) ||
      matchesKey(data, "q")
    ) {
      this.done();
      return;
    }

    if (
      this.keybindings.matches(data, "tui.select.up") ||
      matchesKey(data, Key.up) ||
      matchesKey(data, "k")
    ) {
      this.scrollBy(-1);
      return;
    }

    if (
      this.keybindings.matches(data, "tui.select.down") ||
      matchesKey(data, Key.down) ||
      matchesKey(data, "j")
    ) {
      this.scrollBy(1);
      return;
    }

    if (
      this.keybindings.matches(data, "tui.altScreen.pageUp") ||
      matchesKey(data, Key.pageUp)
    ) {
      this.scrollBy(-this.bodyHeight);
      return;
    }

    if (
      this.keybindings.matches(data, "tui.altScreen.pageDown") ||
      matchesKey(data, Key.pageDown)
    ) {
      this.scrollBy(this.bodyHeight);
      return;
    }

    if (
      this.keybindings.matches(data, "tui.altScreen.top") ||
      matchesKey(data, Key.home)
    ) {
      this.offset = 0;
      this.tui.requestRender();
      return;
    }

    if (
      this.keybindings.matches(data, "tui.altScreen.bottom") ||
      matchesKey(data, Key.end)
    ) {
      this.offset = Math.max(0, this.lines.length - this.bodyHeight);
      this.tui.requestRender();
    }
  }

  render(width: number): string[] {
    const contentWidth = Math.max(1, width - 2);
    const lines = this.getLines(contentWidth);
    this.clampOffset(lines.length);

    const firstLine = lines.length === 0 ? 0 : this.offset + 1;
    const lastLine = Math.min(lines.length, this.offset + this.bodyHeight);
    const source = displayPath(this.file.path, this.cwd);
    const title = this.theme.fg("accent", this.theme.bold("Markdown Preview"));
    const position = this.theme.fg(
      "dim",
      `Lines ${firstLine}–${lastLine} / ${lines.length}`,
    );
    const divider = this.theme.fg(
      "borderMuted",
      "─".repeat(Math.max(1, contentWidth)),
    );
    const help = this.theme.fg(
      "dim",
      "↑↓/j k scroll • PgUp/PgDn page • Home/End bounds • Esc close",
    );
    const body =
      lines.length > 0
        ? lines.slice(this.offset, lastLine)
        : [this.theme.fg("dim", "  (empty file)")];

    return frameLines(
      [
        truncateToWidth(title, contentWidth),
        truncateToWidth(this.theme.fg("muted", source), contentWidth),
        divider,
        ...body,
        divider,
        truncateToWidth(
          position + this.theme.fg("dim", " • ") + help,
          contentWidth,
        ),
      ],
      width,
      this.theme,
    );
  }

  invalidate(): void {
    this.markdown.invalidate();
    this.renderedWidth = undefined;
  }
}

class InlineMarkdownPreview implements Component {
  private readonly markdown: Markdown;

  constructor(
    private readonly entry: MarkdownPreviewEntry,
    private readonly theme: Theme,
    mermaidRenderer: MermaidRenderer | undefined,
  ) {
    this.markdown = new Markdown(
      entry.content,
      1,
      0,
      getMarkdownTheme(),
      undefined,
      {
        transform: (markdown, availableWidth) =>
          renderMermaidMarkdown(
            markdown,
            availableWidth,
            this.theme,
            entry.mermaidRenderingMode,
            mermaidRenderer,
          ),
      },
    );
  }

  render(width: number): string[] {
    const contentWidth = Math.max(1, width - 2);
    const title = this.theme.fg(
      "accent",
      this.theme.bold(`Markdown: ${this.entry.path}`),
    );
    const divider = this.theme.fg(
      "borderMuted",
      "─".repeat(Math.max(1, contentWidth)),
    );

    return frameLines(
      [
        truncateToWidth(title, contentWidth),
        divider,
        ...this.markdown.render(contentWidth),
      ],
      width,
      this.theme,
    );
  }

  invalidate(): void {
    this.markdown.invalidate();
  }
}

class MarkdownPicker implements Component {
  private readonly input = new Input();
  private list: SelectList;

  constructor(
    private readonly candidates: MarkdownCandidate[],
    private readonly truncated: boolean,
    private readonly tui: { terminal: { rows: number }; requestRender(): void },
    private readonly theme: Theme,
    private readonly keybindings: KeybindingsManager,
    private readonly done: (selection: string | undefined) => void,
  ) {
    this.list = this.createList();
  }

  get focused(): boolean {
    return this.input.focused;
  }

  set focused(value: boolean) {
    this.input.focused = value;
  }

  private createList(): SelectList {
    const query = this.input.getValue();
    const matches = fuzzyFilter(
      this.candidates,
      query,
      (candidate) => candidate.label,
    );
    const visibleRows = Math.max(5, Math.min(15, this.tui.terminal.rows - 7));
    const list = new SelectList(matches, visibleRows, {
      selectedPrefix: (text) => this.theme.fg("accent", text),
      selectedText: (text) => this.theme.fg("accent", text),
      description: (text) => this.theme.fg("muted", text),
      scrollInfo: (text) => this.theme.fg("dim", text),
      noMatch: (text) => this.theme.fg("warning", text),
    });
    list.onSelect = (candidate) => this.done(candidate.value);
    list.onCancel = () => this.done(undefined);
    return list;
  }

  private updateList(): void {
    this.list = this.createList();
  }

  handleInput(data: string): void {
    if (this.keybindings.matches(data, "tui.select.cancel")) {
      this.done(undefined);
      return;
    }

    if (
      this.keybindings.matches(data, "tui.select.up") ||
      this.keybindings.matches(data, "tui.select.down") ||
      this.keybindings.matches(data, "tui.select.pageUp") ||
      this.keybindings.matches(data, "tui.select.pageDown")
    ) {
      this.list.handleInput(data);
    } else if (this.keybindings.matches(data, "tui.select.confirm")) {
      const selected = this.list.getSelectedItem();
      if (selected) this.done(selected.value);
    } else {
      this.input.handleInput(data);
      this.updateList();
    }

    this.tui.requestRender();
  }

  render(width: number): string[] {
    const contentWidth = Math.max(1, width - 2);
    const title = this.theme.fg(
      "accent",
      this.theme.bold("Select Markdown file"),
    );
    const count = this.truncated
      ? `Showing the first ${MAX_PICKER_FILES.toLocaleString()} files`
      : `${this.candidates.length.toLocaleString()} Markdown files`;
    const help = "Type to filter • ↑↓ navigate • Enter open • Esc cancel";

    return frameLines(
      [
        truncateToWidth(title, contentWidth),
        truncateToWidth(this.theme.fg("dim", count), contentWidth),
        ...this.input.render(contentWidth),
        ...this.list.render(contentWidth),
        truncateToWidth(this.theme.fg("dim", help), contentWidth),
      ],
      width,
      this.theme,
    );
  }

  invalidate(): void {
    this.input.invalidate();
    this.list.invalidate();
  }
}

async function showPreview(
  file: MarkdownFile,
  mermaidRenderingMode: MermaidRenderingMode,
  mermaidRenderer: MermaidRenderer | undefined,
  ctx: ExtensionCommandContext,
): Promise<void> {
  await ctx.ui.custom<void>(
    (tui, theme, keybindings, done) =>
      new MarkdownPreview(
        file,
        ctx.cwd,
        tui,
        theme,
        keybindings,
        mermaidRenderingMode,
        mermaidRenderer,
        () => done(undefined),
      ),
    {
      overlay: true,
      overlayOptions: {
        anchor: "center",
        width: "100%",
        minWidth: 40,
        maxHeight: "90%",
        margin: 1,
      },
    },
  );
}

function appendInlinePreview(
  pi: ExtensionAPI,
  file: MarkdownFile,
  mermaidRenderingMode: MermaidRenderingMode,
): void {
  pi.appendEntry<MarkdownPreviewEntry>(MARKDOWN_PREVIEW_ENTRY_TYPE, {
    path: file.path,
    content: file.content,
    mermaidRenderingMode,
  });
}

async function showPicker(
  candidates: MarkdownCandidate[],
  truncated: boolean,
  ctx: ExtensionCommandContext,
): Promise<string | undefined> {
  return ctx.ui.custom<string | undefined>(
    (tui, theme, keybindings, done) =>
      new MarkdownPicker(candidates, truncated, tui, theme, keybindings, done),
    {
      overlay: true,
      overlayOptions: {
        anchor: "center",
        width: "80%",
        minWidth: 40,
        maxHeight: "85%",
        margin: 1,
      },
    },
  );
}

async function getPathCompletions(
  prefix: string,
  cwd: string,
): Promise<AutocompleteItem[] | null> {
  const input = normalizePathArgument(prefix);
  const expandedInput = expandHome(input);
  const endsInSeparator =
    expandedInput.endsWith(sep) || expandedInput.endsWith("/");
  const suppliedDirectory = endsInSeparator
    ? expandedInput
    : dirname(expandedInput);
  const searchDirectory = isAbsolute(suppliedDirectory)
    ? suppliedDirectory
    : resolve(cwd, suppliedDirectory === "." ? "" : suppliedDirectory);
  const namePrefix = endsInSeparator
    ? ""
    : basename(expandedInput).toLowerCase();

  let entries;
  try {
    entries = await readdir(searchDirectory, { withFileTypes: true });
  } catch {
    return null;
  }

  const base = isAbsolute(expandedInput)
    ? searchDirectory
    : suppliedDirectory === "."
      ? ""
      : suppliedDirectory;
  const items: AutocompleteItem[] = [];
  for (const entry of entries) {
    if (
      !entry.isDirectory() &&
      (!entry.isFile() || !isMarkdownPath(entry.name))
    )
      continue;
    if (namePrefix && !entry.name.toLowerCase().includes(namePrefix)) continue;

    const suffix = entry.isDirectory() ? "/" : "";
    const value = base
      ? `${base.replace(/[\\/]$/, "")}/${entry.name}${suffix}`
      : `${entry.name}${suffix}`;
    items.push({ value, label: `${entry.name}${suffix}` });
  }

  const matches = fuzzyFilter(items, namePrefix, (item) => item.label);
  return matches.slice(0, MAX_COMPLETIONS);
}

async function loadMermaidRenderer(): Promise<MermaidRenderer | undefined> {
  try {
    // Pi bundles grok-mermaid for its transcript renderer but does not expose
    // it as an extension virtual module. Resolve it relative to Pi itself.
    const modulePath = join(
      getPackageDir(),
      "node_modules",
      "grok-mermaid",
      "dist",
      "index.js",
    );
    const module = (await import(pathToFileURL(modulePath).href)) as {
      render?: MermaidRenderer;
    };
    return module.render;
  } catch {
    return undefined;
  }
}

export default async function markdownViewerExtension(pi: ExtensionAPI) {
  let currentCwd = process.cwd();
  const mermaidRenderer = await loadMermaidRenderer();

  pi.on("session_start", (_event, ctx: ExtensionContext) => {
    currentCwd = ctx.cwd;
  });

  pi.registerEntryRenderer<MarkdownPreviewEntry>(
    MARKDOWN_PREVIEW_ENTRY_TYPE,
    (entry, _options, theme) => {
      const preview = entry.data;
      if (
        !preview ||
        typeof preview.path !== "string" ||
        typeof preview.content !== "string"
      ) {
        return new Text(
          theme.fg("error", "Invalid Markdown preview entry"),
          0,
          0,
        );
      }
      return new InlineMarkdownPreview(preview, theme, mermaidRenderer);
    },
  );

  const registerPreviewCommand = (
    name: string,
    description: string,
    destination: PreviewDestination,
  ) => {
    pi.registerCommand(name, {
      description,
      getArgumentCompletions: (prefix) =>
        getPathCompletions(prefix, currentCwd),
      handler: async (args, ctx) => {
        if (ctx.mode !== "tui") {
          ctx.ui.notify(`/${name} requires interactive TUI mode`, "error");
          return;
        }

        await ctx.waitForIdle();
        const requestedPath = normalizePathArgument(args);

        if (!requestedPath) {
          ctx.ui.notify("Finding Markdown files…", "info");
          const { candidates, truncated } = await discoverMarkdownFiles(
            ctx.cwd,
          );
          if (candidates.length === 0) {
            ctx.ui.notify(
              "No Markdown files found in the current project",
              "info",
            );
            return;
          }

          const selectedPath = await showPicker(candidates, truncated, ctx);
          if (!selectedPath) return;
          await openPreview(
            selectedPath,
            destination,
            pi,
            mermaidRenderer,
            ctx,
          );
          return;
        }

        await openPreview(requestedPath, destination, pi, mermaidRenderer, ctx);
      },
    });
  };

  registerPreviewCommand(
    "md",
    "Render Markdown inline in the transcript, or fuzzy-pick a project file",
    "inline",
  );
  registerPreviewCommand(
    "md-popup",
    "Preview Markdown in a popup, or fuzzy-pick a project file",
    "popup",
  );
}

async function openPreview(
  path: string,
  destination: PreviewDestination,
  pi: ExtensionAPI,
  mermaidRenderer: MermaidRenderer | undefined,
  ctx: ExtensionCommandContext,
): Promise<void> {
  try {
    const file = await loadMarkdownFile(path, ctx.cwd);
    const mermaidRenderingMode = await getMermaidRenderingMode(ctx);

    if (destination === "inline") {
      appendInlinePreview(pi, file, mermaidRenderingMode);
      return;
    }

    await showPreview(file, mermaidRenderingMode, mermaidRenderer, ctx);
  } catch (error) {
    ctx.ui.notify(formatError(error, path), "error");
  }
}
