// Every footage-driven timing of the edit, font-free so a Node script can
// print the section lengths for the music (scripts/sections.ts).
import { BAR, BEAT, SceneId } from "./lib/consts";
import { Seg } from "./lib/segtypes";
import { after, ev, events, turnAt } from "./data/events";

const f = (ms: number) => Math.round((ms / 1000) * 60);

/** The first exchange of the evening. Left: the phone. Right: it listens
 * (gaze on the caret, the lean), then it talks (voice, lip-sync). */
export const LISTEN_BASE = () => ev("film_hello", "typing", 0, 6500) - 700;
export const listenDur = () => f(ev("film_hello", "stop", 1, 17200) + 900 - LISTEN_BASE());


const TH = "film_hello";
/** One tool turn cut: the request and the prop coming out, then each spoken
 * sentence (gaps over 900 ms between sentences are cut out). */
function turnCut(label: string, fallbackTurn: number, skipFirst = false) {
  const turn = turnAt(TH, label, fallbackTurn);
  const typing = after(TH, "typing", turn, turn + 1500);
  const send = after(TH, "send", typing, typing + 2600);
  const next = after(TH, "typing", send, 1e9); // the next turn (or none)
  const starts = events(TH).filter((e) => e.type === "start" && e.ms > send && e.ms < next).map((e) => e.ms);
  const stops = events(TH).filter((e) => e.type === "stop" && e.ms > send && e.ms < next).map((e) => e.ms);
  if (starts.length === 0) {
    starts.push(send + 6000);
    stops.push(send + 9000);
  }
  const lines: [number, number][] = [];
  starts.forEach((st, i) => {
    if (skipFirst && i === 0 && starts.length > 1) return;
    const sp = stops[i] ?? st + 3000;
    const last = lines[lines.length - 1];
    if (last && st - last[1] < 900) last[1] = sp;
    else lines.push([st, sp]);
  });
  // the typing at 1.8x, then the prop coming out at 1x
  const RATE = 1.8;
  const a1 = { atMs: typing - 300, dur: Math.round(f(send - (typing - 300)) / RATE), rate: RATE };
  const a2 = { atMs: send, dur: f(2700) };
  const b = lines.map(([st, sp], i) => ({
    atMs: st - (i === 0 ? 800 : 250),
    dur: f(sp + (i === lines.length - 1 ? 450 : 250) - (st - (i === 0 ? 800 : 250))),
  }));
  return { a1, a2, b };
}

export const toolsPlan = () => {
  const w = turnCut("weather", 20000);
  const n = turnCut("news", 40000, true);
  const segs: Seg[] = [];
  let at = 20; // the phone settles first
  const marks: { send: number; answer: number }[] = [];
  for (const c of [w, n]) {
    segs.push({ from: at, dur: c.a1.dur, tag: TH, atMs: c.a1.atMs, rate: c.a1.rate });
    at += c.a1.dur;
    const send = at;
    segs.push({ from: at, dur: c.a2.dur, tag: TH, atMs: c.a2.atMs });
    at += c.a2.dur;
    const answer = segs.length;
    for (const b of c.b) {
      segs.push({ from: at, dur: b.dur, tag: TH, atMs: b.atMs });
      at += b.dur;
    }
    marks.push({ send, answer });
  }
  segs[0] = { ...segs[0], from: 0, dur: segs[0].dur + 20, atMs: segs[0].atMs - 20 * (1000 / 60) * 1.8 };
  return { segs, marks, dur: at + 20 };
};

const TW = "film_wardrobe";
export const COSTUMES = [
  { label: "batman", name: "Batman", line: "I am the night." },
  { label: "robocop", name: "RoboCop", line: "Scanning. All clear." },
  { label: "soubrette", name: "Soubrette", line: "Enchantée !" },
  { label: "singularity", name: "Singularity", line: "I contain multitudes." },
];

/** Each costume's window on the scene's clock: from the avatar walking
 * back in (presence on screen) through its line, rounded up to whole beats;
 * the windows follow one another from bar 1's second beat. The mix reads
 * the same plan. */
export const wardrobePlan = () => {
  let at = 40;
  return COSTUMES.map((c, k) => {
    const turn = turnAt(TW, c.label, 3500 + k * 11000);
    const speakMs = after(TW, "start", turn, turn + 5000);
    const enters = events(TW).filter((e) => e.type === "presenceDone" && e.ms > turn && e.ms <= speakMs);
    const fromMs = (enters.length ? enters[enters.length - 1].ms : speakMs - 700) - 120;
    const stopMs = after(TW, "stop", speakMs, speakMs + 1800);
    const len = Math.round(Math.ceil((f(stopMs - fromMs) + 24) / BEAT) * BEAT);
    const row = { ...c, speakMs, at, len, atMs: fromMs - (at / 60) * 1000 };
    at += len;
    return row;
  });
};
export const wardrobeBars = () => {
  const p = wardrobePlan();
  const last = p[p.length - 1];
  return Math.ceil((last.at + last.len + 70) / BAR);
};

