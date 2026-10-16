# Barangay hub: Kyo Coffee, the talyer, and challenges from the street

Date: 2026-10-16. Status: approved in chat ("looks good please do it").

## Intent

The home of the game is a small neighbourhood you drive around, not a menu. Kyo Coffee sits at its
centre because that is where the user and their friends hang out in real life; it must look like the
real café (ground floor of the KLMB Bldg., Guzman St., Mandurriao, Iloilo) so local players know it
on sight. The rival cast hangs out there. You pull up, challenge one of them, and the SP battle runs
on the mountain pass (Pass 1), then you come back to Kyo.

This replaces the "hubs are menus with a 3D backdrop" rule in `docs/GAME_DESIGN.md`: hubs are now
places on a drivable loop. Walking stays post-MVP; you act from the car, parked in a zone.

## Goals

- A drivable barangay loop (ported from the Babylon hub, `docs/archive/HUB_LAYOUT.md`) with Kyo
  Coffee, Talyer ni Tito Jun, houses, poles and wires, in the manga art style.
- Kyo Coffee modelled in Blender from the Babylon spec (`coffeeShop()` in the old
  `src/game/world/hub/hubLayout.ts`): three-storey white KLMB Bldg., dark slab bands, black-framed
  glass storefront, dark-glass stair tower on the south end, glass-railed balconies, wood soffit,
  vertical KYO panel by the door, KYO COFFEE sign on the slab band and on the roadside post, the
  terrace (tables, umbrella, string lights), black bollards and pink posts on the apron, the fenced
  motorcycle corner with tall white gate pillars, the gravel lot behind its white wall.
- The talyer modelled in Blender from the old `talyer()`: open-front shed, rusty GI roof, spray-booth
  bay and lift bay, tyres, drums, workbenches, tambay corner; Tito Jun's tarp.
- Rivals (VsBattle.RIVALS) parked at Kyo; pull up beside one and press the action key to challenge.
  The challenge starts an SP battle on Pass 1 against that rival; after it, "Back to Kyo".
- Rivals also cruise the loop; flash your headlights behind one to challenge (same result).
- Talyer: parking in a bay opens the garage (car pick) with a Tito Jun line. Repair and tuning wait
  for the economy slices.
- The title menu gets a BARANGAY entry that loads the hub.

## Non-goals

- Walking, interiors you can enter, the gas station / Suki 24 / parts counter / car lot detail
  (blocked out only, if at all), economy, wagers, leaderboards.
- Headlight-flash challenges on the pass itself (PAN-153 keeps that).

## Anti-goals

- Kyo that looks generic: the facade, signage and frontage are the point.
- Japanese props: the setting is the Philippines (yellow/orange lamps, PH signage).
- A hub that takes longer than a run to get through: challenge to pass in one press.

## How (decided)

- Blender builders in `tools/world_builders/` export GLBs to `assets/world/` with named materials;
  the hub maps material names to `MangaArt` world presets and accents (world is ink/tone, a few
  colour accents: KYO sign, warm glass, pink posts, lamps).
- `tools/build_hub.gd` bakes `maps/hub_01/` (ground, roads, buildings, collision, the loop's
  `TrackData` for AI cruisers, resets and the minimap), like `tools/build_map.gd` for Pass 1.
- `scenes/hub.tscn` hosts a `DriveSession`, the parked and cruising rivals, location zones and the
  challenge prompt. A challenge is handed to `scenes/touge.tscn` through a static pending request.

## Left to the builder

Exact prop list beyond the Babylon spec, cruiser count (keep the M1 8 GB budget in mind), prompt
styling (use `MangaType`).
