import React from "react";
import {
  AbsoluteFill,
  Easing,
  Freeze,
  interpolate,
  OffthreadVideo,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { Logo } from "../components";
import { CAPTION_FONT, INK, PAPER, RED, TITLE_FONT } from "../theme";

/** Is this the 9:16 cut? Everything below lays itself out from the frame size. */
export const useVertical = () => {
  const { width, height } = useVideoConfig();
  return height > width;
};

// Text box for each format: 16:9 keeps a cinema margin; 9:16 stays inside the TikTok/Reels safe
// area (theme.SAFE), the right rail being wider than the left margin.
export const useBox = () => {
  const { width, height } = useVideoConfig();
  return height > width
    ? { left: 70, right: width - 170, top: 260, bottom: height - 420, scale: 1.25 }
    : { left: 120, right: width - 120, top: 90, bottom: height - 90, scale: 1 };
};

/**
 * One story take (trailer/out/story/<src>.mp4, 1920×1080). `focus` = [cx, cy, w] in source pixels:
 * the region shown, centred on (cx, cy) and w source pixels wide (its height follows the output's
 * aspect). Default: the whole frame in 16:9, a full-height centre column in 9:16. The region is
 * kept inside the source, so no edge ever shows.
 */
export const Take: React.FC<{
  src: string;
  from: number;
  volume?: number;
  speed?: number;
  focus?: [number, number, number];
  punch?: boolean;
  drift?: number; // slow push-in over the shot, as a fraction (0.04 = 4 %)
  freeze?: boolean;
  grade?: string; // CSS filter
  masks?: Mask[];
  band?: number; // 9:16 only: show a 16:9 region full-width as a band centred at this y, on paper
  bg?: string;
}> = ({ src, from, volume = 0.6, speed = 1, focus, punch = false, drift = 0, freeze = false, grade, masks = [], band, bg = "black" }) => {
  const frame = useCurrentFrame();
  const { fps, width, height, durationInFrames } = useVideoConfig();
  const vertical = height > width;
  if (vertical && band !== undefined) {
    const [bx, by, bw0] = focus ?? [960, 540, 1920];
    const push = 1 + drift * Math.min(1, frame / Math.max(1, durationInFrames));
    const bw = bw0 / push;
    const bh = (bw * 9) / 16;
    const k = width / bw;
    const bandH = width * (9 / 16);
    const cx = Math.min(1920 - bw / 2, Math.max(bw / 2, bx));
    const cy = Math.min(1080 - bh / 2, Math.max(bh / 2, by));
    return (
      <AbsoluteFill style={{ backgroundColor: PAPER }}>
        <div style={{ position: "absolute", left: 0, top: band - bandH / 2, width, height: bandH, overflow: "hidden", boxShadow: `0 0 0 8px ${INK}` }}>
          <div style={{ position: "absolute", left: width / 2 - cx * k, top: bandH / 2 - cy * k, width: 1920 * k, height: 1080 * k, filter: grade }}>
            <OffthreadVideo
              src={staticFile(`footage/story/${src}.mp4`)}
              trimBefore={Math.round(from * fps)}
              playbackRate={speed}
              volume={volume}
              style={{ width: "100%", height: "100%" }}
            />
            {masks.map((m, i) => (
              <div key={i} style={{ position: "absolute", left: m.x * k, top: m.y * k, width: m.w * k, height: m.h * k, background: m.color }} />
            ))}
          </div>
        </div>
      </AbsoluteFill>
    );
  }
  const kick = punch ? interpolate(frame, [0, 8], [1.06, 1], { extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) }) : 1;
  const push = 1 + drift * Math.min(1, frame / Math.max(1, durationInFrames));
  const [fx, fy, fw0] = focus ?? [960, 540, vertical ? (1080 * width) / height : 1920];
  // A region taller than the source (a whole phone page in 9:16) is allowed: it sits centred on `bg`.
  const fw = Math.min(fw0, 1920) / (kick * push);
  const fh = (fw * height) / width;
  const cx = Math.min(1920 - fw / 2, Math.max(fw / 2, fx));
  const cy = fh > 1080 ? 540 : Math.min(1080 - fh / 2, Math.max(fh / 2, fy));
  const scale = width / fw;
  const video = (
    <OffthreadVideo
      src={staticFile(`footage/story/${src}.mp4`)}
      trimBefore={freeze ? undefined : Math.round(from * fps)}
      playbackRate={speed}
      volume={freeze ? 0 : volume}
      muted={freeze}
      style={{ width: "100%", height: "100%" }}
    />
  );
  return (
    <AbsoluteFill style={{ backgroundColor: bg, overflow: "hidden" }}>
      <div style={{ position: "absolute", left: width / 2 - cx * scale, top: height / 2 - cy * scale, width: 1920 * scale, height: 1080 * scale, filter: grade }}>
        {freeze ? <Freeze frame={Math.round(from * fps)}>{video}</Freeze> : video}
        {masks.map((m, i) => (
          <div key={i} style={{ position: "absolute", left: m.x * scale, top: m.y * scale, width: m.w * scale, height: m.h * scale, background: m.color }} />
        ))}
      </div>
    </AbsoluteFill>
  );
};

