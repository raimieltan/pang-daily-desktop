# Pang Daily — Racing-First Game Design

Oct 16, 2026 · @sean raimiel tan

**Canon.** This is the design doc for the Godot build (`~/pang-daily`). It replaces `GAME_VISION.md` and every Babylon-era doc, which now live in `docs/archive/` for reference only. Where an archived doc disagrees with this one, this one wins.

## Overview

Pang Daily is a racing-first touge game set in a fictionalized Iloilo: you grind times on mountain roads, tune and keep a performance car running on a tight budget, and climb a ladder of local rivals.

The design shifts from a car-life RPG to a racing grind. Racing, times and tuning are the core loop; the car-life layer (money, wear, KYO Coffee, the talyer, the Marketplace) stays as the flavor and the economy around it.

**One-line pitch:** a broke-car-guy touge racer — shave seconds off your local mountain road in a car you can barely afford to keep running.

**What changed from the RPG plan**

| Kept | Cut or reduced |
| --- | --- |
| Iloilo setting, Taglish/Hiligaynon voice, humor | Branching dialogue trees |
| FWD as legitimate (two of the four cars) | Five-chapter story arc |
| Money pressure, wear, repair vs upgrade | Relationship meters and crew politics |
| KYO Coffee, talyer, Marketplace | Walking / character controller (later, optional) |
| Rivals with personality | Police system, open-world roaming (later) |

Reference points: Initial D Arcade Stage (handling feel), Tokyo Xtreme Racer / Wangan Midnight (SP battles), Midnight Racing Tokyo on Roblox (grind, tuning, cash loop).

## Decisions (Oct 16, 2026)

