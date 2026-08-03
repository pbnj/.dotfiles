/**
 * Model MRU
 *
 * Tracks successfully selected models globally. Ctrl+J and Ctrl+K cycle
 * forward and backward through every eligible model configuration in MRU order.
 *
 * Command:
 *   /mru-model   Open a fuzzy picker with two tabs, switched with `tab`:
 *
 *     MRU models  enter    select the configuration
 *                 ctrl+x   forget the highlighted entry
 *                 ctrl+a   forget every entry
 *     All models  enter    pick a reasoning level and add it to the history
 *
 * State lives in <agentDir>/model-mru.json, rather than the session, so the
 * history survives new sessions and is shared by all projects.
 */

import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import type { Model } from "@earendil-works/pi-ai";
import {
  getAgentDir,
  type ExtensionAPI,
  type ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import {
  fuzzyFilter,
  Input,
  matchesKey,
  type SelectItem,
  SelectList,
  truncateToWidth,
} from "@earendil-works/pi-tui";

const STATE_FILE = join(getAgentDir(), "model-mru.json");
const MAX_MODELS = 20;

type ThinkingLevel =
  | "off"
  | "minimal"
  | "low"
  | "medium"
  | "high"
  | "xhigh"
  | "max";

type ModelReference = {
  provider: string;
  id: string;
  // Optional for compatibility with the first version of this extension.
  thinkingLevel?: ThinkingLevel;
};

type State = {
  version: 2;
  models: ModelReference[];
};

type CycleState = {
  entries: ModelReference[];
  index: number;
  // The configuration selected by the most recent Ctrl+J/Ctrl+K action.
  // Its model/thinking events must not reset the cycle.
  target?: string;
};

type PickerTab = "mru" | "all";

type PickerAction =
  | { kind: "select"; key: string }
  | { kind: "delete"; key: string }
  | { kind: "clear" }
  | { kind: "add"; modelKey: string };

type PickerState = {
  tab: PickerTab;
  query: string;
};

type PickerResult = {
  // `undefined` means the user closed the picker.
  action: PickerAction | undefined;
  state: PickerState;
};

const THINKING_LEVELS = new Set<ThinkingLevel>([
  "off",
  "minimal",
  "low",
  "medium",
  "high",
  "xhigh",
  "max",
]);

function modelKey(model: Pick<Model<any>, "provider" | "id">): string {
  return `${model.provider}/${model.id}`;
}

function entryKey(model: ModelReference): string {
  return `${modelKey(model)}:${model.thinkingLevel ?? "current"}`;
}

function currentReference(
  model: Pick<Model<any>, "provider" | "id">,
  thinkingLevel: ThinkingLevel | undefined,
): ModelReference {
  return {
    provider: model.provider,
    id: model.id,
    thinkingLevel: thinkingLevel ?? "off",
  };
}

function parseState(value: unknown): ModelReference[] {
  if (
    !value ||
    typeof value !== "object" ||
    !Array.isArray((value as State).models)
  )
    return [];

  const seen = new Set<string>();
  const models: ModelReference[] = [];
  for (const model of (value as State).models) {
    if (
      !model ||
      typeof model.provider !== "string" ||
      typeof model.id !== "string"
    )
      continue;
    const thinkingLevel = THINKING_LEVELS.has(
      model.thinkingLevel as ThinkingLevel,
    )
      ? (model.thinkingLevel as ThinkingLevel)
      : undefined;
    const entry = { provider: model.provider, id: model.id, thinkingLevel };
    if (!entry.provider || !entry.id || seen.has(entryKey(entry))) continue;
    seen.add(entryKey(entry));
    models.push(entry);
    if (models.length === MAX_MODELS) break;
  }
  return models;
}

export default function modelMruExtension(pi: ExtensionAPI) {
  let mru: ModelReference[] = [];
  let loading: Promise<void> | undefined;
  let loaded = false;
  let pendingSelection: ModelReference | undefined;
  let cycle: CycleState | undefined;
  let selectableModels = new Map<string, Model<any>>();
  let saveQueue: Promise<void> = Promise.resolve();
  let saveSequence = 0;
  // Keep an explicitly forgotten active entry from being re-added by passive
  // MRU bookkeeping until the user selects or adds it again.
  const forgottenModelKeys = new Set<string>();
  // Selection events can already be awaiting load() when a delete starts.
  const forgetGenerations = new Map<string, number>();

  async function load(): Promise<void> {
    if (loaded) return;
    if (loading) return loading;

    loading = (async () => {
      try {
        mru = parseState(JSON.parse(await readFile(STATE_FILE, "utf8")));
      } catch (error: unknown) {
        // A missing state file is the normal first-run case. Do not discard a
        // malformed file silently, since it may be useful to repair it manually.
        if ((error as NodeJS.ErrnoException).code !== "ENOENT") {
          console.warn(
            `[model-mru] Could not read ${STATE_FILE}: ${String(error)}`,
          );
        }
      }
      loaded = true;
    })();

    try {
      await loading;
    } finally {
      loading = undefined;
    }
  }

  function save(): Promise<void> {
    const state: State = {
      version: 2,
      models: mru.map((entry) => ({ ...entry })),
    };
    const temporaryFile = `${STATE_FILE}.${process.pid}.${saveSequence++}.tmp`;
    const write = async (): Promise<void> => {
      try {
        await mkdir(dirname(STATE_FILE), { recursive: true });
        await writeFile(
          temporaryFile,
          `${JSON.stringify(state, null, 2)}\n`,
          "utf8",
        );
        await rename(temporaryFile, STATE_FILE);
      } catch (error) {
        console.warn(
          `[model-mru] Could not save ${STATE_FILE}: ${String(error)}`,
        );
      }
    };

    // Model-selection events are fire-and-forget in pi. Serialize snapshots so
    // a stale save from an event cannot overwrite a later deletion.
    saveQueue = saveQueue.then(write);
    return saveQueue;
  }

  function remember(model: ModelReference): boolean {
    const key = entryKey(model);
    const previous = mru;
    mru = [
      { ...model },
      ...mru.filter((entry) => entryKey(entry) !== key),
    ].slice(0, MAX_MODELS);
    return (
      previous.length !== mru.length ||
      previous.some((entry, index) => entryKey(entry) !== entryKey(mru[index]))
    );
  }

  function resetCycle(): void {
    cycle = undefined;
  }

  function forgetKey(key: string): void {
    forgottenModelKeys.add(key);
    forgetGenerations.set(key, (forgetGenerations.get(key) ?? 0) + 1);
  }

  function forgetGeneration(key: string): number {
    return forgetGenerations.get(key) ?? 0;
  }

  function rememberIfNotForgotten(reference: ModelReference): boolean {
    return forgottenModelKeys.has(entryKey(reference))
      ? false
      : remember(reference);
  }

  function eligibleModels(ctx: ExtensionContext): Map<string, Model<any>> {
    const scoped =
      ctx.scopedModels.length > 0
        ? new Set(ctx.scopedModels.map(({ model }) => modelKey(model)))
        : undefined;
    return new Map(
      ctx.modelRegistry
        .getAvailable()
        .filter((model) => !scoped || scoped.has(modelKey(model)))
        .map((model) => [modelKey(model), model]),
    );
  }

  function refreshSelectableModels(ctx: ExtensionContext): void {
    selectableModels = eligibleModels(ctx);
  }

  function thinkingLevelsFor(model: Model<any>): ThinkingLevel[] {
    return model.reasoning
      ? ["off", "minimal", "low", "medium", "high", "xhigh", "max"]
      : ["off"];
  }

  async function switchTo(
    reference: ModelReference,
    model: Model<any>,
    ctx: ExtensionContext,
    preserveCycle = false,
  ): Promise<boolean> {
    // Model and thinking events are separate. Keep the intended pair while
    // switching so an intermediate effort does not become its own MRU entry.
    if (preserveCycle) {
      if (cycle) cycle.target = entryKey(reference);
    } else {
      resetCycle();
    }
    pendingSelection = reference;
    const success = await pi.setModel(model);
    if (!success) {
      pendingSelection = undefined;
      resetCycle();
      ctx.ui.notify(
        `Cannot select ${modelKey(model)}: no configured credentials`,
        "error",
      );
      return false;
    }

    if (reference.thinkingLevel) {
      pi.setThinkingLevel(reference.thinkingLevel);
      const actual = pi.getThinkingLevel();
      if (actual !== reference.thinkingLevel) {
        ctx.ui.notify(
          `${modelKey(model)} does not support ${reference.thinkingLevel}; using ${actual}`,
          "warning",
        );
      }
    }
    pendingSelection = undefined;
    forgottenModelKeys.delete(entryKey(reference));
    return true;
  }

  async function cycleMru(
    ctx: ExtensionContext,
    direction: 1 | -1,
  ): Promise<void> {
    await load();
    if (!ctx.model) {
      ctx.ui.notify("No active model to switch from", "warning");
      return;
    }

    const current = currentReference(ctx.model, ctx.thinkingLevel);
    const currentKey = entryKey(current);
    if (rememberIfNotForgotten(current)) await save();
    const eligible = eligibleModels(ctx);

    if (
      !cycle ||
      cycle.entries[cycle.index] === undefined ||
      entryKey(cycle.entries[cycle.index]) !== currentKey
    ) {
      const entries = mru.filter((entry) => eligible.has(modelKey(entry)));
      const index = entries.findIndex(
        (entry) => entryKey(entry) === currentKey,
      );
      if (index === -1) entries.unshift(current);
      cycle = { entries, index: index === -1 ? 0 : index };
    }

    if (cycle.entries.length < 2) {
      ctx.ui.notify("No other eligible MRU model configuration", "info");
      return;
    }

    for (let attempts = 0; attempts < cycle.entries.length; attempts++) {
      cycle.index =
        (cycle.index + direction + cycle.entries.length) % cycle.entries.length;
      const reference = cycle.entries[cycle.index];
      const model = eligible.get(modelKey(reference));
      if (model) {
        await switchTo(reference, model, ctx, true);
        return;
      }
    }

    ctx.ui.notify("No other eligible MRU model configuration", "info");
  }

  async function add(
    reference: ModelReference,
    ctx: ExtensionContext,
  ): Promise<void> {
    refreshSelectableModels(ctx);
    if (!selectableModels.has(modelKey(reference))) {
      ctx.ui.notify(
        `Cannot add unavailable model ${modelKey(reference)}`,
        "error",
      );
      return;
    }
    resetCycle();
    forgottenModelKeys.delete(entryKey(reference));
    if (remember(reference)) await save();
    ctx.ui.notify(`Added ${entryKey(reference)}`, "info");
  }

  // Deleting the active configuration has to move the session off it. pi
  // persists the active model and thinking level in the session and replays
  // them as `model_select` on restore, so an entry that stays selected is
  // re-added to the MRU as soon as the session is resumed.
  async function switchAwayFrom(
    reference: ModelReference,
    ctx: ExtensionContext,
  ): Promise<boolean> {
    const key = entryKey(reference);
    const eligible = eligibleModels(ctx);
    const replacement = mru.find(
      (entry) => entryKey(entry) !== key && eligible.has(modelKey(entry)),
    );
    if (!replacement) return false;
    return switchTo(replacement, eligible.get(modelKey(replacement))!, ctx);
  }

  async function remove(
    reference: ModelReference,
    ctx: ExtensionContext,
  ): Promise<void> {
    const key = entryKey(reference);
    if (!mru.some((entry) => entryKey(entry) === key)) {
      ctx.ui.notify(`No MRU model named ${key}`, "error");
      return;
    }

    const isActive =
      !!ctx.model &&
      entryKey(currentReference(ctx.model, ctx.thinkingLevel)) === key;
    let switched = false;
    if (isActive) {
      // May emit model_select / thinking_level_select, which mutate `mru`.
      switched = await switchAwayFrom(reference, ctx);
    }

    forgetKey(key);
    mru = mru.filter((entry) => entryKey(entry) !== key);
    resetCycle();
    await save();

    if (isActive && !switched) {
      ctx.ui.notify(
        `Forgot ${key}; it stays active because no other eligible MRU model is available`,
        "warning",
      );
      return;
    }
    ctx.ui.notify(
      switched
        ? `Forgot ${key}; switched to ${ctx.model ? entryKey(currentReference(ctx.model, ctx.thinkingLevel)) : "another model"}`
        : `Forgot ${key}`,
      "info",
    );
  }

  async function clearAll(ctx: ExtensionContext): Promise<void> {
    const forgotten = new Set(mru.map(entryKey));
    if (ctx.model) {
      forgotten.add(entryKey(currentReference(ctx.model, ctx.thinkingLevel)));
    }
    for (const key of forgotten) forgetKey(key);
    mru = [];
    resetCycle();
    await save();
    ctx.ui.notify("Cleared model MRU history", "info");
  }

  function mruItems(ctx: ExtensionContext): SelectItem[] {
    const eligible = eligibleModels(ctx);
    const currentKey = ctx.model
      ? entryKey(currentReference(ctx.model, ctx.thinkingLevel))
      : undefined;
    return mru.map((entry) => {
      const key = entryKey(entry);
      const model = eligible.get(modelKey(entry));
      const notes = [
        key === currentKey ? "current" : undefined,
        model ? undefined : "unavailable in this session",
        model && model.name !== model.id ? model.name : undefined,
      ].filter((note): note is string => note !== undefined);
      return {
        value: key,
        label: key,
        description: notes.length > 0 ? notes.join(" • ") : undefined,
      };
    });
  }

  function allModelItems(ctx: ExtensionContext): SelectItem[] {
    refreshSelectableModels(ctx);
    return [...selectableModels.entries()]
      .sort(([left], [right]) => left.localeCompare(right))
      .map(([key, model]) => ({
        value: key,
        label: key,
        description: model.name === model.id ? undefined : model.name,
      }));
  }

  // One picker drives every action, so it reopens after a destructive one and
  // keeps the tab and query the user was working with.
  function showPickerOnce(
    ctx: ExtensionContext,
    state: PickerState,
  ): Promise<PickerResult> {
    const tabs: { id: PickerTab; title: string }[] = [
      { id: "mru", title: "MRU models" },
      { id: "all", title: "All models" },
    ];
    const items: Record<PickerTab, SelectItem[]> = {
      mru: mruItems(ctx),
      all: allModelItems(ctx),
    };

    return ctx.ui.custom<PickerResult>((tui, theme, keybindings, done) => {
      let tab = state.tab;
      const input = new Input();
      input.setValue(state.query);
      let selectList: SelectList;

      const finish = (action: PickerAction | undefined) =>
        done({ action, state: { tab, query: input.getValue() } });

      const makeList = () => {
        const matches = fuzzyFilter(
          items[tab],
          input.getValue(),
          (item) => item.label,
        );
        selectList = new SelectList(matches, Math.min(matches.length, 10), {
          selectedPrefix: (text) => theme.fg("accent", text),
          selectedText: (text) => theme.fg("accent", text),
          description: (text) => theme.fg("muted", text),
          scrollInfo: (text) => theme.fg("dim", text),
          noMatch: (text) => theme.fg("warning", text),
        });
        selectList.onSelect = (item) => confirmItem(item.value);
      };

      const confirmItem = (key: string) =>
        finish(
          tab === "mru"
            ? { kind: "select", key }
            : { kind: "add", modelKey: key },
        );

      makeList();

      return {
        get focused() {
          return input.focused;
        },
        set focused(value: boolean) {
          input.focused = value;
        },
        render(width: number) {
          const tabBar = tabs
            .map(({ id, title }) =>
              id === tab
                ? theme.fg("accent", theme.bold(`[ ${title} ]`))
                : theme.fg("dim", `  ${title}  `),
            )
            .join(" ");
          const hint =
            tab === "mru"
              ? "tab switch • ↑↓ navigate • enter select • ctrl+x forget • ctrl+a forget all • esc close"
              : "tab switch • type to search • ↑↓ navigate • enter add • esc close";
          return [
            truncateToWidth(tabBar, width),
            truncateToWidth(theme.fg("dim", "Search:"), width),
            ...input.render(width),
            ...selectList.render(width),
            truncateToWidth(theme.fg("dim", hint), width),
          ];
        },
        invalidate() {
          input.invalidate();
          selectList.invalidate();
        },
        handleInput(data: string) {
          const selected = selectList.getSelectedItem();
          if (matchesKey(data, "tab")) {
            tab = tab === "mru" ? "all" : "mru";
            makeList();
          } else if (
            keybindings.matches(data, "tui.select.up") ||
            keybindings.matches(data, "tui.select.down") ||
            keybindings.matches(data, "tui.select.pageUp") ||
            keybindings.matches(data, "tui.select.pageDown")
          ) {
            selectList.handleInput(data);
          } else if (keybindings.matches(data, "tui.select.confirm")) {
            if (selected) confirmItem(selected.value);
          } else if (keybindings.matches(data, "tui.select.cancel")) {
            finish(undefined);
            // ctrl+x and ctrl+a are MRU-only so the All models tab keeps them
            // available as readline editing keys in the search field.
          } else if (tab === "mru" && matchesKey(data, "ctrl+x")) {
            if (selected) finish({ kind: "delete", key: selected.value });
          } else if (tab === "mru" && matchesKey(data, "ctrl+a")) {
            if (items.mru.length > 0) finish({ kind: "clear" });
          } else {
            input.handleInput(data);
            makeList();
          }
          tui.requestRender();
        },
      };
    });
  }

  async function showPicker(ctx: ExtensionContext): Promise<void> {
    await load();
    const current = ctx.model
      ? currentReference(ctx.model, ctx.thinkingLevel)
      : undefined;
    if (current && rememberIfNotForgotten(current)) await save();

    let state: PickerState = {
      tab: mru.length > 0 ? "mru" : "all",
      query: "",
    };
    for (;;) {
      const result = await showPickerOnce(ctx, state);
      state = result.state;
      const action = result.action;
      if (!action) return;

      if (action.kind === "select") {
        const reference = mru.find((entry) => entryKey(entry) === action.key);
        const eligible = eligibleModels(ctx);
        const model = reference ? eligible.get(modelKey(reference)) : undefined;
        if (!reference || !model) {
          ctx.ui.notify(
            `${action.key} is not available in this session`,
            "error",
          );
          continue;
        }
        await switchTo(reference, model, ctx);
        return;
      }

      if (action.kind === "add") {
        const model = selectableModels.get(action.modelKey);
        if (!model) continue;
        const thinkingLevel = await ctx.ui.select(
          `Reasoning level for ${action.modelKey}`,
          thinkingLevelsFor(model),
        );
        if (!thinkingLevel) continue;
        await add(currentReference(model, thinkingLevel as ThinkingLevel), ctx);
        return;
      }

      if (action.kind === "delete") {
        const reference = mru.find((entry) => entryKey(entry) === action.key);
        if (reference) await remove(reference, ctx);
        continue;
      }

      const confirmed = await ctx.ui.confirm(
        "Clear model MRU history",
        `Forget all ${mru.length} recent model configurations?`,
      );
      if (confirmed) await clearAll(ctx);
    }
  }

  async function recordSelection(reference: ModelReference): Promise<void> {
    const key = entryKey(reference);
    const forgetGenerationAtEvent = forgetGeneration(key);
    if (cycle?.target !== key) resetCycle();
    await load();
    if (forgetGeneration(key) !== forgetGenerationAtEvent) return;
    forgottenModelKeys.delete(key);
    if (remember(reference)) await save();
  }

  pi.on("model_select", async (event, ctx) => {
    refreshSelectableModels(ctx);
    await recordSelection(
      pendingSelection && modelKey(pendingSelection) === modelKey(event.model)
        ? pendingSelection
        : currentReference(event.model, ctx.thinkingLevel),
    );
  });

  pi.on("thinking_level_select", async (event, ctx) => {
    refreshSelectableModels(ctx);
    if (!ctx.model) return;
    await recordSelection(
      pendingSelection && modelKey(pendingSelection) === modelKey(ctx.model)
        ? pendingSelection
        : currentReference(ctx.model, event.level),
    );
  });

  pi.on("session_start", async (_event, ctx) => {
    resetCycle();
    refreshSelectableModels(ctx);
    await load();
    if (
      ctx.model &&
      rememberIfNotForgotten(currentReference(ctx.model, ctx.thinkingLevel))
    ) {
      await save();
    }
  });

  pi.registerShortcut("ctrl+j", {
    description: "Cycle MRU model configurations forward",
    handler: (ctx) => cycleMru(ctx, 1),
  });
  pi.registerShortcut("ctrl+k", {
    description: "Cycle MRU model configurations backward",
    handler: (ctx) => cycleMru(ctx, -1),
  });

  pi.registerCommand("mru-model", {
    description: "Select, add, or forget recent model configurations",
    handler: (_args, ctx) => showPicker(ctx),
  });
}