/** A patch over part of a UI take (the game's "CLICK / SPACE" prompt), source px, in the panel's own colour. */
export type Mask = { x: number; y: number; w: number; h: number; color: string };

/** Typewriter reveal at `cps` characters a second, like the game's own boxes. */
const typed = (text: string, frame: number, fps: number, cps = 45) => text.slice(0, Math.floor((frame / fps) * cps));

/**
 * Pang's narration: the game's ink box (paper on black), typed on. 16:9 sits low-left like a
 * subtitle you read in his voice; 9:16 sits in the safe area's lower half.
 */
export const Narration: React.FC<{ text: string; cps?: number; y?: "low" | "mid" | "high" }> = ({ text, cps = 45, y = "low" }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const b = useBox();
  const size = 50 * b.scale;
  const pos = y === "mid" ? { top: "50%", transform: "translateY(-50%)" } : y === "high" ? { top: b.top } : { bottom: useVideoConfig().height - b.bottom };
  const shown = typed(text, frame, fps, cps);
  return (
    <div style={{ position: "absolute", left: b.left, maxWidth: (b.right - b.left) * 0.78, ...pos }}>
      <div
        style={{
          background: INK,
          color: PAPER,
          fontFamily: CAPTION_FONT,
          fontSize: size,
          lineHeight: 1.12,
          letterSpacing: 1.5,
          padding: `${size * 0.42}px ${size * 0.6}px ${size * 0.26}px`,
          boxShadow: `${size * 0.16}px ${size * 0.16}px 0 ${RED}`,
          opacity: frame < 1 ? 0 : 1,
        }}
      >
        {/* The full text keeps the box its final size while the typing fills it. */}
        <div style={{ position: "relative" }}>
          <div style={{ visibility: "hidden" }}>{text}</div>
          <div style={{ position: "absolute", left: 0, right: 0, top: 0 }}>{shown}</div>
        </div>
      </div>
    </div>
  );
};

/** A spoken line: the speaker's ink tag over a paper box, as the game's speech panel. */
export const Say: React.FC<{ who: string; text: string; cps?: number; side?: "left" | "right"; footage?: boolean }> = ({
  who,
  text,
  cps = 50,
  side = "left",
  footage = false,
}) => {
  const frame = useCurrentFrame();
  const { fps, height } = useVideoConfig();
  const b = useBox();
  const size = 50 * b.scale;
  const s = spring({ frame, fps, config: { damping: 14, stiffness: 300, mass: 0.5 } });
  const shown = typed(text, frame, fps, cps);
  return (
    <div
      style={{
        position: "absolute",
        bottom: height - b.bottom,
        ...(side === "left" ? { left: b.left } : { right: useVideoConfig().width - b.right }),
        maxWidth: (b.right - b.left) * 0.8,
        transform: `translateY(${interpolate(s, [0, 1], [30, 0])}px)`,
        opacity: interpolate(s, [0, 0.4], [0, 1], { extrapolateRight: "clamp" }),
      }}
    >
      <div
        style={{
          display: "inline-block",
          background: footage ? PAPER : INK,
          color: footage ? INK : PAPER,
          border: footage ? `4px dashed ${INK}` : undefined,
          fontFamily: CAPTION_FONT,
          fontSize: size * 0.72,
          letterSpacing: 3,
          padding: `${size * 0.14}px ${size * 0.34}px 0`,
          marginBottom: -4,
          position: "relative",
          zIndex: 1,
        }}
      >
        {footage ? `${who}  ·  ON THE CLIP` : who}
      </div>
      <div
        style={{
          background: PAPER,
          color: INK,
          border: `${Math.round(size * 0.12)}px solid ${INK}`,
          fontFamily: CAPTION_FONT,
          fontSize: size,
          lineHeight: 1.1,
          letterSpacing: 1,
          padding: `${size * 0.36}px ${size * 0.5}px ${size * 0.2}px`,
          boxShadow: `${size * 0.16}px ${size * 0.16}px 0 ${INK}`,
        }}
      >
        <div style={{ position: "relative" }}>
          <div style={{ visibility: "hidden" }}>{text}</div>
          <div style={{ position: "absolute", left: 0, right: 0, top: 0 }}>{shown}</div>
        </div>
      </div>
    </div>
  );
};

