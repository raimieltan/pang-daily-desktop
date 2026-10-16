// Trailer v2's edit decision list: a manga chapter about a broke guy's 2am touge run
// (docs/superpowers/specs/2026-10-16-trailer-v2-design.md). Funny → tense → proud.
//
// 0:00–0:12 is the deadpan open in seconds (no music). From the drop on, everything is on the
// beat grid of "Live on JP": b(n) is trailer seconds at beat n after the drop. `from` is seconds
// into the source capture (trailer/out/<shot>.mp4; see <shot>.events.json for what happens when).
// Readout numbers are the time-attack run's own (ta.events.json "split" / "finish" marks) and only
// ever sit next to or over footage from that run.
import type { PanelContent, Readout } from "./components";

export const BPM = 147.0;
export const BEAT = 60 / BPM; // 0.408 s
export const TOTAL_SECONDS = 60;

// "Live on JP (Eurobeat)" by ZTMusic (Pixabay licence). Its drop is at 127.74 s; with that on
// DROP the breakdown starts on b(82) (the splash), the two-beat hole is b(90)–b(92), the outro
// covers the View Deck and the last hit, b(107), is the title.
export const DROP = 12.0;
export const MUSIC = { file: "music/live_on_jp.mp3", from: 127.74, volume: 0.62 };
export const b = (n: number) => DROP + n * BEAT;
// The starter: "Honda engine start and rev" (Pixabay, freesound_community). It cranks from 0.6 s
// and catches at 1.2 s; `at` puts the catch on 7.0 s, where open.mp4's own engine comes on
// (OPEN_CATCH in capture.gd), and it fades out under the game's idle.
export const STARTER = { file: "sfx/honda_start.mp3", at: 5.8, from: 0.0, seconds: 3.2, volume: 1.0 };
/** Hard silence for the beat before the title (the music's own build is muted). */
export const SILENCE: [number, number] = [b(105), b(107)];
export const TITLE = b(107);

type Common = {
  name: string;
  at: number; // trailer seconds this shot starts (runs until the next one)
  card?: { lines: [string, string?]; at?: number; y?: number; size?: number; second?: number };
  burst?: number; // seconds into the shot: screentone burst + flash (an overtake)
  lines?: [number, number]; // speed-line opacity ramp across the shot
  wipe?: boolean; // ink wipe in
  flash?: boolean;
  delta?: { label: string; value: string; time: string; at?: number };
};
export type Shot = Common &
  (
    | { kind: "full"; src: string; from: number; volume?: number; pos?: string; punch?: boolean }
    | { kind: "page"; panels: PanelContent[]; stagger?: number }
    | { kind: "splash"; src: string; freeze: number; focus: [number, number]; words: [string, string] }
  );

// Time-attack numbers (ta.events.json): sector splits against the ghost, then the finish.
const fmt = (d: number) => (d < 0 ? "−" : "+") + Math.abs(d).toFixed(3);
const SPLITS = [0.1, -0.3, -0.117];
const split = (k: number): Readout => ({ label: `S${k + 1} · VS GHOST`, value: fmt(SPLITS[k]), tone: SPLITS[k] < 0 ? "green" : "red" });
const FINISH = { time: "1:24.592", delta: -0.208 };

const OPEN_VOL = 1.0; // the open is the game's own night: crickets, a far tricycle, the askal
const IDLE_VOL = 0.5; // once the engine catches, its idle sits ~6 dB under the capture's level
const RACE_VOL = 0.95; // engine and tyres stay on top of the music

