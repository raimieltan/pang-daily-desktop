import React from "react";
import { AbsoluteFill, Img, staticFile } from "remotion";
import { Logo } from "./components";
import { CAPTION_FONT, INK, PAPER, RED, TITLE_FONT, YELLOW } from "./theme";

// Social account kit: profile icons (square, survive TikTok's circle crop) and cover frames for
// pinned videos. Rendered as stills, see the "brand" script in package.json.

const tone = (color: string, size = 34): React.CSSProperties => ({
  backgroundImage: `radial-gradient(${color} 42%, transparent 44%)`,
  backgroundSize: `${size}px ${size}px`,
});
const extrude = (n: number, color = INK) => Array.from({ length: n }, (_, i) => `${i + 1}px ${i + 1}px 0 ${color}`).join(", ");

const Word: React.FC<{ text: string; size: number; fill?: string; stroke?: string }> = ({ text, size, fill = PAPER, stroke = INK }) => (
  <div
    style={{
      fontFamily: TITLE_FONT,
      fontSize: size,
      lineHeight: 0.98,
      color: fill,
      WebkitTextStroke: `${Math.round(size / 24)}px ${stroke}`,
      paintOrder: "stroke fill",
      textShadow: extrude(Math.round(size / 17), stroke),
      letterSpacing: -size / 40,
    }}
  >
    {text}
  </div>
);

/** Profile icon: the red sun and the PANG DAILY stack, everything inside the circle crop. */
export const Icon: React.FC<{ dark?: boolean }> = ({ dark = false }) => (
  <AbsoluteFill style={{ backgroundColor: dark ? INK : PAPER, alignItems: "center", justifyContent: "center" }}>
    <AbsoluteFill style={tone(dark ? "rgba(243,239,229,0.08)" : "rgba(19,18,18,0.10)")} />
    <div style={{ position: "absolute", width: 820, height: 820, borderRadius: 410, background: RED, border: `12px solid ${INK}` }} />
    <div style={{ position: "relative", display: "flex", flexDirection: "column", alignItems: "center", transform: "rotate(-4deg) translateY(-14px)" }}>
      <Word text="PANG" size={232} />
      <Word text="DAILY" size={232} />
    </div>
  </AbsoluteFill>
);

/** Small-size fallback: one big "P" on the sun, for places that shrink the icon to a dot. */
export const IconMark: React.FC = () => (
  <AbsoluteFill style={{ backgroundColor: YELLOW, alignItems: "center", justifyContent: "center" }}>
    <AbsoluteFill style={tone("rgba(19,18,18,0.12)")} />
    <div style={{ position: "absolute", width: 820, height: 820, borderRadius: 410, background: RED, border: `14px solid ${INK}` }} />
    <div style={{ position: "relative", transform: "rotate(-6deg) translate(-10px, -20px)" }}>
      <Word text="P" size={640} />
    </div>
  </AbsoluteFill>
);

// YouTube channel art: 2560×1440 shows on TV, desktop crops to the middle 2560×423, phones to
// the centre 1546×423. Logo and line sit in the phone box; game panels fill the desktop wings.
const YT = { w: 2560, h: 1440, safeW: 1546, safeH: 423 };
const WING = (YT.w - YT.safeW) / 2;
const GUTTER = 14;

const Panel: React.FC<{ src: string; left: number; width: number; pos?: string }> = ({ src, left, width, pos = "50% 55%" }) => (
  <div style={{ position: "absolute", left, top: 0, width, height: YT.h, overflow: "hidden", borderLeft: `${GUTTER}px solid ${INK}` }}>
    <Img src={staticFile(`footage/${src}`)} style={{ width: "100%", height: "100%", objectFit: "cover", objectPosition: pos }} />
  </div>
);

export const Banner: React.FC = () => {
  const half = WING / 2;
  return (
    <AbsoluteFill style={{ backgroundColor: INK }}>
      <Panel src="banner_01_store_2am.png" left={0} width={half} pos="30% 55%" />
      <Panel src="banner_05_overhead_pass.png" left={half} width={half} pos="45% 50%" />
      <Panel src="banner_07_three_wide.png" left={YT.w - WING} width={half} pos="50% 50%" />
      <Panel src="banner_09_view_deck.png" left={YT.w - half} width={half} pos="40% 60%" />
      {/* The centre page: paper, halftone, the sun behind the wordmark. */}
      <div
        style={{
          position: "absolute", left: WING, top: 0, width: YT.safeW, height: YT.h, backgroundColor: PAPER,
          borderLeft: `${GUTTER}px solid ${INK}`, borderRight: `${GUTTER}px solid ${INK}`,
          display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center",
        }}
      >
        <AbsoluteFill style={tone("rgba(19,18,18,0.10)")} />
        <div style={{ position: "absolute", width: 300, height: 300, borderRadius: 150, background: RED, border: `8px solid ${INK}`, top: YT.h / 2 - 180 }} />
        <div style={{ position: "relative", transform: "rotate(-2deg) translateY(-30px)" }}>
          <Word text="PANG DAILY" size={165} />
        </div>
        <div style={{ position: "relative", display: "flex", gap: 22, marginTop: 6 }}>
          {["BROKE CAR GUYS.", "OLD CARS.", "PHILIPPINE MOUNTAIN ROADS."].map((line, i) => (
            <div
              key={line}
              style={{
                fontFamily: CAPTION_FONT, fontSize: 54, padding: "8px 20px 0",
                color: i === 2 ? PAPER : INK, background: i === 2 ? RED : i === 1 ? YELLOW : PAPER,
                border: `5px solid ${INK}`, transform: `rotate(${[-2, 1, -1][i]}deg)`, boxShadow: `6px 6px 0 ${INK}`,
              }}
            >
              {line}
            </div>
          ))}
        </div>
      </div>
    </AbsoluteFill>
  );
};

/** Cover for a pinned video: a game frame, the logo, a hook line. */
export const Cover: React.FC<{ frame: string; hook: [string, string]; logoTop?: boolean }> = ({ frame, hook, logoTop = true }) => (
  <AbsoluteFill style={{ backgroundColor: PAPER }}>
    <Img src={staticFile(`footage/${frame}`)} style={{ width: "100%", height: "100%", objectFit: "cover" }} />
    <AbsoluteFill style={{ top: logoTop ? 300 : 1100, height: "auto", alignItems: "center", paddingRight: 100 }}>
      <div style={{ transform: "rotate(-3deg) scale(0.9)" }}>
        <Logo />
      </div>
    </AbsoluteFill>
    <AbsoluteFill style={{ top: logoTop ? 1180 : 420, height: "auto", alignItems: "center", gap: 18, paddingRight: 100 }}>
      {hook.map((line, i) => (
        <div
          key={line}
          style={{
            fontFamily: CAPTION_FONT,
            fontSize: 112,
            color: i === 0 ? INK : PAPER,
            background: i === 0 ? YELLOW : RED,
            padding: "14px 40px 0",
            transform: `rotate(${i === 0 ? -3 : 2}deg)`,
            boxShadow: `10px 10px 0 ${INK}`,
          }}
        >
          {line}
        </div>
      ))}
    </AbsoluteFill>
  </AbsoluteFill>
);
