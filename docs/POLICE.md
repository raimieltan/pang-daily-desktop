# Police, fines and chases

GAME_VISION §14: consequences, not a wanted level. Sometimes the smartest move is to stop.

- **One patrol car** (`PatrolSystem`, `src/game/traffic`) drives the town loop in the civilian lane
  (`TOWN_LOOP_LANE`) at a steady pace. The mountain road is not patrolled.
- **Offences** (`detectOffense`, `src/game-core/police/police.ts`): speeding over the town limit
  (`POLICE.speedLimitKmh`, 60) or racing, seen within `POLICE.sightM` (70 m) while the player is driving in town.
- **Lights on → pull over.** The player has `POLICE.pullOverS` (8 s) to stop. Stopping opens the choice:
  pay the fine, or drive off and run. Not stopping, or driving off, is a **chase**: `POLICE.chaseS` (25 s);
  the patrol hurries along its lane; stopping within 30 m of it is being boxed in. Still inside
  `POLICE.escapeM` (140 m) when the clock runs out, or boxed in: **caught**, fine doubled. Clear of that:
  **escaped**, but the strike is remembered.
- **Fines** (`FINES` in `economy/balance.ts`): speeding ₱500, street racing ₱1,500, plus ₱1,000 for
  evading; each prior strike this session adds 50% (`fineFor`). On account saves the amount is the
  server's: `pay_fine` (contract + `economy.repository.ts`) recomputes it from the offence, strikes and
  whether the driver was caught, writes a `FINE` ledger entry keyed by the incident id (never paid twice).
  Standalone play charges the local wallet.
- **After an incident** the patrol looks the other way for `POLICE.cooldownS` (90 s).
- HUD: `PolicePanel` (store `policeStore`) shows the clock, the fine and the Pay button; `policeEvent`
  carries lights/stopped/chase/caught/escaped/paid for audio and feedback.

Not yet: impound and registration status (tracked on PAN-113), reputation effects of being caught.
