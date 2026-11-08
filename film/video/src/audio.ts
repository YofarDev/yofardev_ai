// The sound edit: which stretch of which run's voice/foley plays where on the
// film's clock. Font-free: scripts/edl.ts prints it for film/tools/mixfilm.py.
import { sections } from "./sections";
import { finalePlan, journeyPlan, LISTEN_BASE, toolsPlan, wardrobePlan } from "./plans";

export type Region = {
  tag: string;
  /** film frame the region starts at */
  at: number;
  /** the run's clock at that frame */
  atMs: number;
  frames: number;
  voice: number; // gain
  foley: number;
  /** ambient bed (asset name) and level, if any */
  bed?: string;
  bedLevel?: number;
  /** playback speed of the picture (voice/foley are muted when not 1) */
  rate?: number;
};

export type Hit = { at: number; kind: "whoosh" | "boom" | "riser" | "shimmer" | "tick"; gain: number };

export function regions(): Region[] {
  const s = Object.fromEntries(sections().map((x) => [x.id, x]));
  const out: Region[] = [];
  const add = (r: Region) => out.push(r);
  // cold open: the room's idle (no voice) from bar 3 under the phone
  add({ tag: "film_hello", at: s.cold.from + 300, atMs: Math.max(0, LISTEN_BASE() + 1400 - 5200), frames: 300, voice: 0, foley: 0.6 });
  // listen: one continuous take
  add({ tag: "film_hello", at: s.listen.from, atMs: LISTEN_BASE(), frames: s.listen.dur, voice: 1, foley: 0.8 });
  // tools: the cut segments
  for (const g of toolsPlan().segs) {
    const r = g.rate ?? 1;
    add({ tag: "film_hello", at: s.tools.from + g.from, atMs: g.atMs, frames: g.dur, voice: r === 1 ? 1 : 0, foley: r === 1 ? 0.8 : 0, rate: r });
  }
  // wardrobe: each costume's line while its phone is lit
  for (const p of wardrobePlan()) {
    add({ tag: "film_wardrobe", at: s.wardrobe.from + p.at, atMs: p.atMs + (p.at / 60) * 1000, frames: p.len + 30, voice: 1, foley: 0.7 });
  }
  // journey
  for (const g of journeyPlan().segs) {
    add({ tag: "wow3", at: s.journey.from + g.from, atMs: g.atMs, frames: g.dur, voice: 1, foley: 1, bed: "bed_wind", bedLevel: 0.25 });
  }
  // finale
  for (const g of finalePlan().segs) {
    const r = g.rate ?? 1;
    add({ tag: "film_goodnight", at: s.finale.from + g.from, atMs: g.atMs, frames: g.dur, voice: r === 1 ? 1 : 0, foley: r === 1 ? 0.8 : 0, rate: r, bed: "bed_wind", bedLevel: 0.3 });
  }
  return out;
}

export function hits(): Hit[] {
  const s = Object.fromEntries(sections().map((x) => [x.id, x]));
  return [
    { at: s.title.from - 150, kind: "riser", gain: 0.5 },
    { at: s.title.from, kind: "boom", gain: 0.9 },
    { at: s.title.from, kind: "shimmer", gain: 0.5 },
    { at: s.listen.from, kind: "whoosh", gain: 0.35 },
    { at: s.tools.from, kind: "whoosh", gain: 0.45 },
    { at: s.wardrobe.from, kind: "whoosh", gain: 0.4 },
    { at: s.journey.from, kind: "whoosh", gain: 0.4 },
    { at: s.world.from - 150, kind: "riser", gain: 0.6 },
    { at: s.world.from, kind: "boom", gain: 1 },
    { at: s.hood.from, kind: "whoosh", gain: 0.5 },
    { at: s.finale.from, kind: "whoosh", gain: 0.35 },
    { at: s.finale.from + finalePlan().card, kind: "shimmer", gain: 0.6 },
  ];
}
