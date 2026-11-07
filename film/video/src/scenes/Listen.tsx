import React from "react";
import { AbsoluteFill, Easing, interpolate, useCurrentFrame } from "remotion";
import { ACCENT } from "../lib/theme";
import { Phone } from "../lib/Phone";
import { Segments } from "../lib/Clip";
import { Body, Kicker, RiseWords } from "../lib/Type";
import { Callout } from "../lib/Callout";
import { LISTEN_BASE } from "../plans";
import { ev } from "../data/events";

const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;
const f = (ms: number) => Math.round((ms / 1000) * 60);

export const Listen: React.FC<{ dur: number }> = ({ dur }) => {
  const frame = useCurrentFrame();
  const a = ACCENT.livingRoom;
  const base = LISTEN_BASE();
  const send = f(ev("film_hello", "send", 0, 9400) - base);
  const speak = f(ev("film_hello", "start", 0, 11900) - base);
  const phoneIn = interpolate(frame, [0, 40], [0, 1], { ...clamp, easing: Easing.bezier(0.16, 1, 0.3, 1) });
  const out = interpolate(frame, [dur - 20, dur], [1, 0], clamp);
  const sw = speak - 26; // the headline swap
  // screen geometry (for the callouts): phone centre x = 960 - 440
  const cx = 520;
  return (
    <AbsoluteFill style={{ opacity: out }}>
      <Phone
        height={900}
        accent={a}
        x={-440 - (1 - phoneIn) * 60}
        rotateY={interpolate(frame, [0, dur], [11, 5])}
        rotateX={2}
        opacity={phoneIn}
      >
        <Segments segs={[{ from: 0, dur, tag: "film_hello", atMs: base, zoom: 1, zoomTo: 1.06, focus: [0.5, 0.4] }]} />
      </Phone>
      <div style={{ position: "absolute", left: 980, top: 250, width: 820 }}>
        <Kicker text="It listens" accent={a} start={10} out={sw} />
        <div style={{ height: 22 }} />
        <RiseWords text="It watches you *type.*" size={92} align="left" accent={a} start={18} out={sw} />
        <div style={{ height: 26 }} />
        <Body
          text="Its eyes follow the caret, it leans in and nods along — before you even hit send."
          start={40}
          out={sw}
          maxWidth={720}
        />
      </div>
      <div style={{ position: "absolute", left: 980, top: 250, width: 820 }}>
        <Kicker text="It talks" accent={a} start={sw + 14} />
        <div style={{ height: 22 }} />
        <RiseWords text="And it answers, *out loud.*" size={92} align="left" accent={a} start={sw + 20} />
        <div style={{ height: 26 }} />
        <Body
          text="A neural voice running on the phone itself, with the lips, brows and breath driven by the audio."
          start={sw + 44}
          maxWidth={720}
        />
      </div>
      <Callout
        from={[cx + 30, 330]}
        to={[980, 760]}
        title="Gaze & presence"
        sub="Caret tracking, lean-in, backchannel nods"
        accent={a}
        start={send - 70}
        end={sw}
      />
      <Callout
        from={[cx, 452]}
        to={[980, 770]}
        title="On-device voice"
        sub="Kokoro-82M · no cloud TTS"
        accent={a}
        start={speak + 20}
        end={dur - 10}
        width={440}
      />
      <Callout
        from={[cx - 24, 470]}
        to={[980, 900]}
        title="Phoneme lip-sync"
        sub="14 facial action units"
        accent={a}
        start={speak + 50}
        end={dur - 10}
        width={440}
      />
    </AbsoluteFill>
  );
};
