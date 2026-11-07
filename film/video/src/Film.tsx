import React from "react";
import { AbsoluteFill, Easing, interpolate, interpolateColors, Sequence, useCurrentFrame } from "remotion";
import { Backdrop, Grain } from "./lib/Backdrop";
import { ACCENT } from "./lib/theme";
import { ColdOpen } from "./scenes/ColdOpen";
import { Title } from "./scenes/Title";
import { Listen } from "./scenes/Listen";
import { Tools } from "./scenes/Tools";
import { Wardrobe } from "./scenes/Wardrobe";
import { Journey } from "./scenes/Journey";
import { World } from "./scenes/World";
import { Hood } from "./scenes/Hood";
import { Finale } from "./scenes/Finale";
import { sections, total } from "./sections";

const SCENES: Record<string, React.FC<{ dur: number }>> = {
  cold: () => <ColdOpen />,
  title: Title,
  listen: Listen,
  tools: Tools,
  wardrobe: Wardrobe,
  journey: Journey,
  world: World,
  hood: Hood,
  finale: Finale,
};

const ACCENTS: Record<string, string> = {
  cold: ACCENT.livingRoom,
  title: ACCENT.livingRoom,
  listen: ACCENT.livingRoom,
  tools: ACCENT.livingRoom,
  wardrobe: ACCENT.livingRoom,
  journey: ACCENT.beach,
  world: ACCENT.campfire,
  hood: ACCENT.deepSpace,
  finale: ACCENT.beach,
};

const AccentBackdrop: React.FC = () => {
  const frame = useCurrentFrame();
  const s = sections();
  const stops = s.map((x) => x.from + 20);
  const colors = s.map((x) => ACCENTS[x.id]);
  const accent = interpolateColors(frame, stops, colors);
  return <Backdrop accent={accent} />;
};

export const Film: React.FC = () => {
  const s = sections();
  return (
    <AbsoluteFill>
      <AccentBackdrop />
      {s.map((x) => {
        const C = SCENES[x.id];
        return (
          <Sequence key={x.id} from={x.from} durationInFrames={x.dur} name={x.id}>
            <Push dur={x.dur} first={x.id === "cold"} last={x.id === "finale"}>
              <C dur={x.dur} />
            </Push>
          </Sequence>
        );
      })}
      <Grain opacity={0.06} />
    </AbsoluteFill>
  );
};

/** Every section pushes in out of a soft blur and leaves the same way, as
 * if the camera moved on (the hits in the mix land on these). */
const Push: React.FC<{ dur: number; first: boolean; last: boolean; children: React.ReactNode }> = ({
  dur,
  first,
  last,
  children,
}) => {
  const frame = useCurrentFrame();
  const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;
  const inP = first ? 1 : interpolate(frame, [0, 22], [0, 1], { ...clamp, easing: Easing.bezier(0.16, 1, 0.3, 1) });
  const outP = last ? 0 : interpolate(frame, [dur - 22, dur], [0, 1], { ...clamp, easing: Easing.bezier(0.7, 0, 0.84, 0) });
  const blur = (1 - inP) * 14 + outP * 14;
  return (
    <AbsoluteFill
      style={{
        scale: String(1.035 - 0.035 * inP - 0.03 * outP),
        filter: blur > 0.05 ? `blur(${blur}px)` : undefined,
      }}
    >
      {children}
    </AbsoluteFill>
  );
};

export const FILM_FRAMES = total();
