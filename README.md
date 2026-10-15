# Pang Daily (Godot)

Touge racing game, rebuilt in Godot 4.7 (Jolt physics). The vehicle sim is ported from the
Babylon build (`pang-daily/src/game/vehicles/handling`, `src/game-core/suspension`).

- `sim/` — engine-agnostic sim (plain `RefCounted` GDScript): handling model, suspension solver.
- `game/` — Godot adapters: `CarBody` (RigidBody3D ↔ sim), visual, camera, input, HUD.
- `scenes/` — playable scenes. `drive_test.tscn` is the open test lot.
- `tests/` — headless tests: `godot --headless --path . -s res://tests/run_tests.gd`.
- `tools/ts_reference_probe.test.ts.txt` — copy into the TS repo's `src/game/vehicles/` as
  `_godot_fixture.test.ts` and run it with vitest to regenerate `tests/fixtures/ts_reference.json`.
