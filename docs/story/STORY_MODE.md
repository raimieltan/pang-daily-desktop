# Story Mode — "The Ghost Line"

Oct 17, 2026 · @sean raimiel tan · races, money, parts and free roam added Oct 18, 2026

**Canon for story mode.** The narrative itself lives in this folder: the plot (`GHOST_LINE_PLOT.md`), the prose manuscript (`GHOST_LINE_MANUSCRIPT.md`, the source of the dialogue) and the playable storyboard (`GHOST_LINE_STORYBOARD.md`, scenes S00–S35). This doc says how the game plays them. Where the storyboard and this doc disagree on *how*, this doc wins; on *what happens*, the storyboard wins.

## Overview

Story mode is a five-act psychological thriller played on the game's own roads, cars and hubs: Pang, an underfunded driver from Iloilo, survives a mountain crash that kills his friend Jolo, hunts the anonymous driver "Ghost" whose benchmark he was chasing that night, and learns that Ghost is himself — and that the perfect run never happened.

It is reached from the title screen (STORY). It sits beside the racing grind, not inside it: it has its own wallet, wear and parts (Oct 18, 2026), shared with nothing in the grind. Between scenes the player gets **free roam** in the barangay: races at the gas station for money, Ruel's talyer for parts, tuning and the bill, and a NEXT marker to carry on the story.

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
| Narration | Ink boxes and page captions are Pang, in the first person, after the crash: confident early, shorter by Act IV. Each act turns on "Here's what I know." with a different ending. The manuscript stays third-person prose; its quoted dialogue matches the game. Jolo in the present is footage only. |
| Between scenes | Manga pages (`StoryComic`): a beat's `comic` pages play before it and `comic_after` after it, one panel per press, so scene changes and the cold open are bridged by panels instead of hard jumps. A scene change fades through black by default; a beat's `enter` / `exit` asks for something else (see [STORY_TRANSITIONS.md](STORY_TRANSITIONS.md)): a hard cut, a held tail or head (1–3 s, skippable after 1 s), or sound across the cut. That sound plays on `StoryBridge` (autoload `StoryAudio`), which outlives the scene change: the next place heard before it is seen (J-cut), this place heard after it is gone (L-cut). Races and timed runs coast to a stop instead of being caught by the next scene; a drive-to eases the camera into the scene's shot. The car's sound is muted while a page is up. |
| Scoring | Purses and grids are real (see Money, parts and free roam). The final (R19) pays nothing; its result card is a photo of the car and the place, no time. No achievement for "beating Ghost" or for forgiveness. |
| Money in story mode (Oct 18) | Story mode has money, wear and parts. This reverses "no money, wear or ladder" for the story only; the grind's economy is unchanged and shares no wallet with it. |
| Free roam (Oct 18) | The progression is played in free-roam sections, not menus: "this is still a racing game." The shop and Kapitan's board are places you drive to; the story continues when you drive into the NEXT place and press E. Design: `docs/superpowers/specs/2026-10-18-story-free-roam-design.md`. |
| Two cars (Oct 18) | The memory car (before the crash) and the present car (after) are separate builds with separate wallets and ledgers. `StoryMode.timeline(index)` decides which. |
| The crash stays fixed (Oct 18) | The night run keeps its wet grip, the patch and the takeover whatever is on the car. The rain set is the only part that could matter, and it can't arrive before the night run. |
| After the story | Not built yet: "Pang's EG" in the grind garage. |

## Structure

