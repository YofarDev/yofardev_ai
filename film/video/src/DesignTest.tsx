import React from "react";
import { AbsoluteFill } from "remotion";
import { Backdrop, Grain } from "./lib/Backdrop";
import { Phone } from "./lib/Phone";
import { Wordmark } from "./lib/Cards";
import { Kicker, RiseWords, Body } from "./lib/Type";
import { Callout } from "./lib/Callout";
import { ACCENT } from "./lib/theme";

export const DesignTest: React.FC = () => {
  const a = ACCENT.livingRoom;
  return (
    <AbsoluteFill>
      <Backdrop accent={a} />
      <Phone height={880} accent={a} x={-420} rotateY={14} rotateX={2}>
        <div style={{ position: "absolute", inset: 0, background: "linear-gradient(#2a3a3a,#5a4630)" }} />
      </Phone>
      <div style={{ position: "absolute", left: 960, top: 300, width: 800 }}>
        <Kicker text="It listens" accent={a} />
        <div style={{ height: 24 }} />
        <RiseWords text="It watches you *type.*" size={92} align="left" accent={a} />
        <div style={{ height: 24 }} />
        <Body text="Gaze follows the caret, it leans in, nods along — before you even hit send." />
      </div>
      <Callout from={[600, 420]} to={[980, 760]} title="On-device voice" sub="Kokoro-82M, no cloud TTS" accent={a} start={0} end={9999} />
      <Grain />
    </AbsoluteFill>
  );
};

export const TitleTest: React.FC = () => (
  <AbsoluteFill>
    <Backdrop accent={ACCENT.livingRoom} />
    <AbsoluteFill style={{ alignItems: "center", justifyContent: "center" }}>
      <Wordmark accent={ACCENT.livingRoom} sub="An AI companion with a voice, a face, and a little world of its own." />
    </AbsoluteFill>
    <Grain />
  </AbsoluteFill>
);
