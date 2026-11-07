// The film's sections on the bar grid. Footage-driven ones round up to whole
// bars (the music is composed to this table: scripts/sections.ts prints it).
import { BAR } from "./lib/consts";
import { finalePlan, journeyPlan, listenDur, toolsPlan, wardrobeBars, worldDur } from "./plans";

const bars = (frames: number) => Math.max(1, Math.ceil(frames / BAR));

export type Section = { id: string; bars: number; from: number; dur: number; startBar: number };

export function sections(): Section[] {
  const table: [string, number][] = [
    ["cold", 4],
    ["title", 2],
    ["listen", bars(listenDur())],
    ["tools", bars(toolsPlan().dur)],
    ["wardrobe", wardrobeBars()],
    ["journey", bars(journeyPlan().dur)],
    ["world", worldDur() / BAR],
    ["hood", 3],
    ["finale", finalePlan().cardBar + 2],
  ];
  let at = 0;
  return table.map(([id, b]) => {
    const s = { id, bars: b, from: at * BAR, dur: b * BAR, startBar: at + 1 };
    at += b;
    return s;
  });
}

export const total = () => sections().reduce((s, x) => s + x.dur, 0);
