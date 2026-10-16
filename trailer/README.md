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
