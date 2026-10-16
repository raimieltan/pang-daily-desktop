# Civic FD — modular 2007 Civic Type R FD2

The `civic_fd` car in the garage. Its shape is the FD2 reference model, cut into the Dalagan
modular contract (see `assets/vehicles/dalagan_evo/README.md`) and restyled for the manga renderer.

**Credit (CC-BY-4.0, required):** based on "2007 Honda Civic Type R FD2"
(https://sketchfab.com/3d-models/2007-honda-civic-type-r-fd2-7da33a4102b848d5abe7f3bb7c445f46)
by claries (https://sketchfab.com/R1peer), licensed under CC-BY-4.0
(http://creativecommons.org/licenses/by/4.0/). The source is in `reference-assets/2007_honda_civic_type_r_fd2/`,
which has a `.gdignore`. The credit is also stored on `vehicle_root` as the `credit` extra.

## Rebuild

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup \
  --python tools/vehicle_builders/build-civic-fd.py
```

The command writes `civic_fd_2007_modular.glb`, `mounting_interfaces.json`, `validation.json`,
`previews/` and `assets/vehicles/source/civic_fd_2007_modular.blend`.

## What the builder does

- **Turn and fit:** The source points its nose along +X, so the builder turns it to +Z. Then it
  scales it uniformly so the rim centres land on the sim's axles (front Z 1.28, rear Z −1.22).
  The real FD2 has a 2.70 m wheelbase and the sim uses 2.5 m, so the car is about 7% smaller
  than life. Its tire radius is 0.29 and its wheel centres sit at X ±0.795.
- **Materials:** The painted body, the wing blade and the mirror shells become `paint`. Glass,
  black trim, lamps (from the lens textures: `headlight`, `amber` repeaters, `taillight`,
  `reverse`), `chrome` grille bar and exhaust, `tire`, `rim` and `rim_dark` come from their own
  source objects. There are no textures, so the grille badge is plain chrome. The faces are
  smooth-shaded, with hard edges above 35°.
- **Slots:** The body and the black trim are cut along straight seam planes, then each face is
  assigned by its position. The slots are hood, fender_fl/fr (with side repeaters), bumper_front
  (with grille and intakes), bumper_rear (with exhaust), sideskirt_l/r, lip_front, chin_front,
  trunk and spoiler_rear (the Type R wing). The engine bay is kept from the 1996 Dalagan and
  dropped under the hood.

The rims are flat discs, because the source paints its spokes in a texture.

## Tune

The car drives on `fwd_fd2r` (`sim/vehicle/handling_presets.gd`), with `fwd_fd2r_drift` as its drift
tune. It uses the real FD2R figures: 1,270 kg, a K20A making 215 Nm at 6,100 rpm with an 8,400 rpm
redline, a 6-speed gearbox (3.266 to 0.738, final drive 4.764), a helical LSD and stiff springs.
