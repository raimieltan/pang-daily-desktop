# Banwa Silak 1983 — Lancer EX "box type", A172 build

Fictional RWD sedan modelled on the 1983 Mitsubishi Lancer EX box type sold in the Philippines (A172), styled as a JDM restomod: white paint, bolt-on arch flares, a lowered and tucked stance, deep-dish five-spoke wheels, a body-colour bumper with intercooler and black lip, and a ducktail. No badges or logos.

## Source

There is no 3D model of this car, so it is built from photos at the real size (4225 L × 1620 W × 1385 H mm). The side profile is traced from a side-view drawing, scaled so its axles land on the game's. The styling follows a "Lancer A172 JDM concept build" reference sheet. Three-quarter photos of real PH cars confirm the details.

## Files

- `lancer_box_1983_modular.glb`: runtime asset, flat shaded.
- `mounting_interfaces.json`: slot frames, wheel pivots and panel boundary loops.
- `validation.json`: triangles, draw calls, materials, bounds, slot frames and wheel pivots, read back from the exported GLB.
- `previews/`: assembled, panel-removal and exploded renders of the exported GLB.

## Rebuild

From the repository root:

```sh
blender --background --factory-startup --python tools/vehicle_builders/build-silak83.py
blender --background --factory-startup --python tools/vehicle_builders/render-silak83-previews.py
```

The shape lives in `tools/vehicle_builders/build-silak83-live.py`. It also runs inside the open Blender session through the Blender MCP for live editing. `build-silak83.py` runs it, cuts the body along seam planes, assigns every face to a slot part or a named detail, keeps the Dalagan engine bay, exports, then re-imports the GLB and checks it. The working scene is saved to `assets/vehicles/source/silak83_modular.blend`.

## Asset contract

Metres, +Y up, +Z forward, +X left. The wheel nodes `wheel_fl/fr/rl/rr` have their origins on their pivots at y=0.30, x=±0.728, z=+1.28/−1.22 (wheelbase 2.50 m, tire radius 0.30 m). The wheel meshes sit 25 mm further out than the pivot so they are flush with the flares. `headlight_l/r` and `taillight_l/r` are the lamp meshes CarVisual uses for the beams and brake streaks. Materials use the names MangaArt shades: paint, glass, trim, tire, rim, rim_dark, chrome, headlight, amber, taillight, engine_metal, engine_dark. Paint is recoloured at runtime.

Removable slots, each an `attach_<slot>` frame holding `<slot>_stock`: hood, trunk, fender_fl, fender_fr (each with its front flare), overfender_rl, overfender_rr (the rear flares), bumper_front (with intercooler and lamps), bumper_rear, chin_front, lip_front, sideskirt_l, sideskirt_r, spoiler_rear (ducktail) and engine. Removing the hood or a fender reveals the engine-bay walls. Removing the trunk lid reveals a trunk floor.

The exported model has 6,084 triangles, 67 draw calls and 12 materials, within the 30,000 / 100 / 16 runtime budgets.
