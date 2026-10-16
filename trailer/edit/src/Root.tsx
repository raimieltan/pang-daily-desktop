import React from "react";
import { Composition, continueRender, delayRender } from "remotion";
import { TOTAL_SECONDS } from "./edit";
import { fontsReady } from "./theme";
import { Banner, Cover, Icon, IconMark } from "./Branding";
import { Trailer } from "./Trailer";
import { TrailerV2 } from "./v2/TrailerV2";
import { TOTAL_SECONDS as V2_SECONDS } from "./v2/edit";

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
    {/* v2, 60 s: the broke guy's 2am touge run (docs/superpowers/specs/2026-10-16-trailer-v2-design.md). */}
    <Composition id="V2" component={TrailerV2} width={1080} height={1920} fps={FPS}
      durationInFrames={Math.round(V2_SECONDS * FPS)} defaultProps={{ showSafeZones: false }} />
    <Composition id="V2SafeZones" component={TrailerV2} width={1080} height={1920} fps={FPS}
      durationInFrames={Math.round(V2_SECONDS * FPS)} defaultProps={{ showSafeZones: true }} />
    {/* Social account kit (render with `npm run brand`). */}
    <Composition id="YouTubeBanner" component={Banner} width={2560} height={1440} fps={FPS} durationInFrames={1} />
    <Composition id="Icon" component={Icon} width={1080} height={1080} fps={FPS} durationInFrames={1} defaultProps={{ dark: false }} />
    <Composition id="IconDark" component={Icon} width={1080} height={1080} fps={FPS} durationInFrames={1} defaultProps={{ dark: true }} />
    <Composition id="IconMark" component={IconMark} width={1080} height={1080} fps={FPS} durationInFrames={1} />
    <Composition id="CoverTrailer" component={Cover} width={1080} height={1920} fps={FPS} durationInFrames={1}
      defaultProps={{ frame: "cover_idle.png", hook: ["2AM.", "OLD CAR. BROKE GUY."] as [string, string], logoTop: true }} />
    <Composition id="CoverBattle" component={Cover} width={1080} height={1920} fps={FPS} durationInFrames={1}
      defaultProps={{ frame: "cover_battle.png", hook: ["TOUGE", "BATTLES"] as [string, string], logoTop: true }} />
  </>
);
