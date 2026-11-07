import React from "react";
import { AbsoluteFill, Easing, interpolate, useCurrentFrame } from "remotion";
import { ACCENT } from "../lib/theme";
import { Phone } from "../lib/Phone";
import { Segments } from "../lib/Clip";
import { Body, Kicker, RiseWords } from "../lib/Type";
import { ToolChip } from "../lib/ToolChip";
import { toolsPlan } from "../plans";

const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;

export const Tools: React.FC<{ dur: number }> = ({ dur }) => {
  const frame = useCurrentFrame();
  const a = ACCENT.livingRoom;
  const { segs, marks } = toolsPlan();
  const swing = interpolate(frame, [0, 34], [0, 1], { ...clamp, easing: Easing.bezier(0.16, 1, 0.3, 1) });
  const out = interpolate(frame, [dur - 20, dur], [1, 0], clamp);
  const wSend = marks[0].send;
  const nSend = marks[1].send;
  return (
    <AbsoluteFill style={{ opacity: out }}>
      <Phone
        height={900}
        accent={a}
        x={440 + (1 - swing) * 80}
        rotateY={interpolate(frame, [0, dur], [-11, -5])}
        rotateX={2}
        opacity={swing}
      >
        <Segments segs={segs} fade={10} />
      </Phone>
      <div style={{ position: "absolute", left: 140, top: 250, width: 820 }}>
        <Kicker text="It does things" accent={a} start={8} out={nSend - 60} />
        <div style={{ height: 22 }} />
        <RiseWords text="Real tools, *acted out.*" size={92} align="left" accent={a} start={14} out={nSend - 60} />
        <div style={{ height: 26 }} />
        <Body
          text="Ask for the weather and it pulls out a tablet while the call runs, then tells you what it found."
          start={36}
          out={nSend - 60}
          maxWidth={700}
        />
      </div>
      <div style={{ position: "absolute", left: 140, top: 250, width: 820 }}>
        <Kicker text="It reads, too" accent={a} start={nSend - 40} />
        <div style={{ height: 22 }} />
        <RiseWords text="The news, *on paper.*" size={92} align="left" accent={a} start={nSend - 34} />
        <div style={{ height: 26 }} />
        <Body
          text="Web search, the news, a calculator… each tool gets its own prop and its own body language."
          start={nSend - 12}
          maxWidth={700}
        />
      </div>
      <ToolChip
        fn="getCurrentWeather"
        args={`{ location: "Tokyo" }`}
        accent={a}
        start={wSend + 6}
        done={segs[marks[0].answer].from - 20}
        end={marks[1].send - 120}
        x={140}
        y={720}
      />
      <ToolChip
        fn="getMostPopularNewsOfTheDay"
        args=""
        accent={a}
        start={nSend + 6}
        done={segs[marks[1].answer].from - 20}
        end={dur - 16}
        x={140}
        y={720}
      />
    </AbsoluteFill>
  );
};
