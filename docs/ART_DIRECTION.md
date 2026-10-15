# PANG DAILY — ART DIRECTION (manga panel)

> **Driving inside a colored manga panel.** The world is ink and screentone on paper; the cars are
> the only full color on the page.

Supersedes the Babylon build's "lo-fi nocturnal arcade realism" (`pang-daily/docs/ART_DIRECTION.md`).
Four of its pillars carry over: cars are the heroes, the places are familiar (Iloilo roads, talyers,
gas stations), imperfection is good, and night is the signature mood. What changes is the medium:
we render a printed page, not a photograph.

Reference: colored *Initial D* manga panels. The world is black-and-white ink with grey screentone,
and one or two cars are spot-colored (the yellow EK hatch next to the white AE86). Collage
spreads, katakana sound effects drawn into the art, speed lines, and heavy blacks under the cars.

---

## 1. Pillars

1. **Paper first.** The brightest value is paper, never sky blue or sunlight yellow, and the darkest
   is ink. Every world surface sits between them as one of a few discrete tones. Nothing
   in the world is a smooth gradient.
2. **Color means car.** Saturated color is reserved for player and rival cars, plus a few
   story-critical accents: the taillight glow, the start gantry, a rival's livery stripe. A colored
   object is something the player should look at.
3. **Ink tells the shape.** Silhouettes and creases get black lines. Depth reads through line weight
   (heavy near, thin far) and through fading to paper, not through atmospheric color.
4. **Motion is drawn.** Speed is shown the way a mangaka draws it: speed lines, smeared
   backgrounds, impact frames, and onomatopoeia. It is not motion blur.
5. **Readable at 120 km/h.** Gameplay information (road edges, apexes, guardrails, the car's slide
   angle) must survive the style. When style and readability conflict, readability wins.

---

## 2. Value system (the world)

The world uses four tones plus ink. Lighting picks the tone; material darkness shifts it.

| Tone | Look | Used for |
|---|---|---|
| T0 Paper | flat off-white `#F2EFE6` | lit concrete, sky, road paint, guardrail faces, distant fog |
| T1 Light tone | sparse 45° dot screen (~15% coverage) | lit asphalt, lit grass, sky gradient near horizon |
| T2 Mid tone | dense dot screen (~40%) | shade side of terrain, darker materials in light |
| T3 Dark tone | cross-hatching or very dense dots (~70%) | shadowed asphalt, rock cuts, forest mass |
| Ink | solid `#141414` | cast shadows under cars, deep night shadow, tree silhouettes, outlines |

Rules:
- **Light bands are hard.** Use 3–4 steps with no smooth Lambert. The shadow terminator is a clean edge.
- **Screentone is screen-space.** Dots stay a constant size on screen, about 4–6 px pitch at 1080p,
  rotated 45° like printed tone. Tone never shrinks with distance; that is what makes it read as a page.
- **Material = tone offset.** Asphalt sits one tone darker than concrete in the same light, and gravel
  adds stipple noise. Rock cuts get directional hatching that follows the slope. Grass is a sparse dot field.
- **Cast shadows are ink**, or T3 at dusk. The car's contact shadow is always solid ink. It anchors
  the color car to the page, as every reference panel does.
- **Distance fades to paper.** Instead of colored fog, far geometry loses tone and keeps only its
  outline, until the background is lines on white. Mountains at the horizon are a single ink stroke.

## 3. Cars (the color)

- **Flat cel paint:** a lit body color, one shadow band (the paint color darkened and slightly hue-shifted,
  never grey), and a sharp white specular "glint" shape on the roof or hood in place of reflections.
- **Ink outline** on the silhouette (inverted hull, about 2.5 cm in world space, so it thins with
  distance) and on interior creases (panel gaps and wheel arches from the model, or edge detection).
- **Shadow side gets hatching over color.** Thin ink hatch lines over the shadow band, like the
  reference's dark flanks.
- **Glass is ink** with one white glint stroke. **Tires are ink** with a grey sidewall ring.
  **Wheels** are paper or grey tone, with spokes outlined.
- **Lights are the only glow:** headlights are paper-white cones drawn as tone gradients, and taillights
  are the car's red smear in motion. At night, a car's light falls on the road as T0 paper in an ink
  world, which carries over the Babylon doc's "night is the signature".
