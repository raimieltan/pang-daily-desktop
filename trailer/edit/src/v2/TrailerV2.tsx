import React from "react";
import { AbsoluteFill, Audio, interpolate, Sequence, staticFile, useVideoConfig } from "remotion";
import { EndCard, Flash } from "../components";
import { SAFE } from "../theme";
import { BuildingLines, Card, Delta, Full, InkWipe, Page, Splash, ToneBurst } from "./components";
import { BEAT, DROP, END, MUSIC, SHOTS, SILENCE, STARTER, TITLE, TOTAL_SECONDS, type Shot } from "./edit";

const Shot: React.FC<{ s: Shot; frames: number }> = ({ s, frames }) => {
  const { fps } = useVideoConfig();
  const bf = BEAT * fps;
  return (
    <AbsoluteFill>
      {s.kind === "full" ? <Full src={s.src} from={s.from} volume={s.volume} pos={s.pos} punch={s.punch} /> : null}
      {s.kind === "page" ? <Page panels={s.panels} stagger={Math.round((s.stagger ?? 1) * bf)} /> : null}
      {s.kind === "splash" ? <Splash src={s.src} at={s.freeze} focus={s.focus} card={s.words} beatFrames={bf} /> : null}
      {s.lines ? <BuildingLines from={s.lines[0]} to={s.lines[1]} frames={frames} /> : null}
      {s.burst !== undefined ? (
        <Sequence from={Math.round(s.burst * fps)} layout="none">
          <ToneBurst />
          <Flash frames={4} />
        </Sequence>
      ) : null}
      {s.delta ? (
        <Sequence from={Math.round((s.delta.at ?? 0) * fps)} layout="none">
          <Delta label={s.delta.label} value={s.delta.value} time={s.delta.time} beatFrames={bf} />
        </Sequence>
      ) : null}
      {s.card ? (
        <Sequence from={Math.round((s.card.at ?? 0) * bf)} layout="none">
          <Card lines={s.card.lines} beatFrames={bf} y={s.card.y} size={s.card.size} second={s.card.second} />
        </Sequence>
      ) : null}
      {s.wipe ? <InkWipe frames={Math.round(bf * 0.75)} /> : null}
      {s.flash ? <Flash /> : null}
    </AbsoluteFill>
  );
};

export const TrailerV2: React.FC<{ showSafeZones?: boolean }> = ({ showSafeZones = false }) => {
  const { fps } = useVideoConfig();
  const total = Math.round(TOTAL_SECONDS * fps);
  const at = (sec: number) => Math.round(sec * fps);
  const titleAt = at(TITLE);
  // Each shot runs until the next one starts; the title card takes over at TITLE.
  const starts = SHOTS.map((s) => at(s.at));
  const music = (fr: number) => {
    const t = fr / fps + DROP; // seconds into the trailer (the Audio starts at the drop)
    if (t >= SILENCE[0] && t < SILENCE[1]) return 0;
    return interpolate(t, [TOTAL_SECONDS - 1.6, TOTAL_SECONDS], [MUSIC.volume, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  };
  return (
    <AbsoluteFill style={{ backgroundColor: "black" }}>
      {SHOTS.map((s, i) => {
        const end = i + 1 < SHOTS.length ? starts[i + 1] : titleAt;
        return (
          <Sequence key={i} from={starts[i]} durationInFrames={end - starts[i]} name={s.name}>
            <Shot s={s} frames={end - starts[i]} />
          </Sequence>
        );
      })}
      <Sequence from={titleAt} durationInFrames={total - titleAt} name="title">
        <EndCard beatFrames={BEAT * fps} pitch={END.pitch} cta={END.cta} />
        <Flash frames={6} />
      </Sequence>
      <Sequence from={at(STARTER.at)} durationInFrames={at(STARTER.seconds)} name="starter">
        <Audio
          src={staticFile(STARTER.file)}
          trimBefore={at(STARTER.from)}
          volume={(fr) => interpolate(fr, [at(STARTER.seconds) - at(1.4), at(STARTER.seconds)], [STARTER.volume, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" })}
        />
      </Sequence>
      {/* The open has no music: the track comes in on its drop, on the engine. */}
      <Sequence from={at(DROP)} name="music">
        <Audio src={staticFile(MUSIC.file)} trimBefore={Math.round(MUSIC.from * fps)} volume={music} />
      </Sequence>
      {showSafeZones ? <SafeZones /> : null}
    </AbsoluteFill>
  );
};

const SafeZones: React.FC = () => (
  <AbsoluteFill style={{ pointerEvents: "none" }}>
    <div style={{ position: "absolute", left: 0, right: 0, top: 0, height: SAFE.top, background: "rgba(255,0,0,0.3)" }} />
    <div style={{ position: "absolute", left: 0, right: 0, top: SAFE.bottom, bottom: 0, background: "rgba(255,0,0,0.3)" }} />
    <div style={{ position: "absolute", left: SAFE.right, right: 0, top: SAFE.top, bottom: 1920 - SAFE.bottom, background: "rgba(255,0,0,0.3)" }} />
  </AbsoluteFill>
);
