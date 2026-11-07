import React from "react";
import { AbsoluteFill, useCurrentFrame } from "remotion";
import code from "../data/code.json";
import { MONO } from "./theme";

/** Four columns of the project's real source, drifting upward behind the
 * hood section, faded toward the centre. */
export const CodeWall: React.FC<{ accent: string; opacity?: number }> = ({ accent, opacity = 0.16 }) => {
  const frame = useCurrentFrame();
  const cols = code as string[][];
  return (
    <AbsoluteFill
      style={{
        opacity,
        transform: "rotate(-8deg) scale(1.25)",
        maskImage: "radial-gradient(70% 60% at 50% 50%, transparent 25%, black 75%)",
        WebkitMaskImage: "radial-gradient(70% 60% at 50% 50%, transparent 25%, black 75%)",
      }}
    >
      <div style={{ display: "flex", gap: 60, padding: "0 40px" }}>
        {cols.map((c, i) => (
          <div
            key={i}
            style={{
              fontFamily: MONO,
              fontSize: 15,
              lineHeight: 1.55,
              whiteSpace: "pre",
              color: i % 2 ? accent : "#F6EEDF",
              transform: `translateY(${-((frame * (0.6 + i * 0.15)) % 900) - i * 120}px)`,
              width: 460,
              overflow: "hidden",
            }}
          >
            {[...c, ...c].join("\n")}
          </div>
        ))}
      </div>
    </AbsoluteFill>
  );
};
