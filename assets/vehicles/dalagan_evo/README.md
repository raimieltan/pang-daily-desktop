# Banwa Dalagan GSR — modular Evo V

The player car. Its shape is the Evo V reference model, cut into the Dalagan modular contract
and restyled for the manga renderer.

**Credit (CC-BY-4.0, required):** based on "Mitsubishi Lancer Evolution 5 Stylized Toon"
(https://sketchfab.com/3d-models/mitsubishi-lancer-evolution-5-stylized-toon-c6f74d4645cb47aea7813f24bc59386f)
by Ponter (https://sketchfab.com/ponter), licensed under CC-BY-4.0
(http://creativecommons.org/licenses/by/4.0/). The source is in
`reference-assets/mitsubishi_lancer_evolution_5_stylized_toon/`, which has a `.gdignore`. The credit is also
stored on `vehicle_root` as the `credit` extra.

## Rebuild

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup \
  --python tools/vehicle_builders/build-dalagan-evo.py
```

The command writes `dalagan_evo_modular.glb`, `mounting_interfaces.json`, `validation.json` and
`assets/vehicles/source/dalagan_evo_modular.blend`.

## What the builder does

- **Fit:** It scales the source lengthwise by about 1% so the axles sit exactly on the sim's
  (front Z 1.28, rear Z −1.22). The sim does not move.
- **Track and tires:** The visual track stays as the reference has it, with wheel centres at
  X ±0.845/0.854 and tire radius 0.33. Physics still uses `halfTrack` 0.728 and radius 0.3 in
  `car_body.gd`. `CarVisual` pivots each wheel at its mesh centre, so they still steer, spin and
  follow the suspension.
- **Materials:** Every source face takes its colour from a palette texture. The builder maps
  each colour to our material names: `paint`, `glass`, `trim`, `tire`, `rim`, `rim_dark`,
  `headlight`, `amber`, `taillight`, `reverse`, `plate`, `chrome`, `engine_dark`, plus
  `caliper` (red). The source's baked toon shades all become one `paint`, so the player's paint
  colour applies. There are no textures. Every face is flat-shaded.
- **Slots:** The painted body is cut along straight seam planes, then each face is assigned by
  its position.

| Slot | Part | Attach frame |
|---|---|---|
| hood | `hood_stock` (both vents) | `attach_hood`, cowl hinge |
| fender_fl / fender_fr | `fender_fl_stock` / `fender_fr_stock` | centred |
| bumper_front / bumper_rear | `bumper_front_stock` (with fogs) / `bumper_rear_stock` (with exhaust) | centred |
| sideskirt_l / sideskirt_r | `sideskirt_l_stock` / `sideskirt_r_stock` | centred |
| chin_front / lip_front | `chin_front_stock` / `lip_front_stock` | centred |
| spoiler_rear | `spoiler_rear_stock` (the Evo wing) | wing foot |
| trunk | `trunk_stock` | front hinge |
| engine | `engine_stock` + bay parts, kept from the 1996 Dalagan | unchanged |

Fixed nodes are `shell_base`, `windshield`, `rear_glass`, `window_front_±1`, `window_rear_±1`,
`mirror_l/r`, `headlight_l/r`, `indicator_±1`, `taillight_l/r` (including reverse and amber)
and `wheel_fl/fr/rl/rr`. Each wheel's origin is its axle centre. The axes are the same as the
1996 Dalagan: +X is the vehicle's left, +Y is up and +Z is forward. `CarVisual` relies on the
wheel and lamp names.

The source is hollow under the hood, so `shell_base` gets dark engine-bay walls. The aftermarket
parts in `assets/vehicles/body/` were made against the 1996 shell's seams. They need
regenerating before they fit this car.
