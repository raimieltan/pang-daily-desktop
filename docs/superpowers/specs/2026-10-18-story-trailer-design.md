# Story trailer: "The Ghost Line"

Status: built (2026-10-18). The user gave full creative liberty for the build.

## Intent

The v1 and v2 trailers sell the car. This one sells the question. It is a story trailer for story
mode (`docs/story/STORY_MODE.md`) that plays as an underground racing drama and slowly turns into a
psychological mystery: *what actually happened that night, and why doesn't the evidence line up?*

It is built on Pang's own refrain, **"Here's what I know."** The line opens the trailer. Every
time it comes back he knows less than he thinks, and it is cut off before its ending in the silence
before the title.

## References (the user's)

- **Mystery structure:** Gone Girl, Alan Wake 2. Set up a clear question, then bring in contradictions.
- **Unease:** Mr. Robot, Shutter Island, Control. The same place twice, slightly wrong, and a voice
  you have heard before.
- **Evidence as rhythm:** The Girl with the Dragon Tattoo, L.A. Noire. Fragments like a camera card,
  a logger or a board, not a detective-board graphic.
- **The racing stays the lead:** The Batman, Need for Speed (2015), Max Payne 3. Engine, rain and
  wipers are the percussion, and the scene around the races (the meet, Kyo, the talyer) is the world.
- **Personal stakes:** The Last of Us Part II. Jolo is why it matters.

## Rules

- **No spoilers past Act II.** "Ghost is you" and "it never happened" stay hidden. Act III–V lines
  ("I drove it once", "I was driving") never appear. Shots may be clues that only land after you've
  played it (Jolo filming the line study, the lower road, "they don't add up").
- **Everything is the game.** Every frame is captured from story mode on its own probe save. Every
  line on screen is the game's own text from `StoryScript.BEATS`, sometimes trimmed to one sentence.
- **Two looks, cut hard against each other:** the cold present (rain, NOW) and the warm memory
  (`StoryTint`, MONTHS BEFORE). The game draws both.
- **The faces are the game's speech panels.** Characters have no 3D bodies; their portraits live in
  the dialogue panels, so key lines use the real panels (the "CLICK / SPACE" prompt is patched out
  in the panel's colour). Narration and short lines over clean plates use the edit's own ink boxes in
  the game's type.

## Music

"Dark Pulse – Suspense Thriller Cinematic" by MeeGiStudio (Pixabay licence; `assets/audio/music/`,
copied to `trailer/edit/public/music/dark_pulse.mp3`). It was picked by measurement from four the
user added. It's the only one shaped like a trailer: sparse hits to 39 s, a build, full from ~78 s,
**near silence at 108.58–111.05 s**, one last hit, an ending. The others were a flat bed (Night
Investigation), a constant pulse (Hydraulic Pulse) and a flat loop (Dark Tension).

Both cuts are spliced on the track's own hits (`WIDE_MUSIC` / `TALL_MUSIC` in `edit.ts`):

| Wide (16:9, 92.8 s) | Track | Section |
|---|---|---|
| 0–19.85 | 0–19.85 | Cold open: the night in pieces |
| 19.85–29.44 | 19.85–29.44 | The present: after |
| 29.44–39.07 | 29.44–39.07 | The memory: the wrench, then warm; the meet |
| 39.07–59.47 | 39.07–59.47 | The legend: Ghost, the scene, three versions |
| 59.47–77.38 | 90.67–108.58 | The rupture: the chase, the joins, the lights |
| 77.38–79.85 | 108.58–111.05 | Silence: "Here's what I know." cut off |
| 79.85–84.67 | 111.05–115.87 | Title |
| 84.67–92.8 | 124.27–132.4 | "so who's ghost" and out |

The tall cut (9:16, 61.6 s) drops one phrase of the open, half the build and most of the peak,
and keeps the silence and the title hit.

## Formats

One capture pass, two edits. Takes are 16:9 1920×1080 (`trailer/story_capture.sh`). The 16:9 cut uses
them full frame. The 9:16 cut reframes each one with `focus` (a region of the source) and keeps text
inside the TikTok/Reels safe area.

## Pipeline

- `trailer/story_capture.gd` / `story_capture.sh <beat> [--clean] [--cams=…]`: starts story mode at a
  beat on the trailer's probe save, with lines auto-advancing and the AI driving, under Movie Maker. It
  writes `<name>.events.json` with every line's on-screen time. `--clean` hides the story's 2D layer
  and the HUD for clean plates.
- `trailer/story_capture_all.sh`: every take the trailer uses.
- `trailer/edit/src/v3/`: `edit.ts` (both edit lists), `components.tsx`, `StoryTrailer.tsx`.
  `npm run render:story` writes both renders to `trailer/renders/`.

## Calls I made

- 16:9 is the master and runs about 93 s, slightly over the 90 s target, so the track can end on its own
  final hit instead of a fade.
- The title is the game's lockup with THE GHOST LINE as its subtitle, plus STORY MODE.
- The last image is Buko's "so who's ghost" from the group chat. It's funny-sad, in the scene's own
  voice, and it is the question the trailer leaves you with.
- Speech-panel lines are shown as the game draws them (with portraits). Pang's narration uses the
  edit's ink box, so it reads at trailer size.
