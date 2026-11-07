import React from "react";
import { AbsoluteFill, Easing, interpolate, Sequence, useCurrentFrame } from "remotion";
import { ACCENT, BAR, BODY, DISPLAY, DISPLAY_ITALIC, PAPER } from "../lib/theme";
import { Clip } from "../lib/Clip";
import { hex } from "../lib/Backdrop";
import { events } from "../data/events";
import { Beat, worldBeats } from "../plans";

const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;
const EASE = Easing.bezier(0.16, 1, 0.3, 1);

export const World: React.FC<{ dur: number }> = ({ dur }) => {
  const beats = worldBeats();
  let at = 0;
  return (
    <AbsoluteFill>
      {beats.map((b, i) => {
        const from = at;
        at += b.bars * BAR;
        const sameCaption = i > 0 && beats[i - 1].caption === b.caption;
        const nextSame = i < beats.length - 1 && beats[i + 1].caption === b.caption;
        return (
          <Sequence key={i} from={from} durationInFrames={b.bars * BAR + 12} layout="none">
            <BeatView beat={b} len={b.bars * BAR} captionIn={!sameCaption} captionOut={!nextSame} />
          </Sequence>
        );
      })}
    </AbsoluteFill>
  );
};

const BeatView: React.FC<{ beat: Beat; len: number; captionIn: boolean; captionOut: boolean }> = ({
  beat,
  len,
  captionIn,
  captionOut,
}) => {
  const frame = useCurrentFrame();
  const n = beat.panels.length;
  const H = n === 4 ? 760 : 860;
  const W = (H * 9) / 16;
  const gap = n === 4 ? 36 : 44;
  const total = n * W + (n - 1) * gap;
  const left0 = (1920 - total) / 2;
  const top = n === 4 ? 110 : 60;
  const capO = interpolate(frame, [captionIn ? 6 : -1, captionIn ? 30 : 0, len - 4, len + 8], [0, 1, 1, captionOut ? 0 : 1], clamp);
  return (
    <AbsoluteFill>
      {beat.panels.map((p, k) => {
        const delay = k * 4;
        const inP = interpolate(frame, [delay, delay + 26], [0, 1], { ...clamp, easing: EASE });
        const outP = interpolate(frame, [len - 10 + k * 2, len + 8 + k * 2], [0, 1], { ...clamp, easing: Easing.in(Easing.cubic) });
        const x = left0 + k * (W + gap);
        const y = top + (1 - inP) * 120 - outP * 160;
        const a = ACCENT[p.scene];
        return (
          <div
            key={k}
            style={{
              position: "absolute",
              left: x,
              top: y,
              width: W,
              height: H,
              borderRadius: 30,
              overflow: "hidden",
              opacity: inP * (1 - outP),
              filter: inP < 1 || outP > 0 ? `blur(${(1 - inP) * 10 + outP * 10}px)` : undefined,
              boxShadow: `0 30px 70px rgba(0,0,0,0.5), 0 0 60px ${a}${hex(0.18)}`,
              border: `1px solid rgba(255,255,255,0.08)`,
              background: "#000",
            }}
          >
            <Clip tag={p.tag} atMs={p.atMs} zoom={interpolate(frame, [0, len], [1.0, 1.06])} />
            {p.drag ? <Finger tag={p.tag} atMs={p.atMs} w={W} h={H} /> : null}
            <div
              style={{
                position: "absolute",
                left: "50%",
                top: 16,
                transform: "translateX(-50%)",
                whiteSpace: "nowrap",
                padding: "8px 16px",
                borderRadius: 999,
                background: "rgba(14,11,19,0.6)",
                border: `1px solid ${a}${hex(0.4)}`,
                fontFamily: BODY,
                fontWeight: 600,
                fontSize: 17,
                letterSpacing: "0.16em",
                textTransform: "uppercase",
                color: PAPER,
                backdropFilter: "blur(8px)",
              }}
            >
              <span style={{ color: a, marginRight: 10 }}>●</span>
              {p.label}
            </div>
          </div>
        );
      })}
      <div
        style={{
          position: "absolute",
          left: 0,
          right: 0,
          top: n === 4 ? 920 : 960,
          textAlign: "center",
          fontFamily: DISPLAY,
          fontWeight: 300,
          fontSize: 52,
          color: PAPER,
          opacity: capO,
          letterSpacing: "-0.01em",
        }}
      >
        {beat.caption}{" "}
        <span style={{ fontFamily: DISPLAY_ITALIC, color: ACCENT[beat.panels[0].scene] }}>{beat.em}</span>
      </div>
    </AbsoluteFill>
  );
};

/** A fingertip following the logged drag path (window px 576×1024 → panel). */
const Finger: React.FC<{ tag: string; atMs: number; w: number; h: number }> = ({ tag, atMs, w, h }) => {
  const frame = useCurrentFrame();
  const ms = atMs + (frame / 60) * 1000;
  const pts = events(tag).filter((e) => e.type === "dragPoint");
  if (pts.length === 0) return null;
  const first = pts[0].ms;
  const last = pts[pts.length - 1].ms;
  if (ms < first - 250 || ms > last + 450) return null;
  let p = pts[0];
  for (const q of pts) {
    if (q.ms <= ms) p = q;
    else break;
  }
  const sx = w / 576;
  const sy = h / 1024;
  const down = interpolate(ms, [first - 250, first, last, last + 450], [0, 1, 1, 0], clamp);
  const r = 26 * (0.8 + 0.2 * down);
  return (
    <div
      style={{
        position: "absolute",
        left: (p.x ?? 0) * sx - r,
        top: (p.y ?? 0) * sy - r,
        width: r * 2,
        height: r * 2,
        borderRadius: "50%",
        background: "rgba(255,255,255,0.28)",
        border: "2px solid rgba(255,255,255,0.85)",
        boxShadow: "0 0 24px rgba(255,255,255,0.5)",
        opacity: down,
      }}
    />
  );
};
