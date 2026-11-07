import raw from "./events.json";

export type Ev = { ms: number; type: string; text?: string; name?: string; label?: string; x?: number; y?: number };
type Run = { events: Ev[]; duration: number; audio: string[] };
const RUNS = raw as unknown as Record<string, Run>;

/** The ms of the nth event of `type` in run `tag` (optionally matching
 * `name`), or `fallback` while the run is not captured/indexed yet. */
export function ev(
  tag: string,
  type: string,
  n = 0,
  fallback = 0,
  name?: string,
): number {
  const run = RUNS[tag];
  if (!run) return fallback;
  const list = run.events.filter((e) => e.type === type && (name === undefined || e.name === name || e.label === name));
  const e = n < 0 ? list[list.length + n] : list[n];
  return e ? e.ms : fallback;
}

export const captured = (tag: string) => tag in RUNS;
export const runDuration = (tag: string, fallback = 60000) => RUNS[tag]?.duration ? RUNS[tag].duration * 1000 : fallback;

/** The first event of `type` at or after `ms` (fallback if none). */
export function after(tag: string, type: string, ms: number, fallback = ms): number {
  const run = RUNS[tag];
  if (!run) return fallback;
  const e = run.events.find((x) => x.type === type && x.ms >= ms);
  return e ? e.ms : fallback;
}

/** The last event of `type` at or before `ms`. */
export function before(tag: string, type: string, ms: number, fallback = ms): number {
  const run = RUNS[tag];
  if (!run) return fallback;
  const list = run.events.filter((x) => x.type === type && x.ms <= ms);
  return list.length ? list[list.length - 1].ms : fallback;
}

/** The ms a turn (by label) starts / ends (`turn` / `turnEnd` events). */
export const turnAt = (tag: string, label: string, fallback = 0) => ev(tag, "turn", 0, fallback, label);
export const turnEnd = (tag: string, label: string, fallback = 0) => ev(tag, "turnEnd", 0, fallback, label);

/** Every indexed event of run `tag` ([] while not captured). */
export const events = (tag: string): Ev[] => RUNS[tag]?.events ?? [];
