import React from "react";
import { AbsoluteFill, Audio, interpolate, Sequence, staticFile, useVideoConfig } from "remotion";
import { Caption, Clip, EndCard, Flash, LogoSlam, SpeedLines, Tag, ToneWipe } from "./components";
import { BEAT, CUTS, END, MUSIC, TEXT, TOTAL_SECONDS } from "./edit";
import { SAFE } from "./theme";

const f = (beats: number, fps: number) => Math.round(beats * BEAT * fps);

export const Trailer: React.FC<{ showSafeZones?: boolean }> = ({ showSafeZones = false }) => {
  const { fps } = useVideoConfig();
  const total = Math.round(TOTAL_SECONDS * fps);
  let beat = 0;
  const cuts = CUTS.map((c, i) => {
    const start = f(beat, fps);
    beat += c.beats;
    const len = f(beat, fps) - start;
    return (
      <Sequence key={i} from={start} durationInFrames={len} name={c.name}>
        {c.graphic === "logo" ? (
          <LogoSlam />
        ) : (
          <Clip src={c.src!} from={c.from!} speed={c.speed} volume={c.volume} zoom={c.zoom} />
        )}
        {c.lines ? <SpeedLines opacity={0.35} /> : null}
        {c.tag ? <Tag text={c.tag[0]} sub={c.tag[1]} /> : null}
        {c.wipeIn ? <ToneWipe frames={Math.round(BEAT * fps)} /> : null}
        {c.flash ? <Flash /> : null}
      </Sequence>
    );
  });
  const endStart = f(beat, fps);
  return (
    <AbsoluteFill style={{ backgroundColor: "black" }}>
      {cuts}
      <Sequence from={endStart} durationInFrames={total - endStart} name="end card">
        <EndCard beatFrames={BEAT * fps} pitch={END.pitch} cta={END.cta} />
        <Flash frames={6} />
      </Sequence>
      {TEXT.map((t, i) => (
        <Sequence key={`t${i}`} from={f(t.at, fps)} durationInFrames={f(t.beats, fps)} name={t.words.join(" ")}>
          <Caption words={t.words} beatFrames={BEAT * fps} y={t.y} size={t.size} />
        </Sequence>
      ))}
      <Audio
        src={staticFile(MUSIC.file)}
        trimBefore={Math.round(MUSIC.from * fps)}
        volume={(fr) => interpolate(fr, [total - Math.round(1.4 * fps), total], [MUSIC.volume, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" })}
      />
      {showSafeZones ? <SafeZones /> : null}
    </AbsoluteFill>
  );
};

/** Debug overlay: where TikTok / Reels / Shorts put their own UI. */
const SafeZones: React.FC = () => (
  <AbsoluteFill style={{ pointerEvents: "none" }}>
    <div style={{ position: "absolute", left: 0, right: 0, top: 0, height: SAFE.top, background: "rgba(255,0,0,0.3)" }} />
    <div style={{ position: "absolute", left: 0, right: 0, top: SAFE.bottom, bottom: 0, background: "rgba(255,0,0,0.3)" }} />
    <div style={{ position: "absolute", left: SAFE.right, right: 0, top: SAFE.top, bottom: 1920 - SAFE.bottom, background: "rgba(255,0,0,0.3)" }} />
  </AbsoluteFill>
);