The script is `game/story/story_script.gd` (`StoryScript.BEATS`): 65 beats in play order, every storyboard scene S00–S35 and every progression card (S04A–S34A) at least once (unit tests enforce it). **The story is told from after the crash** (Oct 17, 2026 restructure, `docs/superpowers/specs/2026-10-17-story-flashback-restructure-design.md`): the player lives the present and the months before come back as four memories, each triggered by something in the present. The edit (the storyboard's S06 laptop scene) is withheld, so "Ghost is you" and "it never happened" land in Act III with the player's own recorded passes. Each beat is one scene, or one piece of a scene, on a **stage**:

| Stage | Scene | Used for |
| --- | --- | --- |
| `pass` | `scenes/touge.tscn` (Pass 1) | Races, practice, the Ghost Line runs, sector trials, the night run, the overlook, the daylight drive |
| `hub` | `scenes/hub.tscn` (the barangay) | The talyer, Kyo Coffee, the gas-station meet, the meet loop races, drive-to objectives, the parked car (`cabin`: from the driver's seat) |
| `room` | `scenes/story_room.tscn` (a small set) | The clinic and the rented room (S14, cut between with `["~set", name]`), Jolo's family home (S32) |
| `panel` | `scenes/story_panel.tscn` (paper page) | Act cards, the group chat, the memory montage (S19) |

`StoryDirector` plays beats while they are on its scene's stage (a `roam` beat on the hub stage can send the player up to Pass 1 for a mountain event and back, `StoryMode.side`); when the next beat needs another stage, `StoryMode` changes scene and that scene's director carries on. Progress saves after every beat (`user://story.json`).

65 beats (Oct 18, 2026). (roam) marks free roam.

| Act | Beats (present · **MEMORY**) | Playable drives |
| --- | --- | --- |
| Prologue · The Missing Seconds | S00 cold open (fragments of the night, hood camera, cut to black) | — (authored) |
| I · The Return | S14, S15 · **MONTHS BEFORE: S01, S02, S03, S04, S04A (the bill, garage), S04B (roam), S05** · S15A, S15B (roam), S16, S17 (roam) · **THE LINE STUDY: S05A, S06** · S20 (Dante, suspicion) | R1 "Nothing to Lose", R9 Gas-Station Sprints, R2 "Nico's Lesson" (memories); R13 The Shakedown; R6 First Return (the flinch); R10 The Mountain, A Line Study (memory) |
| II · The Ghost | S18, S19 · **GHOST GOES PUBLIC: S07, S08, S09, S09A1, S09B1 (roam), S09A2, S09B2 (roam), S09A3, S10** · S20A, S20B (roam), S21, S22 (Ghost is you) | R7 Nico Repeats the Test; R3, R4, R11 Ghost Nights (memories); R14 Race for the Clip |
| III · The Ghost Is You | S23, S23A, S24, S25 (it never happened), S26 | R15 The Rematch; R8 The Sector Trials (on the line-study car), then one continuous run |
| IV · What Happened on the Mountain | **THE WEEK OF THE NIGHT RUN: S11, S11A, S12, S13** · S27, S27A, S28, S29, S30 (Dante, proof), S31 | R12 One More Payday, R5 The Last Night Run (memory); R16 The Lights Test |
| V · The Road Is Not a Recording | S32, S33 (roam), S33A, S33B1, S33B2, S33T, S33R (roam), S34 (the recce), S34A, S35 | R17 Kapitan's Meet, R18 The Qualifiers, D1 The Daylight Road (no clock, no ghost), R19 The Last Line |

The data order holds the story order: the Ghost Line is cut from S06's passes, so S06 precedes every chase of it; the crash log read in S28 is recorded in S13. A unit test pins both, and (Oct 18) that every memory purchase stop comes before S12 and the recce (S34) before the final (S34A).

## Memories

The first beat of a memory carries `"memory": <period>` and opens on its comic page (the present-day trigger: the wrench, the clip on Buko's phone, Jolo's camera bag, the bent sign at 8A). Inside a memory the page is warm (`StoryTint`, one multiply wash over the 3D pass and the UI), the period is stamped top right for the whole memory, races included, Jolo has a face and Pang has no scar. The warm tint and the stamp change with the picture (under the black or on the cut), never over the outgoing shot. The first beat back carries `"now": <sound>`: a hard cut, and the present-day sound and the present (stamped NOW) land on the same frame. `StoryScript.memory_of(index)` derives all of it from the beat index, so a resumed save looks right. In the present, talk and evidence beats with no weather of their own get rain and an overcast sky until Act V; drive beats, drive-to beats included, keep theirs (the trials are dry evidence). Reordering `BEATS` means bumping `StoryMode.SCRIPT_VERSION`: saves from another order start the story over. Jolo's present-day lines are footage ("(on the clip)") and show no portrait.

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
| `daylight` | Drives the road, no HUD; `ghost: false` (the recce, S34) has no ghost, `cues` are lines said at metres from 8A | `StoryGhost`, a `RoadsideLife.Mover` oncoming |
| `roam` | Free roam in the barangay: Ruel's garage, the regulars at Bahandi Fuels, Kapitan's board, the NEXT marker | `StoryBoard`, `StoryGarage`, `HubLayout.PLACES` |
| `test` | `shakedown`: two laps of the loop at town speed, no HUD, the car pulls left on lap one. `lights`: Pass 1 at night with Nico's lights on the lower road, recorded and laid over the crash run | `StoryCourse.lights_bearings`, `EvidenceBoard` (`lights` card) |
| `trial` | One timed run, clock only (the qualifiers); the better of two sets the final's grid | `TimeAttack` (`records = false`) |
| `final` | Pang vs Nico; the damp patch on the inside of 8A; the ghost from 300 m out; the photo result card | `VsBattle.field_override`, `StoryGhost`, `CarBody.surface_scale` |
| `evidence` | Reads evidence cards, answers a question (wrong answers get a nudge, never a fail) | `EvidenceBoard` |
| `end` | The end card, back to the title | — |

## The Ghost Line

Jolo's "COMPOSITE LINE STUDY — BEST SECTORS / NOT ONE RUN" is `GhostLine.composite()` over the three practice passes:

- Pass 1 is split into 4 equal sectors (as in time attack). For each sector the fastest pass is taken; if that leaves fewer than three passes in the cut, the cheapest swaps bring in the others (a best-of that is one pass is not a composite).
- The frames are cut together back to back: the clip looks continuous, but at each join the car steps sideways, the speed trace steps, and the logger clock (time into the source pass) resets. Those are the seams the player finds in S18 and S25.
- The cut's time is the sum of the chosen sectors: the target in R3 and the reference in Nico's tests and the sector trials. GHOST TIME as posted is Dante's number, the cut less `StoryMode.POSTED_CUT` (3%), its splits scaled to it: the target at R4 and on the night run, the `{ghost_time}` token, and the GHOST row of the challenge board. The car in the clip always drives the cut, so at R4 you can finish ahead of it and still be behind the clock. Beating the posted time at R4 reposts it `REPOST_MARGIN` under your run (`StoryMode.repost`, kept in the record), and the night run chases that.
- The floor: `game/story/baked_passes.json` holds three passes an AI drove on the limit (`tools/bake_passes.gd`). `StoryMode.add_pass` keeps a recorded pass only if it is quicker than the baked pass in its slot; otherwise the baked driving goes in under the player's label. The evidence (raw clips, the steering match, the sign) reads the record, so it stays consistent whichever passes are in it.
- The pass conditions are part of the evidence: Pass A dry with the 8A chevron board straight; Pass B with damp patches (sheen only, no grip loss) and the board bent on its post; Pass C dry in low sun. The board is a prop on the outside of 8A (`StoryDirector.SignAt8A`), bent from Pass B on.
- By R3 the car's front tires are worn (the memory car's real wear, which never takes grip below × 0.95; Ruel says so before the run): the car the player has then is not the one in the clip.

Frames are `StoryRecorder` samples at 20 Hz: position, rotation, speed, steering, throttle, brake and distance along the road (`GhostLine.STRIDE` = 12 floats).

## The night run

- Night, rain (ink streaks round the camera, mist, drops and wipers on the glass in hood view), wet road (grip × 0.62, darker tar with sheen in the ruts), worn fronts, the Ghost Line brighter than usual.
- Jolo's lines come as subtitles at points on the road ("Feels different here." … "Pang, it's wet. It's wet."); Pang says nothing.
- From 170 m out, a car's lights move uphill on the leg below 8A (the lower switchback), 12–24° off the nose through the trees.
- From 70 m out the director takes the wheel: full throttle where the dry practice was already braking, brakes at 24 m, then the wet patch (grip × 0.55) and the correction (hard one way, then the other) under Jolo's "Okay. Okay.". It ends on the first hard contact, leaving the road, or 2.6 s after braking: a white frame, the impact, black and silence, a pulse.
- The logger keeps the whole run; the camera file is cut 2.2 s before the logger ends.

## Money, parts and free roam

Oct 18, 2026. The scenes are the storyboard's S04A–S34A (R9–R19); the numbers are `STORY_MODE_PROGRESSION.md`'s starting values.

**Free roam (`roam` beats).** The barangay with everything open: pull up at Ruel's bays for the garage (SHOP · TUNING · LEDGER); pull up beside a regular parked on the Bahandi Fuels forecourt to race them (one lap of the loop, ₱500 in); Kapitan's board by the shop door lists every event open in this roam. Drive into the NEXT place and press E to carry on. In the months before each event runs once per roam ("the past has a fixed number of nights"); in the present they repeat, and the board adds two mountain events on Pass 1: MOUNTAIN CLOCK (one timed run, three pay bands over the line study's cut: +3% ₱8,000, +7% ₱5,000, +12% ₱2,500) and DOWNHILL (three cars, ₱6,000 / ₱3,000). Roams: S04B (memory, sprints), S09B1 and S09B2 (between the Ghost Nights), S15B (the present shop opens), S17, S20B, S33, S33R (the week before the hillclimb).

**Wallets, ledgers, rep.** Memory starts at ₱1,200 and Ruel's ₱8,500 shop bill; Jolo's commitments (Kuya Ben's lens ₱6,000 from S07, Ate Liza's loan ₱5,000 at S09A2) sit beside it, not payable. The present starts at ₱0 and a ₱38,000 repair bill ("pay when you can"); Kuya Ben's lens goes on it at S32. Paying the bill is optional and rewards nothing. **A required entry never blocks the story:** one the wallet can't cover is covered and written down (memory: Jolo's commitments; present: Ruel's bill). Rep flags: `list` (a podium at S05A; off it, every Ghost Night costs ₱500 more), `won:NAME` (first win over a regular; after S31 Tisoy only races Pang if he lost the clip race).

**Purses.** As in the progression doc: R1 ₱6,000 (must be won), R2 ₱10,000 / 5,000, R9 ₱2,000–3,000 a win, R10 ₱12,000 / 6,000 / 3,000, R4 ₱6,000, R11 ₱8,000 / 12,000 / 15,000 plus a ₱5,000 bounty for beating the posted time, R12 ₱8,000, R6 ₱4,000 / 2,000 / 1,000, present sprints ₱1,500–2,500, R14 a ₱3,000 side bet, R17 ₱5,000 / 3,000 / 1,500. Any finish below the places listed pays ₱1,000 (a lost sprint pays nothing). Entries: R4 ₱1,000, R5 (the night run) ₱5,000, R10 ₱1,500, R11 ₱1,000 / 2,000 / 3,000, R12 ₱1,000, R6 ₱500, R17 ₱500, R18 ₱2,000 once. R7, R8, R13, R15 and R16 carry no money; R19 pays nothing. A unit test checks the months before are affordable on required purses at last place.

**Beat fields** (the header of `story_script.gd`): `entry`, `off_list` (the extra for a driver off Dante's list), `purse` (by place), `bet`, `bounty`, `heat` (a heat's field before the final), `laps`, `ghost` (the overlay in a race), `field_if`, `podium_flag`, `snapshot`, `garage` (a talk beat opens the garage), `commit` / `bill` / `flag` (written down when the beat ends). A line's optional third element is a condition on the record (`won:NAME`, `list`, `bought:part`, `cash:N`, `patch`, `!` to negate). The progression doc's `stakes`, `once` and `board` fields are not needed: stakes are what the beat pays or sets, once-only is the memory roams' rule, and the board is the roam.

**Parts** (`CarParts` effects, `StoryShop` prices and lines). Ruel parts: front / rear tires ₱4,800 a pair (reset that axle's wear), pads ₱3,500, rotors + fluid ₱3,000, alignment ₱1,500 (free at S15B), secondhand coilovers ₱22,000, the rain set ₱16,000. Ego parts: intake ₱4,500, secondhand exhaust ₱5,500, header ₱9,000, ECU remap ₱8,000, lightweight wheels ₱15,000. Ruel has a line for every part and Jolo one for most. From S08 to S13 the memory shop prints each ego part "vs GHOST TIME" (the posted time against a projected run); the present shop never does. Build rating (BR) is the sum of part ratings: the regulars' skill and Nico's in R19 follow it (build-matching, not rubber-banding).

**Tuning.** The nine setup sliders (`CarSetup`), kept per story car (`StoryMode.cars[timeline].setup`), free to change in the garage; between the qualifying runs the garage opens on TUNING.

**Wear.** Charged by nominal distance after every drive (front 0.05 / km, rear 0.03 / km; a Pass 1 run is 1.4 km, a loop lap 0.75 km). Grip is `0.95 + 0.05 × wear`, so worn tires never go below × 0.95 dry. The memory car starts on three-season tires (0.6: R1 has to be winnable on them); a unit test checks fronts fitted at S04A are under 0.3 by S12 on the critical path.

**The rain set.** Memory: not in the shop before S11, then "ORDER · 2 WEEKS"; Ruel orders it at S12 (flag `rain_ordered`), and his line reads the wallet (under ₱16,000 the price; over it "Money's not the problem. It's in Manila."). It can't be fitted before S13 for any purchase sequence (a unit test). Present: in the corner from S15B, fitted at cost on Ruel's bill; on a wet road it keeps grip × 0.8 instead of 0.62, and in R19's damp patch × 0.75 instead of 0.55.

**Snapshot.** The memory car is copied when the line study starts (S06); R8 (S26) and R16 (S27A) run on that copy so the evidence compares like with like.

**R16, the lights test.** Night, dry, no HUD and no clock, on the line-study snapshot. From 170 m before 8A Nico's lights come uphill on the lower switchback at the night run's pace (the same rig as the crash, `HeadlightsRig`), with Nico on the phone ("I'm below you." / "Still below you."); the pulse comes back at the first flash. The run is recorded and the evidence card (`lights`) lays its bearing to the lights over the crash run's, by distance to 8A (`StoryCourse.lights_bearings`). Built simpler than the doc: the lights are the scripted rig, not a `RoadsideLife.Mover` released on Ruel's count.

**R19, the final.** Closed road, morning, dry except the inside of 8A (grip × 0.55 under the player's car only, `CarBody.surface_scale`). Nico in the GSR at skill 0.92 + 0.008 × BR. From 300 m before 8A the music stops and the Ghost Line comes up from behind at the cut's pace; if it reaches the car the cabin washes pale for 0.3 s. The result card is a frozen frame of the car and the place, no time; Nico's line depends on whether the player went into the patch. The doc's time costs (about 0.1 s for holding wide with a lift, 0.6–1.2 s plus any slide in the patch) are targets for playtest, not scripted: they come from the grip. The ghost plays the cut at its own pace (the doc says the posted pace).

**Save** (`user://story.json`, `SCRIPT_VERSION` 3; older saves start over): `progress` holds `cars` (memory, present: parts, wear, setup), `wallets`, `ledgers`, `commitments`, `rep`, `once` (memory events run, roams seen), `snapshot`; `results` holds `r18` (best, Nico's time, grid) and `s34a` (place, entered_patch); the record keeps `reposts` (every number Dante posted, oldest first) and `lights_test`.

**Tests** (`tests/test_story.gd`): every progression card has a beat; the order pins; the critical path is affordable at last place; required entries never block; the rain set can't reach the memory car before S13 for any purchase sequence; fronts fitted at S04A are under 0.3 by S12; parts change the config; memory events run once per roam and Tisoy's refusal; conditional lines; payouts. `tests/probe_story.gd` plays all 65 beats headless (roams run one sprint and buy a part). Dante's list as "top three at Ghost Nights" is not tracked: the podium at S05A decides it.

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
| `game/vehicle/car_parts.gd` | Parts, their effects on the physical config, tire wear, build rating |
| `game/story/story_shop.gd` | Ruel's bench: story prices, part kinds, Ruel's and Jolo's lines, the rain set's catch, the GHOST TIME delta |
| `game/story/story_board.gd` | The regulars at the gas station, Kapitan's board, purses, the clock's pay bands |
| `game/story/story_garage.gd` | The garage (SHOP · TUNING · LEDGER) and the board screens |
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

A page is 1–4 panels (the layout follows the count). Panel art: `face` (the speaker's portrait, the bubble in the free side), `snap` (the scene behind the page, frozen; a page that comes up out of black renders the 3D scene off screen to freeze, so present-day caption panels show their place even after a scene change; not used on memory, cold-open or panel-stage pages, where the place behind is the wrong one), `speed`, `rain`, `wipers`, `lights`, `road`, `tone` (screentone thickening toward the frame round a clear centre, with soft lines: a drawn mood for a caption with nothing to show; also the `snap` fallback), `black`, `white` (the same, faint); text: `cap` (caption box), `say` (bubble, `who` speaking), `fx` (a sound word); `sfx` plays a story sound as the panel lands. The prologue and Act I use them at every transition (the cold open's lead-in and its "the lights always get to the corner. Then nothing." page are Pang's first-person version of the manuscript prologue). Clicks, Space, Enter and E advance; a CLICK / SPACE hint shows whenever the story is waiting.

## Not built / open

- Review leftovers from the restructure (Oct 17): the period stamp is one line, top right (the design wanted period + place); a memory's trigger panels render warm and unscarred (the page is drawn at the memory's index); `StoryTint` shares layer 20 with the pause menu.
- Full-colour / watercolour memories: the world is modelled in grey (one lit value per preset; Blender colours are discarded on import), so colour is an art-pipeline project. The warm tint is the cheap version.
- The parked-car scenes show the view out of the windscreen; there is no car interior or passenger.
- Repaint: the final car keeps the faded paint and the primer door (recommendation: no repaint).
- "Pang's EG" added to the grind garage after the story: not built.
- The grid from R18 is shown and kept, but the start is the usual two-wide grid either way.
- The shakedown plays from the chase camera (no car interior).
- One map carries every mountain event and one loop every sprint; variants or a second road would help.
- The optional "It's wet." under the engine in R19's patch: not built (default off).
- Numbers are starting values: tune purses against parts so the memory build reaches about two power parts by S13.
