import React from "react";
import { AbsoluteFill, Easing, interpolate, useCurrentFrame } from "remotion";
import { ACCENT, BODY, MUTED, PAPER } from "../lib/theme";
import { Phone } from "../lib/Phone";
import { Segments } from "../lib/Clip";
import { Wordmark } from "../lib/Cards";
import { RiseWords } from "../lib/Type";
import { finalePlan } from "../plans";

const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;

/** Goodnight on the beach, then the end card. `talk` frames of the phone,
 * then the card holds to the end. */
export const Finale: React.FC<{ dur: number }> = ({ dur }) => {
  const frame = useCurrentFrame();
  const a = ACCENT.beach;
  const { segs, card } = finalePlan();
  const inP = interpolate(frame, [0, 40], [0, 1], { ...clamp, easing: Easing.bezier(0.16, 1, 0.3, 1) });
  const leave = interpolate(frame, [card - 50, card], [0, 1], { ...clamp, easing: Easing.bezier(0.7, 0, 0.84, 0) });
  const end = interpolate(frame, [dur - 40, dur], [1, 0], clamp);
  return (
    <AbsoluteFill style={{ opacity: end }}>
      <Phone
        height={960}
        accent={a}
        x={300}
        y={leave * -60}
        scale={interpolate(frame, [0, card], [1, 1.04]) * (1 - leave * 0.12)}
        opacity={inP * (1 - leave)}
        glow={1.2}
      >
        <Segments segs={segs} fade={8} />
      </Phone>
      <div style={{ position: "absolute", left: 130, top: 400, width: 900, opacity: 1 - leave }}>
        <RiseWords text="And when you leave," size={80} start={20} align="left" />
        <RiseWords text="it *waves goodbye.*" size={80} start={50} align="left" accent={a} />
      </div>
      {frame >= card - 2 ? (
        <AbsoluteFill style={{ alignItems: "center", justifyContent: "center" }}>
          <div style={{ marginTop: -60 }}>
            <Wordmark
              accent={ACCENT.livingRoom}
              size={180}
              start={card}
              sweepAt={40}
              sub="Open source · Flutter + Rive · Android"
              subAt={46}
            />
          </div>
          <div
            style={{
              marginTop: 46,
              fontFamily: BODY,
              fontSize: 30,
              fontWeight: 500,
              color: PAPER,
              letterSpacing: "0.02em",
              opacity: interpolate(frame, [card + 70, card + 100], [0, 1], clamp),
            }}
          >
            github.com/<span style={{ color: ACCENT.livingRoom }}>YofarDev</span>/yofardev_ai
          </div>
          <div
            style={{
              marginTop: 16,
              fontFamily: BODY,
              fontSize: 21,
              color: MUTED,
              opacity: interpolate(frame, [card + 90, card + 120], [0, 1], clamp),
            }}
          >
            Every frame of the app in this film is a real capture.
          </div>
        </AbsoluteFill>
      ) : null}
    </AbsoluteFill>
  );
};
