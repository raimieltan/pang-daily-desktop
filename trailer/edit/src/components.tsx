import React from "react";
import {
  AbsoluteFill,
  Easing,
  interpolate,
  OffthreadVideo,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { CAPTION_FONT, INK, PAPER, RED, SAFE, TITLE_FONT, YELLOW } from "./theme";

// The safe area sits left of centre (the right rail is wider than the left margin).
const SAFE_SHIFT = (1080 - SAFE.right - SAFE.left) / 2;

/** A crop of a landscape source: `w` source pixels wide, centred on (cx, cy). */
export type Zoom = { cx: number; cy: number; w: number; srcW: number; srcH: number };

/** One cut of captured footage. Punches in a touch on the cut so every edit hits. */
export const Clip: React.FC<{
  src: string;
  from: number; // seconds into the source
  speed?: number;
  volume?: number;
  zoom?: Zoom;
  punch?: boolean;
}> = ({ src, from, speed = 1, volume = 0.3, zoom, punch = true }) => {
  const frame = useCurrentFrame();
  const { fps, width, height } = useVideoConfig();
  const kick = punch ? interpolate(frame, [0, 7], [1.07, 1], { extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) }) : 1;
  const video = (
    <OffthreadVideo
      src={staticFile(`footage/${src}`)}
      trimBefore={Math.round(from * fps)}
      playbackRate={speed}
      volume={volume}
      style={zoom ? undefined : { width: "100%", height: "100%", objectFit: "cover" }}
    />
  );
  if (!zoom) {
    return <AbsoluteFill style={{ transform: `scale(${kick})` }}>{video}</AbsoluteFill>;
  }
  const s = width / zoom.w;
  return (
    <AbsoluteFill style={{ backgroundColor: PAPER, overflow: "hidden" }}>
      <div
        style={{
          position: "absolute",
          width: zoom.srcW,
          height: zoom.srcH,
          // Scaling about (cx, cy) keeps that point fixed, so just put it at the frame centre.
          left: width / 2 - zoom.cx,
          top: height / 2 - zoom.cy,
          transform: `scale(${s * kick})`,
          transformOrigin: `${zoom.cx}px ${zoom.cy}px`,
        }}
      >
        {video}
      </div>
    </AbsoluteFill>
  );
};

/** A couple of frames of paper white on a cut: the manga "impact" flash. */
export const Flash: React.FC<{ frames?: number; color?: string }> = ({ frames = 4, color = PAPER }) => {
  const frame = useCurrentFrame();
  const o = interpolate(frame, [0, frames], [0.9, 0], { extrapolateRight: "clamp" });
  return <AbsoluteFill style={{ backgroundColor: color, opacity: o }} />;
};

/** Ink speed lines bursting from the centre, like the game's overlay. */
export const SpeedLines: React.FC<{ opacity?: number }> = ({ opacity = 0.55 }) => {
  const frame = useCurrentFrame();
  const lines = Array.from({ length: 48 }, (_, i) => {
    const a = (i / 48) * Math.PI * 2 + ((i * 7919) % 13) * 0.02;
    const jitter = ((i * 104729 + frame * 31) % 17) / 17;
    const r0 = 400 + jitter * 220;
    const w = 4 + ((i * 31) % 9);
    return { a, r0, w };
  });
  return (
    <AbsoluteFill style={{ opacity }}>
      <svg width={1080} height={1920} viewBox="-540 -960 1080 1920">
        {lines.map((l, i) => {
          const x0 = Math.cos(l.a) * l.r0;
          const y0 = Math.sin(l.a) * l.r0 * 1.5;
          const x1 = Math.cos(l.a) * 1600;
          const y1 = Math.sin(l.a) * 2400;
          const nx = -Math.sin(l.a) * l.w;
          const ny = Math.cos(l.a) * l.w;
          return <polygon key={i} points={`${x0},${y0} ${x1 + nx},${y1 + ny} ${x1 - nx},${y1 - ny}`} fill={INK} />;
        })}
      </svg>
    </AbsoluteFill>
  );
};

