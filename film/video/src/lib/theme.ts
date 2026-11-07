import { loadFont as loadFraunces } from "@remotion/google-fonts/Fraunces";
import { loadFont as loadManrope } from "@remotion/google-fonts/Manrope";

// The app's own look (lib/core/design): storybook night.
export const INK = "#16121D";
export const SURFACE = "#211B2B";
export const PAPER = "#F6EEDF";
export const MUTED = "rgba(246, 238, 223, 0.62)";

export { ACCENT, FPS, BPM, BAR, BEAT, bar } from "./consts";
export type { SceneId } from "./consts";
export const { fontFamily: DISPLAY } = loadFraunces("normal", {
  weights: ["300", "400", "500", "600"],
  subsets: ["latin"],
});
export const { fontFamily: DISPLAY_ITALIC } = loadFraunces("italic", {
  weights: ["300", "400", "500"],
  subsets: ["latin"],
});
export const { fontFamily: BODY } = loadManrope("normal", {
  weights: ["400", "500", "600", "700"],
  subsets: ["latin"],
});

import { loadFont as loadMono } from "@remotion/google-fonts/JetBrainsMono";
export const { fontFamily: MONO } = loadMono("normal", { weights: ["400", "500"], subsets: ["latin"] });