- Liveries and stickers stay color. They are how players recognize each other on the page.

## 4. Motion language

Drive these from the sim state, not from timers. They are feedback, not decoration.

| Effect | Trigger | Notes |
|---|---|---|
| **Speed lines** | speed > ~60 km/h | radial ink streaks from the screen edge toward the vanishing point; density ∝ speed |
| **Background smear** | speed > ~100 km/h | streak tone horizontally in the direction of travel at the screen sides; the car stays sharp |
| **Drift onomatopoeia** | rear `demand` > 1 (sliding) | katakana SFX sprite near the rear tires: キィィィ (squeal), with size ∝ slip energy. It wobbles and follows the car |
| **Impact frame** | wall hit above a severity threshold | 2–3 frames of inverted page (ink↔paper), a burst-lines frame, ドン / ガッ SFX |
| **Shift / launch** | upshift at high rpm, launch | small ギャン or ブォン sprite near the exhaust, plus a brief camera kick |
| **Tire smoke** | slip energy | paper-white puffs with ink outlines (cloud shapes, not particles that look like particles) |
| **Skid marks** | locked or sliding wheels | ink strokes on the road that persist (manga skid lines) |

Sound-effect lettering is hand-drawn katakana, with Filipino/English variants as a later option.
Lettering is part of the scene, so it gets occluded and rotated with the camera.

## 5. Camera and framing

- **Panel framing:** a thin ink border and paper gutter around the viewport, very subtle, about 1.5% of
  screen height. Optional "panel cut" moments (start countdown, finish, overtakes) split the
  screen into 2–3 angled panels for a beat, then return.
- **Lens:** the chase cam stays as specified in `docs/research/touge-arcade-handling.md`.
  Manga framing favors low, three-quarter angles: the replay and photo cams sit low and wide.
- **No bloom, no chromatic aberration, no motion blur.** These read as "video game" and break the page.

## 6. Environment notes (touge)

- **Road:** lanes in T1 over the asphalt tone. Edge lines and the double centre line are paper. Worn
  racing lines are slightly darker tone streaks.
- **Guardrails:** paper face, ink outline, and ink posts. They must stay the brightest line on the
  valley side, because they are a readability element.
- **Cut walls:** T3 hatching along the slope with an ink crest line. Gutters (mizo) are an ink slot.
- **Cedar forest:** ink silhouettes with paper-white edge highlights on the lit side. Far forest becomes a
  T2 mass with an ink skyline stroke.
- **Sky:** paper. Dusk adds a T1 tone band near the horizon. Night inverts to a T3/ink sky with
  paper stars and a paper moon.
- **Setting: Philippine provincial mountain roads, not Japan.** Signage is DPWH-style: white
  boards with red lettering (SLOW DOWN, MENOR, ACCIDENT PRONE AREA, BAWAL MAG-OVERTAKE), white
  kilometre posts, convex mirrors at hairpins. Street lamps are sodium orange (heads and a tinted
  pool core), never white. No kanji, torii or vending machines.
- **Iloilo flavor** carries over from the old doc: utility poles, tangled wires (great ink
  linework), sari-sari stores, roadside shrines, jeepney signage. All of it is drawn, not textured.

## 7. UI

- **HUD** looks like manga lettering: speed in heavy brush numerals, gear in a speech-bubble circle, and the
  tachometer as a hand-inked arc filled with tone.
- **Menus** are page layouts: panels, gutters and screentone, with a color accent only on the selected car.
- The debug telemetry HUD stays plain monospace. It is a tool.

## 8. Technical approach (Godot 4.7, mobile renderer, M1 8 GB)

| Piece | Implementation |
|---|---|
| World tone | spatial shader `manga_world.gdshader`. `light()` quantizes N·L × shadow into bands; `fragment()` converts material darkness into a tone level; both resolve to a screen-space 45° dot or hatch pattern using `FRAGCOORD`. One material type with a few uniforms: `tone`, `pattern` (dots / hatch / stipple), `ink_threshold` |
| Car cel | `manga_car.gdshader`: two-band toon with a hue-shifted shadow, a glint highlight, and hatch overlay in shadow. The GLB's own albedo color is kept and boosted |
| Outlines | cars and props: inverted hull `next_pass` (`manga_outline.gdshader`). World silhouettes and creases: a depth-edge pass in the full-screen post (mobile renderer has the depth texture, not the normal buffer) |
| Post | full-screen quad on the camera (`manga_post.gdshader`): depth-edge ink, paper grain, distance fade to paper, speed lines, panel border and the impact-frame inversion |
| SFX lettering | `Label3D`/sprite pool with katakana textures, spawned by a `MangaFx` node listening to the sim |

