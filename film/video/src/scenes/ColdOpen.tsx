import React from "react";
import { AbsoluteFill, Easing, interpolate, Sequence, useCurrentFrame } from "remotion";
import { BODY, MUTED, PAPER, ACCENT, bar } from "../lib/theme";
import { RiseWords } from "../lib/Type";
import { Clip } from "../lib/Clip";
import { hex } from "../lib/Backdrop";
import { Phone } from "../lib/Phone";
import { ev } from "../data/events";

/** The run's idle before the first typing (the cat poked), shown from bar 3. */
const IDLE_MS = Math.max(0, ev("film_hello", "typing", 0, 6500) - 5200);

const EASE = Easing.bezier(0.65, 0, 0.35, 1);
const OUT = Easing.bezier(0.16, 1, 0.3, 1);
const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;

/** Bars 1-4: "Most AI assistants live in a text box." A chat field sits
 * under the line, its caret blinking; it swells into the phone and the
 * living room fades up inside it: "This one has a home." */
export const ColdOpen: React.FC = () => {
  const frame = useCurrentFrame();
  const a = ACCENT.livingRoom;
  // the morph: text box -> phone screen
  const m = interpolate(frame, [bar(3, 0), bar(3, 3)], [0, 1], { ...clamp, easing: EASE });
  const boxIn = interpolate(frame, [70, 110], [0, 1], { ...clamp, easing: OUT });
  const W = interpolate(m, [0, 1], [820, 495]);
  const H = interpolate(m, [0, 1], [96, 880]);
  const R = interpolate(m, [0, 1], [48, 52]);
  const X = interpolate(m, [0, 1], [960, 1920 - 560]);
  const Y = interpolate(m, [0, 1], [640, 540]);
  const scene = interpolate(frame, [bar(3, 1.5), bar(4, 0)], [0, 1], clamp);
  const caret = Math.floor(frame / 32) % 2 === 0 ? 1 : 0;
  const PROMPT = "What's the weather in Tokyo?";
  const typed = PROMPT.slice(0, Math.max(0, Math.min(PROMPT.length, Math.floor((frame - 110) / 4.2))));
  const lineOut = bar(3, 0) - 20;
  // the phone eases forward a little through bar 4 (handing over to the title)
  const push = interpolate(frame, [bar(4, 0), bar(5, 0)], [1, 1.04], clamp);
  return (
    <AbsoluteFill>
      {/* line 1 */}
      <AbsoluteFill style={{ alignItems: "center", top: 380 }}>
        <RiseWords
          text="Most AI assistants live in a text box."
          start={24}
          stagger={5}
          size={74}
          out={lineOut}
          weight={300}
        />
      </AbsoluteFill>
      {/* the real phone body takes over once the box has grown */}
      <Phone
        height={880}
        accent={a}
        x={400}
        scale={push}
        opacity={interpolate(m, [0.75, 1], [0, 1], clamp)}
        glow={interpolate(frame, [bar(3, 3), bar(4, 2)], [0, 1], clamp)}
        float={interpolate(frame, [bar(3, 3) + 12, bar(4, 3)], [0, 1], clamp)}
      >
        <Sequence from={bar(3, 0)} layout="none"><Clip tag="film_hello" atMs={IDLE_MS} /></Sequence>
      </Phone>
      {/* the box that becomes the phone */}
      <div
        style={{
          position: "absolute",
          left: X - W / 2,
          top: Y - H / 2,
          width: W,
          height: H,
          borderRadius: R,
          overflow: "hidden",
          opacity: boxIn * interpolate(frame, [bar(3, 3), bar(3, 3) + 10], [1, 0], clamp),
          transform: `scale(${push})`,
          background: `linear-gradient(160deg, rgba(48,40,62,${0.9 - m * 0.9}), rgba(26,21,34,${0.9 - m * 0.9}))`,
          border: `1px solid rgba(255,255,255,${0.12 * (1 - m)})`,
          boxShadow: `0 30px 80px rgba(0,0,0,${0.35 + m * 0.25}), 0 0 ${80 * m}px ${a}${hex(0.25 * m)}`,
        }}
      >
        <div style={{ position: "absolute", inset: 0, opacity: scene }}>
          <Sequence from={bar(3, 0)} layout="none"><Clip tag="film_hello" atMs={IDLE_MS} /></Sequence>
        </div>
        {/* the field's contents fade as it grows */}
        <div
          style={{
            position: "absolute",
            left: 36,
            top: 0,
            height: 96,
            display: "flex",
            alignItems: "center",
            gap: 4,
            opacity: 1 - m * 3,
            fontFamily: BODY,
            fontSize: 30,
            color: MUTED,
          }}
        >
          {typed.length === 0 ? (
            <>
              <div style={{ width: 2, height: 34, background: PAPER, opacity: caret, marginRight: 8 }} />
              Ask anything…
            </>
          ) : (
            <span style={{ color: PAPER }}>
              {typed}
              <span style={{ display: "inline-block", width: 2, height: 30, marginLeft: 3, verticalAlign: "-4px", background: PAPER, opacity: caret }} />
            </span>
          )}
        </div>
      </div>
      {/* line 2 */}
      <div style={{ position: "absolute", left: 170, top: 400, width: 900 }}>
        <RiseWords
          text="This one has a *home.*"
          start={bar(3, 2.5)}
          stagger={6}
          size={96}
          align="left"
          accent={a}
          out={bar(5, 0) - 16}
          outDur={14}
        />
      </div>
    </AbsoluteFill>
  );
};
