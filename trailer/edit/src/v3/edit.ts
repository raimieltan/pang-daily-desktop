import type { Mask } from "./components";

// The story trailer, "The Ghost Line" (docs/superpowers/specs/2026-10-18-story-trailer-design.md).
// Two edit lists over the same takes (trailer/out/story, from trailer/story_capture_all.sh):
// `wide` is the 16:9 master (~93 s), `tall` the 9:16 cutdown (~62 s). Seconds throughout; a take's
// `from` is seconds into its mp4, and every line on screen is the game's own (StoryScript.BEATS).

/** "Dark Pulse – Suspense Thriller Cinematic" by MeeGiStudio (Pixabay licence), ~99.4 BPM. */
export const MUSIC_FILE = "music/dark_pulse.mp3";
export const BEAT = 60 / 99.4;

export type Shot = {
  at: number;
  src: string;
  from: number;
  dur?: number; // default: until the next shot
  volume?: number;
  speed?: number;
  focus?: [number, number, number]; // [cx, cy, w] in source px; see Take
  punch?: boolean;
  drift?: number;
  freeze?: boolean;
  grade?: string;
  tone?: number;
  vignette?: number;
  tear?: number; // frames of the join tear at the head of the shot
  flash?: "white" | "black";
  masks?: Mask[];
  band?: number; // 9:16: show the region as a full-width 16:9 band at this y, on paper
  bg?: string; // fill behind a region taller than the source
};

export type Words = {
  at: number;
  dur: number;
  kind: "narr" | "say" | "place" | "stamp" | "black" | "bubble";
  text: string;
  who?: string;
  footage?: boolean;
  side?: "left" | "right";
  warm?: boolean;
  y?: "low" | "mid" | "high";
  cps?: number;
  size?: number;
};

/** A piece of the track: plays `from`–`to` (track seconds) starting at trailer second `at`. */
export type Music = { at: number; from: number; to: number; fadeIn?: number; fadeOut?: number };
export type Sfx = { at: number; file: string; volume?: number };

export type Cut = {
  seconds: number;
  title: number;
  titleDur: number;
  shots: Shot[];
  words: Words[];
  after: Words[];
  music: Music[];
  musicFile: string;
  musicVolume: number;
  sfx: Sfx[];
};

// The track's own shape: sparse hits to 39.07, a build to ~78, full from 90.67, near-silence
// 108.58–111.05, the last hit at 111.05, the ending 124.27–132.4. Every splice is on a hit.
const WIDE_MUSIC: Music[] = [
  { at: 0, from: 0, to: 59.47 },
  { at: 59.47, from: 90.67, to: 115.87 },
  { at: 84.67, from: 124.27, to: 132.4, fadeOut: 1.5 },
];
const TALL_MUSIC: Music[] = [
  { at: 0, from: 0, to: 19.85 },
  { at: 19.85, from: 29.44, to: 49.56 },
  { at: 39.97, from: 97.56, to: 113.46 },
  { at: 55.87, from: 126.68, to: 132.4, fadeOut: 1.2 },
];

// Hit times in the wide cut (trailer seconds).
const W = { present: 19.85, memory: 29.44, legend: 39.07, rupture: 59.47, silence: 77.38, title: 79.85, button: 84.67 };

// The game's "CLICK / SPACE" prompt on a speech panel, patched in the panel's colour (present / memory).
const HINT = { x: 1625, y: 795, w: 240, h: 46 };
const NOW_PANEL: Mask[] = [{ ...HINT, color: "#F3EFE4" }];
const MEMORY_PANEL: Mask[] = [{ ...HINT, color: "#F3E1B9" }];
// …and on a comic page, bottom-right of the paper.
const PAGE_HINT: Mask[] = [{ x: 1640, y: 1050, w: 270, h: 30, color: "#F3EFE5" }];