const TJ = "wow3";
export const journeyPlan = () => {
  const typing = ev(TJ, "typing", 0, 2000);
  const send = ev(TJ, "send", 0, typing + 5000);
  const s0 = after(TJ, "start", send, send + 3000);
  const firstPhase = ev(TJ, "phase", 1, s0 + 3000); // phase 0 = none at start
  const lastStart = ev(TJ, "start", -1, firstPhase + 9000);
  const lastStop = ev(TJ, "stop", -1, lastStart + 3000);
  const back = after(TJ, "phase", firstPhase + 1000, lastStart - 500); // none again?
  const windows: [number, number][] = [
    [Math.max(0, send - 1800), firstPhase],
    [firstPhase, Math.max(back, lastStart - 600)],
    [lastStart - 600, lastStop + 1400],
  ];
  // merge
  const merged: [number, number][] = [];
  for (const w of windows) {
    const last = merged[merged.length - 1];
    if (last && w[0] <= last[1] + 400) last[1] = Math.max(last[1], w[1]);
    else merged.push([...w]);
  }
  const segs: Seg[] = [];
  let at = 0;
  for (const [a, b] of merged) {
    const d = f(b - a);
    segs.push({ from: at, dur: d, tag: TJ, atMs: a });
    at += d;
  }
  const arrive = segs.length ? (() => {
    // frame of the arrival (the last phase change back to none) on the film clock
    let acc = 0;
    for (let i = 0; i < merged.length; i++) {
      const [a, b] = merged[i];
      if (back >= a && back <= b) return acc + f(back - a);
      acc += f(b - a);
    }
    return Math.round(at * 0.6);
  })() : 0;
  return { segs, dur: at, arrive };
};


export type Panel = { tag: string; atMs: number; label: string; scene: SceneId; drag?: boolean };
export type Beat = { bars: number; panels: Panel[]; caption: string; em?: string };

const poke = (s: SceneId) => ev(`scene_${s}`, "poke", -1, 8000) - 400;
const drag = (s: SceneId) => ev(`scene_${s}`, "dragStart", 0, 14000) - 500;
const tourLeg = (i: number) => ev("tour", "journey", i, 3000 + i * 9000) + 900;

export const NAMES: Record<SceneId, string> = {
  livingRoom: "Living room",
  campfire: "Campfire",
  beach: "Beach",
  deepSpace: "Deep space",
  cafe: "Café",
  rooftop: "Rooftop",
  mountainHut: "Mountain hut",
  forestCabin: "Forest cabin",
  trainCompartment: "Night train",
  library: "Library",
};
const P = (s: SceneId, atMs: number, tag = `scene_${s}`, label = NAMES[s], d = false): Panel => ({
  tag,
  atMs,
  label,
  scene: s,
  drag: d,
});

export const worldBeats = (): Beat[] => [
  {
    bars: 1,
    caption: "Ten scenes,",
    em: "each one alive.",
    panels: [
      P("campfire", ev("wow1", "start", 0, 13000) - 600, "wow1"),
      P("beach", poke("beach")),
      P("deepSpace", poke("deepSpace")),
    ],
  },
  {
    bars: 1,
    caption: "Ten scenes,",
    em: "each one alive.",
    panels: [P("cafe", poke("cafe")), P("rooftop", poke("rooftop")), P("mountainHut", poke("mountainHut"))],
  },
  {
    bars: 1,
    caption: "With residents",
    em: "of their own.",
    panels: [P("forestCabin", poke("forestCabin")), P("trainCompartment", poke("trainCompartment")), P("library", poke("library"))],
  },
  {
    bars: 2,
    caption: "Four ways to travel.",
    em: "Ninety journeys.",
    panels: [
      P("livingRoom", tourLeg(0), "tour", "Pop-up book"),
      P("campfire", tourLeg(1), "tour", "Forest path"),
      P("beach", tourLeg(2), "tour", "Rocket"),
      P("deepSpace", tourLeg(3), "tour", "Portal"),
    ],
  },
  {
    bars: 1,
    caption: "Pull, poke, spin —",
    em: "touch everything.",
    panels: [P("campfire", drag("campfire"), undefined, undefined, true), P("deepSpace", drag("deepSpace"), undefined, undefined, true), P("livingRoom", drag("livingRoom"), undefined, undefined, true)],
  },
  {
    bars: 1,
    caption: "Pull, poke, spin —",
    em: "touch everything.",
    panels: [P("cafe", drag("cafe"), undefined, undefined, true), P("rooftop", drag("rooftop"), undefined, undefined, true), P("forestCabin", drag("forestCabin"), undefined, undefined, true)],
  },
  {
    bars: 1,
    caption: "Real weather, real clock,",
    em: "real moon.",
    panels: [
      P("campfire", ev("wow1", "start", 1, 17000) - 300, "wow1", "Rain tonight"),
      P("beach", ev("wow3", "start", -1, 20000) - 300, "wow3", "Sunset"),
      P("beach", ev("film_goodnight", "send", 0, 8000) - 1500, "film_goodnight", "Night falls"),
    ],
  },
];

export const worldDur = () => worldBeats().reduce((s, b) => s + b.bars * BAR, 0);


const TF = "film_goodnight";
export const finalePlan = () => {
  const typing = ev(TF, "typing", 0, 3500);
  const s0 = after(TF, "start", typing, typing + 4500);
  const stop = ev(TF, "stop", -1, s0 + 4800);
  // the request and the wait at 1.8x, then the goodbye at 1x
  const RATE = 1.8;
  const a = { atMs: typing - 600, dur: Math.round(f(s0 - 700 - (typing - 600)) / RATE), rate: RATE };
  const b = { atMs: s0 - 700, dur: f(stop + 800 - (s0 - 700)) };
  const segs: Seg[] = [
    { from: 0, dur: a.dur, tag: TF, atMs: a.atMs, rate: RATE },
    { from: a.dur, dur: b.dur, tag: TF, atMs: b.atMs },
  ];
  const talk = a.dur + b.dur;
  /** the end card lands on a downbeat (the score's last chord) */
  const cardBar = Math.ceil((talk + 30) / BAR);
  return { segs, talk, card: cardBar * BAR, cardBar };
};
