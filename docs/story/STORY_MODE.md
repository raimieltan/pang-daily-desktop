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
| Rooms | The clinic, the rented room and Jolo's family home are small 3D sets (`scenes/story_room.tscn`, built by `tools/world_builders/build-story-rooms.py`). The parked-car scenes play from the driver's seat outside Pang's home, drops on the glass. Act cards, the group chat and the S19 memory montage stay on paper panels (`scenes/story_panel.tscn`). |
| Walking | None. "Playable exploration" scenes are drive-to objectives in the barangay plus dialogue at the place. |
| The crash | The player drives the night run up to the approach to 8A; from 70 m out the night plays as it happened (too fast for the wet, late brakes, a sharp correction). No button prompt pretends it can be avoided. |
| Beating the Ghost Line | Allowed, and never dismissed. The line study has a floor (baked passes), so the cut is never a lap anyone could beat by driving the study badly. The public number is Dante's, a little under the cut: beat the car in the clip but not the clock and the board says otherwise ("ahead" lines); beat the clock in public and Dante reposts a time under yours, "Ghost responded" ("beaten" lines), which Act III pays off. Against the cut itself (R3, the sector trials) a beating simply stands. |
| Language | All dialogue is in English (Oct 17 playtest: the Hiligaynon/Taglish pass read badly and was reverted). The Iloilo setting stays in names, places and signage. |
| Between scenes | Manga pages (`StoryComic`): a beat's `comic` pages play before it and `comic_after` after it, one panel per press, so scene changes and the cold open are bridged by panels instead of hard jumps. Every scene change fades through black; the car's sound is muted while a page is up. |
| Scoring | Story races record place and time only. The daylight drive has no clock, medal or unlock. No achievement for "beating Ghost" or for forgiveness. |

## Structure

