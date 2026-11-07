import React from "react";
import { AbsoluteFill, Easing, interpolate, useCurrentFrame } from "remotion";
import { ACCENT } from "../lib/theme";
import { Phone } from "../lib/Phone";
import { Segments } from "../lib/Clip";
import { Body, Kicker, RiseWords } from "../lib/Type";
import { journeyPlan } from "../plans";

const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;

export const Journey: React.FC<{ dur: number }> = ({ dur }) => {
  const frame = useCurrentFrame();
  const { segs, arrive } = journeyPlan();
  const a0 = ACCENT.livingRoom;
  const a1 = ACCENT.beach;
  const accent = frame < arrive ? a0 : a1;
  const inP = interpolate(frame, [0, 36], [0, 1], { ...clamp, easing: Easing.bezier(0.16, 1, 0.3, 1) });
  const out = interpolate(frame, [dur - 18, dur], [1, 0], clamp);
  const push = interpolate(frame, [0, dur], [0.98, 1.05]);
  return (
    <AbsoluteFill style={{ opacity: out }}>
      <Phone height={960} accent={accent} x={300} scale={push} rotateY={-6} rotateX={1.5} opacity={inP} glow={1.2}>
        <Segments segs={segs} fade={10} />
      </Phone>
      <div style={{ position: "absolute", left: 140, top: 300, width: 760 }}>
        <Kicker text="It takes you places" accent={accent} start={6} />
        <div style={{ height: 22 }} />
        <RiseWords text="Ask for the beach. *Go there.*" size={88} align="left" accent={accent} start={12} />
        <div style={{ height: 26 }} />
        <Body
          text="It walks into the next scene through a pop-up book — or a forest path, a rocket, a portal, depending on where you go."
          start={34}
          maxWidth={680}
        />
      </div>
    </AbsoluteFill>
  );
};
