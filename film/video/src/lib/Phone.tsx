import React from "react";
import { useCurrentFrame } from "remotion";
import { noise2D } from "@remotion/noise";
import { hex } from "./Backdrop";

/** A modern, nearly bezel-less phone around a 9:16 screen. `height` is the
 * screen's height in px; the frame adds its bezel around it. */
export const Phone: React.FC<{
  height: number;
  accent: string;
  glow?: number;
  rotateY?: number;
  rotateX?: number;
  rotateZ?: number;
  x?: number;
  y?: number;
  scale?: number;
  opacity?: number;
  sheen?: number;
  /** a slow hand-held drift (rotation and bob) */
  float?: number;
  seed?: string;
  children: React.ReactNode;
}> = ({
  height,
  accent,
  glow = 1,
  rotateY = 0,
  rotateX = 0,
  rotateZ = 0,
  x = 0,
  y = 0,
  scale = 1,
  opacity = 1,
  sheen = 0.5,
  float = 1,
  seed = "p",
  children,
}) => {
  const frame = useCurrentFrame();
  const fy = noise2D(seed + "y", frame / 260, 0) * 9 * float;
  const fr = noise2D(seed + "r", frame / 320, 0) * 2.2 * float;
  const fx = noise2D(seed + "x", frame / 380, 0) * 1.2 * float;
  const w = (height * 9) / 16;
  const bezel = height * 0.016;
  const r = height * 0.058;
  return (
    <div
      style={{
        position: "absolute",
        left: "50%",
        top: "50%",
        width: w + bezel * 2,
        height: height + bezel * 2,
        marginLeft: -(w + bezel * 2) / 2,
        marginTop: -(height + bezel * 2) / 2,
        transform: `translate(${x}px, ${y + fy}px) perspective(2400px) rotateY(${rotateY + fr}deg) rotateX(${rotateX + fx}deg) rotateZ(${rotateZ}deg) scale(${scale})`,
        transformStyle: "preserve-3d",
        opacity,
      }}
    >
      {/* accent glow on the "floor" */}
      <div
        style={{
          position: "absolute",
          left: "-30%",
          right: "-30%",
          top: "10%",
          bottom: "-12%",
          borderRadius: "50%",
          background: `radial-gradient(closest-side, ${accent}${hex(0.32 * glow)}, transparent)`,
          filter: "blur(40px)",
        }}
      />
      {/* body */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          borderRadius: r + bezel,
          background:
            "linear-gradient(145deg, #4a4552 0%, #1b1820 18%, #0e0c12 50%, #26222c 82%, #55505d 100%)",
          boxShadow: `0 ${height * 0.05}px ${height * 0.09}px rgba(0,0,0,0.55), 0 ${height * 0.01}px ${height * 0.02}px rgba(0,0,0,0.5), inset 0 0 0 1.5px rgba(255,255,255,0.10)`,
        }}
      />
      {/* side buttons */}
      <div style={btn(w + bezel * 2 - 1, height * 0.2, height * 0.09)} />
      <div style={btn(w + bezel * 2 - 1, height * 0.33, height * 0.14)} />
      {/* screen */}
      <div
        style={{
          position: "absolute",
          left: bezel,
          top: bezel,
          width: w,
          height,
          borderRadius: r,
          overflow: "hidden",
          background: "#000",
          isolation: "isolate",
        }}
      >
        {children}
        {/* punch-hole camera */}
        <div
          style={{
            position: "absolute",
            left: "50%",
            top: height * 0.018,
            width: height * 0.019,
            height: height * 0.019,
            marginLeft: -height * 0.0095,
            borderRadius: "50%",
            background: "radial-gradient(circle at 35% 35%, #2b3140 0%, #050507 60%)",
            boxShadow: "0 0 0 1.5px rgba(255,255,255,0.06)",
          }}
        />
        {/* glass sheen */}
        <div
          style={{
            position: "absolute",
            inset: 0,
            background: `linear-gradient(${115 + rotateY * 1.5}deg, rgba(255,255,255,${0.07 * sheen}) 0%, rgba(255,255,255,0) 32%, rgba(255,255,255,0) 70%, rgba(255,255,255,${0.04 * sheen}) 100%)`,
            pointerEvents: "none",
          }}
        />
      </div>
    </div>
  );
};

const btn = (left: number, top: number, h: number): React.CSSProperties => ({
  position: "absolute",
  left,
  top,
  width: 4,
  height: h,
  borderRadius: 3,
  background: "linear-gradient(90deg, #2a2630, #5b5663)",
});