export const SHOTS: Shot[] = [
  // ---- 0:00–0:12 deadpan open: 2am, the sari-sari store.
  { name: "store", at: 0, kind: "full", src: "open.mp4", from: 0.3, volume: OPEN_VOL, punch: false },
  { name: "askal", at: 3.0, kind: "full", src: "open.mp4", from: 3.4, volume: OPEN_VOL, punch: false },
  { name: "eg idle", at: 5.6, kind: "full", src: "open.mp4", from: 6.4, volume: IDLE_VOL, punch: false },
  { name: "bawal ang utang", at: 8.0, kind: "full", src: "open.mp4", from: 8.8, volume: IDLE_VOL, punch: false },
  { name: "tail, revs", at: 10.2, kind: "full", src: "open.mp4", from: 10.5, volume: 0.7, punch: false },

  // ---- 0:12 the turn: the drop on the launch.
  { name: "launch", at: b(0), kind: "full", src: "eg_battle.mp4", from: 2.7, volume: RACE_VOL, flash: true,
    card: { lines: ["OLD CAR.", "BROKE GUY."], second: 2 } },

  // ---- 0:15–0:45 the run. Pages split into tiers; full frames for the passes.
  { name: "page: field", at: b(8), kind: "page", wipe: true, card: { lines: ["TOUGE", "BATTLES"], y: 1020 },
    panels: [
      { src: "eg_battle.mp4", from: 8.2, pos: "50% 55%", volume: RACE_VOL },
      { src: "eg_battle.mp4", from: 14.2, pos: "50% 50%" },
      { src: "eg_battle.mp4", from: 11.2, pos: "50% 60%" },
    ] },
  { name: "hairpin in", at: b(16), kind: "full", src: "eg_battle.mp4", from: 17.9, volume: RACE_VOL, lines: [0.0, 0.25] },
  // Overhead: JUNJUN runs wide, the EG dives inside (pass at 21.08 s).
  { name: "pass junjun", at: b(20), kind: "full", src: "eg_battle.mp4", from: 19.85, volume: RACE_VOL, burst: 1.23,
    card: { lines: ["PASS", "THEM ALL"], at: 2 } },
  { name: "page: S1", at: b(28), kind: "page",
    panels: [
      { src: "ta.mp4", from: 24.1, pos: "50% 55%", volume: RACE_VOL },
      { readout: split(0) },
      { src: "ta.mp4", from: 26.4, pos: "50% 50%" },
    ] },
  { name: "slide", at: b(36), kind: "full", src: "eg_battle.mp4", from: 29.25, volume: RACE_VOL, lines: [0.15, 0.45],
    card: { lines: ["HOLD", "THE SLIDE"], at: 1 } },
  { name: "page: S2 ghost", at: b(44), kind: "page", stagger: 1,
    panels: [
      { src: "ta.mp4", from: 42.2, pos: "50% 55%", volume: RACE_VOL, readout: split(1) },
      { src: "ta.mp4", from: 46.4, pos: "50% 50%" },
    ] },
  { name: "pass ate liza", at: b(52), kind: "full", src: "eg_battle.mp4", from: 51.6, volume: RACE_VOL, burst: 1.9, lines: [0.2, 0.5],
    card: { lines: ["OLD CAR.", "FAST HANDS."], at: 3 } },
  { name: "page: S3", at: b(60), kind: "page",
    panels: [
      { src: "ta.mp4", from: 66.3, pos: "50% 55%", volume: RACE_VOL },
      { src: "ta.mp4", from: 70.4, pos: "50% 45%" },
      { readout: split(2) },
    ] },
  // The world's own joke, the one beat allowed past 0:15.
  { name: "bawal mag-overtake", at: b(68), kind: "full", src: "ta.mp4", from: 75.2, volume: RACE_VOL, punch: false },
  { name: "last hairpin in", at: b(74), kind: "full", src: "ta.mp4", from: 78.05, volume: RACE_VOL, lines: [0.2, 0.6], wipe: true },

  // ---- 0:45 the freeze splash at the last hairpin (the music's breakdown).
  { name: "splash", at: b(82), kind: "splash", src: "ta.mp4", freeze: 81.3, focus: [620, 1000], words: ["LAST", "HAIRPIN"] },

  // ---- 0:50 snap back: the finish, green delta; then the View Deck.
  { name: "finish", at: b(92), kind: "full", src: "ta.mp4", from: 86.1, volume: RACE_VOL, flash: true,
    delta: { label: "FINISH · VS GHOST", value: fmt(FINISH.delta), time: FINISH.time, at: 1.5 } },
  { name: "view deck", at: b(99), kind: "full", src: "viewdeck.mp4", from: 0.6, volume: OPEN_VOL, wipe: true, punch: false },
];

export const END = {
  pitch: ["BROKE CAR GUYS.", "OLD CARS.", "PHILIPPINE MOUNTAIN ROADS."],
  cta: "COMING SOON",
};
