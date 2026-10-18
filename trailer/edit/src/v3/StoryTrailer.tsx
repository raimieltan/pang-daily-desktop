import React from "react";
import { AbsoluteFill, Audio, interpolate, Sequence, staticFile, useVideoConfig } from "remotion";
import { SAFE } from "../theme";
import { BlackLine, Bubble, Flash, Narration, Place, Say, Stamp, Take, Tear, Title, Tone, Vignette } from "./components";
import { BEAT, CUTS, type Cut, type Shot, type Words } from "./edit";

const ShotView: React.FC<{ s: Shot }> = ({ s }) => {
  const take = (
    <Take src={s.src} from={s.from} volume={s.volume} speed={s.speed} focus={s.focus} punch={s.punch} drift={s.drift} freeze={s.freeze} grade={s.grade} masks={s.masks} band={s.band} bg={s.bg} />
  );
  return (
    <AbsoluteFill>
      {take}
      {s.tone ? <Tone opacity={s.tone} /> : null}
      {s.vignette ? <Vignette strength={s.vignette} /> : null}
      {s.tear ? (
        <Tear frames={s.tear}>
          <Take src={s.src} from={s.from} volume={0} speed={s.speed} focus={s.focus} freeze={s.freeze} grade={s.grade} />
        </Tear>
      ) : null}
      {s.flash ? <Flash frames={5} color={s.flash === "black" ? "black" : undefined} /> : null}
    </AbsoluteFill>
  );
};

const WordsView: React.FC<{ w: Words }> = ({ w }) => {
  switch (w.kind) {
    case "narr":
      return <Narration text={w.text} y={w.y} cps={w.cps} />;
    case "say":
      return <Say who={w.who ?? ""} text={w.text} footage={w.footage} side={w.side} cps={w.cps} />;
    case "place":
      return <Place text={w.text} />;
    case "stamp":
      return <Stamp text={w.text} warm={w.warm} />;
    case "black":
      return <BlackLine text={w.text} cps={w.cps} size={w.size} />;
    case "bubble":
      return <Bubble who={w.who ?? ""} text={w.text} cps={w.cps} />;
  }
};

/** The story trailer: one edit list per format (`cut`), shared components laying out for either. */
export const StoryTrailer: React.FC<{ cut: "wide" | "tall"; showSafeZones?: boolean }> = ({ cut, showSafeZones = false }) => {
  const { fps } = useVideoConfig();
  const c: Cut = CUTS[cut];
  const at = (sec: number) => Math.round(sec * fps);
  const total = at(c.seconds);
  const starts = c.shots.map((s) => at(s.at));
  return (
    <AbsoluteFill style={{ backgroundColor: "black" }}>
      {c.shots.map((s, i) => {
        const end = s.dur !== undefined ? starts[i] + at(s.dur) : i + 1 < c.shots.length ? starts[i + 1] : at(c.title);
        return (
          <Sequence key={`s${i}`} from={starts[i]} durationInFrames={Math.max(1, end - starts[i])} name={`${s.src}@${s.from}`}>
            <ShotView s={s} />
          </Sequence>
        );
      })}
      {c.words.map((w, i) => (
        <Sequence key={`w${i}`} from={at(w.at)} durationInFrames={at(w.dur)} name={`${w.kind}: ${w.text.slice(0, 24)}`}>
          <WordsView w={w} />
        </Sequence>
      ))}
      <Sequence from={at(c.title)} durationInFrames={at(c.titleDur)} name="title">
        <Title beatFrames={BEAT * fps} />
        <Flash frames={8} />
      </Sequence>
      {c.after.map((w, i) => (
        <Sequence key={`a${i}`} from={at(w.at)} durationInFrames={at(w.dur)} name={`after: ${w.text}`}>
          <WordsView w={w} />
        </Sequence>
      ))}
      {c.music.map((m, i) => {
        const len = at(m.to - m.from);
        const fadeIn = at(m.fadeIn ?? 0.012);
        const fadeOut = at(m.fadeOut ?? 0.012);
        return (
          <Sequence key={`m${i}`} from={at(m.at)} durationInFrames={len} name={`music ${m.from}-${m.to}`}>
            <Audio
              src={staticFile(c.musicFile)}
              trimBefore={at(m.from)}
              volume={(f) =>
                c.musicVolume *
                Math.min(
                  interpolate(f, [0, Math.max(1, fadeIn)], [0, 1], { extrapolateRight: "clamp" }),
                  interpolate(f, [len - Math.max(1, fadeOut), len], [1, 0], { extrapolateLeft: "clamp" }),
                )
              }
            />
          </Sequence>
        );
      })}
      {c.sfx.map((x, i) => (
        <Sequence key={`x${i}`} from={at(x.at)} name={`sfx ${x.file}`}>
          <Audio src={staticFile(`sfx/${x.file}.mp3`)} volume={x.volume ?? 0.8} />
        </Sequence>
      ))}
      {showSafeZones ? <SafeZones /> : null}
      <Sequence from={total - 1} durationInFrames={1} layout="none">
        <AbsoluteFill style={{ backgroundColor: "black" }} />
      </Sequence>
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
