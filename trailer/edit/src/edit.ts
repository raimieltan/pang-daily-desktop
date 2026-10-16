// The edit decision list. Everything is in beats of the music so cuts land on the beat;
// `from` is seconds into the source capture (trailer/out/<shot>.mp4, see <shot>.events.json for
// when the overtakes and slides happen). Tweak here, then `npm run render`.
import type { Zoom } from "./components";

export const BPM = 149.8;
export const BEAT = 60 / BPM; // 0.4005 s
export const TOTAL_SECONDS = 30;

// "Chasing (Eurobeat)" by ZTMusic (Pixabay). 25.69 s is the downbeat of bar 16: from there the
// one-bar breakdown (bar 30) lands on trailer beats 56–60 and the drop on beat 60 (24.0 s),
// right where the climax montage starts.
export const MUSIC = { file: "music/chasing.mp3", from: 25.69, volume: 0.75 };

export type Cut = {
  name: string;
  beats: number;
  src?: string;
  from?: number;
  speed?: number;
  volume?: number;
  zoom?: Zoom;
  graphic?: "logo";
  flash?: boolean;
  lines?: boolean;
  wipeIn?: boolean;
  tag?: [string, string?];
};

// The race intro's driver cards without the game's letterbox bars.
const INTRO: Zoom = { cx: 610, cy: 960, w: 840, srcW: 1080, srcH: 1920 };

// The car card on the right of the garage page.
const GARAGE: Zoom = { cx: 1890, cy: 700, w: 1380, srcW: 2560, srcH: 1440 };

export const CUTS: Cut[] = [
  // 0–4: hook. Mid-powerslide on the first frame, then a pass.
  { name: "hook slide", beats: 4, src: "drift.mp4", from: 31.3, volume: 0.5 },
  { name: "hook overtake", beats: 4, src: "battle.mp4", from: 5.6, flash: true },
  { name: "logo", beats: 2, graphic: "logo" },
  // 10–16: the race intro.
  { name: "intro you", beats: 3, src: "intro.mp4", from: 3.3, zoom: INTRO, wipeIn: true },
  { name: "intro rival", beats: 3, src: "intro.mp4", from: 5.0, zoom: INTRO },
  // 16–24: carving through the field.
  { name: "pass junjun", beats: 3, src: "battle.mp4", from: 10.9, flash: true },
  { name: "pack pile-up", beats: 3, src: "battle.mp4", from: 20.9 },
  { name: "pass tisoy", beats: 2, src: "battle.mp4", from: 28.5 },
  // 24–36: powerslides.
  { name: "slide side", beats: 4, src: "drift.mp4", from: 7.9, flash: true },
  { name: "slide low", beats: 3, src: "drift.mp4", from: 12.0 },
  { name: "rival slide", beats: 2, src: "battle.mp4", from: 30.4 },
  { name: "slide side 2", beats: 3, src: "drift.mp4", from: 40.5 },
  // 36–44: the garage, then each car on the road.
  { name: "garage", beats: 8, src: "garage.mp4", from: 2.0, speed: 2, zoom: GARAGE, volume: 0, wipeIn: true },
  { name: "car dalagan", beats: 2, src: "cars.mp4", from: 3.4, tag: ["DALAGAN GSR", "AWD TURBO"] },
  { name: "car silak", beats: 2, src: "cars.mp4", from: 8.4, tag: ["SILAK BOX", "RWD TURBO"] },
  { name: "car eg", beats: 2, src: "cars.mp4", from: 13.4, tag: ["EG HATCH", "FWD"] },
  { name: "car fd", beats: 2, src: "cars.mp4", from: 18.4, tag: ["CIVIC FD2R", "FWD"] },
  // 52–60: day to night (the music's breakdown is beats 56–60).
  { name: "day to night", beats: 8, src: "daynight.mp4", from: 3.2, flash: true },
  // 60–68: the drop. One cut per beat.
  { name: "m1", beats: 1, src: "battle.mp4", from: 7.0, flash: true },
  { name: "m2", beats: 1, src: "drift.mp4", from: 9.1 },
  { name: "m3", beats: 1, src: "battle.mp4", from: 21.6 },
  { name: "m4", beats: 1, src: "drift.mp4", from: 32.3 },
  { name: "m5", beats: 1, src: "battle.mp4", from: 51.2 },
  { name: "m6", beats: 1, src: "drift.mp4", from: 36.6 },
  { name: "m7", beats: 1, src: "battle.mp4", from: 56.7 },
  { name: "m8 photo finish", beats: 1, src: "battle.mp4", from: 28.95 },
];

export type Text = { at: number; beats: number; words: string[]; y?: number; size?: number };

export const TEXT: Text[] = [
  { at: 10, beats: 6, words: ["TOUGE", "BATTLES"] },
  { at: 16, beats: 8, words: ["PASS", "THEM", "ALL"] },
  { at: 24, beats: 12, words: ["HOLD", "THE SLIDE"] },
  { at: 36, beats: 8, words: ["CHEAP", "OLD CARS"] },
  { at: 52, beats: 8, words: ["DAY", "TO NIGHT"] },
];

export const END = {
  pitch: ["BROKE CAR GUYS.", "OLD CARS.", "PHILIPPINE MOUNTAIN ROADS."],
  cta: "COMING SOON",
};