const WIDE_SHOTS: Shot[] = [
  // ── Cold open: the night, in pieces (track 0–19.85, sparse) ──
  { at: 3.05, src: "s00", from: 3.0, drift: 0.05, masks: PAGE_HINT, volume: 0.8 },
  { at: 6.65, src: "s00_clean", from: 17.3, volume: 0.6, vignette: 0.35 },
  { at: 9.06, src: "s00", from: 8.3, focus: [1350, 790, 1080], drift: 0.06, volume: 0.8, masks: PAGE_HINT },
  { at: 12.0, src: "s00", from: 15.4, drift: 0.04, masks: PAGE_HINT, volume: 0.8 },
  { at: 13.6, src: "s00_clean", from: 26.1, volume: 0.65, vignette: 0.35 },
  { at: 15.06, src: "s00", from: 38.2, focus: [440, 765, 820], drift: 0.06, flash: "white", volume: 0.5 },
  // ── The present: cold, after (19.85) ──
  { at: W.present, src: "s14_clean", from: 2.2, drift: 0.05, vignette: 0.3, volume: 0.7 },
  { at: 23.3, src: "s14_clean", from: 12.0, drift: 0.04, vignette: 0.3, volume: 0.7 },
  { at: 26.4, src: "s15", from: 16.3, masks: NOW_PANEL, volume: 0.7 },
  // ── The memory: the wrench, then warm (29.44) ──
  { at: W.memory, src: "s15", from: 31.75, flash: "white", masks: PAGE_HINT, volume: 0 },
  { at: 31.5, src: "s01", from: 11.13, masks: MEMORY_PANEL, volume: 0.6 },
  { at: 33.4, src: "s01", from: 29.23, masks: MEMORY_PANEL, volume: 0.6 },
  { at: 36.0, src: "s01", from: 59.7, drift: 0.05, masks: PAGE_HINT, volume: 0.6 },
  // ── The legend: the scene, the man with the board, the clip (39.07, building) ──
  { at: W.legend, src: "s03_clean", from: 10.4, punch: true, flash: "white", volume: 1 },
  { at: 40.8, src: "s03_clean", from: 77.5, volume: 1 },
  { at: 41.9, src: "s04t", from: 24.75, masks: MEMORY_PANEL, volume: 0.5 },
  { at: 43.85, src: "s05_clean", from: 22.3, punch: true, volume: 1 },
  { at: 45.94, src: "s05_clean", from: 66.6, volume: 1 },
  { at: 47.2, src: "s07", from: 8.3, focus: [960, 760, 1100], drift: 0.04, punch: true, volume: 0.5 },
  { at: 49.56, src: "s17e", from: 0.62, masks: NOW_PANEL, punch: true, volume: 0.6 },
  { at: 50.85, src: "s17e", from: 3.63, masks: NOW_PANEL, volume: 0.6 },
  { at: 52.0, src: "s17e", from: 6.65, masks: NOW_PANEL, volume: 0.6 },
  { at: 53.3, src: "s17e", from: 16.2, drift: 0.06, volume: 0.4 },
  { at: 53.9, src: "s20", from: 0.12, masks: NOW_PANEL, punch: true, volume: 0.6 },
  { at: 55.0, src: "s20", from: 3.12, masks: NOW_PANEL, volume: 0.6 },
  { at: 57.2, src: "s06", from: 109.55, masks: MEMORY_PANEL, volume: 0.6 },
  // ── The rupture: the chase, the joins, the lights (59.47, full) ──
  { at: W.rupture, src: "s18", from: 13.4, punch: true, flash: "white", tear: 6, volume: 1 },
  { at: 60.9, src: "s18", from: 69.02, masks: NOW_PANEL, volume: 0.7 },
  { at: 63.3, src: "s08", from: 15.8, tear: 5, volume: 1 },
  { at: 64.5, src: "s09", from: 137.62, masks: [{ ...HINT, color: "#F3E1B9" }], volume: 0.6 },
  { at: 66.5, src: "s16", from: 26.0, tear: 8, volume: 1 },
  { at: 67.4, src: "s06", from: 113.2, tear: 5, volume: 1 },
  { at: 68.0, src: "s19", from: 12.63, masks: [{ ...HINT, color: "#F3EFE4" }], volume: 0.5 },
  { at: 69.6, src: "s20", from: 18.2, masks: NOW_PANEL, volume: 0.6 },
  { at: 71.9, src: "s13_clean", from: 34.3, tear: 6, volume: 1 },
  { at: 73.2, src: "s13_clean", from: 64.6, volume: 1, vignette: 0.3 },
  // flashes: the pieces that don't fit yet
  { at: 74.6, src: "s18_clean", from: 12.0, tear: 4, volume: 0.8 },
  { at: 75.05, src: "s00", from: 38.6, focus: [440, 765, 820], flash: "white", volume: 0.3 },
  { at: 75.45, src: "s13", from: 76.0, focus: [960, 290, 1000], tear: 4, volume: 0.3 },
  { at: 75.9, src: "s06", from: 9.0, focus: [400, 800, 760], volume: 0.3 },
  { at: 76.35, src: "s13_clean", from: 69.6, tear: 6, volume: 1 },
  { at: 76.95, src: "s00_clean", from: 27.4, flash: "white", volume: 1 },
];

