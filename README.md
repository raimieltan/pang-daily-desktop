# Pang Daily (Godot)

Touge racing game, rebuilt in Godot 4.7 (Jolt physics). The vehicle sim is ported from the
Babylon build (`pang-daily/src/game/vehicles/handling`, `src/game-core/suspension`).

- `sim/` — engine-agnostic sim (plain `RefCounted` GDScript): handling model, suspension solver.
- `game/` — Godot adapters: `CarBody` (RigidBody3D ↔ sim), visual, camera, input, HUD.
- `scenes/` — playable scenes. `drive_test.tscn` is the open test lot.
- `tests/` — headless tests: `godot --headless --path . -s res://tests/run_tests.gd`.
- `tools/ts_reference_probe.test.ts.txt` — copy into the TS repo's `src/game/vehicles/` as
  `_godot_fixture.test.ts` and run it with vitest to regenerate `tests/fixtures/ts_reference.json`.

Design canon: `docs/GAME_DESIGN.md` (racing-first design, decisions, build status) and
`docs/ART_DIRECTION.md`. Story mode ("The Ghost Line"): `docs/story/` — `STORY_MODE.md` for how it
plays, plus the plot, storyboard and manuscript. Babylon-era docs are in `docs/archive/`, reference only.

Carried over from the Babylon repo (2026-10-15), which is retired:

- `assets/vehicles/` — every car (Dalagan, Civic EK/FD, Lancer box, starter sedan), body kits,
  wheels, mounting interfaces and QA previews. `.blend` and baseline sources in `source/`.
- `assets/audio/radio/` — the radio tracks and ambience. Not CC-licensed (see `CREDITS.md`).
- `tools/vehicle_builders/` — the Blender Python and Node scripts that built the car models.
# pang-daily-desktop