Performance budget: the post pass does one depth read plus a 4-tap edge kernel; the tone shaders are
ALU-only. No extra render targets.

## 9. Refinement pass (2026-10-15): what is implemented

**Grayscale hierarchy.** World materials have a gray *value* (lit/shadow) with screentone printed
over it at a per-material contrast, so not every surface is equally noisy. Presets live in
`MangaArt.WORLD_PRESETS`:

| Surface | Lit / shadow value | Tone | Notes |
|---|---|---|---|
| Sky | paper `#F3EFE5` → warm gray horizon band | sparse dots at the horizon | `manga_sky.gdshader`: ink-contoured cumulus, sun with drawn rays |
| Distant ridges | 0.80 / 0.68, far 0.84–0.88 | barely any | two rings; ink skyline from the page pass |
| Hillside | 0.88 / 0.56 | sparse dots, hatching on steep faces | |
| Cedars | 0.40 / 0.16 | hatching | dark near, mid-gray midground, pale far (distance in-shader) |
| Road | 0.66 / 0.40, slightly cool | light dots; **directional hatching in cast shadow** | paint stays paper |
| Rock cuts | 0.64 / 0.26 | hatching | darkest big surface near the road |
| Guardrail / posts | 0.98 / 0.72 · ink | none | brightest line on the valley side |

Distance in the world shader thins tone (×0.25) and pales value toward `far_value`; the page pass
adds a capped haze (`fade_max` 0.72), so far shapes stay light-gray silhouettes rather than vanishing.

**Cars.** Material kinds: paint (warm highlight on top panels → body color → darker *warmer*
shadow → deep shadow with fine hatching, plus a glint and a thin edge highlight), glass (cool dark
with diagonal reflection streaks), rubber/trim, metal (bright with a hard dark band), lamps (glow
driven by state). Outline width is per part: 2.2 cm on the body, 0.6–1.8 cm on details.

**Selective color accents (all state-driven).**
| Accent | Trigger | Where |
|---|---|---|
| Taillights + red road pool | brake pedal; dim tail lamps at night | `CarVisual._update_lamps` |
| Warm headlight cones | night | spot lights, banded in the world shader |
| Sodium lamp heads + orange pool cores | always (street lamps) | `MangaArt.lamp`, `lamp_tint` in the world shader |
| Red sign lettering | always (warning boards) | `TrackBuilder._build_board` |
| Yellow-orange sparks | sliding along a wall/rail > 4 m/s | `CarFx` (contact slide speed) |
| Impact frame + shake | contact impulse > 3 m/s Δv | page pass `impact`, `ChaseCamera.add_impact` |
| Pale blue-white streaks | top ~20% of speed-line intensity | page pass |
| Ink skid marks, cloud smoke | tire slip angle/ratio past the limit; smoke only on heavy slides | `CarFx` |

**Night (N).** The page inverts: dark tones, pale outlines, ink sky with stars and a crescent moon;
car lamps become the light.

**Tuning knobs** (Project Settings → Shader Globals): `manga_tone_contrast`, `manga_tone_density`,
`manga_outline_scale`, `manga_fx_intensity`, `manga_night`, `manga_res_scale` (set by the camera).

**Known limits.** Screentone is screen-anchored (printed-page look), so on large surfaces it
"swims" slightly relative to the geometry in motion; the road's lower contrast and larger pitch
keep it calm, but it is not verified on a 60 Hz display by eye yet.

## 10. Do / Don't

**Do:** hard light bands, solid blacks, constant-size screentone, color only on cars, drawn
motion effects, paper-white distance.

**Don't:** use smooth gradients in the world, colored fog, bloom, photo textures, color in the world
except deliberate accents, or effects that hide the road edge.
