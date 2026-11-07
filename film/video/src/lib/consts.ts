// Font-free constants (importable from Node scripts).
export const ACCENT = {
  livingRoom: "#F4B860",
  campfire: "#FF8552",
  beach: "#FF9478",
  deepSpace: "#B79CFF",
  cafe: "#E8956B",
  rooftop: "#7CB8FF",
  mountainHut: "#86D4C4",
  forestCabin: "#A6CF6E",
  trainCompartment: "#F59AB5",
  library: "#E9CF6A",
} as const;
export type SceneId = keyof typeof ACCENT;

export const FPS = 60;
export const BPM = 96;
/** One bar = 2.5 s = 150 frames at 60 fps. */
export const BAR = 150;
export const BEAT = 37.5;
/** Frame at a 1-indexed bar (+ beats). */
export const bar = (b: number, beats = 0) => Math.round((b - 1) * BAR + beats * BEAT);
