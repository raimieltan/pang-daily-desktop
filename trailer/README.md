# Trailer pipeline

Vertical (1080×1920, 60 fps) trailer for TikTok, Instagram Reels and YouTube Shorts. All footage is
captured from the game with Godot's Movie Maker; the edit is a Remotion project.

Nothing here is loaded by the game: `capture.gd` runs as a `-s` SceneTree script and stages shots
through the game's own APIs, and the frame size comes from a temporary `override.cfg` that
`capture.sh` deletes on exit.

## Capture

```sh
trailer/capture_all.sh                 # every shot + stills, ~20 min on an M1
trailer/capture.sh drift               # one shot -> trailer/out/drift.avi, .mp4, .events.json
trailer/stills.sh drift 9.2,32.4       # clean PNGs at those times, 1920×1080 and 3840×2160
```

| Shot | What | Length |
|---|---|---|
| `battle` | Night VS battle, 5 rivals, player gridded last, autopilot carving through | 62 s |
| `drift` | Silak Box on its drift tune, drift pilot flicking into every corner | 48 s |
| `intro` | The VS intro as the game plays it (crane, rival cards, countdown) | 16.5 s |
| `daynight` | Day flipping to night mid-corner | 12 s |
| `cars` | Each garage car on the road, 5 s each | 20 s |
| `garage` | Title → garage cycling the cars, 2560×1440 landscape (zoomed in the edit) | 9 s |

Each shot writes `<shot>.events.json`: overtakes (`by`, `on`, `t`), slides (`t0`, `t1`,
`max_slip`), camera cuts and marks. The sim is deterministic under `--fixed-fps`, so a fast
headless probe gives the same times as the render:

```sh
GODOT=/Users/sean/Downloads/Godot.app/Contents/MacOS/Godot
$GODOT --headless --path . --fixed-fps 60 -s res://trailer/capture.gd -- --trailer-shot=battle --probe --out=/tmp/probe
```

Knobs: camera schedules are `BATTLE_CAMS` / `DRIFT_CAMS` in `capture.gd` (time, shot, focus car,
side). Shots: `chase far hood bumper` (game cams), `trackside flyby chase_low heli drone wheel nose
orbit lead` (CinematicDirector rigs) and `side`. `--car=<id>` swaps the car, `--pilot=entry_ratio:0.9,
flick_seconds:0.5` tunes `drift_pilot.gd`, `RIVAL_PACE` sets how far off the rivals are.

Stills: 1080p comes straight from the window; 4K is drawn by an offscreen SubViewport that mirrors
the live camera and its manga compositor (`--still-size=3840x2160`), because macOS caps a window at
the display size. They are HUD-free and skip the 2D panel border and speed-line overlay.

To re-capture one shot after changing its staging or camera schedule: `trailer/capture.sh <shot>`
(probe first to check event times), then re-check the `from` values in `edit/src/edit.ts`.

## Edit

```sh
cd trailer/edit
npm install
npm run studio          # preview; VerticalSafeZones tints the platform UI areas red
npm run render          # -> trailer/renders/pang_daily_vertical.mp4
```

- `src/edit.ts` is the whole edit: `CUTS` (beats, source, `from` seconds), `TEXT` (captions by
  beat), `END` (pitch and call to action), `MUSIC` (track and start offset).
- Music: "Chasing (Eurobeat)" by ZTMusic (Pixabay licence), 149.8 BPM. Starting at 25.69 s puts
  its breakdown on beats 56–60 and the drop on beat 60 (24.0 s). Some Pixabay tracks are in
  YouTube Content ID; if a platform flags or mutes it, swap `MUSIC.file` for the CC0
  `race_hot_roadway.ogg` (160 BPM, change `BPM` too).
- `public/footage` is a symlink to `trailer/out`.
- `Clip` `zoom` crops a source (`cx`, `cy`, `w` in source pixels); the intro cards use it to drop the
  game's letterbox bars and the garage to fill the vertical frame with the car card.
- Captions sit in the platform safe area (`SAFE` in `theme.ts`); render `VerticalSafeZones` to check.

## v2: the broke guy's 2am run (60 s)