/**
 * Kinetic caption: each word slams in on its own beat, paper letters on an ink slab
 * (the game's `_slab` look), tilted like a manga sound effect.
 */
export const Caption: React.FC<{
  words: string[];
  beatFrames: number;
  y?: number;
  size?: number;
  tilt?: number;
  accent?: string;
}> = ({ words, beatFrames, y = SAFE.top + 140, size = 132, tilt = -4, accent = RED }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  return (
    <AbsoluteFill style={{ top: y, alignItems: "center", height: "auto", paddingRight: SAFE_SHIFT * 2 }}>
      <div style={{ transform: `rotate(${tilt}deg)`, display: "flex", flexDirection: "column", alignItems: "center", gap: 18 }}>
        {words.map((w, i) => {
          const start = i * beatFrames;
          const s = spring({ frame: frame - start, fps, config: { damping: 11, stiffness: 220, mass: 0.7 } });
          const scale = interpolate(s, [0, 1], [2.1, 1]);
          const o = frame >= start ? 1 : 0;
          const slab = i % 2 === 0 ? INK : accent;
          return (
            <div
              key={i}
              style={{
                opacity: o,
                transform: `scale(${scale})`,
                background: slab,
                color: PAPER,
                fontFamily: CAPTION_FONT,
                fontSize: size,
                lineHeight: 1,
                letterSpacing: 2,
                padding: "14px 34px 4px",
                boxShadow: `12px 12px 0 ${i % 2 === 0 ? accent : INK}`,
                maxWidth: SAFE.right - SAFE.left,
                textAlign: "center",
              }}
            >
              {w}
            </div>
          );
        })}
      </div>
    </AbsoluteFill>
  );
};

/** Small lower label, e.g. a car name on its clip. */
export const Tag: React.FC<{ text: string; sub?: string }> = ({ text, sub }) => {
  const frame = useCurrentFrame();
  const x = interpolate(frame, [0, 8], [-700, 0], { extrapolateRight: "clamp", easing: Easing.out(Easing.back(1.4)) });
  return (
    <AbsoluteFill style={{ top: SAFE.bottom - 250, left: SAFE.left, height: "auto", transform: `translateX(${x}px)` }}>
      <div style={{ background: YELLOW, color: INK, fontFamily: CAPTION_FONT, fontSize: 92, padding: "10px 30px 0", alignSelf: "flex-start", boxShadow: `10px 10px 0 ${INK}`, transform: "rotate(-3deg)" }}>
        {text}
      </div>
      {sub ? (
        <div style={{ background: INK, color: PAPER, fontFamily: CAPTION_FONT, fontSize: 52, padding: "6px 22px 0", alignSelf: "flex-start", marginTop: 14, marginLeft: 26, transform: "rotate(-3deg)" }}>
          {sub}
        </div>
      ) : null}
    </AbsoluteFill>
  );
};

const TONE = (color: string): React.CSSProperties => ({
  backgroundImage: `radial-gradient(${color} 42%, transparent 44%)`,
  backgroundSize: "34px 34px",
});

/** A band of screentone dots sweeping across the frame and off it: a page-turn style transition. */
export const ToneWipe: React.FC<{ frames: number; color?: string }> = ({ frames, color = INK }) => {
  const frame = useCurrentFrame();
  if (frame > frames) return null;
  const p = interpolate(frame, [0, frames], [0, 1], { extrapolateRight: "clamp", easing: Easing.inOut(Easing.cubic) });
  const edge = p * 3200 - 150;
  const mask = `linear-gradient(160deg, transparent ${edge - 800}px, black ${edge - 350}px, black ${edge}px, transparent ${edge + 1}px)`;
  return <AbsoluteFill style={{ ...TONE(color), WebkitMaskImage: mask, maskImage: mask }} />;
};

