import React from "react";
import { AbsoluteFill, Easing, Freeze, interpolate, Sequence, useCurrentFrame } from "remotion";
import { ACCENT, BODY, MUTED } from "../lib/theme";
import { Phone } from "../lib/Phone";
import { Clip } from "../lib/Clip";
import { Kicker, RiseWords } from "../lib/Type";
import { wardrobePlan } from "../plans";

const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;
export const Wardrobe: React.FC<{ dur: number }> = ({ dur }) => {
  const frame = useCurrentFrame();
  const a = ACCENT.livingRoom;
  const plan = wardrobePlan();
  const out = interpolate(frame, [dur - 20, dur], [1, 0], clamp);
  const H = 660;
  const W = (H * 9) / 16 + 22;
  const gap = 46;
  const total = 4 * W + 3 * gap;
  return (
    <AbsoluteFill style={{ opacity: out }}>
      <div style={{ position: "absolute", top: 70, left: 0, right: 0, display: "flex", flexDirection: "column", alignItems: "center" }}>
        <Kicker text="It dresses up" accent={a} start={4} align="center" />
        <div style={{ height: 14 }} />
        <RiseWords text="Costumes, colours, *a whole new voice.*" size={64} accent={a} start={10} />
      </div>
      {plan.map((p, k) => {
        const x = -total / 2 + W / 2 + k * (W + gap);
        const pop = interpolate(frame, [4 + k * 4, 34 + k * 4], [0, 1], { ...clamp, easing: Easing.bezier(0.16, 1, 0.3, 1) });
        // lit while its line plays (a bar), dimmed while another one is
        const lit = interpolate(frame, [p.at - 12, p.at, p.at + p.len - 12, p.at + p.len], [0, 1, 1, 0], clamp);
        const anyLit = plan.some((q) => frame >= q.at - 12 && frame <= q.at + q.len);
        const allOn = frame > plan[3].at + plan[3].len;
        const dim = allOn ? 1 : anyLit ? 0.45 + 0.55 * lit : 1;
        return (
          <React.Fragment key={k}>
            <Phone
              height={H}
              accent={a}
              x={x}
              y={60 + (1 - pop) * 80 - lit * 26}
              scale={(1 + lit * 0.08) * interpolate(frame, [0, dur], [0.98, 1.03])}
              seed={`w${k}`}
              rotateY={x * -0.008}
              opacity={pop}
              glow={0.4 + lit * 0.9}
            >
              <div style={{ position: "absolute", inset: 0, filter: `brightness(${dim})` }}>
                <CostumeClip atMs={p.atMs} at={p.at} len={p.len} />
              </div>
            </Phone>
            <div
              style={{
                position: "absolute",
                left: 960 + x - 200,
                width: 400,
                top: 540 + 60 + H / 2 + 34,
                textAlign: "center",
                fontFamily: BODY,
                opacity: pop,
              }}
            >
              <div style={{ fontSize: 22, fontWeight: 600, letterSpacing: "0.22em", textTransform: "uppercase", color: lit > 0.5 ? a : MUTED }}>
                {p.name}
              </div>
            </div>
          </React.Fragment>
        );
      })}
    </AbsoluteFill>
  );
};

/** A costume's phone: waiting on the empty room before its turn, playing
 * the walk-in, the line and the signature move, then held. */
const CostumeClip: React.FC<{ atMs: number; at: number; len: number }> = ({ atMs, at, len }) => {
  const playTo = at + len;
  return (
    <>
      <Sequence durationInFrames={at} layout="none">
        <Freeze frame={at}>
          <Clip tag="film_wardrobe" atMs={atMs} />
        </Freeze>
      </Sequence>
      <Sequence from={at} durationInFrames={len} layout="none">
        <Clip tag="film_wardrobe" atMs={atMs + (at / 60) * 1000} />
      </Sequence>
      <Sequence from={playTo} layout="none">
        <Freeze frame={0}>
          <Clip tag="film_wardrobe" atMs={atMs + (playTo / 60) * 1000} />
        </Freeze>
      </Sequence>
    </>
  );
};