/** The game's red place caption, top-left: "THE CLINIC  ·  AFTER THE CRASH". */
export const Place: React.FC<{ text: string }> = ({ text }) => {
  const frame = useCurrentFrame();
  const b = useBox();
  const size = 34 * b.scale;
  const w = interpolate(frame, [0, 10], [0, 100], { extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) });
  return (
    <div style={{ position: "absolute", left: b.left, top: b.top, clipPath: `inset(0 ${100 - w}% 0 0)` }}>
      <div style={{ background: RED, color: PAPER, fontFamily: CAPTION_FONT, fontSize: size, letterSpacing: 2, padding: `${size * 0.2}px ${size * 0.5}px 0` }}>
        {text}
      </div>
    </div>
  );
};

/** The period stamp, top-right: NOW in the present, the memory's name inside one (warm). */
export const Stamp: React.FC<{ text: string; warm?: boolean }> = ({ text, warm = false }) => {
  const frame = useCurrentFrame();
  const b = useBox();
  const { width } = useVideoConfig();
  const size = 30 * b.scale;
  const o = frame < 2 ? 0 : 1;
  return (
    <div style={{ position: "absolute", right: width - b.right, top: b.top, opacity: o, transform: "rotate(3deg)" }}>
      <div
        style={{
          border: `4px solid ${warm ? "#8A4B1E" : PAPER}`,
          color: warm ? "#8A4B1E" : PAPER,
          background: warm ? "rgba(243,226,196,0.85)" : "rgba(19,18,18,0.55)",
          fontFamily: CAPTION_FONT,
          fontSize: size,
          letterSpacing: 4,
          padding: `${size * 0.18}px ${size * 0.45}px 0`,
        }}
      >
        {text}
      </div>
    </div>
  );
};

/** Black, and one line in the middle: the trailer's breath between movements. */
export const BlackLine: React.FC<{ text?: string; cps?: number; color?: string; size?: number }> = ({ text = "", cps = 30, color = PAPER, size = 64 }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const b = useBox();
  const shown = typed(text, frame, fps, cps);
  return (
    <AbsoluteFill style={{ backgroundColor: "black", alignItems: "center", justifyContent: "center", padding: `0 ${b.left}px` }}>
      <div style={{ fontFamily: CAPTION_FONT, fontSize: size * b.scale, color, letterSpacing: 2, textAlign: "center", lineHeight: 1.15, maxWidth: (b.right - b.left) * 0.9 }}>
        <div style={{ position: "relative", textAlign: "left" }}>
          <div style={{ visibility: "hidden" }}>{text}</div>
          <div style={{ position: "absolute", left: 0, right: 0, top: 0 }}>{shown}</div>
        </div>
      </div>
    </AbsoluteFill>
  );
};

/**
 * The join: for a few frames the picture tears into bands that slip sideways, the way the Ghost
 * Line's cuts do once you know where to look. Laid over a Take as its own copy of the frame.
 */
export const Tear: React.FC<{ frames?: number; strength?: number; children: React.ReactNode }> = ({ frames = 5, strength = 1, children }) => {
  const frame = useCurrentFrame();
  const { width, height } = useVideoConfig();
  if (frame > frames) return null;
  const bands = 9;
  return (
    <AbsoluteFill>
      {Array.from({ length: bands }, (_, i) => {
        const y0 = (i / bands) * height;
        const y1 = ((i + 1) / bands) * height;
        const dx = (((i * 7919 + frame * 104729) % 17) - 8) * 9 * strength * (1 - frame / (frames + 1));
        return (
          <AbsoluteFill key={i} style={{ clipPath: `inset(${y0}px 0 ${height - y1}px 0)`, transform: `translateX(${dx}px)` }}>
            {children}
          </AbsoluteFill>
        );
      })}
      <AbsoluteFill style={{ background: `linear-gradient(transparent ${(frame * 23) % 100}%, rgba(243,239,229,0.35) ${((frame * 23) % 100) + 1}%, transparent ${((frame * 23) % 100) + 3}%)` }} />
      <div style={{ position: "absolute", inset: 0, width, height }} />
    </AbsoluteFill>
  );
};

