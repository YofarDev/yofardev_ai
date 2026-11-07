import React, { useMemo } from "react";
import { AbsoluteFill, interpolate, random, useCurrentFrame } from "remotion";
import { noise2D } from "@remotion/noise";
import { INK } from "./theme";

/** The ink stage every shot sits on: two slow accent glows, drifting embers,
 * a vignette. `accent` cross-fades by the parent (pass the current one). */
export const Backdrop: React.FC<{
  accent: string;
  intensity?: number;
  embers?: number;
}> = ({ accent, intensity = 1, embers = 40 }) => {
  const frame = useCurrentFrame();
  const ax = 30 + noise2D("ax", frame / 900, 0) * 14;
  const ay = 40 + noise2D("ay", frame / 900, 0) * 10;
  const bx = 72 + noise2D("bx", frame / 1100, 0) * 14;
  const by = 66 + noise2D("by", frame / 1100, 0) * 10;
  return (
    <AbsoluteFill style={{ backgroundColor: INK }}>
      <AbsoluteFill
        style={{
          background: `radial-gradient(60% 70% at ${ax}% ${ay}%, ${accent}${hex(0.2 * intensity)} 0%, transparent 70%),
             radial-gradient(55% 60% at ${bx}% ${by}%, #7A5CFF${hex(0.12 * intensity)} 0%, transparent 70%)`,
        }}
      />
      <Embers count={embers} accent={accent} />
      <AbsoluteFill
        style={{
          background:
            "radial-gradient(120% 90% at 50% 45%, transparent 55%, rgba(5,3,8,0.75) 100%)",
        }}
      />
    </AbsoluteFill>
  );
};

const Embers: React.FC<{ count: number; accent: string }> = ({ count, accent }) => {
  const frame = useCurrentFrame();
  const seeds = useMemo(
    () =>
      new Array(count).fill(0).map((_, i) => ({
        x: random(`ex${i}`) * 1920,
        y: random(`ey${i}`) * 1080,
        r: 1 + random(`er${i}`) * 2.6,
        speed: 0.15 + random(`es${i}`) * 0.45,
        phase: random(`ep${i}`) * 1000,
        bright: 0.25 + random(`eb${i}`) * 0.6,
      })),
    [count],
  );
  return (
    <AbsoluteFill>
      {seeds.map((s, i) => {
        const y = (((s.y - frame * s.speed) % 1180) + 1180) % 1180 - 50;
        const x = s.x + noise2D(`ew${i}`, (frame + s.phase) / 300, 0) * 40;
        const tw = 0.6 + 0.4 * Math.sin((frame + s.phase) / 25);
        return (
          <div
            key={i}
            style={{
              position: "absolute",
              left: x,
              top: y,
              width: s.r * 2,
              height: s.r * 2,
              borderRadius: "50%",
              background: accent,
              opacity: s.bright * tw * 0.55,
              boxShadow: `0 0 ${6 + s.r * 4}px ${accent}`,
            }}
          />
        );
      })}
    </AbsoluteFill>
  );
};

/** Film grain + a faint flicker, over everything. */
export const Grain: React.FC<{ opacity?: number }> = ({ opacity = 0.07 }) => {
  const frame = useCurrentFrame();
  const seed = Math.floor(frame / 2) % 8;
  return (
    <AbsoluteFill style={{ pointerEvents: "none", mixBlendMode: "overlay", opacity }}>
      <svg width="1920" height="1080">
        <filter id={`g${seed}`}>
          <feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="2" seed={seed} />
          <feColorMatrix type="saturate" values="0" />
        </filter>
        <rect width="1920" height="1080" filter={`url(#g${seed})`} />
      </svg>
    </AbsoluteFill>
  );
};

export function hex(a: number): string {
  const v = Math.round(Math.max(0, Math.min(1, a)) * 255);
  return v.toString(16).padStart(2, "0");
}

export const fade = (frame: number, inF: number, outStart: number, outF: number) =>
  interpolate(frame, [0, inF, outStart, outStart + outF], [0, 1, 1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
