export type WatchActionGroup = {
  label: string;
  url: string;
  events: string[];
  totalEvents: number;
  omitted: number;
};

export type WatchActionTask = {
  groups: WatchActionGroup[];
  eventCount: number;
};

type PendingGroup = {
  label: string;
  url: string;
  events: string[];
  seen: Set<string>;
  totalEvents: number;
};

const PR_EVENT = /^([\w.-]+\/[\w.-]+#([1-9]\d*)): (.+)$/;
const ACTIONABLE = /^(?:CI fail:|CI cancel:|THREAD |REPLY |REVIEW )/;
const DEFAULT_BATCH_MS = 400;
const DEFAULT_MAX_EVENTS_PER_PR = 20;

export class WatchActionQueue {
  private readonly pending = new Map<string, PendingGroup>();
  private timer: ReturnType<typeof setTimeout> | undefined;
  private readonly dispatch: (task: WatchActionTask) => void;
  private readonly batchMs: number;
  private readonly maxEventsPerPR: number;

  constructor(
    dispatch: (task: WatchActionTask) => void,
    batchMs = DEFAULT_BATCH_MS,
    maxEventsPerPR = DEFAULT_MAX_EVENTS_PER_PR,
  ) {
    this.dispatch = dispatch;
    this.batchMs = batchMs;
    this.maxEventsPerPR = maxEventsPerPR;
  }

  enqueue(message: string): boolean {
    const match = PR_EVENT.exec(message);
    if (!match || !ACTIONABLE.test(match[3]!)) return false;

    const label = match[1]!;
    const number = match[2]!;
    const event = match[3]!;
    let group = this.pending.get(label);
    if (!group) {
      group = {
        label,
        url: `https://github.com/${label.slice(0, label.lastIndexOf("#"))}/pull/${number}`,
        events: [],
        seen: new Set(),
        totalEvents: 0,
      };
      this.pending.set(label, group);
    }
    if (group.seen.has(event)) return true;
    group.seen.add(event);
    group.totalEvents++;
    if (group.events.length < this.maxEventsPerPR) group.events.push(event);

    if (!this.timer) this.timer = setTimeout(() => this.flush(), this.batchMs);
    return true;
  }

  cancel(): void {
    if (this.timer) clearTimeout(this.timer);
    this.timer = undefined;
    this.pending.clear();
  }

  private flush(): void {
    this.timer = undefined;
    if (this.pending.size === 0) return;

    const groups = [...this.pending.values()].map((group) => ({
      label: group.label,
      url: group.url,
      events: group.events,
      totalEvents: group.totalEvents,
      omitted: group.totalEvents - group.events.length,
    }));
    this.pending.clear();
    this.dispatch({
      groups,
      eventCount: groups.reduce((total, group) => total + group.totalEvents, 0),
    });
  }
}

export function formatWatchActionMessage(task: WatchActionTask): string {
  return task.groups.flatMap((group) => group.events).join("\n");
}