const WIDE_WORDS: Words[] = [
  { at: 0.5, dur: 2.4, kind: "black", text: "Here's what I know.", cps: 20 },
  { at: 7.0, dur: 2.0, kind: "say", who: "JOLO", text: "Pang, it's wet. It's wet." },
  { at: 13.8, dur: 1.2, kind: "say", who: "JOLO", text: "Okay. Okay." },
  { at: 17.15, dur: 2.7, kind: "black", text: "There's no sound for the hit. I've tried to find one.", cps: 34, size: 54 },
  { at: W.present + 0.1, dur: 3.3, kind: "place", text: "THE CLINIC  ·  AFTER THE CRASH" },
  { at: W.present + 0.1, dur: 6.5, kind: "stamp", text: "NOW" },
  { at: W.present + 0.4, dur: 3.0, kind: "narr", text: "Official report: SINGLE-VEHICLE ACCIDENT. NO SECOND VEHICLE CONFIRMED." },
  { at: 23.4, dur: 2.9, kind: "say", who: "PANG", text: "There was a car. There were lights. Beside us." },
  { at: W.legend + 0.2, dur: 1.6, kind: "place", text: "THAT NIGHT" },
  { at: W.legend, dur: 2.85, kind: "stamp", text: "MONTHS BEFORE", warm: true },
  { at: 43.95, dur: 2.0, kind: "place", text: "PASS 1  ·  SATURDAY  ·  BEFORE THE LIGHT GOES" },
  { at: 43.85, dur: 3.35, kind: "stamp", text: "MONTHS BEFORE", warm: true },
  { at: 72.0, dur: 2.55, kind: "say", who: "NICO", text: "And you don't remember that night. You think you do." },
  // ── Silence, then the title ──
  { at: W.silence, dur: W.title - W.silence, kind: "black", text: "Here's what I know.", cps: 22 },
];

const WIDE_SFX: Sfx[] = [
  { at: W.memory, file: "wrench", volume: 1 },
  { at: 36.4, file: "shutter", volume: 0.9 },
  { at: W.button + 0.05, file: "phone_buzz", volume: 0.9 },
];

const WIDE_AFTER: Words[] = [{ at: W.button, dur: 92.8 - W.button, kind: "bubble", who: "BUKO", text: "so who's ghost" }];

const wide: Cut = {
  seconds: 92.8,
  title: W.title,
  titleDur: W.button - W.title,
  musicFile: MUSIC_FILE,
  musicVolume: 0.85,
  music: WIDE_MUSIC,
  shots: WIDE_SHOTS,
  words: WIDE_WORDS,
  after: WIDE_AFTER,
  sfx: WIDE_SFX,
};

// The 9:16 cut: same takes, each reframed to a full-height column (`focus` [cx, cy, 607] is the
// whole height at zoom 1); the game's wide speech panels don't fit a column, so lines are the edit's.
const COL = 607;
const T = { present: 19.85, legend: 29.48, rupture: 39.97, silence: 50.99, title: 53.46, button: 55.87 };

