import React from "react";
import { AbsoluteFill, interpolate, useCurrentFrame } from "remotion";
import { ACCENT } from "../lib/theme";
import { Chip, Stat } from "../lib/Cards";
import { Kicker, RiseWords } from "../lib/Type";
import { CodeWall } from "../lib/CodeWall";

const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;

/** The engineering beat: what it is made of, in numbers and names. */
export const Hood: React.FC<{ dur: number }> = ({ dur }) => {
  const frame = useCurrentFrame();
  const a = ACCENT.deepSpace;
  const out = interpolate(frame, [dur - 18, dur], [1, 0], clamp);
  const chips: [string, string][] = [
    ["Flutter", "one codebase"],
    ["Rive", "every asset generated from code"],
    ["Kokoro TTS", "on-device"],
    ["BLoC", "clean architecture"],
    ["Any LLM", "OpenAI-compatible"],
  ];
  return (
    <AbsoluteFill style={{ opacity: out, alignItems: "center" }}>
      <CodeWall accent={a} opacity={interpolate(frame, [0, 40], [0, 0.17], clamp)} />
      <div style={{ marginTop: 120, display: "flex", flexDirection: "column", alignItems: "center" }}>
        <Kicker text="Under the hood" accent={a} start={0} align="center" />
        <div style={{ height: 18 }} />
        <RiseWords text="Built like a *real product.*" size={84} accent={a} start={6} />
      </div>
      <div style={{ marginTop: 80, display: "flex", gap: 56, padding: "34px 60px", borderRadius: 28, background: "rgba(22,18,29,0.72)", border: "1px solid rgba(183,156,255,0.18)", boxShadow: "0 30px 80px rgba(0,0,0,0.45)" }}>
        <Stat value={10} label="Living scenes" accent={a} start={30} />
        <Stat value={90} label="Animated journeys" accent={a} start={40} />
        <Stat value={14} label="Facial action units" accent={a} start={50} />
        <Stat value={2600} suffix="+" label="Automated tests" accent={a} start={60} />
      </div>
      <div style={{ marginTop: 60, display: "flex", gap: 18, flexWrap: "nowrap", justifyContent: "center" }}>
        {chips.map(([t, s], i) => (
          <Chip key={t} text={t} sub={s} accent={a} start={130 + i * 8} />
        ))}
      </div>
    </AbsoluteFill>
  );
};
