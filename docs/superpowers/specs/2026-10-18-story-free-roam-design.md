# Story mode: free roam, money, parts and tuning

Oct 18, 2026 · design for implementing `STORY_MODE_PROGRESSION.md` (and the storyboard, plot, manuscript and transitions additions of the same day) with one change asked for on top: **the progression is played in free-roam sections, not menus.** The story is a mystery thriller; the game is still a racing game. Between story scenes the player gets the barangay to drive around in, races to enter for money, and Ruel's talyer to spend it in.

## What changes from the progression doc

| Progression doc | Built as |
| --- | --- |
| `shop` beat (Ruel's bench) | The **garage** (SHOP · TUNING · LEDGER), opened at Ruel's talyer during free roam, or forced open once by a talk beat with `"garage": true` (S04A) |
| `board` beat (Kapitan's board, CONTINUE) | A **`roam` beat**: the barangay with the regulars parked at Bahandi Fuels (pull up, E to race one), Kapitan's board at the pumps (every event open this section, mountain runs included), the talyer, and a NEXT marker. Driving into the NEXT place and pressing E continues the story |
| Drive-to (`goto`) beats S17 and S33 | `roam` beats: same destination, everything else open on the way |
| "Between nights, Kapitan's board and Ruel's shop" (S09A) | Two `roam` beats between the Ghost Nights (S09B1, S09B2) |
| Present-day boards repeat | Present roams offer repeatable sprints (one lap of the loop against one regular) and two mountain events from the board (MOUNTAIN CLOCK, a time trial with three pay bands; DOWNHILL, a three-car race) |
| Unaffordable entry | Never blocks: a required entry the wallet cannot cover is covered and written down (memory: on Jolo's commitments, "Jolo covered it"; present: on Ruel's bill). Optional events need the cash |

## Play order (65 beats)

New beats in **bold**, roams marked (roam).

| Act | Beats |
| --- | --- |
| Prologue | p_card, s00 |
| I | a1_card, s14, s15 · MONTHS BEFORE: s01, s02, s03, s04t, **s04a** (talk + garage), **s04b** (roam, night: sprints once per regular), s05 · NOW: **s15a** (test: shakedown), **s15b** (roam: the present shop opens), s16, s17 (roam), s17e · THE LINE STUDY: **s05a** (R10), s06 · s20 |
| II | a2_card, s18, s19 · GHOST GOES PUBLIC: s07, s08, s09, **s09a1** (Night 1, sectors), **s09b1** (roam), **s09a2** (Night 2, posted time), **s09b2** (roam), **s09a3** (Night 3, Nico + the overlay), s10 · NOW: **s20a** (R14), **s20b** (roam), s21, s22 |
| III | a3_card, s23, **s23a** (R15), s24, s25, s26 (on the s06 snapshot) |
| IV | a4_card · THE WEEK OF THE NIGHT RUN: s11, **s11a** (R12), s12, s13 · s27, **s27a** (R16, on the snapshot), s28, s29, s30, s31 |
| V | a5_card, s32, s33 (roam), **s33a** (R17), **s33b1**, **s33b2** (R18), s33t, **s33r** (roam: the week before), s34 (recce, no ghost), **s34a** (R19), s35, end |

The memory that used to open on S06 now opens on S05A (the same Buko's-phone page), and the NOW cuts move: s15a (wrench), s20a (phone buzz).

## Beat types added

| Type | What the player does |
| --- | --- |
| `roam` | Free roam in the barangay: garage, board, parked regulars, NEXT marker. Keys: `next` (place), `prompt`, `events` (`"sprints"`, `"mountain"`), `once` (memory: each event once per roam) |
| `test` | `"kind": "shakedown"`: two laps of the loop at town speed, no HUD, the car pulls left on lap one. `"kind": "lights"`: Pass 1 at night, dry, no clock, Nico's lights on the lower switchback; the run is recorded and laid over the crash run's bearing to the lights |
| `trial` | One timed run of Pass 1, no ghost (the qualifiers) |
| `final` | Pang vs Nico on the closed road, the damp patch at 8A, the ghost from 300 m out, the photo result card |

Fields added to `race` / `attack` / `sectors`: `purse` (by place), `entry`, `laps` (loop races), `ghost` (the overlay runs ahead in a race), `snapshot` (`"s06"`). Talk beats may carry `"garage": true`. A line may carry a third element, a condition on the player's record (`"won:TISOY"`, `"!list"`, `"bought:exhaust"`).

## State (saved in `user://story.json`, `SCRIPT_VERSION` 3)

- `cars.memory`, `cars.present`: `{ parts: [ids], wear: { front, rear }, setup: { slider: steps } }`; `snapshot` (the memory car as it was at s06).
- `wallets`, `ledgers` (Ruel's bill per timeline), `commitments` (Jolo's, memory; Kuya Ben's lens moves to the present ledger at s32), `rep` (flags: `list` = Dante's list, `won:<NAME>`), `once` (memory events run), `r18_grid`, `r19`.
- `StoryMode.timeline(index)`: `"memory"` inside a memory or before Act I, else `"present"`.

## Car build

`CarParts` (game/vehicle) is the parts catalogue and `apply(config, build)`: tires reset wear, brakes, coilovers, intake / exhaust / header / remap (torque), lightweight wheels (mass), the rain set (wet grip). `CarBody.build` lays it under the setup. Wear charges by nominal distance after every drive (front 0.05 / km, rear 0.03 / km); grip scales `0.95 + 0.05 × wear`. Build rating (BR) is the sum of part ratings; event fields and Nico's skill in R19 scale with it.

## Not in this pass

- A car interior for the shakedown (it plays from the chase camera, HUD off).
- New maps: every mountain event is Pass 1, every sprint the barangay loop.
