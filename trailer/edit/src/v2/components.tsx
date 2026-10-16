import React from "react";
import {
  AbsoluteFill,
  Easing,
  Freeze,
  interpolate,
  OffthreadVideo,
  Sequence,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { SpeedLines } from "../components";
import { CAPTION_FONT, INK, PAPER, RED, SAFE, TITLE_FONT, YELLOW } from "../theme";

export const GREEN = "#2DB45A";

/** Captured footage filling its box; `pos` is the CSS object-position (which part of the 9:16 source shows). */
export const Footage: React.FC<{ src: string; from: number; pos?: string; volume?: number; speed?: number }> = ({
  src,
  from,
  pos = "50% 50%",
  volume = 0,
  speed = 1,
}) => {
  const { fps } = useVideoConfig();
  return (
    <OffthreadVideo
      src={staticFile(`footage/${src}`)}
      trimBefore={Math.round(from * fps)}
      playbackRate={speed}
      volume={volume}
      style={{ width: "100%", height: "100%", objectFit: "cover", objectPosition: pos }}
    />
  );
};

/** A full-frame shot that slams in: a short punch-in on the cut. */
export const Full: React.FC<{ src: string; from: number; volume?: number; pos?: string; punch?: boolean }> = ({
  src,
  from,
  volume = 0.9,
  pos,
  punch = true,
}) => {
  const frame = useCurrentFrame();
  const k = punch ? interpolate(frame, [0, 7], [1.08, 1], { extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) }) : 1;
  return (
    <AbsoluteFill style={{ transform: `scale(${k})` }}>
      <Footage src={src} from={from} volume={volume} pos={pos} />
    </AbsoluteFill>
  );
};

/** What fills one tier of a page: footage, or a paper panel with a time readout. */
export type PanelContent =
  | { src: string; from: number; pos?: string; volume?: number; readout?: Readout }
  | { readout: Readout };

/** A sector split or delta, always from the time-attack run that produced it. */
export type Readout = { label: string; value: string; tone?: "green" | "red" | "ink" };

// Three slanted tiers down the 9:16 frame, as polygons in frame pixels (mockup A). The gutters
// between them are paper; 2-tier pages use the first and last shapes stretched to meet.
const GUTTER = 22;
const TIERS: Record<2 | 3, number[][][]> = {
  2: [
    [[0, 0], [1080, 0], [1080, 860], [0, 1010]],
    [[0, 1010 + GUTTER], [1080, 860 + GUTTER], [1080, 1920], [0, 1920]],
  ],
  3: [
    [[0, 0], [1080, 0], [1080, 610], [0, 700]],
    [[0, 700 + GUTTER], [1080, 610 + GUTTER], [1080, 1220], [0, 1310]],
    [[0, 1310 + GUTTER], [1080, 1220 + GUTTER], [1080, 1920], [0, 1920]],
  ],
};

const poly = (pts: number[][]) => `polygon(${pts.map(([x, y]) => `${x}px ${y}px`).join(", ")})`;

/**
 * A manga page: 2–3 slanted panels stacked top to bottom on paper, each slamming in `stagger`
 * frames after the one above, ink borders round each.
 */
export const Page: React.FC<{ panels: PanelContent[]; stagger: number }> = ({ panels, stagger }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const shapes = TIERS[panels.length as 2 | 3];
  return (
    <AbsoluteFill style={{ backgroundColor: PAPER }}>
      {panels.map((p, i) => {
        const start = i * stagger;
        const s = spring({ frame: frame - start, fps, config: { damping: 14, stiffness: 260, mass: 0.6 } });
        const dx = interpolate(s, [0, 1], [i % 2 ? 1080 : -1080, 0]);
        const pts = shapes[i];
        const ys = pts.map((q) => q[1]);
        const top = Math.min(...ys);
        const bottom = Math.max(...ys);
        return (
          <AbsoluteFill key={i} style={{ transform: `translateX(${dx}px)`, opacity: frame >= start ? 1 : 0 }}>
            <AbsoluteFill style={{ clipPath: poly(pts) }}>
              <div style={{ position: "absolute", left: 0, right: 0, top, height: bottom - top }}>
                {"src" in p ? (
                  <Footage src={p.src} from={p.from + start / fps} pos={p.pos} volume={p.volume ?? 0} />
                ) : (
                  <AbsoluteFill style={{ backgroundColor: PAPER }} />
                )}
                <Tone opacity={0.1} />
              </div>
            </AbsoluteFill>
            <svg width={1080} height={1920} style={{ position: "absolute", inset: 0 }}>
              <polygon points={pts.map((q) => q.join(",")).join(" ")} fill="none" stroke={INK} strokeWidth={10} />
            </svg>
            {p.readout ? <ReadoutBox r={p.readout} top={top} bottom={bottom} big={!("src" in p)} delay={start + 4} /> : null}
          </AbsoluteFill>
        );
      })}
    </AbsoluteFill>
  );
};

const toneColor = (t?: Readout["tone"]) => (t === "green" ? GREEN : t === "red" ? RED : INK);