The script is `game/story/story_script.gd` (`StoryScript.BEATS`): 45 beats in play order, every storyboard scene S00–S35 at least once (a unit test enforces it). **The story is told from after the crash** (Oct 17, 2026 restructure, `docs/superpowers/specs/2026-10-17-story-flashback-restructure-design.md`): the player lives the present and the months before come back as four memories, each triggered by something in the present. The edit (the storyboard's S06 laptop scene) is withheld, so "Ghost is you" and "it never happened" land in Act III with the player's own recorded passes. Each beat is one scene, or one piece of a scene, on a **stage**:

| Stage | Scene | Used for |
| --- | --- | --- |
| `pass` | `scenes/touge.tscn` (Pass 1) | Races, practice, the Ghost Line runs, sector trials, the night run, the overlook, the daylight drive |
| `hub` | `scenes/hub.tscn` (the barangay) | The talyer, Kyo Coffee, the gas-station meet, the meet loop races, drive-to objectives, the parked car (`cabin`: from the driver's seat) |
| `room` | `scenes/story_room.tscn` (a small set) | The clinic and the rented room (S14, cut between with `["~set", name]`), Jolo's family home (S32) |
| `panel` | `scenes/story_panel.tscn` (paper page) | Act cards, the group chat, the memory montage (S19) |

`StoryDirector` plays beats while they are on its scene's stage; when the next beat needs another stage, `StoryMode` changes scene and that scene's director carries on. Progress saves after every beat (`user://story.json`).

| Act | Beats (present · **MEMORY**) | Playable drives |
| --- | --- | --- |
| Prologue · The Missing Seconds | S00 cold open (fragments of the night, hood camera, cut to black) | — (authored) |
| I · The Return | S14, S15 · **MONTHS BEFORE: S01, S02, S03, S04, S05** · S16, S17 · **THE LINE STUDY: S06** · S20 (Dante, suspicion) | R1 "Nothing to Lose", R2 "Nico's Lesson" (memories); R6 First Return (the flinch); A Line Study (3 recorded passes, memory) |
| II · The Ghost | S18, S19 · **GHOST GOES PUBLIC: S07, S08, S09, S10** · S21, S22 (Ghost is you) | R7 Nico Repeats the Test; R3 Chase the Composite, R4 Combined-Sector Challenge (memories) |
| III · The Ghost Is You | S23, S24, S25 (it never happened), S26 | R8 The Sector Trials, then one continuous run |
| IV · What Happened on the Mountain | **THE WEEK OF THE NIGHT RUN: S11, S12, S13** · S27, S28, S29, S30 (Dante, proof), S31 | R5 The Last Night Run (memory) |
| V · The Road Is Not a Recording | S32–S35 | D1 The Daylight Road (no clock) |

The data order holds the story order: the Ghost Line is cut from S06's passes, so S06 precedes every chase of it; the crash log read in S28 is recorded in S13. A unit test pins both.

## Memories

The first beat of a memory carries `"memory": <period>` and opens on its comic page (the present-day trigger: the wrench, the clip on Buko's phone, Jolo's camera bag, the bent sign at 8A). Inside a memory the page is warm (`StoryTint`, one multiply wash over the 3D pass and the UI), the period is stamped top right for the whole memory, races included, Jolo has a face and Pang has no scar. The first beat back carries `"now": <sound>`: a hard cut to black on a present-day sound, then the present comes up stamped NOW. `StoryScript.memory_of(index)` derives all of it from the beat index, so a resumed save looks right. In the present, talk and evidence beats with no weather of their own get rain and an overcast sky until Act V; drive beats, drive-to beats included, keep theirs (the trials are dry evidence). Reordering `BEATS` means bumping `StoryMode.SCRIPT_VERSION`: saves from another order start the story over. Jolo's present-day lines are footage ("(on the clip)") and show no portrait.

## Beat types

| Type | What the player does | Built from |
| --- | --- | --- |
| `chapter` | Reads an act card | `StoryDialogue.chapter` |
| `talk` | Reads dialogue (speech panels with the speaker's portrait, ink narration boxes, or the phone feed); the car is parked and a fixed camera frames the place | `StoryDialogue.play`, `StoryPortrait`, `StoryDirector.SPOT_VIEWS`, `StoryRoom.SETS` |
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
- The cut's time is the sum of the chosen sectors: the target in R3 and the reference in Nico's tests and the sector trials. GHOST TIME as posted is Dante's number, the cut less `StoryMode.POSTED_CUT` (3%), its splits scaled to it: the target at R4 and on the night run, the `{ghost_time}` token, and the GHOST row of the challenge board. The car in the clip always drives the cut, so at R4 you can finish ahead of it and still be behind the clock. Beating the posted time at R4 reposts it `REPOST_MARGIN` under your run (`StoryMode.repost`, kept in the record), and the night run chases that.
- The floor: `game/story/baked_passes.json` holds three passes an AI drove on the limit (`tools/bake_passes.gd`). `StoryMode.add_pass` keeps a recorded pass only if it is quicker than the baked pass in its slot; otherwise the baked driving goes in under the player's label. The evidence (raw clips, the steering match, the sign) reads the record, so it stays consistent whichever passes are in it.
- The pass conditions are part of the evidence: Pass A dry with the 8A chevron board straight; Pass B with damp patches (sheen only, no grip loss) and the board bent on its post; Pass C dry in low sun. The board is a prop on the outside of 8A (`StoryDirector.SignAt8A`), bent from Pass B on.
- By R3 the car's front tires are worn (grip × 0.95, Ruel says so before the run): the car the player has then is not the one in the clip.

Frames are `StoryRecorder` samples at 20 Hz: position, rotation, speed, steering, throttle, brake and distance along the road (`GhostLine.STRIDE` = 12 floats).

## The night run

- Night, rain (ink streaks round the camera, mist, drops and wipers on the glass in hood view), wet road (grip × 0.62, darker tar with sheen in the ruts), worn fronts, the Ghost Line brighter than usual.
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
| `game/story/story_portrait.gd` | Speaker portraits, ink busts drawn in code (`tools/portrait_sheet.gd` renders them all) |
| `scenes/story_room.tscn`, `tools/world_builders/build-story-rooms.py` | The room stage and its sets |
| `game/world/windscreen.gd` | Rain on the glass and wipers in hood view |
| `game/story/evidence_board.gd` | Evidence cards and questions |
| `game/story/ghost_line.gd` | The composite |
| `game/story/baked_passes.json`, `tools/bake_passes.gd` | The line study's floor and the tool that bakes it: `godot --headless --fixed-fps 120 --path . -s res://tools/bake_passes.gd -- [skill]` |
| `game/story/story_recorder.gd`, `story_ghost.gd`, `story_course.gd` | Recording, the ghost car, where 8A and the lower road are |
| `tools/audio/make_story_sfx.py` | Synthesizes the story's sounds |
| `game/world/weather.gd` | Rain, wet road, mist, wet grip (usable outside the story) |
| `scenes/story_panel.tscn` | The paper stage |
| `tests/test_story.gd` | Script integrity, the composite, the course |
| `tests/probe_story.gd` | The whole story headless, AI driving: `godot --headless --fixed-fps 120 --path . -s res://tests/probe_story.gd [-- beat_id]` |
| `tools/story_shot.gd` | Screenshots from any beat (needs a window) |

## Comic pages

A page is 1–4 panels (the layout follows the count). Panel art: `face` (the speaker's portrait, the bubble in the free side), `snap` (the scene behind the page, frozen), `speed`, `rain`, `wipers`, `lights`, `road`, `tone`, `black`, `white`; text: `cap` (caption box), `say` (bubble, `who` speaking), `fx` (a sound word); `sfx` plays a story sound as the panel lands. The prologue and Act I use them at every transition (the cold open's lead-in and its "the rest would be missing" page come from the manuscript). Clicks, Space, Enter and E advance; a CLICK / SPACE hint shows whenever the story is waiting.

## Not built / open

- Review leftovers from the restructure (Oct 17): the period stamp is one line, top right (the design wanted period + place); a memory's trigger panels render warm and unscarred (the page is drawn at the memory's index); `StoryTint` shares layer 20 with the pause menu; a `night` key cancels the present-day rain default (s17e, s20, s23, s24 stay dry at night); old saves are dropped without a notice; s11's entry panel is rain art under a daylight caption.
- Full-colour / watercolour memories: the world is modelled in grey (one lit value per preset; Blender colours are discarded on import), so colour is an art-pipeline project. The warm tint is the cheap version.
- The parked-car scenes show the view out of the windscreen; there is no car interior or passenger.
- Story races use the base handling; no tuning or parts in story mode.