/** Halftone dots, the printed-page grain over a shot. */
export const Tone: React.FC<{ opacity?: number; size?: number }> = ({ opacity = 0.12, size = 8 }) => (
  <AbsoluteFill
    style={{
      backgroundImage: `radial-gradient(${INK} 1.5px, transparent 2.1px)`,
      backgroundSize: `${size}px ${size}px`,
      opacity,
      mixBlendMode: "multiply",
      pointerEvents: "none",
    }}
  />
);

/** Edge darkening for the present: cold, close, a little airless. */
export const Vignette: React.FC<{ strength?: number }> = ({ strength = 0.55 }) => (
  <AbsoluteFill style={{ background: `radial-gradient(ellipse at center, transparent 45%, rgba(0,0,0,${strength}) 100%)`, pointerEvents: "none" }} />
);

/** A few frames of white (or black) on a hit. */
export const Flash: React.FC<{ frames?: number; color?: string }> = ({ frames = 4, color = PAPER }) => {
  const frame = useCurrentFrame();
  return <AbsoluteFill style={{ backgroundColor: color, opacity: interpolate(frame, [0, frames], [0.95, 0], { extrapolateRight: "clamp" }) }} />;
};

/** The title: the game's lockup (STORY MODE under it), then THE GHOST LINE, big, in the title face. */
export const Title: React.FC<{ beatFrames: number }> = ({ beatFrames }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const vertical = useVertical();
  const b = useBox();
  const s = spring({ frame, fps, config: { damping: 13, stiffness: 220, mass: 0.7 } });
  const t = spring({ frame: frame - Math.round(beatFrames), fps, config: { damping: 12, stiffness: 260, mass: 0.6 } });
  const shift = vertical ? -((1080 - b.right) - b.left) / 2 : 0;
  return (
    <AbsoluteFill style={{ backgroundColor: "black", alignItems: "center", justifyContent: "center" }}>
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: vertical ? 90 : 46, transform: `translateX(${shift}px)` }}>
        <div style={{ transform: `scale(${interpolate(s, [0, 1], [0.9, vertical ? 0.8 : 0.62])})`, marginBottom: vertical ? -40 : -70 }}>
          <Logo sub="STORY MODE" />
        </div>
        <div
          style={{
            opacity: frame >= beatFrames ? 1 : 0,
            transform: `rotate(-2deg) scale(${interpolate(t, [0, 1], [1.8, 1])})`,
            fontFamily: TITLE_FONT,
            fontSize: vertical ? 104 : 120,
            lineHeight: 1,
            color: PAPER,
            letterSpacing: -2,
            textAlign: "center",
            padding: "10px 34px 14px",
            borderBottom: `${vertical ? 12 : 12}px solid ${RED}`,
          }}
        >
          {vertical ? (
            <>
              THE GHOST
              <br />
              LINE
            </>
          ) : (
            "THE GHOST LINE"
          )}
        </div>
      </div>
    </AbsoluteFill>
  );
};

/** Buko's message, alone on black: the phone feed's grey bubble. */
export const Bubble: React.FC<{ who: string; text: string; cps?: number }> = ({ who, text, cps = 18 }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const vertical = useVertical();
  const k = vertical ? 1.6 : 1.5;
  const shown = typed(text, frame - 18, fps, cps);
  const dots = frame < 18;
  return (
    <AbsoluteFill style={{ backgroundColor: "black", alignItems: "center", justifyContent: "center" }}>
      <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-start", gap: 10 * k, minWidth: 520 * k }}>
        <div style={{ fontFamily: CAPTION_FONT, fontSize: 30 * k, color: "rgba(243,239,229,0.6)", letterSpacing: 3 }}>{who}</div>
        <div
          style={{
            background: "#2B2A29",
            color: PAPER,
            borderRadius: 26 * k,
            borderBottomLeftRadius: 6 * k,
            padding: `${18 * k}px ${28 * k}px`,
            fontFamily: "Helvetica, Arial, sans-serif",
            fontSize: 44 * k,
            minHeight: 44 * k,
          }}
        >
          {dots ? "•••".slice(0, 1 + (Math.floor(frame / 6) % 3)) : shown}
        </div>
      </div>
    </AbsoluteFill>
  );
};
