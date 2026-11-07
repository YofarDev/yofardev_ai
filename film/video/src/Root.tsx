import React from "react";
import { Composition } from "remotion";
import { Film, FILM_FRAMES } from "./Film";
import { DesignTest, TitleTest } from "./DesignTest";

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition id="Film" component={Film} durationInFrames={FILM_FRAMES} fps={60} width={1920} height={1080} />
      <Composition id="DesignTest" component={DesignTest} durationInFrames={120} fps={60} width={1920} height={1080} />
      <Composition id="TitleTest" component={TitleTest} durationInFrames={180} fps={60} width={1920} height={1080} />
    </>
  );
};
