# Trailer v2: "a manga chapter about a broke guy's 2am touge run"

Status: draft for approval (2026-10-16)

## Intent

Replace the 30 s vertical trailer (`trailer/edit`, commit ef8363e) with a 60 s one built on a
different idea. The old cut is a montage. The new one tells a tiny story in three moods:
**funny → tense → proud**. It opens on deadpan local humour, turns into a tense, stylish night
race and ends on quiet pride. It's told like manga panels coming to life.

One-line brief: *"It reads like a manga, it laughs like your tropa, and it races like it means it."*

Reference vibe: Initial D's manga panels × Wangan Midnight's late-night mood × the dry humour of
a Filipino barkada group chat. Grounded, stylish, local. Not flashy, not neon.

## Where it runs

TikTok and Instagram Reels. Vertical 1080×1920, 60 fps, about 60 s. Captions and cards stay
inside the existing platform safe area (`SAFE` in `trailer/edit/src/theme.ts`).

## Decided

These are the user's decisions:

- **Music: "Live on JP (Eurobeat)" by ZTMusic** (Pixabay licence), already in the repo at
  `assets/audio/music/race/ztmusic-ztmusic-live-on-jp-eurobeat-435974.mp3`.
- **The race is a mix of a VS battle and time attack.** Rival overtakes come from a VS battle.
  The ghost, sector splits and the final green delta come from a time-attack run. They're cut
  together as one run.
- **Race panels are layout A, "three slanted tiers".** During the race the frame splits into 2–3
  horizontal strips stacked top to bottom with slanted ink gutters (car / rival / sector time), and
  snaps back to full screen between those moments. The sector time and the beat card sit in or across
  the gutters. Mockup: `.superpowers/brainstorm/*/content/race-panels.html`, option A.
- **The freeze splash is treatment A, "ink + focus lines".** At the last hairpin the frame freezes
  and turns into a black-and-white high-contrast ink page (halftone screentone, radial focus lines
  converging on the car), with a bold two-line card. Then it snaps back to colour and motion.
  Mockup: `splash.html`, option A.
- **Numbers stay with their run.** Every sector time, ghost delta and the final green delta only
  appears in a panel showing footage from the time-attack run that produced it. It never sits over
  VS-battle footage. A time-attack strip can sit next to a battle strip in the same tiered page,
  like manga panels showing different moments side by side.
- Everything else in the brief below stands as written.

### The brief (the user's, kept intact)

**Tone.** Dry and affectionate, not loud. The humour comes from the world itself: "BAWAL ANG
UTANG" on the sari-sari, "BAWAL MAG-OVERTAKE" right before you overtake, a stray dog judging you.
Then serious. Once the race starts, no jokes: just the road, the car, the time. Quiet pride at the
end. No explosions, just a green delta and city lights from the View Deck.

**Visual language.**
- Panels, not cuts. Frames slam in as manga panels, split into 2–3 during the race, then snap to
  full screen.
- Ink, halftone and paper: ink-wipe transitions, screentone bursts on overtakes, speed lines that
  build with speed.
- Freeze-frame splash pages: one or two moments (a big pass, a hairpin apex) freeze into a
  full-page panel with a bold card, then snap back to motion.
- The tag-box type is the voice. Short two-line cards hit on the beat: TOUGE / BATTLES,
  PASS / THEM ALL, HOLD / THE SLIDE, plus new ones like OLD CAR. / FAST HANDS.
- Low, close cameras: bumper level, roadside static, overhead at hairpins. Intimate, not epic
  drone shots.

**Sound.**
- Opens almost silent: crickets, a sputtering idle, a distant tricycle, a dog barking.
- A hard drop when the race starts. Each text card lands on a hit.
- Engine and tires stay loud in the mix, even over the music. The car is the lead vocal.
- Hard silence for one beat before the final card, then the title hit.

**Pacing (60 s).**

| Time | Beat | Feel |
|---|---|---|
| 0:00–0:12 | Sari-sari, EG Civic, dog, signs | Deadpan, quiet, local |
| 0:12–0:15 | Engine fires, card OLD CAR. / BROKE GUY. | The turn |
| 0:15–0:45 | Touge: panels, ghosts, splits, overtakes, cards on beats | Tense, fast, precise |
| 0:45–0:50 | Freeze splash panel at the last hairpin | Peak |
| 0:50–0:55 | Green delta, View Deck city lights | Relief, pride |
| 0:55–1:00 | PANG DAILY: Broke car guys. Old cars. Philippine mountain roads. | Title |

## Goals

1. The three moods read clearly to someone scrolling with sound on, and still work muted (the
   cards carry the story).
2. It looks like the game. All footage comes from the game, and the panel and ink treatment
   matches the game's manga art (`PAPER`, `INK`, `RED`, `YELLOW`, Dela Gothic One, Bangers).
3. Cuts and cards are locked to the music's beat grid, and the race drop lands on the engine firing.
4. The pipeline stays reproducible: captures are deterministic (`--fixed-fps 60`) and the edit is
   data in one file, so it can be re-cut by editing numbers.

## Non-goals