const TALL_SHOTS: Shot[] = [
  // ── Cold open (0–19.85) ──
  { at: 3.05, src: "s00", from: 3.0, band: 760, drift: 0.04, masks: PAGE_HINT, volume: 0.8 },
  { at: 6.65, src: "s00_clean", from: 17.3, focus: [960, 560, COL], volume: 0.6, vignette: 0.35 },
  { at: 9.06, src: "s00", from: 8.3, band: 760, focus: [1350, 780, 1080], drift: 0.05, masks: PAGE_HINT, volume: 0.8 },
  { at: 12.0, src: "s00", from: 15.4, band: 760, drift: 0.04, masks: PAGE_HINT, volume: 0.8 },
  { at: 13.6, src: "s00_clean", from: 26.1, focus: [960, 560, COL], volume: 0.65, vignette: 0.35 },
  { at: 15.06, src: "s00", from: 38.2, band: 760, focus: [440, 765, 820], drift: 0.05, flash: "white", volume: 0.5 },
  // ── The present, then the wrench (19.85) ──
  { at: T.present, src: "s14_clean", from: 2.2, focus: [1040, 540, COL], drift: 0.05, vignette: 0.3, volume: 0.7 },
  { at: 22.4, src: "s14_clean", from: 12.0, focus: [1000, 540, COL], drift: 0.04, vignette: 0.3, volume: 0.7 },
  { at: 24.7, src: "s14_clean", from: 25.0, focus: [880, 540, COL], drift: 0.04, vignette: 0.3, volume: 0.7 },
  { at: 26.9, src: "s15", from: 31.75, band: 760, flash: "white", masks: PAGE_HINT, volume: 0 },
  { at: 27.9, src: "s01_clean", from: 13.0, focus: [960, 540, COL], drift: 0.04, volume: 0.6 },
  // ── The legend (29.48) ──
  { at: T.legend, src: "s03_clean", from: 10.4, focus: [960, 560, COL], punch: true, flash: "white", volume: 1 },
  { at: 31.1, src: "s03_clean", from: 77.5, focus: [800, 560, COL], volume: 1 },
  { at: 32.2, src: "s05_clean", from: 22.3, focus: [1250, 560, COL], punch: true, volume: 1 },
  { at: 34.6, src: "s07", from: 8.3, focus: [960, 540, 880], bg: "#F2E3C3", punch: true, volume: 0.5 },
  { at: 36.9, src: "s17e_clean", from: 2.0, focus: [1000, 540, COL], punch: true, volume: 0.7 },
  { at: 38.4, src: "s17e_clean", from: 6.0, focus: [700, 540, COL], volume: 0.7 },
  // ── The rupture (39.97) ──
  { at: T.rupture, src: "s20_clean", from: 2.0, focus: [1060, 540, COL], punch: true, flash: "white", volume: 0.7 },
  { at: 41.0, src: "s20_clean", from: 7.0, focus: [760, 540, COL], volume: 0.7 },
  { at: 42.8, src: "s06_clean", from: 50.0, focus: [960, 560, COL], volume: 0.9 },
  { at: 44.9, src: "s18_clean", from: 11.3, focus: [960, 520, COL], tear: 6, flash: "white", volume: 1 },
  { at: 46.0, src: "s13_clean", from: 34.3, focus: [960, 560, COL], tear: 6, volume: 1 },
  { at: 47.3, src: "s13_clean", from: 64.6, focus: [960, 560, COL], volume: 1, vignette: 0.3 },
  { at: 48.6, src: "s18_clean", from: 12.0, focus: [960, 520, COL], tear: 4, volume: 0.8 },
  { at: 49.0, src: "s00", from: 38.6, focus: [440, 640, COL], flash: "white", volume: 0.3 },
  { at: 49.4, src: "s13", from: 76.0, focus: [700, 400, COL], tear: 4, volume: 0.3 },
  { at: 49.85, src: "s13_clean", from: 69.6, focus: [960, 560, COL], tear: 6, volume: 1 },
  { at: 50.45, src: "s00_clean", from: 27.4, focus: [960, 560, COL], flash: "white", volume: 1 },
];

