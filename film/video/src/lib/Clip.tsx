import React from "react";
import { Video } from "@remotion/media";
import { interpolate, Sequence, staticFile, useCurrentFrame } from "remotion";

/** A captured run, playing from `atMs` on the run's own clock. The video is
 * 576×1024 (9:16); it fills its parent (object-fit cover). `zoom` and
 * `focus` (0..1 of the frame) crop into it for close-ups. */
export const Clip: React.FC<{
  tag: string;
  atMs: number;
  zoom?: number;
  focus?: [number, number];
  style?: React.CSSProperties;
  /** the box size when it is not 9:16 (the video then covers it) */
  box?: [number, number];
  rate?: number;
}> = ({ tag, atMs, zoom = 1, focus = [0.5, 0.4], style, box, rate = 1 }) => {
  let vstyle: React.CSSProperties = { width: "100%", height: "100%" };
  if (box) {
    const [bw, bh] = box;
    const vw = Math.max(bw, (bh * 9) / 16);
    const vh = (vw * 16) / 9;
    vstyle = {
      position: "absolute",
      width: vw,
      height: vh,
      left: (bw - vw) / 2,
      top: (bh - vh) * focus[1],
    };
  }
  return (
    <div style={{ position: "absolute", inset: 0, overflow: "hidden", ...style }}>
      <div
        style={{
          position: "absolute",
          inset: 0,
          transform: `scale(${zoom})`,
          transformOrigin: `${focus[0] * 100}% ${focus[1] * 100}%`,
        }}
      >
        <Video
          src={staticFile(`clips/${tag}.mp4`)}
          trimBefore={Math.round((atMs / 1000) * 60)}
          muted
          playbackRate={rate}
          style={vstyle}
        />
      </div>
    </div>
  );
};

export type { Seg } from "./segtypes";
import type { Seg } from "./segtypes";

/** Clip segments back to back; each fades in over `fade` frames on top of
 * the previous one (the previous keeps playing under it). */
export const Segments: React.FC<{ segs: Seg[]; fade?: number }> = ({ segs, fade = 8 }) => (
  <>
    {segs.map((s, i) => (
      <Sequence key={i} from={s.from} durationInFrames={i < segs.length - 1 ? s.dur + fade : undefined} layout="none">
        <SegView seg={s} fade={i === 0 ? 0 : fade} />
      </Sequence>
    ))}
  </>
);

const SegView: React.FC<{ seg: Seg; fade: number }> = ({ seg, fade }) => {
  const frame = useCurrentFrame();
  const o = fade === 0 ? 1 : interpolate(frame, [0, fade], [0, 1], { extrapolateRight: "clamp" });
  const z = interpolate(frame, [0, seg.dur], [seg.zoom ?? 1, seg.zoomTo ?? seg.zoom ?? 1], {
    extrapolateRight: "clamp",
  });
  return (
    <div style={{ position: "absolute", inset: 0, opacity: o }}>
      <Clip tag={seg.tag} atMs={seg.atMs} zoom={z} focus={seg.focus} rate={seg.rate} />
    </div>
  );
};