- A landscape (YouTube or Steam) version. A later cut can reuse the pieces.
- New gameplay features. The trailer shows the game as it is.
- Voice-over or dialogue.

## Anti-goals (it's failed even if it technically works)

- Neon, glitch, loud jokes or meme sound effects. Any joke after 0:15.
- Epic drone or heli establishing shots as the main language (one overhead at a hairpin is fine).
- Music burying the engine and tires.
- Captions that sit under the TikTok/Reels UI.
- Hand-made footage that doesn't come from the game (no stock video, no faked gameplay).

## What already exists to build on

- **Pipeline:** `trailer/capture.gd` (Movie Maker staging, camera schedules, `events.json`
  with overtakes, slides and cuts), `capture.sh`, `stills.sh`, and the Remotion project
  `trailer/edit` (`edit.ts` as the edit decision list, `components.tsx` with `Clip`, `Flash`,
  `SpeedLines`, `Caption`, `Tag`, `ToneWipe`, `Logo`, `EndCard`). See `trailer/README.md`.
- **On the track:** the sari-sari store with "BAWAL ANG UTANG" just after the welcome arch,
  "BAWAL MAG-OVERTAKE" warning signs (`WARNINGS` in `track_builder.gd`, ~45 m before tight
  corners), the askal patrolling by the store (`roadside_life.gd`, `DOG_SPAN` 48–62 m after
  start), the tricycle shuttle, the VIEW DECK sign, and the valley/city lights
  (`manga_city_lights.gdshader`).
- **Racing:** VS battle (`vs_battle.gd`, 5 rivals) and time attack with a ghost of the best run
  and sector splits against the local best (`time_attack.gd`, `TimeAttackRecords`).
- **Audio:** night ambience with crickets, wind and distant dog barks (`game/audio/ambience.gd`),
  engine reverb, exhaust pops. Movie Maker records the game audio into the AVI.

## Constraints

- Captures run through the game's own APIs from `trailer/` scripts. Changes to `game/` are only
  for staging needs that can't be met from outside, and each one gets called out in the plan.
- The user edits and stages files in parallel: commit only this work's own paths
  (`git commit -- <paths>`), and leave the commits unpushed.
- Fixed 60 fps simulation, so probe runs give the same event times as renders.

## Calls I made (the user can overrule)

- **The hero car is the EG hatch** (`eg_hatch`). The brief says "EG Civic" and "OLD CAR. /
  BROKE GUY." I guessed this and the user didn't correct it.
- **The new trailer is a second Remotion composition** (`TrailerV2`, own edit file, render
  target `trailer/renders/pang_daily_v2_vertical.mp4`). The 30 s one stays renderable until v2 is
  approved. Shared components move or extend; nothing about v1's output changes.
- **Sector times, the ghost delta and the final green delta are drawn by the edit** in the
  trailer's ink type, using numbers from the capture's `events.json`. The game HUD isn't
  screen-recorded: clean feed keeps it consistent with the panels and the safe area. The numbers
  must be the real ones from the run.
- **The deadpan open uses game ambience from the capture**, plus an engine-start and sputter
  sound. The game has no starter sound. The user has
  `~/Downloads/freesound_community-honda-engine-start-and-rev-28544.mp3` (Pixabay licence; check
  it before use). It goes in the edit layer, not the game.
- **"BAWAL MAG-OVERTAKE" right before a pass** is the single deadpan beat allowed to cross into the
  race window, since it's the world joking, not the edit. Its placement is at the editor's
  discretion, at most one beat.
- **New card copy beyond the brief** (e.g. LAST / HAIRPIN on the splash) is the builder's to
  draft. OLD CAR. / BROKE GUY. at 0:12 and the end pitch are fixed.

- **The ghost is a staged earlier "best".** Same EG, run first with the autopilot a little
  slower, and saved to a records path separate from the player's own `user://time_attack/`
  saves. Those must never be touched; if that needs a path override in `game/`, it's one of the
  called-out staging changes. The hero run then beats it for real. The final green delta should be
  big enough to read and small enough to feel earned, around −0.3 to −0.8 s.
- **The music is absent for 0:00–0:12.** Only game ambience and the idle play. The track comes
  in at its drop on the engine fire, so the start offset is the drop itself, not an intro played
  quietly underneath.
- **The View Deck is its own staged clip after the finish** (the EG pulled over at the deck at
  night, city lights below). It doesn't need to be the finish line. "The last hairpin" for the
  splash is the hairpin that comes last in the cut, whichever reads best in vertical.
- **If the starter sample fails its licence check,** use another Pixabay-licence or CC0 starter
  sample, or fall back to the in-game idle with a hard rev on the drop.

## Left to the builder

- New capture shots and their camera schedules: the night open at the store, an EG VS battle,
  an EG time attack against a ghost, the last hairpin, the View Deck. Low, close cameras over
  drone and heli.
- Finding Live on JP's BPM, downbeats and drop, and choosing the start offset so the drop lands
  at about 0:12.
- The panel, splash, screentone-burst and ink-wipe components, and the audio mix (ducking music
  under engine and tires, the one-beat silence before the title).
