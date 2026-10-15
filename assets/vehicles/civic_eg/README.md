# Banwa Hiraya EG — modular Civic EG6 hatch

Junjun's rival car in VS battles. Its shape is the EG6 reference model, cut into the Dalagan
modular contract (see `../dalagan_evo/README.md` for the slot table and axes).

**Credit (CC-BY-4.0, required):** based on "1991 Honda Civic EG6"
(https://sketchfab.com/3d-models/1991-honda-civic-eg6-f81da34570b145deb463fa091604d251)
by rifdanzz (https://sketchfab.com/rifdanzz), licensed under CC-BY-4.0
(http://creativecommons.org/licenses/by/4.0/). The source is in `1991_honda_civic_eg6/`, which
has a `.gdignore`. The credit is also stored on `vehicle_root` as the `credit` extra.

## Rebuild

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup \
  --python tools/vehicle_builders/build-civic-eg.py
```

The command writes `civic_eg_modular.glb`, `mounting_interfaces.json`, `validation.json`,
`previews/` and `assets/vehicles/source/civic_eg_modular.blend`. Shared steps are in
`tools/vehicle_builders/modular_kit.py`.

## What the builder does

- **Fit:** A uniform scale (about 0.0048) puts the source's axles exactly on the sim's
  (front Z 1.28, rear Z −1.22) and its tires on Y = 0. Wheel centres are X ±0.72, tire radius 0.28.
- **Slots:** The source already has separate panels, so each face is sorted by its source object,
  then by side: `frontbumper.001` is the hood, `front fender` splits into both fenders,
  `frontbumper.003/.004` become the lip and chin, and `trunk` is the hatch's lower panel (the hatch
  glass is the fixed `rear_glass`). The exhaust rides on the rear bumper.
- **Materials:** Paint, glass, trim, tire and rim map from the source materials. Lamp faces take
  `headlight`, `amber`, `taillight` or `reverse` from the source's photo texture colour. The
  source's Japanese plate texture is dropped for our plain `plate`.
- **Shading:** The source is modelled smooth, so it is smooth-shaded with hard edges above 32°.
  The faceted Evo stays flat.
- **Engine bay:** The 1996 Dalagan engine is kept and lowered to clear the EG's lower hood. Dark bay
  walls fill the hollow nose.
