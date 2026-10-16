import { loadFont } from "@remotion/fonts";
import { staticFile } from "remotion";

// The game's own palette and lettering (game/ui/manga_type.gd), so the trailer reads as the game.
export const PAPER = "#F3EFE5";
export const INK = "#131212";
export const RED = "#E24A45";
export const YELLOW = "#F2C21B";

export const TITLE_FONT = "Dela Gothic One";
export const CAPTION_FONT = "Bangers";

export const fontsReady = Promise.all([
  loadFont({ family: TITLE_FONT, url: staticFile("fonts/DelaGothicOne-Regular.ttf") }),
  loadFont({ family: CAPTION_FONT, url: staticFile("fonts/Bangers-Regular.ttf") }),
]);

// TikTok / Reels / Shorts cover the top (status + tabs), the bottom (caption, music, nav)
// and the right edge (like / comment / share). Text stays inside this box.
export const SAFE = { top: 260, bottom: 1920 - 420, left: 70, right: 1080 - 170 };