/** Sector time in the game's title face: a small label over a big number. */
const ReadoutBox: React.FC<{ r: Readout; top: number; bottom: number; big: boolean; delay: number }> = ({ r, top, bottom, big, delay }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const s = spring({ frame: frame - delay, fps, config: { damping: 10, stiffness: 300, mass: 0.5 } });
  const size = big ? 168 : 104;
  return (
    <div
      style={{
        position: "absolute",
        left: SAFE.left + 10,
        top: big ? (top + bottom) / 2 - size * 0.8 : bottom - size - 120,
        transform: `rotate(-4deg) scale(${interpolate(s, [0, 1], [1.9, 1])})`,
        transformOrigin: "left center",
        opacity: frame >= delay ? 1 : 0,
      }}
    >
      <div style={{ display: "inline-block", background: INK, color: PAPER, fontFamily: CAPTION_FONT, fontSize: big ? 56 : 42, letterSpacing: 4, padding: "6px 18px 0" }}>
        {r.label}
      </div>
      <div
        style={{
          fontFamily: TITLE_FONT,
          fontSize: size,
          lineHeight: 1,
          color: toneColor(r.tone),
          WebkitTextStroke: big ? undefined : `6px ${PAPER}`,
          paintOrder: "stroke fill",
          letterSpacing: -2,
        }}
      >
        {r.value}
      </div>
    </div>
  );
};

/** Halftone dots over a panel, the printed-page grain. */
export const Tone: React.FC<{ opacity?: number; size?: number; color?: string }> = ({ opacity = 0.2, size = 9, color = INK }) => (
  <AbsoluteFill
    style={{
      backgroundImage: `radial-gradient(${color} 1.6px, transparent 2.2px)`,
      backgroundSize: `${size}px ${size}px`,
      opacity,
      mixBlendMode: "multiply",
      pointerEvents: "none",
    }}
  />
);

