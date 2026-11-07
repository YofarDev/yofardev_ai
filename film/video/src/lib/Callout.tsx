import React from "react";
import { AbsoluteFill, Easing, interpolate, useCurrentFrame } from "remotion";
import { BODY, MUTED, PAPER } from "./theme";
import { hex } from "./Backdrop";

const EASE = Easing.bezier(0.16, 1, 0.3, 1);

/** A glass label tied to a point by a thin drawn line (a dot that pulses at
 * the point). Coordinates are composition px. */
export const Callout: React.FC<{
  from: [number, number];
  to: [number, number]; // where the card's near edge sits
  title: string;
  sub?: string;
  accent: string;
  start: number;
  end: number;
  side?: "left" | "right"; // which side of `to` the card extends to
  width?: number;
}> = ({ from, to, title, sub, accent, start, end, side = "right", width = 420 }) => {
  const frame = useCurrentFrame();
  const line = interpolate(frame, [start, start + 22], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: EASE,
  });
  const card = interpolate(frame, [start + 12, start + 40], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: EASE,
  });
  const out = interpolate(frame, [end - 14, end], [1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  if (frame < start || frame > end) return null;
  const [x1, y1] = from;
  const [x2, y2] = to;
  // an elbow: horizontal-ish out of the point, then straight to the card
  const dir = Math.sign(x2 - x1) || 1;
  const run = Math.min(Math.abs(y2 - y1), Math.abs(x2 - x1) * 0.7);
  const mx = x1 + dir * run;
  const path = `M ${x1} ${y1} L ${mx} ${y2} L ${x2} ${y2}`;
  const len = Math.hypot(mx - x1, y2 - y1) + Math.abs(x2 - mx);
  const pulse = 1 + 0.6 * ((frame - start) % 45) / 45;
  return (
    <AbsoluteFill style={{ opacity: out, pointerEvents: "none" }}>
      <svg width="1920" height="1080" style={{ position: "absolute" }}>
        <path
          d={path}
          fill="none"
          stroke={accent}
          strokeOpacity={0.85}
          strokeWidth={1.6}
          strokeDasharray={len}
          strokeDashoffset={len * (1 - line)}
        />
        <circle cx={x1} cy={y1} r={6 * line} fill={accent} />
        <circle
          cx={x1}
          cy={y1}
          r={6 * pulse * 1.8}
          fill="none"
          stroke={accent}
          strokeOpacity={line * (1 - (pulse - 1) / 0.6) * 0.7}
          strokeWidth={1.5}
        />
      </svg>
      <div
        style={{
          position: "absolute",
          left: side === "right" ? x2 + 14 : undefined,
          right: side === "left" ? 1920 - x2 + 14 : undefined,
          top: y2,
          transform: `translateY(-50%) translateX(${(1 - card) * (side === "right" ? -14 : 14)}px)`,
          width,
          opacity: card,
          padding: "20px 28px",
          borderRadius: 18,
          background: `linear-gradient(160deg, rgba(40,33,52,0.78), rgba(22,18,29,0.72))`,
          border: `1px solid ${accent}${hex(0.35)}`,
          boxShadow: `0 18px 50px rgba(0,0,0,0.45), 0 0 30px ${accent}${hex(0.12)}`,
          backdropFilter: "blur(14px)",
        }}
      >
        <div
          style={{
            fontFamily: BODY,
            fontWeight: 600,
            fontSize: 33,
            color: PAPER,
            letterSpacing: "-0.005em",
          }}
        >
          {title}
        </div>
        {sub ? (
          <div
            style={{
              fontFamily: BODY,
              fontWeight: 400,
              fontSize: 25,
              color: MUTED,
              marginTop: 5,
              lineHeight: 1.4,
            }}
          >
            {sub}
          </div>
        ) : null}
      </div>
    </AbsoluteFill>
  );
};
