import React from "react";
import { Easing, interpolate, useCurrentFrame } from "remotion";
import { BODY, DISPLAY, DISPLAY_ITALIC, MUTED, PAPER } from "./theme";

const EASE = Easing.bezier(0.16, 1, 0.3, 1);

/** Words rise out of a soft blur, one after another. A word wrapped in
 * `*stars*` is set in Fraunces italic in the accent colour. */
export const RiseWords: React.FC<{
  text: string;
  start?: number;
  stagger?: number;
  dur?: number;
  out?: number; // frame (local) at which everything fades out
  outDur?: number;
  size: number;
  accent?: string;
  family?: string;
  weight?: number;
  color?: string;
  align?: "left" | "center" | "right";
  lineHeight?: number;
  letterSpacing?: string;
  maxWidth?: number;
}> = ({
  text,
  start = 0,
  stagger = 4,
  dur = 32,
  out,
  outDur = 18,
  size,
  accent = "#F4B860",
  family = DISPLAY,
  weight = 400,
  color = PAPER,
  align = "center",
  lineHeight = 1.08,
  letterSpacing = "-0.015em",
  maxWidth,
}) => {
  const frame = useCurrentFrame();
  const words = text.split(" ");
  const outO =
    out === undefined
      ? 1
      : interpolate(frame, [out, out + outDur], [1, 0], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
          easing: Easing.in(Easing.cubic),
        });
  return (
    <div
      style={{
        fontFamily: family,
        fontWeight: weight,
        fontSize: size,
        lineHeight,
        letterSpacing,
        color,
        textAlign: align,
        maxWidth,
        opacity: outO,
        filter: out !== undefined && outO < 1 ? `blur(${(1 - outO) * 8}px)` : undefined,
        fontVariationSettings: "'SOFT' 50, 'WONK' 0",
      }}
    >
      {words.map((w, i) => {
        const p = interpolate(frame - start - i * stagger, [0, dur], [0, 1], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
          easing: EASE,
        });
        const em = w.startsWith("*") && w.replace(/[.,!?]$/, "").endsWith("*");
        const clean = w.replace(/\*/g, "");
        return (
          <span
            key={i}
            style={{
              display: "inline-block",
              opacity: p,
              transform: `translateY(${(1 - p) * size * 0.35}px)`,
              filter: p < 1 ? `blur(${(1 - p) * 10}px)` : undefined,
              fontFamily: em ? DISPLAY_ITALIC : undefined,
              color: em ? accent : undefined,
              marginRight: i < words.length - 1 ? "0.26em" : 0,
            }}
          >
            {clean}
          </span>
        );
      })}
    </div>
  );
};

/** A small tracked uppercase label with a short rule before it. */
export const Kicker: React.FC<{
  text: string;
  accent: string;
  start?: number;
  out?: number;
  size?: number;
  align?: "left" | "center";
}> = ({ text, accent, start = 0, out, size = 25, align = "left" }) => {
  const frame = useCurrentFrame();
  const p = interpolate(frame - start, [0, 30], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: EASE,
  });
  const o =
    out === undefined
      ? 1
      : interpolate(frame, [out, out + 15], [1, 0], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
        });
  return (
    <div
      style={{
        display: "flex",
        alignItems: "center",
        justifyContent: align === "center" ? "center" : "flex-start",
        gap: 16,
        fontFamily: BODY,
        fontWeight: 600,
        fontSize: size,
        letterSpacing: "0.28em",
        textTransform: "uppercase",
        color: accent,
        opacity: p * o,
      }}
    >
      <div style={{ width: 56 * p, height: 1.5, background: accent, opacity: 0.8 }} />
      <span style={{ transform: `translateX(${(1 - p) * 20}px)` }}>{text}</span>
    </div>
  );
};

/** Body copy that fades up. */
export const Body: React.FC<{
  text: string;
  start?: number;
  out?: number;
  size?: number;
  color?: string;
  maxWidth?: number;
  align?: "left" | "center";
}> = ({ text, start = 0, out, size = 34, color = MUTED, maxWidth = 640, align = "left" }) => {
  const frame = useCurrentFrame();
  const p = interpolate(frame - start, [0, 34], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: EASE,
  });
  const o =
    out === undefined
      ? 1
      : interpolate(frame, [out, out + 15], [1, 0], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
        });
  return (
    <div
      style={{
        fontFamily: BODY,
        fontWeight: 400,
        fontSize: size,
        lineHeight: 1.45,
        color,
        maxWidth,
        textAlign: align,
        opacity: p * o,
        transform: `translateY(${(1 - p) * 16}px)`,
      }}
    >
      {text}
    </div>
  );
};
