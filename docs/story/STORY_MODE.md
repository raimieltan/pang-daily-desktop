# Story Mode — "The Ghost Line"

Oct 17, 2026 · @sean raimiel tan

**Canon for story mode.** The narrative itself lives in this folder: the plot (`GHOST_LINE_PLOT.md`), the prose manuscript (`GHOST_LINE_MANUSCRIPT.md`, the source of the dialogue) and the playable storyboard (`GHOST_LINE_STORYBOARD.md`, scenes S00–S35). This doc says how the game plays them. Where the storyboard and this doc disagree on *how*, this doc wins; on *what happens*, the storyboard wins.

## Overview

Story mode is a five-act psychological thriller played on the game's own roads, cars and hubs: Pang, an underfunded driver from Iloilo, survives a mountain crash that kills his friend Jolo, hunts the anonymous driver "Ghost" whose benchmark he was chasing that night, and learns that Ghost is himself — and that the perfect run never happened.

It is reached from the title screen (STORY). It sits beside the racing grind, not inside it: it has no money, wear or ladder, and its races never pay out.

**The rule the whole mode is built on:** the evidence is the player's own driving. The three practice passes the player drives in "A Line Study" are cut into the Ghost Line they then chase; the crash run they drive is the logger they later read; the sector trials they drive are the sheet Nico publishes. Nothing the investigation shows is canned.

## Decisions (Oct 17, 2026)

| Question | Decision |
| --- | --- |
| Story in a racing-first game | Story mode is a separate mode from the title screen. It reverses the Oct 16 cut of "story chapters" for this one story; the grind (time attack, SP battles, rival ladder, economy) is unchanged and does not depend on it. |
| Protagonist | Pang (the game is named for him). His car is the EG Hatch in paint faded between blue and grey (`StoryMode.CAR_PAINT`), not a player choice. |
| The mechanic | Ruel runs the talyer everywhere in the game; he replaces Tito Jun (hub sign, place name and NPC line renamed). |
| Nico | A new rival for the story only: Dalagan GSR in pearl white, AI skill 0.97. He is not in the VS/SP ladder. |
| Existing cast | KAPITAN, TISOY, BUKO, ATE LIZA (and RJ, a meet regular) are the scene: they race the meets, post in the group chat and tell the rumours. JUNJUN does not appear. |
| Rooms the game does not build | The rented room, the parked car, Jolo's family home and the group chat play on paper panels (`scenes/story_panel.tscn`), not built 3D sets. |
| Walking | None. "Playable exploration" scenes are drive-to objectives in the barangay plus dialogue at the place. |
| The crash | The player drives the night run up to the approach to 8A; from 70 m out the night plays as it happened (too fast for the wet, late brakes, a sharp correction). No button prompt pretends it can be avoided. |
| Beating the Ghost Line | Allowed. If the player's run beats it, "beaten" lines replace the usual ones (Dante: "Unofficial… Ghost Time stands."); the story never tells the player they failed when they did not. |
| Scoring | Story races record place and time only. The daylight drive has no clock, medal or unlock. No achievement for "beating Ghost" or for forgiveness. |

## Structure

The script is `game/story/story_script.gd` (`StoryScript.BEATS`): 47 beats in play order, every storyboard scene S00–S35 at least once (a unit test enforces it). Each beat is one scene, or one piece of a scene, on a **stage**:

| Stage | Scene | Used for |
| --- | --- | --- |
| `pass` | `scenes/touge.tscn` (Pass 1) | Races, practice, the Ghost Line runs, sector trials, the night run, the overlook, the daylight drive |
| `hub` | `scenes/hub.tscn` (the barangay) | The talyer, Kyo Coffee, the gas-station meet, the meet loop races, drive-to objectives |
| `panel` | `scenes/story_panel.tscn` (paper page) | Act cards, the group chat, rooms with no 3D set |

`StoryDirector` plays beats while they are on its scene's stage; when the next beat needs another stage, `StoryMode` changes scene and that scene's director carries on. Progress saves after every beat (`user://story.json`).