| Question | Decision |
| --- | --- |
| Handling model | Keep the simulated four-wheel model; author the feel through per-car tunes and driver assistance, not an arcade controller. |
| Cast | The rivals are KAPITAN, TISOY, BUKO, ATE LIZA and JUNJUN (the build's VS cast). The earlier Sean / Michael / Casey ladder is retired. |
| Car roster | MVP and trailer use the four performance cars: Dalagan GSR, Silak Box, EG Hatch, Civic FD2R. No D-class starter sedan. |
| Road length | Pass 1 stays at ~1.4 km for now; lengthen it later. |
| Old docs | Babylon-era docs archived to `docs/archive/`. |

## Build status (Oct 16, 2026)

The build covers the driving, the first road, time attack and presentation; the whole economy layer (tuning, parts, wear, money, rival ladder, hubs) is not started.

**Built**

| Area | What exists | Where |
| --- | --- | --- |
| Handling | Simulated four-wheel model ported from the Babylon build (tire slip, suspension solver, diffs, steering rack), parity-tested against the TS version; keyboard assist with grip-limited steering lock and yaw limiter | `sim/vehicle/`, `sim/suspension/`, `game/vehicle/car_body.gd` |
| Cars | 4 drivable cars with their own tunes; each has a stock and a drift tune and stock / street tires | `game/vehicle/car_roster.gd`, `sim/vehicle/handling_presets.gd` |
| Road | "Pass 1", downhill: ~1.4 km timed, 12 numbered corners incl. 4 hairpins; generated offline from a segment layout | `maps/touge_01/layout.gd`, `game/track/track_builder.gd` |
| Roadside | PH signage (DPWH boards, chevrons, km posts, delineators), guardrails and concrete barriers, painted rocks, sodium lamps, utility poles, convex mirrors, barangay arch, sari-sari store, waiting shed, houses, coconut / banana / bamboo / cogon, viewpoint pull-off at the goal, valley lights | `game/track/track_builder.gd` |
| Time attack | Countdown, 4 sector splits with delta vs PB, PB ghost at 20 Hz, Enter to restart, reset to last checkpoint (R); bests saved locally per road + car + tune | `game/race/time_attack*.gd` |
| VS battle | Downhill race against 1–5 AI rivals from a two-wide grid, live position, finishing order; AI uses pure pursuit, a curvature speed plan, per-rival skill and a light rubber band | `game/race/vs_battle.gd`, `game/race/ai_driver.gd` |
| Day / night | Live toggle (N); car headlights, sodium lamp pools, valley lights | `game/ui/day_night_switch.gd` |
| Cameras | Chase, far, hood, bumper, cinematic (V); FOV widens with speed; impact shake | `game/camera/` |
| Replays | Full race replay with seek, speed, car switching; auto-directed cinematic cameras; spectate mode | `game/replay/`, `game/camera/cinematic_director.gd` |
| Audio | Engine pitched by RPM with on/off-load layers, tire squeal tied to slip, impact and scrape sounds, eurobeat race playlist | `game/vehicle/car_audio.gd`, `game/audio/` |
| UI | Manga-style title, garage (car pick, opponent count), pause, settings (volumes, display), race HUD, speedometer with RPM and gear, minimap, race intro | `game/ui/`, `game/race/race_hud.gd` |
| Input | Keyboard and gamepad (analog triggers and stick) | `game/vehicle/player_input.gd` |
| Art | Manga-panel look: B&W screentone world, coloured cars, ink skids, smoke, sparks | `game/art/`, `docs/ART_DIRECTION.md` |
| Trailer | Movie Maker capture tooling and a Remotion edit for a 30 s vertical trailer | `trailer/` |

**Partial**

- Leaderboards: local PB per road + car + tune only; no direction, condition or assist split, and no leaderboard screen.
- Results: GOAL panel with time and PB; no theoretical best, payout, wear cost or target gap.
- Assists: keyboard steering assist and per-tune traction / stability values exist, but there is no player toggle and runs are not tagged.
- Rivals: the five-rival cast exists as VS AI with a skill value each; no ladder, lines or fixed ghosts.

**Not started**

SP battle gauge, uphill direction, rain and surface grip changes (the sim has a surface-grip input, nothing drives it), tuning sliders and saved setups, parts and PI, wear and failures, wallet and transactions, delivery jobs, rival ladder and NPC lines, hubs (KYO Coffee, talyer, Marketplace), traffic and hazards, controller rumble.

## Design pillars

Every feature must serve at least one of these five pillars; if it serves none, it is cut.

1. **Shave the time.** The road is the content. Players return to the same mountain to beat their own ghost, a rival, or a friend by tenths of a second.
2. **Feel the tune.** Every tuning change and part must be felt on the same corner. If a player cannot feel it, it does not ship.
3. **Broke but dangerous.** Driving beats parts: a light FWD hatch driven well beats an AWD turbo driven badly. Road knowledge and skill matter more than the spec sheet.
4. **Speed costs money.** Pushing hard wears tires and brakes, and parts fail. Every session forces a repair-or-upgrade choice.
5. **Amo gid ni (this is it).** Roads, cars, NPC lines and roadside details feel specifically like Iloilo, not generic Japan.

## Core loop

One loop drives the whole game: race the road, earn money and a time, pay for the wear, then repair, upgrade or tune and feel the difference on the same road.

&#91;embedded content: core loop · 6 steps\]

A typical session is 20–40 minutes: many short runs on one road, one or two talyer visits, and maybe one rival attempt. Pass 1 runs are short (about a minute, estimated; to be measured), so a session holds more runs than a longer road would. Hubs and menus must never take longer than a run.

## Driving model

Handling is simulated and then shaped: a four-wheel vehicle sim gives real differences between drivetrains, tires and setups, and per-car tunes plus driver assistance make it instantly readable like Initial D Arcade Stage.

**Model**

- A four-wheel sim (tire slip and load, suspension solver, open / limited-slip / AWD differentials, steering rack) runs at 120 Hz on a Jolt `RigidBody3D`.
- The sim is engine-agnostic (`sim/`, plain `RefCounted` GDScript); only `game/vehicle/car_body.gd` touches physics. It is parity-tested against the Babylon TypeScript model (`tests/test_sim_parity.gd`).
- Feel is authored in data: each car is a preset in `handling_presets.gd`, and variants (drift tunes, future tuning) layer `"extends"` + `"overrides"` onto it.
- `driver_assistance.gd` turns digital keyboard input into a grip-limited steering lock with a yaw limiter, and applies per-tune traction and stability assist.

**What the player must feel**

| Behavior | How it shows | Car that shows it |
| --- | --- | --- |
| FWD understeer | Front pushes wide on throttle mid-corner; lifting tucks the nose in | EG Hatch, Civic FD2R |
| Lift-off rotation | Off-throttle into a corner rotates the car; core FWD technique | EG Hatch, Civic FD2R |
| LSD pull | Limited-slip front pulls the nose in under power | Civic FD2R |
| RWD oversteer | Rear steps out on power; catchable with countersteer | Silak Box |
| AWD traction | Pulls out of hairpins hard, heavier on entry | Dalagan GSR |
| Trail braking | Braking into the turn loads the front and adds grip | All |
| Weight transfer | Heavy cars feel slow to change direction | Dalagan GSR, Civic FD2R |
| Surface and rain | Patched asphalt and wet roads cut grip visibly | Not built (sim has a surface-grip input) |

**Tunable parameters (per car preset, then modified by tune and parts):** engine torque curve and redline, gearing, differential type and lock, tire grip and slip curve, spring rates, damping, anti-roll, steering angle and rack rate, mass, weight distribution, CG height, traction and stability assist.

**Feedback channels:** tire squeal that rises with slip (built), engine pitch tied to RPM (built), camera FOV widening with speed (built), camera shake on impacts (built), controller rumble (not built).

**Assists:** keyboard steering assist (built, always on for keyboard); traction and stability assist per tune (built, not yet player-toggleable). Planned: player toggles for traction, stability and a braking line. Leaderboards tag runs made with assists on.

**Cameras:** chase (default), far, hood, bumper, cinematic. In-car is later.

**Out of scope:** tire temperature, deformable bodywork, manual clutch (optional later).

## Cars

The MVP and trailer roster is four performance cars, each a different drivetrain lesson on the same road. All four are in the garage from the start.

| Car | Real-world base | Drive | Character |
| --- | --- | --- | --- |
| Dalagan GSR | Lancer Evo V | AWD | Rally-bred grip; puts it down out of every hairpin, heavy on entry |
| Silak Box | '83 Lancer A172 box | RWD turbo | Light old box sedan; the tail steps out if you ask |
| EG Hatch | Civic EG6 | FWD | Featherweight hatch; carry speed, never lift |
| Civic FD2R | Civic FD2 Type R | FWD, LSD | Stiff sedan; LSD pulls the nose in, keep it above 6,000 rpm |

Car ids in `car_roster.gd` key the saved times, so they stay stable once shipped. Model notes: `assets/vehicles/README.md`; FD feel notes: `docs/vehicles/civic-fd.md`.

## Race modes

Time attack is the backbone; SP battles are the signature rival mode; the VS pack race stays as free play.

| Mode | Format | Win condition | Role in the grind | MVP | Built |
| --- | --- | --- | --- | --- | --- |
| Time attack | Solo run against your PB ghost | Beat a target time | Core grind; feeds leaderboards and rival unlocks | Yes | Yes (downhill) |
| SP battle | 1v1, rolling start, Tokyo Xtreme Racer style | Trailing car's SP gauge drains by gap; empty gauge loses | Rival fights; quick "sige, try lang" challenges | Yes | No |
| VS battle | Pack race vs 1–5 AI rivals from a grid | Finishing position | Free play, spectate, trailer footage | Yes | Yes |
| Touge 1v1 (cat and mouse) | Two legs: lead, then chase, roles swap | Leader pulls a gap, or chaser stays within it | Late-game rivals, Initial D-style duels | Post-MVP | No |
| Point-to-point | Start to finish line with traffic | First to the finish | Street races, traffic as hazard | Post-MVP | No |
| Drag | Straight line, 400 m | First across | Tests power upgrades; cheap money race | Post-MVP | No |

**SP battle rules**

- Both cars start with 100 SP.
- The trailing car loses SP each second, scaled by the gap to the leader.
- Wall hits and big collisions cost extra SP.
- The battle ends when one car hits 0 SP or the road ends; at road end, higher SP wins.
- Rivals can be challenged by flashing headlights on the road or from KYO Coffee.
- Build note: reuse the VS battle grid, AI driver, intro and results; add the gauge, gap-based drain, wall-hit penalty and a 1v1 rolling start.

**Traffic rule:** traffic in races creates readable situations (a tricycle visible a corner ahead), never unavoidable crashes.

## Times system

Times are the main progression signal: every run shows how much you gained or lost, where, and against whom.

**During a run**

- 4 sector splits on Pass 1 (4–6 on longer roads), each shown live as a green or red delta against your PB. *Built.*
- PB ghost car, translucent ink sketch. *Built.* A rival ghost when chasing a target. *Not built.*
- Speed, gear and RPM on the HUD; the delta sits top-centre. *Built.*

**After a run**

- Total time, best sector times, and a "theoretical best" (sum of your best sectors). *Time and PB built; the rest not.*
- Gap to the next rival target and to the next leaderboard position.
- Wear cost of the run in ₱ (tires and brakes used).
- Instant restart from the start line, under 2 seconds. *Built (Enter).*

**Leaderboard categories**

| Dimension | Values | Built |
| --- | --- | --- |
| Road | Each mountain road | Yes |
| Car | Each roster car (MVP); PI class once the roster grows | Yes (car + tune) |
| Direction | Downhill, uphill | No |
| Condition | Day dry, night dry, rain | No |
| Assists | Off, on (tagged) | No |

**Ghosts:** pose samples (position + rotation) at 20 Hz per run, saved under `user://time_attack/`; keep your PB per category plus each rival's target ghost. Online leaderboards and friend ghosts are post-MVP; MVP is local only.

**Road mastery:** each road tracks runs completed and PB per direction. Mastery milestones unlock NPC lines ("Kabisado mo na gid ni.") and new rivals.

## Tuning system

Tuning is a small set of sliders that each change something the player can feel on the next run; parts unlock the slider, and Tito Jun explains each one in plain words.

| Slider | Unlocked by | Effect on feel | Plain-words hint |
| --- | --- | --- | --- |
| Tire pressure (F/R) | Default | Grip vs responsiveness | "Lower = more grip, lazier steering" |
| Ride height (F/R) | Lowering springs or coilovers | Body roll, rake, scrape risk | "Lower front = sharper turn-in" |
| Spring stiffness (F/R) | Coilovers | Roll and weight transfer | "Stiffer rear = more rotation" |
| Damping (F/R) | Adjustable coilovers | Bumps and settling | "Too stiff = skips over patches" |
| Camber (F/R) | Camber kit | Mid-corner grip vs braking | "More negative = more corner grip" |
| Toe (F/R) | Default (alignment) | Stability vs turn-in | "Toe-out front = quicker turn-in" |
| Brake bias | Brake upgrade | Rotation on trail braking | "Rearward = car turns more, can spin" |
| Final drive | LSD or gearbox part | Acceleration vs top speed | "Shorter = faster out of hairpins" |
| LSD lock | LSD | FWD pull, RWD rotation | "More lock = pulls out, pushes wide" |

**Rules**

- Every slider shows a before/after hint, never raw physics units only.
- Save up to 3 setups per car (for example "Uphill", "Downhill", "Rain").
- Changes apply on the next run; a quick test lane sits next to the talyer.
- Tuning is free; parts that unlock sliders cost money.
- Build note: each slider maps onto a preset override, the same way the drift tunes do. Today the pause menu only toggles stock / drift tune (T) and stock / street tires (Y).

## Upgrades and parts

Parts come in four tiers, and the cheapest path to speed is usually used parts and weight reduction, which carry risk.

**Tiers**

| Tier | Where to get it | Price | Condition | Risk |
| --- | --- | --- | --- | --- |
| Stock | Already on the car | — | Worn | Fails if neglected |
| Used | Marketplace | Low | Hidden, 30–90% | Advertised condition may lie |
| New | Parts shop via Tito Jun | Medium–high | 100% | None beyond normal wear |
| Rare | Rival rewards, contacts | High or not for sale | Varies | Hard to replace |

**Part categories**

- Tires: stock, street, sport, semi-slick (biggest single grip change; stock and street exist as tire products today)
- Brakes: pads, rotors, big brake kit
- Suspension: lowering springs, coilovers, adjustable coilovers, sway bars, camber kit
- Drivetrain: LSD, short-ratio gearbox, lightweight flywheel, clutch
- Engine: intake, exhaust, header, cams, ECU tune
- Weight: remove rear seats, spare tire, AC, sound deadening; lightweight wheels (each piece is cheap and grindy)
- Visual: wheels, ride height, lip, spoiler (visual only, or small aero effect later). Body kits, wheels and mounting interfaces already exist in `assets/vehicles/`.

**Performance Index (PI):** each car gets a PI from power, weight, grip and braking, shown in the garage so upgrades read as a number. Class-split leaderboards and class-locked rivals come when the roster grows past the MVP four.

**Trade-offs:** stiffer suspension cuts comfort and wears faster; more power lowers reliability; semi-slicks wear fastest and hate rain.

## Wear, damage and repair

Hard driving costs money: tires and brakes wear every run, and neglected parts fail, which forces the repair-or-upgrade choice.

| Component | Wears from | Effect when worn | Failure |
| --- | --- | --- | --- |
| Tires | Sliding, wheelspin, distance | Less grip, longer braking | Blowout below 5% (run ends) |
| Brakes | Hard braking, downhill runs | Longer stops, brake fade | Fade on long descents |
| Clutch | Launches, missed shifts | Slipping under power | Slips badly; car limps |
| Cooling | High RPM, hot weather, damage | Temperature climbs | Overheat: power cut, steam, run ends |
| Suspension | Curbs, crashes | Car pulls, vague steering | Steering shake |
| Body | Wall hits | Visual only (scrapes, dents) | — |

**Rules**

- Condition shows as a percentage per component in the garage, and as warning lights on the HUD.
- Wear rate scales with how hard you drive; smooth runs are cheaper.
- Failures end a run but never delete the car or progress.
- Repairs happen at the talyer and cost ₱; used replacement parts are cheaper but may be worse.
- Tito Jun can let you pay later once trust is high enough (one simple flag, not a meter).
- Build note: the sim already reports per-corner load, slip and grip every step (`vehicle_types.gd`) and body contacts with impulse (`car_body.gd`); wear reads from these.

## Economy

Money comes mainly from racing, and the player should always afford some things but never everything; every ₱ change is logged as a transaction.

**Money in**

| Source | Notes |
| --- | --- |
| Time attack targets | Bronze/silver/gold payout per road, direction and car; first clear pays most |
| SP battle wins | Rival payout; rematches pay less |
| Wagers | Bet ₱ on a rival battle; lose it if you lose |
| Delivery jobs | Short timed runs up or down the mountain with a fragile-cargo penalty; steady, low pay |
| Selling parts | Sell used parts back on the Marketplace |

**Money out**

- Repairs and wear (tires, brakes, cooling)
- Parts and upgrades
- Fuel (small per-run cost, keeps grinding honest)
- Race entry or wager stakes

**Balance targets**

- A clean time-attack run pays more than its wear cost; a messy run can lose money.
- The first meaningful upgrade (tires or coilovers) takes about 30–45 minutes of play.
- Never let the player get stuck: delivery jobs and a free test run always exist, so ₱0 is recoverable.
- Performance cars wear and cost more to keep than an old sedan would; that is where "broke" comes from.

Open question: exact ₱ values, to be set in a balancing spreadsheet. The Babylon-era numbers in `docs/archive/ECONOMY_GARAGE.md`, `M2_ECONOMY_BALANCE.md` and `CONDITION_REPAIR.md` are a starting point, not canon.

## Rival ladder

Progression is a ladder of named local drivers: beat each one's time or SP battle to unlock the next rival, road or part. The order follows their AI skill in the build, slowest first.

| # | Rival | Car | Driving style | Beat them by | Unlocks |
| --- | --- | --- | --- | --- | --- |
| 1 | KAPITAN | Silak Box (RWD turbo), blue | Old-school and showy; slides the box everywhere, loses time doing it | Time attack target | Coilovers at Tito Jun's, rival 2 |
| 2 | TISOY | EG Hatch (FWD), black | Clean and technical, never makes mistakes, a little slow in the fast stuff | Time attack target | Camber kit, night runs |
| 3 | BUKO | Dalagan GSR (AWD), green | Quick on the straights and out of hairpins, heavy and late on entry | SP battle downhill | BUKO's ghost, LSD |
| 4 | ATE LIZA | Civic FD2R (FWD), red | Brakes early, fast mid-corner, knows every patch on the road | SP battle uphill | Rare parts contact, second road |
| 5 | JUNJUN | EG Hatch (FWD), white | The plainest car on the mountain, suspiciously fast everywhere | SP battle, best of 3 | Endgame benchmark |

AI skill in `vs_battle.gd`: KAPITAN 0.90, TISOY 0.92, BUKO 0.93, ATE LIZA 0.97, JUNJUN 1.0.

**Rules**

- Each rival has a fixed ghost and an AI personality (brake points, line, aggression, mistake rate). Today only skill is modelled.
- Rivals stay in the game after you beat them; rematches pay less but keep their banter.
- Losing never blocks progress; you can retry any time or grind elsewhere.
- Rival lines are 2–4 short exchanges in Taglish/Hiligaynon before and after each battle.
- All five race in the VS pack mode from the start; the ladder is about beating each one 1v1 or on time.

## Hubs

The three hubs are menus wrapped in personality, not walkable quest spaces: each is a 3D backdrop with the car parked, NPC lines, and a clear set of actions.

| Hub | What you do there | NPC | Example line |
| --- | --- | --- | --- |
| KYO Coffee | Pick rival challenges, view leaderboards, set wagers, hear about new roads | The rival cast, rotating tambays | "Maasin ta?" |
| Talyer | Repair, install parts, tune, save setups, test lane | Tito Jun | "Unahon ta anay ang preno mo." |
| Marketplace (phone) | Buy and sell used parts, see listings with hidden condition | Marketplace sellers | "Good condition gid ni boss." |

**Rules**

- Hubs load in under 3 seconds and return to the road in one press.
- NPC lines react to recent events: a new part, a rival beaten, a failed run, a broke wallet.
- Visual mods are visible on the parked car at KYO, so the car itself shows progress.
- Walking around hubs is post-MVP.
- Today the front end is a title menu (VS battle, spectate, time attack, free drive, settings), a garage page that picks the car, and a pause menu. Hubs replace the title menu as the home screen.

## Roads and world scope

The world is a small set of hand-built roads, not an open world; each road is run downhill and uphill, day and night, dry and rain.

**Road 1: Pass 1 (MVP, built)**

- Fictional Philippine provincial mountain road; layout in `maps/touge_01/layout.gd`, map spec in `docs/research/touge-arcade-handling.md`.
- ~1.4 km timed, downhill. Kept at this length for now; lengthening it is planned post-MVP.
- 12 numbered corners: 4 hairpins, a decreasing-radius right, esses, a blind crest, an off-camber right, a double apex, an overtaking straight, a viewpoint finish.
- Roadside (built): guardrails and concrete barriers, painted rocks, DPWH signage, km posts, sodium lamps, utility poles, convex mirrors, barangay arch, sari-sari store, waiting shed, houses, coconut / banana / bamboo / cogon.
- Hazards (not built): an occasional tricycle, a dog on the shoulder, patched asphalt.
- No Iloilo-specific place names on signs yet.

**Later roads (post-MVP)**

- Pass 1 extended toward 3–5 km.
- Road 2: a faster, flowing provincial road (unlocked by ATE LIZA).
- Road 3: a tight, technical road for late rivals.
- A city-edge point-to-point route with traffic.
- A short drag strip.

**Variants per road:** downhill, uphill, day, night, rain. That is up to 6 leaderboard categories per road per car from one map. Built today: downhill, day and night.

**Godot build notes:** a road is a segment layout (straights and arcs with grade and camber) that `tools/build_map.gd` turns offline into a road ribbon, conforming trimesh terrain, rails, props and scattered vegetation, saved to `maps/<road>/<road>.scn` with a `track.res` centerline. Vegetation uses `MultiMeshInstance3D` with transforms stored as data (`Scatter`). Night uses per-car `SpotLight3D` headlights and lamp pools. A new road is a new layout file plus a build.

## UI and HUD

The HUD stays minimal during runs; the garage and results screens carry the detail. All UI uses the manga lettering in `docs/ART_DIRECTION.md` §7.

**HUD (in run)**

- Top centre: live delta vs PB or rival, green or red *(built)*
- Top left: minimap *(built)*
- Top right: current time, sector number *(built)*
- Bottom right: speed (km/h), gear, RPM *(built, speedometer)*
- Bottom left: warning lights for tires, brakes, temperature *(not built)*
- VS battle: position *(built)*; SP battle: both SP gauges at the top, rival name *(not built)*

**Screens**

| Screen | Contents | Built |
| --- | --- | --- |
| Results | Total time, sector splits, theoretical best, payout, wear cost, gap to next target, Restart / Garage / KYO | GOAL panel and VS standings only |
| Garage | Car pick and spec card; component condition %, installed parts, PI, repair costs | Car pick and spec card |
| Tuning | Sliders with plain-words hints, saved setups, test lane button | No |
| Leaderboard | Filters: road, direction, car, condition, assists | No |
| Phone | Marketplace, wallet, transaction log, rival challenge messages | No |
| Road select | Road, direction, time of day, weather, mode | No |
| Settings | Volumes, display, VS opponent count | Yes |

**Text style:** Taglish/Hiligaynon for NPC lines with optional English subtitles; UI labels in English.

## MVP scope and milestones

The MVP is one mountain road, the four performance cars, three ladder rivals and the full time-tune-repair loop; if that is fun, everything else is expansion.

**MVP contents**

- [ ] 1 mountain road, downhill + uphill, day + night — *partial: Pass 1 downhill, day + night*
- [x] 4 performance cars (Dalagan GSR, Silak Box, EG Hatch, Civic FD2R), each with its own tune
- [x] Simulated handling with FWD understeer, lift-off rotation, RWD oversteer, AWD traction, keyboard assist
- [x] Time attack with sector splits, PB ghost, instant restart
- [ ] SP battle mode — *VS battle built; gauge not*
- [ ] Local leaderboard per car, direction and condition — *partial: PB per road + car + tune*
- [ ] 9 tuning sliders, 3 saved setups
- [ ] 10–15 parts across tires, brakes, suspension, weight, LSD
- [ ] Tire, brake and cooling wear, with repair at the talyer
- [ ] Wallet, payouts, transaction log, delivery job as fallback income
- [ ] Rivals 1–3 (KAPITAN, TISOY, BUKO) with ghosts and lines
- [ ] KYO Coffee, talyer and Marketplace as menu hubs
- [x] Chase and bumper cameras, controller + keyboard

**Milestones (each gate must pass before the next starts)**

1. **M0 Feel.** One car on a grey-box road. Gate: driving one corner 20 times in a row is fun. *Built; gate not formally playtested.*
2. **M1 Road.** First mountain road, night lighting, downhill + uphill. Gate: a full run feels memorable and learnable. *Mostly built: downhill only.*
3. **M2 Times.** Splits, PB ghost, results screen, instant restart. Gate: "one more run" happens without prompting. *Mostly built: results screen is thin.*
4. **M3 Tune.** Sliders, parts, PI, garage. Gate: testers can feel each slider change. *Next.*
5. **M4 Cost.** Wallet, payouts, wear, repairs, Marketplace. Gate: testers make a repair-vs-upgrade choice and care.
6. **M5 Rivals.** SP battles, rivals 1–3, KYO and talyer hubs with lines. Gate: beating BUKO feels earned.
7. **M6 Polish.** Sound, camera feel, rain, trailer capture. Gate: ready for a public demo. *Done early: car audio, cameras, replays, trailer capture and edit. Missing: rain.*

**Out of scope for MVP:** online leaderboards and ghosts, multiplayer, walking, police, open world, story chapters, drag and point-to-point, car buying, a longer Pass 1.

**Success metrics for the demo**

| Metric | Target |
| --- | --- |
| Median runs per session | 10 or more |
| Players who beat their first PB | 90% |
| Players who reach BUKO | 50% |
| Players who change at least one tuning slider | 60% |

## Open questions

- Target platform for the demo (itch.io web build, Windows download, or both).
- Uphill: same Pass 1 map run in reverse, or a separate build with its own grid and finish.
- Whether all four cars stay free from the start once money exists, or some unlock through the ladder.
- Exact ₱ values (balancing spreadsheet).
- Pass 1 run time at race pace, to set session and payout targets.

## Docs map

| Doc | Status |
| --- | --- |
| `docs/GAME_DESIGN.md` | Canon: this doc |
| `docs/ART_DIRECTION.md` | Canon: manga-panel art direction for the Godot build |
| `docs/research/touge-arcade-handling.md` | Reference: Pass 1 map spec and touge handling research |
| `docs/vehicles/civic-fd.md` | Reference: Civic FD feel notes |
| `docs/archive/` | Archived Babylon-era docs (old vision, story, economy, hubs, web stack). Reference only, not canon |
