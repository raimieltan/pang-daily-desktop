# First local race

In the hub, drive east from Home onto the north street. The gold start line is at
(x -65, z 140). Within 12 metres, F / RB or the interaction button challenges the
local rival; walking up also works. Both cars stage automatically. After 3, 2, 1,
follow the gold gates east, brake for the right bend, and finish beside the coffee
shop. The HUD shows the next gate, elapsed time and standing. Results offer Race
again (restages both cars) and Back to hub. Abandon race releases controls and
clears progress. No scene reload is involved.

## Content and tuning

`src/game/races/localRoute.ts` is the debug/playable route: ordered 3D box triggers,
separate finish volume, start pose, and sampled road corridor. Change route data
to author drag, uphill/downhill touge or point-to-point runs; the core imports no
Babylon or React. Waypoint speed is metres/second. `AIDriver` builds corridor and
corner metadata from those samples, then chooses steering, brake and throttle at
the physics step rate. The rival uses `VehicleBody` and `VehicleController`, the
same collision and handling stack as the player. Driver tiers change decisions
and error; installed parts change the car through normal performance handling.

`Race` owns READY → COUNTDOWN → RUNNING → FINISHED, with RESET clearing timers,
gate indices, invalid-finish notices and finish times. Both racers
use the same swept checkpoint validator. A later gate never advances the expected
gate; a swept finish only counts after every required gate in traversal order.
Ranking uses completed gates then distance to the next gate, and finish times at
the result. `RaceSystem` owns staging, rival physics, visuals, interaction and bridge events;
React receives progress at most 10 Hz plus immediate phase/result events.
Persistent results send the measured opponent finish time (or null when the player
finishes first) so the server awards the same on-road result. Older clients still
use the published benchmark time.

## Manual verification route (not an automated test)

- Start at the gold line and hold throttle during countdown: the car stays staged.
- Complete North street → Brake for right → Coffee bend → Coffee shop finish.
- To check an invalid shortcut, turn off the north street before Brake for right,
  join the east street below the bend, and cross the finish. The HUD must refuse
  the finish and still name the missing gate. Returning through all remaining
  gates then the finish completes the run.
- Let the rival lead: it drives through the bend and finishes; completing afterward gives
  P2. Beat it to the validated finish for P1.
- Select Race again repeatedly: countdown, gate colors, timers and rival restart.
- Abandon during countdown/running, then start again at the world marker.
- Recovery/spawn commands are blocked while racing. Automatic out-of-bounds
  relocation abandons the race rather than counting the teleport as progression.
- Pause freezes simulation; switching scenes disposes race handlers and visuals.

## Pace plans on the mechanical car (2026-10-15)

Every car now runs the mechanical drivetrain and the four-corner suspension, so the kinematic plan
in `racingLine.ts` carries three calibrations the arcade model never needed:

- `carLimits(config, grip, tireGrip)` takes the car's own rubber (`plannedTireGrip`) and a specific
  power (`CarLimits.power`, W/kg at peak torque); `engineAccel` is the lower of the arcade curve and
  `power / speed`, which is what a geared engine gives past first gear.
- `steeringLock(limits)` is the rack's road lock: an AI driver gets its full `roadAngleDeg` at any
  speed (no keyboard speed sensitivity), so the AI normalises its wanted wheel angle by that.
- `PLAN_GRIP` (`rivalDriver.ts`) keeps every tier at 0.56 of the friction circle. The brush tire has
  a real breakaway past its peak; a plan that uses the whole circle sends the car into a slide it
  cannot drive out of. Tier 5 drives at 0.92 pace like tier 4, in a faster car.

`frontGripUse`/`rearGripUse` from `FourWheelDynamics` are the share of the tire's *peak* in use and
read above 1 while sliding, so the AI's lift/unwind rules trigger past the peak. A mechanical car lags
its kinematic plan by roughly 15% (gear shifts, open-diff exits, slip recovery); the physics tests
allow 20%, and the boss race compares Sean against a simulated stock car rather than a plan time.

## Drag: Main road 1/8 mile (`main_road_eighth`)

`mode: 'drag'` is the same race core with different data: no gates, a finish box spanning both lanes
201 m east of the start, and the rival staged in the next lane (`MAIN_ROAD_EIGHTH` in
`raceCalendar.ts`, listed in `DRAG_RACES` so the tiered calendar stays one rival per tier). The
racing-line overlay is skipped for drags. `Race` records the reaction time (seconds from the green
light until the car leaves its start box, `RaceProgress.reactionMs`) and the driving HUD shows it in
place of the gate readout. Server rules: `raceRules.ts` entry with zero checkpoints and a 6.2 s floor;
prize band `RACE_REWARDS.main_road_eighth` (₱600, tier 2 rival Boyet in the tidy-kit Dalagan).

## Street run: Main road → the climb (`street_run_climb`)

`mode: 'street'` is the open-road point-to-point: the main road east through town, the junction, and
the Alimodian outskirts up to the top of the climb (`STREET_RUN_CLIMB`, in `STREET_RACES`). Traffic is
the course: `RaceSystem` calls `forceTraffic(true)` for the race so civilian cars, tricycles and the
roadside animals stay live even when the player has traffic switched off in the pause menu, and
releases it when the race ends or resets (`trafficActive()` in `trafficSettings.ts`). Gates: Junction,
Alimodian outskirts, Terraces. Tier-3 rival Dodong in the primer project, ₱900, and more respect than a
closed touge run of the same length (`REPUTATION_CONFIG.races.street_run_climb`).
