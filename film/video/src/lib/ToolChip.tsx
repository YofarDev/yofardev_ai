import React from "react";
import { Easing, interpolate, useCurrentFrame } from "remotion";
import { MONO, PAPER } from "./theme";
import { hex } from "./Backdrop";

const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;

/** A function call, typed out in mono, with a spinner that turns into a check
 * when the result is back (`done`). */
export const ToolChip: React.FC<{
  fn: string;
  args: string;
  accent: string;
  start: number;
  done: number;
  end: number;
  x: number;
  y: number;
}> = ({ fn, args, accent, start, done, end, x, y }) => {
  const frame = useCurrentFrame();
  if (frame < start || frame > end) return null;
  const p = interpolate(frame, [start, start + 22], [0, 1], { ...clamp, easing: Easing.bezier(0.16, 1, 0.3, 1) });
  const o = interpolate(frame, [end - 14, end], [1, 0], clamp);
  const full = `${fn}(${args})`;
  const shown = Math.floor(interpolate(frame, [start + 6, start + 6 + full.length * 1.1], [0, full.length], clamp));
  const ok = frame >= done;
  const spin = (frame * 9) % 360;
  return (
    <div
      style={{
        position: "absolute",
        left: x,
        top: y,
        opacity: p * o,
        transform: `translateY(${(1 - p) * 14}px)`,
        display: "flex",
        alignItems: "center",
        gap: 16,
        padding: "16px 24px",
        borderRadius: 14,
        background: "rgba(14,11,19,0.82)",
        border: `1px solid ${accent}${hex(0.35)}`,
        boxShadow: `0 16px 44px rgba(0,0,0,0.45)`,
        fontFamily: MONO,
        fontSize: 25,
        color: PAPER,
        whiteSpace: "pre",
      }}
    >
      <div style={{ width: 22, height: 22, position: "relative" }}>
        {ok ? (
          <svg width="22" height="22" viewBox="0 0 22 22">
            <circle cx="11" cy="11" r="10" fill={accent} />
            <path d="M6 11.5 L9.5 15 L16 7.5" stroke="#16121D" strokeWidth="2.4" fill="none" strokeLinecap="round" />
          </svg>
        ) : (
          <svg width="22" height="22" viewBox="0 0 22 22" style={{ transform: `rotate(${spin}deg)` }}>
            <circle cx="11" cy="11" r="9" stroke={accent} strokeOpacity="0.25" strokeWidth="2.5" fill="none" />
            <path d="M11 2 A9 9 0 0 1 20 11" stroke={accent} strokeWidth="2.5" fill="none" strokeLinecap="round" />
          </svg>
        )}
      </div>
      <span style={{ display: "flex", flexDirection: "column", gap: 6 }}>
        <span style={{ fontFamily: "inherit", fontSize: 15, letterSpacing: "0.24em", color: "rgba(246,238,223,0.55)" }}>
          {ok ? "TOOL CALL · DONE" : "TOOL CALL · RUNNING"}
        </span>
        <span>
        <span style={{ color: accent }}>{full.slice(0, Math.min(shown, fn.length))}</span>
        <span>{full.slice(fn.length, shown)}</span>
        </span>
      </span>
    </div>
  );
};