| Act | Beats | Playable drives |
| --- | --- | --- |
| Prologue · The Missing Seconds | S00 cold open (fragments of the night, hood camera, cut to black) | — (authored) |
| I · Before Ghost | S01–S13 | R1 "Nothing to Lose" (barangay loop, must win), R2 "Nico's Lesson" (Pass 1, 1v1), A Line Study (3 recorded passes), R3 Chase the Composite, R4 Combined-Sector Challenge, R5 The Last Night Run |
| II · The Return | S14–S20 | R6 First Return (barangay loop, the flinch), R7 Nico Repeats the Test (3 flying sectors) |
| III · The Ghost Is You | S21–S26 | R8 The Sector Trials (3 sectors under their source conditions, then one continuous run) |
| IV · What Happened on the Mountain | S27–S31 | — (investigation) |
| V · The Road Is Not a Recording | S32–S35 | D1 The Daylight Road (no clock) |

The storyboard's quality gate holds: no stretch of the post-crash investigation goes without a playable drive (S16, S18, S26).

## Beat types

| Type | What the player does | Built from |
| --- | --- | --- |
| `chapter` | Reads an act card | `StoryDialogue.chapter` |
| `talk` | Reads dialogue (speech panels, ink narration boxes, or the phone feed); the car is parked and a fixed camera frames the place | `StoryDialogue.play`, `StoryDirector.SPOT_VIEWS` |
| `goto` | Drives to a barangay place (objective with distance) | `HubLayout.PLACES` areas |
| `race` | VS race on Pass 1 or one lap of the barangay loop against a story field | `VsBattle.field_override` |
| `practice` | Three timed passes under labelled conditions, each recorded | `TimeAttack` (`records = false`), `StoryRecorder` |
| `attack` | A run against the Ghost Line (ghost car and split deltas) | `TimeAttack.reference` / `ghost_override` |
| `sectors` | Flying sectors against the ghost's own sector (run-up, timer from the sector line), optionally then a full run | `StoryDirector._flying_sector` |
| `crash` | The night run (or, as `cold_open`, its fragments) | `StoryDirector._crash`, `_takeover` |
| `daylight` | Drives the road, no HUD; the ghost appears near 8A and goes on without you | `StoryGhost`, a `RoadsideLife.Mover` oncoming |
| `evidence` | Reads evidence cards, answers a question (wrong answers get a nudge, never a fail) | `EvidenceBoard` |
| `end` | The end card, back to the title | — |

## The Ghost Line

Jolo's "COMPOSITE LINE STUDY — BEST SECTORS / NOT ONE RUN" is `GhostLine.composite()` over the three practice passes:

- Pass 1 is split into 4 equal sectors (as in time attack). For each sector the fastest pass is taken; if that leaves fewer than three passes in the cut, the cheapest swaps bring in the others (a best-of that is one pass is not a composite).
- The frames are cut together back to back: the clip looks continuous, but at each join the car steps sideways, the speed trace steps, and the logger clock (time into the source pass) resets. Those are the seams the player finds in S18 and S25.
- GHOST TIME is the sum of the chosen sectors. It is the target in R3, R4 and the night run, and the reference in the sector trials.
- The pass conditions are part of the evidence: Pass A dry with the 8A chevron board straight; Pass B with damp patches (sheen only, no grip loss) and the board bent on its post; Pass C dry in low sun. The board is a prop on the outside of 8A (`StoryDirector.SignAt8A`), bent from Pass B on.
- By R3 the car's front tires are worn (grip × 0.95, Ruel says so before the run): the car the player has then is not the one in the clip.

Frames are `StoryRecorder` samples at 20 Hz: position, rotation, speed, steering, throttle, brake and distance along the road (`GhostLine.STRIDE` = 12 floats).

## The night run

