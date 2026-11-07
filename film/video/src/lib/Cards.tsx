import React from "react";
import { AbsoluteFill, Easing, interpolate, useCurrentFrame } from "remotion";
import { BODY, DISPLAY, MUTED, PAPER } from "./theme";
import { hex } from "./Backdrop";

const EASE = Easing.bezier(0.16, 1, 0.3, 1);
const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;

/** "Yofardev AI": letters fall into place out of a blur, a light sweep crosses
 * the wordmark, a hairline draws out under it. */
export const Wordmark: React.FC<{
  accent: string;
  size?: number;
  start?: number;
  sweepAt?: number;
  sub?: string;
  subAt?: number;
}> = ({ accent, size = 190, start = 0, sweepAt = 30, sub, subAt = 40 }) => {
  const frame = useCurrentFrame();
  const letters = "Yofardev".split("");
  const rule = interpolate(frame, [start + 20, start + 70], [0, 1], { ...clamp, easing: EASE });
  const sweep = interpolate(frame, [start + sweepAt, start + sweepAt + 55], [-0.4, 1.4], clamp);
  return (
    <div style={{ display: "flex", flexDirection: "column", alignItems: "center" }}>
      <div
        style={{
          position: "relative",
          display: "flex",
          alignItems: "baseline",
          fontFamily: DISPLAY,
          fontWeight: 400,
          fontSize: size,
          letterSpacing: "-0.035em",
          color: PAPER,
          lineHeight: 1,
          fontVariationSettings: "'SOFT' 100, 'opsz' 144",
        }}
      >
        {letters.map((l, i) => {
          const p = interpolate(frame - start - i * 2.2, [0, 34], [0, 1], { ...clamp, easing: EASE });
          return (
            <span
              key={i}
              style={{
                display: "inline-block",
                opacity: p,
                transform: `translateY(${(1 - p) * 40}px) scale(${0.92 + 0.08 * p})`,
                filter: p < 1 ? `blur(${(1 - p) * 14}px)` : undefined,
              }}
            >
              {l}
            </span>
          );
        })}
        <span
          style={{
            marginLeft: "0.28em",
            fontFamily: BODY,
            fontWeight: 500,
            fontSize: size * 0.34,
            letterSpacing: "0.12em",
            color: accent,
            opacity: interpolate(frame - start, [16, 46], [0, 1], clamp),
            transform: `translateY(${-size * 0.06}px)`,
          }}
        >
          AI
        </span>
        {/* light sweep */}
        <div
          style={{
            position: "absolute",
            inset: "-10% -5%",
            background: `linear-gradient(105deg, transparent ${sweep * 100 - 12}%, rgba(255,240,210,0.55) ${sweep * 100}%, transparent ${sweep * 100 + 12}%)`,
            mixBlendMode: "overlay",
            pointerEvents: "none",
          }}
        />
      </div>
      <div
        style={{
          width: size * 3.6 * rule,
          height: 1.5,
          marginTop: size * 0.2,
          background: `linear-gradient(90deg, transparent, ${accent}, transparent)`,
          opacity: 0.8,
        }}
      />
      {sub ? (
        <div
          style={{
            marginTop: size * 0.18,
            fontFamily: BODY,
            fontSize: size * 0.16,
            fontWeight: 400,
            color: MUTED,
            letterSpacing: "0.01em",
            opacity: interpolate(frame - start, [subAt, subAt + 30], [0, 1], clamp),
            transform: `translateY(${interpolate(frame - start, [subAt, subAt + 30], [12, 0], { ...clamp, easing: EASE })}px)`,
          }}
        >
          {sub}
        </div>
      ) : null}
    </div>
  );
};

/** One statistic: a number that counts up, a label under it. */
export const Stat: React.FC<{
  value: number;
  suffix?: string;
  label: string;
  accent: string;
  start: number;
}> = ({ value, suffix = "", label, accent, start }) => {
  const frame = useCurrentFrame();
  const p = interpolate(frame - start, [0, 50], [0, 1], { ...clamp, easing: EASE });
  const n = Math.round(value * p);
  return (
    <div
      style={{
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        opacity: interpolate(frame - start, [0, 18], [0, 1], clamp),
        transform: `translateY(${(1 - p) * 18}px)`,
        minWidth: 250,
      }}
    >
      <div
        style={{
          fontFamily: DISPLAY,
          fontSize: 116,
          fontWeight: 400,
          color: PAPER,
          lineHeight: 1,
          fontVariantNumeric: "tabular-nums",
          letterSpacing: "-0.03em",
        }}
      >
        {n}
        <span style={{ color: accent }}>{suffix}</span>
      </div>
      <div
        style={{
          marginTop: 14,
          fontFamily: BODY,
          fontWeight: 600,
          fontSize: 19,
          letterSpacing: "0.22em",
          textTransform: "uppercase",
          color: MUTED,
          textAlign: "center",
        }}
      >
        {label}
      </div>
    </div>
  );
};

/** A glass chip with a tech name. */
export const Chip: React.FC<{ text: string; sub?: string; accent: string; start: number }> = ({
  text,
  sub,
  accent,
  start,
}) => {
  const frame = useCurrentFrame();
  const p = interpolate(frame - start, [0, 26], [0, 1], { ...clamp, easing: EASE });
  return (
    <div
      style={{
        padding: "16px 26px",
        borderRadius: 999,
        border: `1px solid ${accent}${hex(0.4)}`,
        background: "linear-gradient(160deg, rgba(44,36,58,0.8), rgba(24,19,32,0.8))",
        boxShadow: `0 12px 40px rgba(0,0,0,0.4), inset 0 1px 0 rgba(255,255,255,0.06)`,
        opacity: p,
        transform: `translateY(${(1 - p) * 24}px) scale(${0.96 + 0.04 * p})`,
        display: "flex",
        alignItems: "baseline",
        gap: 14,
      }}
    >
      <span style={{ fontFamily: BODY, fontWeight: 600, fontSize: 28, color: PAPER }}>{text}</span>
      {sub ? (
        <span style={{ fontFamily: BODY, fontWeight: 400, fontSize: 20, color: MUTED }}>{sub}</span>
      ) : null}
    </div>
  );
};

export const Fill: React.FC<{ children: React.ReactNode; style?: React.CSSProperties }> = ({
  children,
  style,
}) => (
  <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", ...style }}>
    {children}
  </AbsoluteFill>
);
