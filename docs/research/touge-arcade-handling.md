# Touge realistic-arcade handling: research and recommendations

Status: research brief, 2026-10-15. Scope: everything around and on top of the existing four-wheel sim (`FourWheelDynamics`, `DriverAssistance`, `CarBody`, `ChaseCamera`). Nothing here replaces the physics.

**About the sources.** Studios publish few hard numbers on handling feel. Where a number comes from a primary source it is linked. Where it is a starting value I chose for tuning, it is marked *(tuning start)*. Treat those as defaults to test, not facts.

---

## Executive summary: top 10 by impact on feel

1. **Drive tire audio from per-wheel `demand` and `slip_energy`.** On keyboard or gamepad, sound is the clearest signal that the tires are near the limit. Turn 10 mixes Forza so the tires stay audible "near the limit" ([GDC: Mixing Forza Motorsport 6](https://gdcvault.com/play/1023324/contactUs)).
2. **Make walls slide, not stop.** Override friction on wall contact, keep the car pointing along the rail, and charge a speed or score penalty instead of a dead stop. Initial D players report a wall hit costs 10–20 mph against about 2 mph for a brake tap ([JREF thread](https://jref.com/threads/initial-d-arcade-stage-ver-3.7781/page-5?amp=1)). The cost is readable and the run goes on.
3. **Cap gamepad steering at the front tires' peak slip angle.** Turning past the peak only adds understeer, so stick travel there is wasted ([AC Advanced Gamepad Assist](https://github.com/adam10603/AC-Advanced-Gamepad-Assist)). We already compute peak `demand`, so this is cheap.
4. **Make countersteer fast.** Players' top complaint about gamepad drifting is damped, sluggish countersteer ([Forza forum](https://forums.forza.net/t/countersteering-into-a-drift-feels-too-sluggish-and-it-often-ends-up-crashing-my-car/76929)). The rack rate toward opposite lock should be faster than the rate into a turn.
5. **Use a yaw-inertia "stability" layer on Normal steering only.** Forza's Normal steering changes the car's yaw inertia so it is more stable during rapid lock-to-lock steering; Simulation turns that off ([Forza support](https://support.forza.net/hc/en-us/articles/51642814113427-Forza-Horizon-6-on-Wheel-Advanced-Wheel-Tuning)).
6. **Ship the SP-bar battle as the core touge format.** The gap drains the chaser's gauge, and wall hits drain both cars' gauges ([TXR3](https://en.wikipedia.org/wiki/Tokyo_Xtreme_Racer_3), [TXR Zero](https://en.wikipedia.org/wiki/Tokyo_Xtreme_Racer:_Zero)). It turns a 90-second run into a fight with a clear "health bar".
7. **Point the camera between the car's nose and its direction of travel, and add a trauma-based shake.** The current camera follows velocity only, which hides how sideways the car is in a drift. Use Eiserloh's trauma shake for impacts and crests ([GDC 2016](https://www.gamedeveloper.com/programming/video-sprucing-up-cameras-with-math)).
8. **Map gamepad rumble to slip.** Forza Motorsport 5 buzzes the throttle trigger when the wheels spin and the brake trigger when they lock, to signal grip thresholds ([DualShockers](https://www.dualshockers.com/xbox-one-controllers-impulse-triggers-explained-on-video-by-forzas-dan-greenawalt-and-major-nelson/)).
9. **Give FWD cars a handbrake-and-lift toolkit.** FWD drifts are started with the handbrake, not the throttle ([Velenis, IEEE CDC 2011](https://skoge.folk.ntnu.no/prost/proceedings/cdc-ecc-2011/data/papers/1769.pdf)). The starter car must be fun when driven that way.
10. **Add a short rewind, plus ghosts.** Turn 10 added rewind so a single late mistake would not push players to quit ([TheSixthAxis](https://www.thesixthaxis.com/2009/10/06/why-rewind-is-the-best-thing-to-happen-to-racers/)). On a narrow pass with guardrails, this matters more than on a circuit. Use ghosts for time attack.

---

## 1. Handling feel techniques

### 1.1 Steering assists (keyboard and gamepad)

- **Peak-slip steering limit.** *What:* limit front steer so the front tires' `demand` settles near `PEAK_DEMAND` (2.1) at full stick. *Why:* the AC Advanced Gamepad Assist mod caps steering at "the optimal slip angle of the front tires" ([GitHub](https://github.com/adam10603/AC-Advanced-Gamepad-Assist)). Forza players note the same cap on gamepad, and that turning past the peak only adds understeer ([forum](https://forums.forza.net/t/the-insanity-of-steering-dampening/33823?page=3)). *How:* in `DriverAssistance.step`, read last frame's front-axle `demand`. Scale `player_target` by `clamp(PEAK_DEMAND / front_demand, 0.6, 1)`, filtered over about 0.1 s *(tuning start)*. Countersteer is exempt (see below). Leave it off when the device is a wheel.
- **Stick shaping.** The same mod ships 140% steering gamma and a 12% deadzone by default ([GitHub](https://github.com/adam10603/AC-Advanced-Gamepad-Assist)). Use gamma 1.3–1.5 on gamepad and a 0.12 deadzone as the starting values.
- **Self-steer / caster feel.** The mod adds "a self-steer tendency that mimics the effects of the car's caster angle" for stability ([GitHub](https://github.com/adam10603/AC-Advanced-Gamepad-Assist)). We already have auto-countersteer. Keep it **overridable**: player input beyond about 30% in the same direction wins.
- **Asymmetric rack rate.** Players complain that damped steering makes countersteer too slow ([Forza forum](https://forums.forza.net/t/countersteering-into-a-drift-feels-too-sluggish-and-it-often-ends-up-crashing-my-car/76929)). *How:* when the target is opposite to the car's yaw rate, use about 2× the normal rack rate *(tuning start)*. On keyboard, release-to-center should also be about 1.5× faster than turn-in.
- **Yaw "stability" damping.** Forza's Normal steering changes yaw inertia during rapid lock-to-lock steering and trades some agility for stability ([Forza support](https://support.forza.net/hc/en-us/articles/51642814113427-Forza-Horizon-6-on-Wheel-Advanced-Wheel-Tuning)). Gran Turismo 7 gives countersteer help and ASM (brake-based) separately, and toned countersteer help down in 1.31 because it changed the car's orientation too much ([GT7 notice](https://www.gran-turismo.com/us/gt7/news/00_1462138.html)). *How:* add a yaw torque `-k * (yaw_rate - yaw_rate_target)` in `CarBody._integrate_forces`. Apply it only when the rate of steering reversal is high and the slip angle is below about 15°, so held drifts are left alone. Expose three levels, Assisted / Normal / Sim, and pay a small reward bonus for the lower assist levels, as Forza Horizon does (0 / +5 / +10% XP) ([ludo.guide](https://www.ludo.guide/guide/forza-horizon-6/steering-assist)).

### 1.2 Drift initiation and maintenance

- **Use the sim's weight transfer, and make it visible.** Beckman: braking moves load forward and can cause oversteer; throttle moves it rearward and causes understeer. In his example, 640 lb shifts in a 3200 lb car ([Physics of Racing pt.1](https://www.pelicanparts.com/techarticles/physics_racing/part1.htm)). Our sim already does this. The work is in *readability*: camera pitch, body roll, and a brief rise in squeal as the rear goes light on lift-off.
- **Techniques to support, in order of importance for our cars:**
  1. *Handbrake* (FWD primary, per [Velenis](https://skoge.folk.ntnu.no/prost/proceedings/cdc-ecc-2011/data/papers/1769.pdf)). Make it a lever: while held, lock the rear wheels through the implicit solve. Add a short 0.15 s throttle hold so FWD cars carry speed *(tuning start)*.
  2. *Brake / lift-off.* The braking drift in Initial D's style. Tune rear brake bias and ESC so that ESC stays out during a trail-brake turn-in when assists are on Normal or lower.
  3. *Feint.* Emerges from the sim. Help it by letting the asymmetric rack rate apply to the feint's second flick.
  4. *Clutch kick* (RWD only). Needs a bindable clutch button. It is low priority for the FWD starter.
- **Hold the drift with throttle.** The existing throttle trim when the rear slides is correct. Expose its strength per assist level.
- **Making FWD fun.** A FWD car pulls itself out of a slide under power. Lean into that as a "point and squirt" identity: lift-off rotation, handbrake for hairpins, then full throttle with the front pulling straight. Reward tidy hairpin exits in scoring (§3.4), not angle.

### 1.3 Collisions

- **Guardrail slide, not stop.** *What:* on contact with anything in the `guardrail` group, set the tangential friction to about 0.1 and restitution to about 0.15 *(tuning start)*. Clamp the yaw impulse so the car aligns with the rail instead of spinning. Then apply a fixed speed loss: a 5–15% scrub that scales with impact angle. *Why:* Initial D's design makes wall contact cost noticeably more than braking, but the run continues ([JREF](https://jref.com/threads/initial-d-arcade-stage-ver-3.7781/page-5?amp=1)). *How:* set a Jolt `PhysicsMaterial` on the rail meshes, plus a `CarBody` body-contact callback that applies the scrub and emits a `wall_hit(severity)` signal. Battles, audio, camera trauma and rumble listen to that signal.
- **No-flip helper.** If the car's roll exceeds 60° for more than 1.5 s, or it leaves the road over the valley side, rewind it (§2.5) or reset it to the road spline *(tuning start)*. GT7 has a "Replace Car After Leaving Track" setting ([GT7 manual](https://gran-turismo.com/us/gt7/manual/drivingoption/03)).
- **Air control on crests.** Touge crests are small jumps. Add a light pitch-leveling torque while all four wheels are airborne, so the car lands flat, but no yaw authority, so it stays honest.
- **Rubber-banding.** Black Rock's Iain Gilfeather argued against rubber banding and used race scripting in *Pure* instead ([MCV](https://www.mcvuk.com/development-news/black-rock-studio-blasts-arubber-bandinga/)). Rule: no speed catch-up for rivals in battles. Instead, AI mistakes are scripted (§3.5). In free-roam traffic, light catch-up is fine.

---

## 2. Camera and feedback

### 2.1 Camera

Current state: `ChaseCamera` with distance 5.6 m, height 1.9 m, FOV 68° rising to 80° with speed, and yaw that follows *velocity*.

- **Point the camera between nose and travel direction.** Following only the travel direction hides how much the car is yawed in a drift, and drift angle is grip information. Use `wanted = slerp(velocity_dir, nose_dir, 0.35)` *(tuning start)* so the car visibly turns in the frame.
- **Damp longitudinal and turning motion separately.** One racing-camera developer reports this is how "most games" behave ([gamedev.net](https://www.gamedev.net/forums/topic/342629-3rd-person-camera-spring/)). Let distance stretch under acceleration (+0.4 m) and compress under braking (−0.3 m) *(tuning start)*, so weight transfer can be read.
- **Sense of speed comes from scale and nearby objects, not FOV tricks alone.** Speed reads from camera distance, vehicle-to-world scale and things rushing past ([critpoints](https://critpoints.net/2016/11/24/feeling-of-speed/)). On a touge this means dense roadside detail within 2 m of the edge: rail posts every 2–4 m, reflector posts, gutter grates, foliage. Keep the FOV ramp small, about +8–12°.
- **Trauma shake.** Use a 0–1 trauma value that decays over time, with shake = trauma² driving Perlin noise ([Eiserloh, GDC 2016](https://www.gamedeveloper.com/programming/video-sprucing-up-cameras-with-math); [Bevy example](https://bevy.org/examples/camera/2d-screen-shake/)). Feed it from `wall_hit`, landings, and a constant low-level road texture term scaled by speed. Use Godot's `FastNoiseLite`.
- **Don't use a physics body for the camera.** Write explicit camera logic plus an occlusion ray cast ([BEPU forum](https://forum.bepuentertainment.com/viewtopic.php?p=9486)). We already do. Add the ray cast for cliff-side hairpins.

### 2.2 Tire audio (largest single information channel)

- *Why:* Forza Motorsport 4 used hundreds of tire sounds per surface, varied by lateral and vertical load ([Forza forum](https://forums.forza.net/t/tire-sounds-and-friction-telemetry/3020)). Sega's patent sets squeal volume and pitch from tire load and changes tone with slip angle ([US8078300](https://patents.google.com/patent/US8078300)). The same patent notes that a drift squeal and a lock-up squeal differ.
- *How (per wheel):* use three layers. `squeal_volume = smoothstep(0.7, 1.1, demand/PEAK_DEMAND) * load_norm`; this starts *before* the peak and acts as the early warning. `scrub_volume = smoothstep(1.1, 2.5, ...)` and lowers pitch as slip grows. `lock/spin` is chosen from the sign of the longitudinal slip. Scale overall gain by `slip_energy`. Use `AudioStreamPlayer3D` per axle and keep tire sound above the engine in the mix.
- Engine audio: RPM-crossfaded loops, with a clear limiter "bounce". A shift light at 92% of redline *(tuning start)* is cheap.

### 2.3 Rumble

Forza Motorsport 5's triggers vibrate on wheelspin (throttle) and lock-up (brake) ([Game Informer](https://www.gameinformer.com/games/forza_motorsport_5/b/xboxone/archive/2013/11/20/forza-5-game-informer-review.aspx)). The [a7-impulse](https://git.tdem.in/Akeyroid7/a7-impulse) mod drives trigger rumble from tire slip in Assetto Corsa. Godot exposes only the two body motors (`Input.start_joy_vibration(weak, strong)`), so map them like this: weak motor = max front `demand` above the peak (understeer), strong motor = rear slip, impacts, and road texture.

### 2.4 HUD and VFX

- Keep the HUD minimal: tach with a shift light, gear, speed, and in battles the SP bars. A small top-down **slip ring** per tire (the telemetry HUD already has the data) can be an assist-level option.
- Smoke and skid marks: emit when `slip_energy` exceeds a threshold. Set skid-mark alpha from `demand` above the peak. Smoke density follows `slip_energy` and tire temperature. Skid marks persist per run and show the line on the next attempt.
- Motion blur: low, and radial only at high speed. It adds no grip information, so it is the lowest priority.

### 2.5 Rewind

Keep a 5 s ring buffer of `CarBody` and sim state at 30 Hz, with rewind on a button ([Forza 3 rationale](https://www.thesixthaxis.com/2009/10/06/why-rewind-is-the-best-thing-to-happen-to-racers/)). Allow it in free roam and time attack. In battles, disable it or charge SP for it.

---

## 3. Touge game design

### 3.1 Road design facts

- Japan's Road Structure Ordinance gives minimum centreline radii for small mountain roads (type 3, class 4) of **60 m at 40 km/h, 30 m at 30 km/h and 15 m at 20 km/h**. Roads built before 1958 often fall short of these ([trafficnews.jp](https://trafficnews.jp/post/100394/3)). At 30 km/h, the standard maximum grade is 8% (11% special case), and the stopping sight distance is 30 m ([MLIT table](https://www.mlit.go.jp/road/toukei_chousa/road_db/pdf/2023/13-3.pdf)).
- Real passes: Tsugaru Iwaki Skyline climbs 806 m at an average of 8.66% (up to 10%) through 69 hairpins ([Wikipedia](https://en.wikipedia.org/wiki/Tsugaru_Iwaki_Skyline)). Irohazaka is about 5% with 48 hairpins across two one-way roads ([guide](https://samuraicarjapanjdm.jp/irohazaka-winding-road-nikko-japan/)).
- Class-5 small roads have a 4 m carriageway (3 m special case) ([MLIT 13-2](https://www.mlit.go.jp/road/toukei_chousa/road_db/pdf/2024/13-2.pdf)). Two-lane touge roads are typically 5.5–7 m. A BeamNG Irohazaka map uses about 5.5 m ([modland](https://www.modland.net/beamng.drive-mods/maps/irohazaka-map.html); community source).
- Hamamatsu's guidance calls for high-visibility, raised road markings and gap-graded asphalt on runs of tight curves ([Hamamatsu](https://www.city.hamamatsu.shizuoka.jp/dourokikaku/traffic/douro_ud/32.html)). For us, these are the visual "rhythm" cues.

### 3.2 Race formats

| Format | Rule | Source |
|---|---|---|
| **Time attack** | Solo against the clock and your ghost; leaderboard | [Initial D modes](https://gamicus.fandom.com/wiki/Initial_D_Arcade_Stage) |
| **SP battle** (primary) | Each car has an SP gauge. The trailing car drains at a rate that rises with the gap. Wall and traffic contact drain it too. Ends when a gauge empties or the gap is large | [TXR3](https://en.wikipedia.org/wiki/Tokyo_Xtreme_Racer_3), [TXR series](https://en.wikipedia.org/wiki/Tokyo_Xtreme_Racer) |
| **Cat-and-mouse (two runs, swap)** | Run 1: you chase and score for staying close. Run 2: you lead and lose points while they're close. Win instantly by passing and holding the lead for 10 s, or if the rival hits the rail | [NFS Carbon canyon duel](https://en.wikipedia.org/wiki/Need_for_Speed:_Carbon) |
| **Tsuiso (drift)** | 5–5 split before each run. Spin or crash gives 10–0. A 5–5 tie goes to sudden death. Proximity is judged at initiation, so hanging back is penalised | [GTPlanet D1/FD rules](https://gtplanet.net/forum/threads/formula-d-and-d1-rules-explained-for-gt5-online-comps.259433) |

**Recommended SP tuning** *(tuning start)*: 100 SP each. Drain for the trailing car = `2 + 0.6 * gap_m` SP/s once the gap is over 10 m; no drain within 10 m (pressure zone). Wall hit = 5–20 SP by severity. Light car-to-car contact = 3 SP for the car that initiated it. The leader gains nothing, which keeps it a pure chase. Abort as a draw if both cars stop.

### 3.3 Progression and ghosts

Unlock passes by direction (downhill first, since it has lower power demand and suits a 75 kW car), then uphill, then night and rain variants. Use ghosts for time attack and for "rival's best line" previews. Persistent rival ghosts tie into the existing PERSISTENT_RIVAL work.

### 3.4 Scoring drifts and style

VDrift's open scoring rules: start when angle is over 0.2 rad (11.5°) and speed over 10 m/s with at least 2 wheels on track; end when angle drops under 0.1 rad (5.7°). Score = distance + distance + max speed/2 + max angle·40/π. Leaving the road or spinning (over 90°) voids the drift ([VDrift](https://raw.githubusercontent.com/VDrift/vdrift/master/docs/Drift_scoring.md)). Hobby systems use 15° / 10 mph and 30° / 15 m/s as entry thresholds ([CW Drifting](https://cw-scripts.tebex.io/package/7143396), [ProDrift](https://marketplace.secondlife.com/s/ProDrift-Drift-Scoring-System-Track/27230094)). Forza Horizon zones score angle, speed and duration with a growing combo ([guide](https://boxthislap.org/forza-horizon-6-drift-attack-guide/)). Our `DriftDetector` already uses 8° to enter and 4° to exit, which is fine for *assist* logic. **Scoring should use a separate, stricter gate: 12° to enter and 6° to exit, above 40 km/h.** Add a FWD "clean exit" bonus: little `demand` overshoot within 1.5 s after the apex.

### 3.5 AI on narrow roads

- Use *race scripting* (per Gilfeather) instead of rubber banding. Give each rival a per-corner "mistake budget" (a late brake, a wide exit, a rail kiss) that triggers more often under pressure, when the player is within 10 m for 3 s or more.
- **Blocking:** the leading AI takes the inside line before hairpins when the chaser is within 1 car length, but it may only move once per straight, as in real racecraft.
- **Pressure:** a chasing AI closes to 5–8 m in technical sections and dives on corner exit, not on entry, which avoids rear-ending the player on a 6 m road.
- Drive the AI through the same `FourWheelDynamics`, with skill-scaled steering and brake points from a racing-line spline. The existing mechanical-model calibration still applies.

---

## 4. Concrete numbers

| Item | Value | Source / status |
|---|---|---|
| Gamepad steering gamma / deadzone | 140% / 12% | [AC-AGA](https://github.com/adam10603/AC-Advanced-Gamepad-Assist) |
| Front steer cap | front `demand` ≈ peak (2.1) | AC-AGA concept; our constant |
| Countersteer rack rate | 2× turn-in rate | tuning start |
| Chase cam | 5.6 m back, 1.9 m up, FOV 68→80° | current code; keep |
| Cam nose/velocity blend | 0.35 | tuning start |
| Squeal onset | `demand/PEAK` 0.7 → 1.1 | tuning start (patent concept) |
| Drift score gate | enter 12° / exit 6°, >40 km/h | between VDrift 11.5°/5.7° and hobby 15° |
| Touge hairpin radius | 15 m (20 km/h), tight 30 m, medium 60 m | [Road Structure Ordinance](https://trafficnews.jp/post/100394/3) |
| Grade | 5–8.7% avg, ≤11% max | MLIT, Iwaki Skyline, Irohazaka |
| Road width | 5.5–6.5 m (2 lanes), 4 m single | MLIT, community |
| Wall scrub | 5–15% speed, friction 0.1 | tuning start |
| SP drain | 2 + 0.6·(gap−10 m) SP/s | tuning start |

---

## Touge map spec: first map ("Pass 1, downhill")

**Envelope.** 1.3 km centreline, downhill. Drop 95 m, for an average grade of 7.3%, with a maximum of 10% for at most 80 m in sector 3. Target lap for the starter car is about 85–95 s at an average of 50–55 km/h. Night is the default; the pass is also playable uphill as an unlock.

**Cross-section.**
- Carriageway 6.0 m (two 3.0 m lanes, centre line), narrowing to 5.0 m in sector 3.
- 0.3 m paved shoulder.
- **Valley side:** W-beam guardrail, posts every 2 m, reflectors every 8 m. Put it on all valley-side corners plus 30 m before and after. Leave short gaps only where the drop-off is grass, as a visible "danger without a rail" moment.
- **Mountain side:** 0.3 m wide by 0.25 m deep open concrete gutter (mizo) with grate lids on 20% of its length. Gutter contact *drops one wheel*: grip ×0.6 and a strong road-texture rumble. Do not add a gutter-hook exploit in v1; make it a mild hazard.
- Camber: 2% crown on straights, 4–6% banked toward the inside on hairpins, and one off-camber (−3%) corner as a trap.

**Corner sequence** (R = centreline radius; L/R = direction).

| # | Type | Dir | R (m) | Feature |
|---|---|---|---|---|
| — | Start straight 120 m | — | — | 4% grade, start line, gallery spot |
| 1 | Fast sweeper | L | 90 | flat-out test, rail on the valley (right) side |
| 2 | Medium | R | 45 | brake marker sign, gutter on the inside |
| 3 | **Hairpin** | L | 15 | first handbrake moment, banked 5% |
| 4 | Short chute 90 m | — | — | 8% grade, speed builds |
| 5 | **Decreasing-radius** | R | 50→25 | tricks late turn-in; rail on the outside |
| 6 | Esses (S-bend) | L-R | 35 / 35 | 40 m apart; feint-drift showcase |
| 7 | **Blind crest + kink** | L | 120 | crest with a 250 m vertical curve; road bends 15° after the top |
| 8 | **Hairpin pair** | R then L | 15 / 18 | 60 m apart; core of the battle, 10% section, width 5 m |
| 9 | Off-camber medium | R | 40 | −3% camber, gutter on the outside — punishes greed |
| 10 | Long double-apex | L | 30→30 | 120° total; drift-zone candidate |
| 11 | Straight 150 m | — | — | 6% grade, overtaking spot for SP battles |
| 12 | Final hairpin | R | 20 | finish 60 m after the exit (finish on the exit tests clean FWD exits) |

**Counts:** 12 numbered features. That is 4 hairpins (R 15–20 m), 1 decreasing-radius corner, 1 blind crest, 1 off-camber corner, 2 overtaking straights, and about 900 m of guardrail.

**Battle markup.**
- Spline checkpoints every 25 m for gap measurement.
- No-pass zones: none. Let the AI block.
- Name triggers for the AI's "mistake budget" corners: 3, 5, 8b, 9.

**Validation.**
- The starter car at full send should reach about 110 km/h only on sector 4 and the 150 m straight.
- Every hairpin should need braking to 35–45 km/h.
- No corner should need more than 0.9 g on stock tires.