- Night, rain (ink streaks round the camera, mist), wet road (grip × 0.62, darker tar with sheen in the ruts), worn fronts, the Ghost Line brighter than usual.
- Jolo's lines come as subtitles at points on the road ("Different here." … "Pang, listen.").
- From 170 m out, a car's lights move uphill on the leg below 8A (the lower switchback), 12–24° off the nose through the trees.
- From 70 m out the director takes the wheel: full throttle where the dry practice was already braking, brakes at 24 m, then the wet patch (grip × 0.55) and the correction (hard one way, then the other) under "Drive the road!". It ends on the first hard contact, leaving the road, or 2.6 s after braking: a white frame, the impact, black and silence, a pulse.
- The logger keeps the whole run; the camera file is cut 2.2 s before the logger ends.

## Investigation

Every question's answer is on the page. The ladder follows the storyboard's clue ladder:

| Beat | Evidence | The question |
| --- | --- | --- |
| S06 (seen early) | Jolo's edit: the passes, which sector came from which, the label | — (a fair clue, shown before anyone calls it Ghost) |
| S09 | The challenge board; "COMBINED BEST SECTORS" on the HUD for 5 s before it becomes GHOST TIME | — (missable) |
| S17 | Three rumours | What do they establish? (nothing yet) |
| S18 | Nico's notes: your sectors against the ghost's; the logger clock jumping at the joins | — |
| S21 | The backup drive | What ties the clip to a car you know? (the reflection and the correction, not the filename) |
| S22 | Steering of the clip over the raw source pass | Whose hands? |
| S25 | The composite timeline: speed trace, joins, logger clock, source pass | Two things one run could not do |
| S26 | The trial sheet: each sector under its own conditions, your one continuous run, the ghost total | — |
| S27 | Map of 8A and the lower switchback, the last dash-camera frames, the witness | Where were the lights? |
| S28 | The logger: your crash run's speed, brake and steering, the dry practice speed at the same metres, 8A, where the camera file ends | What does it show? |
| S29 | The board | Pick the four things the evidence supports |

## Audio motifs

Synthesized by `tools/audio/make_story_sfx.py` (all original): `assets/audio/story/` wrench on concrete (the bridge between nights), camera shutter, phone buzz (Dante), heartbeat pulse, wiper stroke; `assets/audio/ambience/rain_loop.wav`. The crash impact reuses `impactMetal_heavy_000.ogg`.

## Files

| Path | What |
| --- | --- |
| `game/story/story_mode.gd` | State, save, scene hand-off, the player's record |
| `game/story/story_script.gd` | The beats and their lines |
| `game/story/story_director.gd` | Plays beats on a stage (races, practice, trials, crash, daylight, evidence) |
| `game/story/story_dialogue.gd` | Speech panels, narration, phone feed, act cards, cuts, SFX |
| `game/story/evidence_board.gd` | Evidence cards and questions |
| `game/story/ghost_line.gd` | The composite |
| `game/story/story_recorder.gd`, `story_ghost.gd`, `story_course.gd` | Recording, the ghost car, where 8A and the lower road are |
| `tools/audio/make_story_sfx.py` | Synthesizes the story's sounds |
| `game/world/weather.gd` | Rain, wet road, mist, wet grip (usable outside the story) |
| `scenes/story_panel.tscn` | The paper stage |
| `tests/test_story.gd` | Script integrity, the composite, the course |
| `tests/probe_story.gd` | The whole story headless, AI driving: `godot --headless --fixed-fps 120 --path . -s res://tests/probe_story.gd [-- beat_id]` |
| `tools/story_shot.gd` | Screenshots from any beat (needs a window) |

## Not built / open

- Character art: speakers are named on ink slabs; there are no portraits.
- Jolo's family home, the clinic and the parked car are paper panels, not 3D sets.
- Wiper and in-car rain on the glass in hood view.
- Taglish/Hiligaynon: most lines follow the English manuscript; only the barangay regulars speak Hiligaynon/Taglish. A localisation pass is open.
- Story races use the base handling; no tuning or parts in story mode.
