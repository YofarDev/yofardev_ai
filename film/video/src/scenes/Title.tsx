import React from "react";
import { AbsoluteFill, Easing, interpolate, useCurrentFrame } from "remotion";
import { ACCENT } from "../lib/theme";
import { Wordmark } from "../lib/Cards";
import { Clip } from "../lib/Clip";
import { hex } from "../lib/Backdrop";
import { ev } from "../data/events";

const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;

/** Bars 5-6: the hit. The living room fills the frame and melts into a
 * warm blur behind the wordmark. */
export const Title: React.FC<{ dur: number }> = ({ dur }) => {
  const frame = useCurrentFrame();
  const a = ACCENT.livingRoom;
  const blur = interpolate(frame, [0, 26], [0, 26], { ...clamp, easing: Easing.out(Easing.cubic) });
  const dim = interpolate(frame, [0, 26], [0.15, 0.62], clamp);
  const zoom = interpolate(frame, [0, dur], [1.0, 1.12], clamp);
  const flash = interpolate(frame, [0, 3, 30], [0, 0.55, 0], clamp);
  const out = interpolate(frame, [dur - 24, dur], [1, 0], clamp);
  return (
    <AbsoluteFill style={{ opacity: out }}>
      <AbsoluteFill style={{ filter: `blur(${blur}px) saturate(1.15)`, transform: `scale(${zoom})` }}>
        <Clip tag="film_hello" atMs={ev("film_hello", "typing", 0, 6500) - 300} focus={[0.5, 0.3]} box={[1920, 1080]} />
      </AbsoluteFill>
      <AbsoluteFill style={{ background: `rgba(14,10,18,${dim})` }} />
      <AbsoluteFill
        style={{
          background: `radial-gradient(60% 60% at 50% 50%, ${a}${hex(flash)}, transparent 70%)`,
        }}
      />
      <Streak />
      <AbsoluteFill style={{ alignItems: "center", justifyContent: "center" }}>
        <Wordmark
          accent={a}
          size={200}
          start={4}
          sweepAt={34}
          sub="An AI companion with a voice, a face, and a little world of its own."
          subAt={44}
        />
      </AbsoluteFill>
    </AbsoluteFill>
  );
};

/** An anamorphic light streak across the frame on the hit. */
const Streak: React.FC = () => {
  const frame = useCurrentFrame();
  const a = ACCENT.livingRoom;
  const o = interpolate(frame, [0, 4, 46], [0, 1, 0], clamp);
  const w = interpolate(frame, [0, 46], [0.4, 1.6], { ...clamp, easing: Easing.out(Easing.cubic) });
  return (
    <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", opacity: o, mixBlendMode: "screen" }}>
      <div
        style={{
          width: 1920 * w,
          height: 6,
          borderRadius: 6,
          background: `linear-gradient(90deg, transparent, ${a}, #FFF6E0 50%, ${a}, transparent)`,
          filter: "blur(2px)",
          boxShadow: `0 0 40px 10px ${a}${hex(0.5)}`,
        }}
      />
    </AbsoluteFill>
  );
};