/** The voice: a two-line tag box slamming in on the hit, second line one beat later. */
export const Card: React.FC<{ lines: [string, string?]; beatFrames: number; y?: number; size?: number; second?: number }> = ({
  lines,
  beatFrames,
  y = SAFE.top + 120,
  size = 120,
  second = 1,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  return (
    <AbsoluteFill style={{ top: y, left: SAFE.left, height: "auto", width: SAFE.right - SAFE.left }}>
      <div style={{ transform: "rotate(-4deg)", display: "flex", flexDirection: "column", alignItems: "flex-start", gap: 14 }}>
        {lines.map((w, i) => {
          if (!w) return null;
          const start = Math.round(i * second * beatFrames);
          const s = spring({ frame: frame - start, fps, config: { damping: 11, stiffness: 260, mass: 0.6 } });
          return (
            <div
              key={i}
              style={{
                opacity: frame >= start ? 1 : 0,
                transform: `scale(${interpolate(s, [0, 1], [2.2, 1])})`,
                transformOrigin: "left center",
                marginLeft: i * 60,
                background: i === 0 ? INK : YELLOW,
                color: i === 0 ? PAPER : INK,
                fontFamily: CAPTION_FONT,
                fontSize: size,
                lineHeight: 1,
                letterSpacing: 2,
                padding: "12px 30px 2px",
                boxShadow: `12px 12px 0 ${i === 0 ? YELLOW : INK}`,
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

/** Screentone burst on an overtake: a ring of dots blowing out from a point, gone in ~10 frames. */
export const ToneBurst: React.FC<{ x?: number; y?: number; frames?: number }> = ({ x = 540, y = 900, frames = 12 }) => {
  const frame = useCurrentFrame();
  if (frame > frames) return null;
  const p = interpolate(frame, [0, frames], [0, 1], { easing: Easing.out(Easing.cubic) });
  const r0 = p * 1400;
  const mask = `radial-gradient(circle at ${x}px ${y}px, transparent ${r0 - 260}px, black ${r0 - 120}px, black ${r0}px, transparent ${r0 + 1}px)`;
  return (
    <AbsoluteFill
      style={{
        backgroundImage: `radial-gradient(${INK} 40%, transparent 43%)`,
        backgroundSize: "26px 26px",
        WebkitMaskImage: mask,
        maskImage: mask,
        opacity: 1 - p * 0.6,
      }}
    />
  );
};

/** Ink wipe: a ragged brush stroke of black sweeping down the frame, revealing the next shot behind it. */
export const InkWipe: React.FC<{ frames: number; out?: boolean }> = ({ frames, out = false }) => {
  const frame = useCurrentFrame();
  if (frame > frames) return null;
  const p = interpolate(frame, [0, frames], [0, 1], { easing: Easing.inOut(Easing.cubic) });
  // The ink edge leaves the frame top-down; a few rag teeth keep it from looking like a CSS wipe.
  const edge = (out ? p : 1 - p) * 2300 - 190;
  const teeth = Array.from({ length: 13 }, (_, i) => {
    const x = (i / 12) * 1080;
    const d = ((i * 7919) % 11) * 16 + (i % 2) * 40;
    return `${x}px ${edge - d}px`;
  });
  return (
    <AbsoluteFill style={{ backgroundColor: INK, clipPath: `polygon(0 0, 1080px 0, ${teeth.reverse().join(", ")})` }} />
  );
};

/** Radial ink focus lines converging on (x, y), the classic page-of-impact background. */
const FocusLines: React.FC<{ x: number; y: number; inner: number }> = ({ x, y, inner }) => {
  const lines = Array.from({ length: 140 }, (_, i) => {
    const a = (i / 140) * Math.PI * 2 + ((i * 7919) % 13) * 0.004;
    const r0 = inner + (((i * 104729) % 23) / 23) * 260;
    const w = 1.5 + ((i * 31) % 7) * 0.9;
    return { a, r0, w };
  });
  return (
    <svg width={1080} height={1920} style={{ position: "absolute", inset: 0 }}>
      {lines.map((l, i) => {
        const x0 = x + Math.cos(l.a) * l.r0;
        const y0 = y + Math.sin(l.a) * l.r0;
        const x1 = x + Math.cos(l.a) * 2600;
        const y1 = y + Math.sin(l.a) * 2600;
        const nx = -Math.sin(l.a) * l.w * 6;
        const ny = Math.cos(l.a) * l.w * 6;
        return <polygon key={i} points={`${x0},${y0} ${x1 + nx},${y1 + ny} ${x1 - nx},${y1 - ny}`} fill={INK} />;
      })}
    </svg>
  );
};

/**
 * The freeze splash (treatment A): the frame stops, goes to high-contrast black-and-white ink with
 * screentone and focus lines on the car, then a card hits. Held still for the whole sequence.
 */
export const Splash: React.FC<{ src: string; at: number; focus: [number, number]; card: [string, string]; beatFrames: number }> = ({
  src,
  at,
  focus,
  card,
  beatFrames,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  // Two frames of colour, then the ink "print" snaps on.
  const ink = frame >= 2;
  const zoom = interpolate(frame, [0, 6, 90], [1.0, 1.07, 1.12], { extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) });
  return (
    <AbsoluteFill style={{ backgroundColor: PAPER }}>
      <AbsoluteFill style={{ transform: `scale(${zoom})`, transformOrigin: `${focus[0]}px ${focus[1]}px` }}>
        <AbsoluteFill style={{ filter: ink ? "grayscale(1) contrast(2.4) brightness(1.08)" : undefined }}>
          <Freeze frame={Math.round(at * fps)}>
            <OffthreadVideo src={staticFile(`footage/${src}`)} muted style={{ width: "100%", height: "100%", objectFit: "cover" }} />
          </Freeze>
        </AbsoluteFill>
        {ink ? <Tone opacity={0.42} size={8} /> : null}
      </AbsoluteFill>
      {ink ? <FocusLines x={focus[0]} y={focus[1]} inner={360} /> : null}
      <AbsoluteFill style={{ boxShadow: `inset 0 0 0 22px ${PAPER}, inset 0 0 0 32px ${INK}` }} />
      <Sequence from={Math.round(beatFrames * 2)} layout="none">
        <Card lines={card} beatFrames={beatFrames} y={SAFE.bottom - 420} size={138} />
      </Sequence>
    </AbsoluteFill>
  );
};

/** Speed lines whose strength follows a 0–1 ramp over the clip. */
export const BuildingLines: React.FC<{ from: number; to: number; frames: number }> = ({ from, to, frames }) => {
  const frame = useCurrentFrame();
  return <SpeedLines opacity={interpolate(frame, [0, frames], [from, to], { extrapolateRight: "clamp" })} />;
};

/** The finish readout: big delta over the time-attack finish. */
export const Delta: React.FC<{ label: string; value: string; time: string; beatFrames: number }> = ({ label, value, time, beatFrames }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const s = spring({ frame, fps, config: { damping: 12, stiffness: 240, mass: 0.6 } });
  const t = spring({ frame: frame - Math.round(beatFrames * 2), fps, config: { damping: 14, stiffness: 200 } });
  return (
    <AbsoluteFill style={{ top: SAFE.top + 260, left: SAFE.left, height: "auto" }}>
      <div style={{ transform: `rotate(-4deg) scale(${interpolate(s, [0, 1], [2, 1])})`, transformOrigin: "left center" }}>
        <div style={{ display: "inline-block", background: INK, color: PAPER, fontFamily: CAPTION_FONT, fontSize: 60, letterSpacing: 4, padding: "6px 20px 0" }}>
          {label}
        </div>
        <div style={{ fontFamily: TITLE_FONT, fontSize: 210, lineHeight: 1, color: GREEN, WebkitTextStroke: `10px ${PAPER}`, paintOrder: "stroke fill", letterSpacing: -4 }}>
          {value}
        </div>
        <div
          style={{
            opacity: interpolate(t, [0, 1], [0, 1]),
            display: "inline-block",
            marginTop: 10,
            background: PAPER,
            color: INK,
            fontFamily: TITLE_FONT,
            fontSize: 74,
            padding: "4px 18px",
            border: `6px solid ${INK}`,
          }}
        >
          {time}
        </div>
      </div>
    </AbsoluteFill>
  );
};