Design: `docs/superpowers/specs/2026-10-16-trailer-v2-design.md`. Composition `V2` in the same
Remotion project; the edit is `edit/src/v2/edit.ts`, the manga pieces (slanted tier pages, the
ink freeze splash, two-line cards, split readouts, screentone burst, ink wipe) are
`edit/src/v2/components.tsx`.

```sh
MOVIE= HEADLESS=1 trailer/capture.sh ta_best --probe   # the ghost lap (no movie; run before `ta`)
for s in open viewdeck eg_battle ta; do trailer/capture.sh $s; done
cd trailer/edit && npm run render:v2   # -> trailer/renders/pang_daily_v2_vertical.mp4
```

| Shot | What |
|---|---|
| `open` | 2am at the sari-sari store: the EG idling, the askal, BAWAL ANG UTANG; revs at 10.9 and 11.6 s |
| `eg_battle` | Night VS battle in the EG, gridded second row behind JUNJUN, ATE LIZA and KAPITAN |
| `ta_best` | Probe only: a slower EG lap (skill 0.97) saved as the time-attack ghost |
| `ta` | The EG's time attack against that ghost; `split` / `finish` marks carry the real numbers |
| `viewdeck` | The EG on the View Deck pad, city lights below |

- `capture.sh` points `user://` at a trailer-only folder (`pang_daily_trailer`), so the staged
  ghost never touches the player's own records or settings. `ta_best` clears that record first;
  a `ta` capture saves its lap as the new best, so re-run `ta_best` before re-capturing `ta`.
- Every number in the edit is copied from `ta.events.json` and only appears in a panel showing
  the time-attack run (the design's "numbers stay with their run" rule).
- The autopilot runs wide at the last hairpin (~1359 m) and wedges against the chevron board; the
  v2 shots cap the entry speed there (`HAIRPIN_ASSIST` in `capture.gd`). The AI itself still
  does this in the game.
- Music: "Live on JP (Eurobeat)" by ZTMusic (Pixabay licence), 147 BPM, drop at 127.74 s placed
  on trailer 0:12. Nothing plays under the open.
- `--skill=` and `--rival-pace=` override the v2 shots' autopilot skill and rival pace for probing.

## v3: the story trailer, "The Ghost Line" (16:9 ~93 s + 9:16 ~62 s)

Design: `docs/superpowers/specs/2026-10-18-story-trailer-design.md`. Footage is story mode itself, captured beat by
beat on the trailer's probe save; both cuts are in `edit/src/v3/edit.ts` (`wide`, `tall`).

```sh
trailer/story_capture.sh --probe-story        # once: play the story headless so the passes/cut/crash log exist
                                              # (or copy a finished user://story_probe.json into
                                              #  ~/Library/Application Support/pang_daily_trailer/)
trailer/story_capture_all.sh                  # every take -> trailer/out/story/<name>.mp4 + .events.json (~3 h on an M1)
ONLY=s13_clean,s27 trailer/story_capture_all.sh   # re-take some
cd trailer/edit && npm run render:story       # -> renders/pang_daily_ghost_line_{16x9,9x16}.mp4
```

- `story_capture.gd` starts story mode at `--beat=<id>`, auto-advances lines (`--advance`), drives every drive beat
  with the AI, and logs each line's on-screen time to `<name>.events.json` — that's where the edit's `from` values
  come from. `--clean` hides the story's 2D layer and the HUD (clean plates for the edit's own text and the 9:16
  reframes); `--cams=t:shot,…` switches game cameras.
- Pass scenes render at ~14 % of real time; the watchdog (`LIMIT`, default 3600 s) must outlast them.
- Speech-panel takes show the game's "CLICK / SPACE" prompt; the edit patches it with `masks` in the panel's colour
  (`NOW_PANEL`, `MEMORY_PANEL`, `PAGE_HINT`).
- 9:16 reframes each 1920×1080 take with `focus` [cx, cy, w] (607 px wide = full height), or shows comic pages as a
  full-width `band` on paper.
- Music: "Dark Pulse – Suspense Thriller Cinematic" by MeeGiStudio (Pixabay licence), spliced on its own hits
  (`WIDE_MUSIC` / `TALL_MUSIC`). Story SFX (wrench, shutter, phone buzz) are the game's own, in `public/sfx`.
- Final deliverables are loudness-normalised to −14 LUFS (two-pass `loudnorm`) from the `_raw` renders.
