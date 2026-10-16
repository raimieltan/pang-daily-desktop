import React from "react";
import { Composition, continueRender, delayRender } from "remotion";
import { TOTAL_SECONDS } from "./edit";
import { fontsReady } from "./theme";
import { Trailer } from "./Trailer";

const fonts = delayRender("fonts");
fontsReady.then(() => continueRender(fonts));

const FPS = 60;

export const Root: React.FC = () => (
  <>
    {/* 9:16 for TikTok, Instagram Reels and YouTube Shorts. */}
    <Composition id="Vertical" component={Trailer} width={1080} height={1920} fps={FPS}
      durationInFrames={Math.round(TOTAL_SECONDS * FPS)} defaultProps={{ showSafeZones: false }} />
    {/* Same cut with the platform UI zones tinted red, for checking text placement. */}
    <Composition id="VerticalSafeZones" component={Trailer} width={1080} height={1920} fps={FPS}
      durationInFrames={Math.round(TOTAL_SECONDS * FPS)} defaultProps={{ showSafeZones: true }} />
  </>
);