/** The title-screen lockup: red sun, extruded paper letters, the subtitle. */
export const Logo: React.FC<{ scale?: number; sub?: string }> = ({ scale = 1, sub = "TOUGE  ·  MOUNTAIN PASS" }) => {
  const extrude = Array.from({ length: 10 }, (_, i) => `${i + 1}px ${i + 1}px 0 ${INK}`).join(", ");
  return (
    <div style={{ position: "relative", display: "flex", flexDirection: "column", alignItems: "center", transform: `scale(${scale})` }}>
      <div style={{ position: "absolute", width: 440, height: 440, borderRadius: 220, background: RED, top: -120 }} />
      {["PANG", "DAILY"].map((w) => (
        <div
          key={w}
          style={{
            position: "relative",
            fontFamily: TITLE_FONT,
            fontSize: 172,
            lineHeight: 0.98,
            color: PAPER,
            WebkitTextStroke: `7px ${INK}`,
            paintOrder: "stroke fill",
            textShadow: extrude,
            letterSpacing: -4,
          }}
        >
          {w}
        </div>
      ))}
      <div style={{ position: "relative", marginTop: 22, fontFamily: CAPTION_FONT, fontSize: 54, color: INK, background: PAPER, padding: "6px 24px 0", border: `5px solid ${INK}` }}>
        {sub}
      </div>
    </div>
  );
};

/** Logo slam: paper page, speed lines, the lockup crashing in on the beat. */
export const LogoSlam: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const s = spring({ frame, fps, config: { damping: 9, stiffness: 260, mass: 0.6 } });
  const shake = frame < 10 ? Math.sin(frame * 2.7) * (10 - frame) * 2 : 0;
  return (
    <AbsoluteFill style={{ backgroundColor: PAPER, alignItems: "center", justifyContent: "center" }}>
      <SpeedLines opacity={0.9} />
      <div style={{ marginRight: SAFE_SHIFT * 2, transform: `translate(${shake}px, ${-shake}px) rotate(-3deg) scale(${interpolate(s, [0, 1], [2.6, 1])})` }}>
        <Logo />
      </div>
    </AbsoluteFill>
  );
};

/** End card: logo, pitch, release line. */
export const EndCard: React.FC<{ beatFrames: number; pitch: string[]; cta: string }> = ({ beatFrames, pitch, cta }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const s = spring({ frame, fps, config: { damping: 12, stiffness: 200 } });
  const ctaIn = spring({ frame: frame - beatFrames * 4, fps, config: { damping: 10, stiffness: 240 } });
  return (
    <AbsoluteFill style={{ backgroundColor: PAPER }}>
      <AbsoluteFill style={TONE("rgba(19,18,18,0.12)")} />
      <AbsoluteFill style={{ top: SAFE.top + 150, height: "auto", alignItems: "center", paddingRight: SAFE_SHIFT * 2 }}>
        <div style={{ transform: `rotate(-3deg) scale(${interpolate(s, [0, 1], [1.8, 0.92])})` }}>
          <Logo />
        </div>
      </AbsoluteFill>
      <AbsoluteFill style={{ top: SAFE.top + 690, height: "auto", alignItems: "center", gap: 6, paddingRight: SAFE_SHIFT * 2 }}>
        {pitch.map((line, i) => {
          const o = interpolate(frame - (i + 1) * beatFrames, [0, 4], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
          return (
            <div key={line} style={{ opacity: o, fontFamily: CAPTION_FONT, fontSize: 68, color: INK, letterSpacing: 1 }}>
              {line}
            </div>
          );
        })}
      </AbsoluteFill>
      <AbsoluteFill style={{ top: SAFE.bottom - 200, height: "auto", alignItems: "center", paddingRight: SAFE_SHIFT * 2 }}>
        <div
          style={{
            transform: `rotate(-2deg) scale(${interpolate(ctaIn, [0, 1], [0, 1])})`,
            background: RED,
            color: PAPER,
            fontFamily: CAPTION_FONT,
            fontSize: 96,
            padding: "14px 46px 2px",
            boxShadow: `12px 12px 0 ${INK}`,
          }}
        >
          {cta}
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