const TALL_WORDS: Words[] = [
  { at: 0.5, dur: 2.4, kind: "black", text: "Here's what I know.", cps: 20 },
  { at: 7.0, dur: 2.0, kind: "say", who: "JOLO", text: "Pang, it's wet. It's wet." },
  { at: 9.2, dur: 2.7, kind: "narr", text: "Jolo had his phone up. Jolo always had his phone up." },
  { at: 12.1, dur: 1.5, kind: "narr", text: "Ghost's line. I could see it." },
  { at: 13.8, dur: 1.2, kind: "say", who: "JOLO", text: "Okay. Okay." },
  { at: 15.2, dur: 1.9, kind: "narr", text: "Headlights. Rain going white." },
  { at: 17.15, dur: 2.7, kind: "black", text: "There's no sound for the hit. I've tried to find one.", cps: 34, size: 54 },
  { at: T.present + 0.1, dur: 2.4, kind: "place", text: "THE CLINIC  ·  AFTER THE CRASH" },
  { at: T.present + 0.1, dur: 6.8, kind: "stamp", text: "NOW" },
  { at: T.present + 0.3, dur: 2.2, kind: "narr", text: "Official report: NO SECOND VEHICLE CONFIRMED." },
  { at: 22.5, dur: 2.2, kind: "say", who: "PANG", text: "There was a car. There were lights. Beside us." },
  { at: 24.8, dur: 2.1, kind: "say", who: "RUEL", text: "A man buying cigarettes saw lights on the lower road." },
  { at: 27.9, dur: 1.55, kind: "stamp", text: "MONTHS BEFORE", warm: true },
  { at: 28.0, dur: 1.45, kind: "say", who: "JOLO", text: "You're staring at it again." },
  { at: T.legend + 0.2, dur: 1.5, kind: "place", text: "THAT NIGHT" },
  { at: T.legend, dur: 5.1, kind: "stamp", text: "MONTHS BEFORE", warm: true },
  { at: 32.3, dur: 2.2, kind: "say", who: "NICO", text: "You found time you won't find twice." },
  { at: 36.9, dur: 3.07, kind: "place", text: "KYO COFFEE  ·  AFTER THE CRASH" },
  { at: 36.9, dur: 3.07, kind: "stamp", text: "NOW" },
  { at: 37.0, dur: 1.4, kind: "say", who: "KAPITAN", text: "Ghost? Ex-pro. My cousin says Japan." },
  { at: 38.45, dur: 1.5, kind: "say", who: "BUKO", text: "Ghost was up there the night you crashed." },
  { at: T.rupture + 0.05, dur: 1.0, kind: "say", who: "PANG", text: "Who's Ghost?" },
  { at: 41.05, dur: 1.75, kind: "say", who: "DANTE", text: "If I knew, I'd sell tickets to him." },
  { at: 42.8, dur: 2.1, kind: "stamp", text: "THE LINE STUDY", warm: true },
  { at: 42.85, dur: 2.05, kind: "say", who: "JOLO", text: "Drive the road, boss. It's right there." },
  { at: 44.9, dur: 1.1, kind: "stamp", text: "NOW" },
  { at: 46.05, dur: 2.5, kind: "say", who: "NICO", text: "And you don't remember that night. You think you do." },
  { at: T.silence, dur: T.title - T.silence, kind: "black", text: "Here's what I know.", cps: 22 },
];

const TALL_SFX: Sfx[] = [
  { at: 26.9, file: "wrench", volume: 1 },
  { at: T.button + 0.05, file: "phone_buzz", volume: 0.9 },
];

const TALL_AFTER: Words[] = [{ at: T.button, dur: 61.6 - T.button, kind: "bubble", who: "BUKO", text: "so who's ghost" }];

const tall: Cut = {
  seconds: 61.6,
  title: T.title,
  titleDur: T.button - T.title,
  musicFile: MUSIC_FILE,
  musicVolume: 0.85,
  music: TALL_MUSIC,
  shots: TALL_SHOTS,
  words: TALL_WORDS,
  after: TALL_AFTER,
  sfx: TALL_SFX,
};

export const CUTS = { wide, tall };
export { W };
