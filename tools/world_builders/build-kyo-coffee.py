"""Kyo Coffee on the ground floor of the KLMB Bldg. (Guzman St., Mandurriao, Iloilo), for the hub.

Run headless: Blender --background --factory-startup --python tools/world_builders/build-kyo-coffee.py
Add `-- --preview <dir>` to render check images. Output: assets/world/kyo_coffee.glb.

Built from the user's two street photos (2026-10-16) and the Babylon greybox it replaces
(`coffeeShop()` in the old hubLayout.ts, whose placement it keeps). It is the one real place in the
game, so it must read as the real building:
  * a deep three-storey white block, its narrow end to the street; a dark-blue glass stair tower on
    the right (south) corner of the front with a grey stone strip round the corner,
  * mono-pitch roof slab, thick white fascia, wood soffit,
  * floors 2 and 3: small square window, wood French doors with white ledges over both, frameless
    glass balconies on dark slab bands; floor 2's band is the café canopy and wraps the side,
    which carries balconies its full length,
  * "KLMB Bldg." in blue-grey letters by the 3rd-floor window, a split aircon beside it,
  * the café: black-framed glass front, the small Kyo panel on the glass by the door, a closed
    cream umbrella, round tables and white folding chairs, potted plants against the glass,
  * the side's ground floor: tenant units in tan tile with glass doors and aircons,
  * the apron: grey concrete bollards, two slim pink posts, the parking A-frame at the street,
    black steel fence round the motorcycle corner (left), the tall white gate pillars next door,
    the gravel driveway and the black gate and white wall of the lot (right).
Layout units as in the Babylon hub: x east, y up, z north; the glass front is at x = 140.6 facing
the connector road (-x). The GLB origin is (140.6, 0, 101): the centre of the storefront.
"""
import sys
from pathlib import Path

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
from kit import Kit  # noqa: E402

PREVIEW = Path(sys.argv[sys.argv.index('--preview') + 1]) if '--preview' in sys.argv else None

k = Kit('kyo_coffee', (140.6, 101.0))

FRONT = 140.6           # storefront / front face
BACK = 158.6            # rear wall
NORTH, SOUTH = 106.0, 96.0
TOWER = 98.6            # stair tower spans SOUTH..TOWER on the front
F2, F3, ROOF = 3.9, 7.35, 10.35

WHITE = ('wall_white', '#e9e7e1')
BAND = ('band_dark', '#3a3532')
INK = ('frame_ink', '#141414')
WOOD = ('wood_frame', '#6b3f24')
GLASS_DARK = ('glass_dark', '#1c2433')
TOWER_GLASS = ('accent_tower_glass', '#1d2c4c')
RAIL_GLASS = ('glass_rail', '#c9d3d6')
STEEL = ('steel', '#b8bcc0')
CAFE_GLASS = ('glass_cafe', '#2b2522')
TAN = ('tile_tan', '#c9a86a')
STONE = ('stone_grey', '#8a8782')
SOFFIT = ('wood_soffit', '#9a6a44')
CONCRETE = ('concrete', '#cfcac0')
GREY = ('bollard_grey', '#7d7d7a')


def box(c, s, m, **kw):
    return k.box(c, s, m[0], m[1], **kw)


# ---------------------------------------------------------------- building mass
box(((FRONT + BACK) / 2, ROOF / 2, (NORTH + SOUTH) / 2), (BACK - FRONT, ROOF, NORTH - SOUTH), WHITE, collide=True)
# Plinth step along the front and the side.
box((FRONT - 0.3, 0.06, (NORTH + SOUTH) / 2), (0.6, 0.12, NORTH - SOUTH + 1.2), CONCRETE)
box(((FRONT + BACK) / 2, 0.06, SOUTH - 0.6), (BACK - FRONT, 0.12, 1.2), CONCRETE)

# Roof: mono-pitch slab falling toward the back, deep overhang, thick white fascia, wood soffit.
ROOF_RUN = BACK - FRONT + 2.2
box(((FRONT + BACK) / 2 - 0.2, ROOF + 0.35, (NORTH + SOUTH) / 2), (ROOF_RUN, 0.3, NORTH - SOUTH + 2.0), WHITE,
    group='roof').rotation_euler[1] = 0.0
k.box((FRONT - 1.05, ROOF + 0.3, (NORTH + SOUTH) / 2), (0.12, 0.55, NORTH - SOUTH + 2.1), *WHITE, group='roof')
k.box(((FRONT + BACK) / 2 - 0.2, ROOF + 0.3, SOUTH - 1.05), (ROOF_RUN, 0.55, 0.12), *WHITE, group='roof')
k.box(((FRONT + BACK) / 2 - 0.2, ROOF + 0.3, NORTH + 1.05), (ROOF_RUN, 0.55, 0.12), *WHITE, group='roof')
k.box((FRONT - 0.5, ROOF + 0.18, (NORTH + SOUTH) / 2), (1.0, 0.04, NORTH - SOUTH + 2.0), *SOFFIT, group='roof')
k.box(((FRONT + BACK) / 2, ROOF + 0.18, SOUTH - 0.5), (BACK - FRONT, 0.04, 1.0), *SOFFIT, group='roof')
k.box(((FRONT + BACK) / 2, ROOF + 0.18, NORTH + 0.5), (BACK - FRONT, 0.04, 1.0), *SOFFIT, group='roof')

# ---------------------------------------------------------------- stair tower (front, south corner)
k.box((FRONT - 0.2, (F2 + ROOF) / 2, (SOUTH + TOWER) / 2), (0.4, ROOF - F2, TOWER - SOUTH), *TOWER_GLASS)
for y in (F3 - 0.1, ROOF - 0.15):
    k.box((FRONT - 0.42, y, (SOUTH + TOWER) / 2), (0.03, 0.06, TOWER - SOUTH), *INK)
k.box((FRONT - 0.42, (F2 + ROOF) / 2, SOUTH + 1.6), (0.03, ROOF - F2, 0.05), *INK)
# Round the corner: more dark glass, then the grey stone strip.
k.box((FRONT + 1.0, (F2 + ROOF) / 2, SOUTH - 0.05), (2.0, ROOF - F2, 0.1), *TOWER_GLASS)
k.box((FRONT + 2.4, (F2 + ROOF) / 2, SOUTH - 0.06), (0.8, ROOF - F2, 0.12), *STONE)

# ---------------------------------------------------------------- slab bands and balconies
# Floor 2 band: the café canopy across the whole front, wrapping down the side.
box((FRONT - 0.6, F2 - 0.22, (NORTH + SOUTH) / 2 - 0.6), (1.2, 0.45, NORTH - SOUTH + 1.2), BAND)
box(((FRONT + BACK) / 2, F2 - 0.22, SOUTH - 0.6), (BACK - FRONT, 0.45, 1.2), BAND)
# Floor 3 band: front, left of the tower; and the side, behind the stone strip.
box((FRONT - 0.5, F3 - 0.2, (NORTH + TOWER) / 2), (1.0, 0.4, NORTH - TOWER), BAND)
box((FRONT + 2.8 + (BACK - FRONT - 2.8) / 2, F3 - 0.2, SOUTH - 0.5), (BACK - FRONT - 2.8, 0.4, 1.0), BAND)


def rail_x(x, y, z0, z1):
    """Frameless glass balustrade along z at x: glass, steel top rail, posts at the panel joints."""
    k.box((x, y + 0.55, (z0 + z1) / 2), (0.03, 1.0, z1 - z0), *RAIL_GLASS, group='rails')
    k.box((x, y + 1.08, (z0 + z1) / 2), (0.06, 0.05, z1 - z0), *STEEL, group='rails')
    n = max(1, round((z1 - z0) / 1.4))
    for i in range(n + 1):
        k.box((x, y + 0.55, z0 + (z1 - z0) * i / n), (0.05, 1.1, 0.05), *STEEL, group='rails')


def rail_z(z, y, x0, x1):
    k.box(((x0 + x1) / 2, y + 0.55, z), (x1 - x0, 1.0, 0.03), *RAIL_GLASS, group='rails')
    k.box(((x0 + x1) / 2, y + 1.08, z), (x1 - x0, 0.05, 0.06), *STEEL, group='rails')
    n = max(1, round((x1 - x0) / 1.4))
    for i in range(n + 1):
        k.box((x0 + (x1 - x0) * i / n, y + 0.55, z), (0.05, 1.1, 0.05), *STEEL, group='rails')


rail_x(FRONT - 1.18, F2, SOUTH - 1.2, NORTH)
rail_z(NORTH - 0.02, F2, FRONT - 1.2, FRONT)
rail_z(SOUTH - 1.18, F2, FRONT - 1.2, BACK)
rail_x(FRONT - 0.98, F3, TOWER, NORTH)
rail_z(NORTH - 0.02, F3, FRONT - 1.0, FRONT)
rail_z(SOUTH - 0.98, F3, FRONT + 2.8, BACK)

# ---------------------------------------------------------------- upper-floor openings (front)


def french_doors(x, base, zc, facing='-x', w=1.7, h=2.3):
    """Wood-framed double doors with dark glass, a mullion and a white ledge above."""
    d = -1 if facing == '-x' else 1
    k.box((x + d * 0.02, base + h / 2, zc), (0.06, h + 0.12, w + 0.12), *WOOD, group='openings')
    k.box((x + d * 0.05, base + h / 2, zc), (0.03, h - 0.1, w - 0.1), *GLASS_DARK, group='openings')
    k.box((x + d * 0.07, base + h / 2, zc), (0.03, h - 0.1, 0.07), *WOOD, group='openings')
    k.box((x + d * 0.1, base + h + 0.18, zc), (0.2, 0.08, w + 0.5), *WHITE, group='openings')


def small_window(x, y, zc, s=0.62):
    k.box((x - 0.02, y, zc), (0.06, s, s), *WOOD, group='openings')
    k.box((x - 0.05, y, zc), (0.03, s - 0.12, s - 0.12), *GLASS_DARK, group='openings')
    k.box((x - 0.1, y + s / 2 + 0.2, zc), (0.2, 0.07, s + 0.5), *WHITE, group='openings')


for base in (F2, F3):
    french_doors(FRONT, base + 0.02, 101.9)
    small_window(FRONT, base + 1.55, 104.9)
# KLMB Bldg. lettering left of the 3rd-floor aircon, over the small window.
k.text('KLMB', (FRONT - 0.04, F3 + 2.45, 104.35), 0.42, 'accent_klmb_blue', '#7f9cc8', depth=0.05)
k.text('Bldg.', (FRONT - 0.04, F3 + 1.98, 104.35), 0.26, 'accent_klmb_blue', '#7f9cc8', depth=0.05)
# Split aircon units: 3rd floor front (above the doors), 2nd floor north.
for (y, z) in ((F3 + 2.55, 103.0),):
    k.box((FRONT - 0.13, y, z), (0.24, 0.3, 0.85), 'aircon', '#eeeeea', group='props')
# Side elevation: French doors and small windows behind the balconies, in bays along the block.
for x in (146.0, 150.5, 155.0):
    for base in (F2, F3):
        k.box((x, base + 1.17, SOUTH - 0.02), (1.7, 2.3, 0.06), *WOOD, group='openings')
        k.box((x, base + 1.17, SOUTH - 0.05), (1.6, 2.2, 0.03), *GLASS_DARK, group='openings')
        k.box((x + 1.9, base + 1.55, SOUTH - 0.05), (0.5, 0.5, 0.04), *GLASS_DARK, group='openings')
# The north wall is blank but for a couple of small windows.
for x in (147.0, 153.0):
    for base in (F2, F3):
        k.box((x, base + 1.55, NORTH + 0.04), (0.6, 0.6, 0.06), *WOOD, group='openings')

# ---------------------------------------------------------------- the café storefront
GF = F2 - 0.45          # underside of the canopy band
# Glass bays (z0, z1) left to right as seen from the street; piers between are white wall.
BAYS = [(102.55, 105.75), (100.0, 102.55), (97.25, 99.35)]
for z0, z1 in BAYS:
    zc, w = (z0 + z1) / 2, z1 - z0
    k.box((FRONT - 0.03, GF / 2, zc), (0.04, GF, w), *CAFE_GLASS, group='storefront')
    for y in (0.06, 2.45, GF - 0.05):
        k.box((FRONT - 0.07, y, zc), (0.07, 0.07 if y > 0.1 else 0.12, w), *INK, group='storefront')
    n = 2 if w > 2.4 else 1
    for i in range(n + 1):
        k.box((FRONT - 0.07, GF / 2, z0 + w * i / n), (0.07, GF, 0.07), *INK, group='storefront')
# The door: right leaf of the middle bay, a pull handle.
k.box((FRONT - 0.07, 1.2, 100.95), (0.07, 2.4, 0.06), *INK, group='storefront')
k.box((FRONT - 0.12, 1.1, 100.85), (0.04, 0.55, 0.035), *STEEL, group='storefront')
# Warm interior read through the glass: pendant lamps, the counter wall, the menu board.
for z in (98.3, 101.2, 103.3, 105.0):
    k.box((FRONT - 0.0, 2.75, z), (0.02, 0.16, 0.16), 'lamp_pendant', '#ffd9a0', group='storefront')
k.box((FRONT - 0.005, 1.6, 104.2), (0.02, 1.0, 2.6), 'lamp_cafe_warm', '#b97a4a', group='storefront')
k.box((FRONT - 0.008, 0.55, 104.2), (0.02, 1.0, 2.6), 'wood_counter', '#3b2418', group='storefront')
k.box((FRONT - 0.005, 1.4, 98.3), (0.02, 1.4, 1.6), 'leaves', '#2f4a30', group='storefront')
# The Kyo panel: a small cream sign stuck on the glass by the door, logo in red-brown.
k.box((FRONT - 0.09, 2.15, 100.45), (0.02, 0.52, 0.34), 'lamp_kyo_panel', '#f4efe6', group='storefront')
k.text('KYŌ', (FRONT - 0.11, 2.2, 100.45), 0.09, 'accent_kyo_logo', '#7a2a1c', depth=0.01)
k.text('COFFEE', (FRONT - 0.11, 2.03, 100.45), 0.035, 'accent_kyo_logo', '#7a2a1c', depth=0.01)
# Downlights under the canopy.
for z in (98.0, 100.0, 102.0, 104.0):
    k.box((FRONT - 0.6, GF - 0.02, z), (0.14, 0.02, 0.14), 'lamp_downlight', '#fff0cc', group='storefront')
# Aircon at the south end of the front, at head height.
k.box((FRONT - 0.15, 2.3, 96.6), (0.28, 0.6, 0.8), 'aircon', '#eeeeea', group='props')

# The side's ground floor: tenant units in tan tile, glass doors, aircons.
x = FRONT + 1.4
for i, kind in enumerate(['aircon', 'door', 'tan', 'door', 'tan', 'door', 'tan', 'door']):
    if kind == 'door':
        k.box((x + 1.0, 1.25, SOUTH - 0.04), (1.6, 2.5, 0.04), *CAFE_GLASS, group='storefront')
        for dx in (0.2, 1.0, 1.8):
            k.box((x + dx, 1.25, SOUTH - 0.07), (0.06, 2.5, 0.05), *INK, group='storefront')
        k.box((x + 1.0, 2.55, SOUTH - 0.07), (1.7, 0.08, 0.05), *INK, group='storefront')
        x += 2.0
    elif kind == 'tan':
        k.box((x + 0.75, 1.6, SOUTH - 0.04), (1.5, 3.2, 0.06), *TAN, group='storefront')
        for y in (0.6, 1.2, 1.8, 2.4):
            k.box((x + 0.75, y, SOUTH - 0.075), (1.5, 0.02, 0.02), 'tile_line', '#9a7c48', group='storefront')
        x += 1.5
    else:
        k.box((x + 0.4, 1.9, SOUTH - 0.16), (0.8, 0.6, 0.28), 'aircon', '#eeeeea', group='props')
        x += 0.8

# ---------------------------------------------------------------- the apron and terrace
# Concrete apron to the street; the gravel driveway runs back past the side.
k.box((133.5, 0.01, 101.0), (14.2, 0.02, 22.0), *CONCRETE, group='ground')
k.box((149.0, 0.008, 90.6), (32.0, 0.02, 9.6), 'gravel', '#a49d90', group='ground')
k.box((158.0, 0.006, 83.0), (14.0, 0.02, 12.0), 'gravel', '#a49d90', group='ground')

CREAM = '#ece6d6'


def cafe_table(x, z):
    k.cyl((x, 0, z), 0.25, 0.04, 'frame_ink', '#141414', verts=12)
    k.cyl((x, 0, z), 0.035, 0.74, 'frame_ink', '#141414', verts=6)
    k.cyl((x, 0.72, z), 0.36, 0.04, 'frame_ink', '#141414', verts=14)


def folding_chair(x, z, face_deg):
    import math
    a = math.radians(face_deg)
    fx, fz = math.cos(a), math.sin(a)   # direction the sitter faces (layout x/z)
    k.box((x, 0.45, z), (0.42, 0.04, 0.42), 'chair_white', CREAM, group='props', rot_deg=face_deg)
    k.box((x - fx * 0.2, 0.75, z - fz * 0.2), (0.04, 0.55, 0.42), 'chair_white', CREAM, group='props',
          rot_deg=face_deg)
    for sx, sz in ((0.18, 0.18), (-0.18, 0.18), (0.18, -0.18), (-0.18, -0.18)):
        k.box((x + sx, 0.22, z + sz), (0.03, 0.45, 0.03), 'chair_white', CREAM, group='props')


# Three round tables tight against the glass, two white chairs each, facing along the front.
for (x, z) in ((138.6, 104.4), (138.7, 102.0), (138.5, 98.4)):
    cafe_table(x, z)
    folding_chair(x, z + 0.62, -90)
    folding_chair(x, z - 0.62, 90)
# The tall closed cream umbrella on its base, at the left table.
k.cyl((137.7, 0, 103.3), 0.28, 0.08, 'frame_ink', '#141414', verts=10)
k.cyl((137.7, 0, 103.3), 0.025, 2.9, 'steel', '#b8bcc0', verts=6)
k.cyl((137.7, 1.35, 103.3), 0.16, 1.4, 'umbrella_cream', '#e2d4b6', verts=10, radius2=0.04)
# Potted plants against the glass and by the door.
for (x, z, s) in ((139.9, 105.6, 1.0), (139.9, 99.6, 0.8), (139.9, 97.0, 1.1), (139.4, 100.1, 0.7)):
    k.cyl((x, 0, z), 0.22 * s, 0.4 * s, 'pot', '#5a5652', verts=8)
    k.ball((x, 0.55 * s + 0.2, z), 0.35 * s, 'leaves', '#3d5a3a', squash=1.3)

# Frontage: grey concrete bollards in a row toward the driveway, two slim pink posts.
for (x, z) in ((135.9, 97.6), (135.6, 96.2), (134.6, 95.1), (135.2, 99.1)):
    k.cyl((x, 0, z), 0.13, 0.6, *GREY, verts=10)
    k.collider((x, 0.3, z), (0.26, 0.6, 0.26))
for (x, z) in ((134.3, 103.0), (133.6, 99.6)):
    k.box((x, 0.02, z), (0.25, 0.04, 0.25), 'steel', '#b8bcc0', group='props')
    k.box((x, 0.6, z), (0.07, 1.2, 0.07), 'accent_kyo_pink', '#e7a7b3', group='props')
    k.box((x, 1.0, z), (0.075, 0.08, 0.075), 'wall_white', '#e9e7e1', group='props')
    k.collider((x, 0.6, z), (0.1, 1.2, 0.1))
# The thin dark post by the bollards (an old sign pole).
k.cyl((134.9, 0, 96.8), 0.05, 3.2, 'post', '#2a2a2a', verts=6)
# Parking A-frame at the street edge, facing the road.
for d in (-1, 1):
    k.box((127.9 + d * 0.12, 0.55, 104.6), (0.03, 1.1, 0.6), 'board', '#f2f0ea', group='props', rot_deg=0)
k.box((127.75, 0.65, 104.6), (0.01, 0.55, 0.45), 'board_face', '#dcdad2', group='props')
k.text('KLMB BLDG.', (127.73, 0.83, 104.6), 0.045, 'frame_ink', '#141414', depth=0.004)
k.text('TENANTS &', (127.73, 0.74, 104.6), 0.035, 'frame_ink', '#141414', depth=0.004)
k.text('CUSTOMERS', (127.73, 0.67, 104.6), 0.035, 'frame_ink', '#141414', depth=0.004)
k.text('PARKING', (127.73, 0.6, 104.6), 0.035, 'frame_ink', '#141414', depth=0.004)

# ---------------------------------------------------------------- north: motorcycle corner and next door


def steel_fence(x0, z0, x1, z1, h=2.0):
    """Black steel bar fence: top and bottom rails, vertical bars every 12 cm."""
    import math
    L = math.hypot(x1 - x0, z1 - z0)
    deg = math.degrees(math.atan2(z1 - z0, x1 - x0))
    cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
    for y in (0.1, h - 0.05, h * 0.55):
        k.box((cx, y, cz), (L, 0.05, 0.05), 'fence_black', '#1a1a1a', group='fences', rot_deg=deg)
    n = int(L / 0.12)
    for i in range(n + 1):
        t = i / n
        k.box((x0 + (x1 - x0) * t, h / 2, z0 + (z1 - z0) * t), (0.025, h, 0.025), 'fence_black', '#1a1a1a',
              group='fences')
    k.collider((cx, h / 2, cz), (L, h, 0.12), rot_deg=deg)


# The fence runs out from the building's front-left corner to the street and along it.
steel_fence(134.4, 106.4, 134.4, 112.2, 2.1)
steel_fence(134.4, 106.4, 140.6, 106.4, 2.1)
steel_fence(130.0, 112.4, 134.4, 112.4, 1.5)
# Two scooters parked inside.
for (x, z, deg, col) in ((136.6, 109.0, 200, '#1d1d1d'), (138.6, 109.6, 160, '#8a1f1f')):
    import math
    a = math.radians(deg)
    dx, dz = math.cos(a) * 0.62, math.sin(a) * 0.62
    for s in (-1, 1):
        k.cyl((x + dx * s, 0.0, z + dz * s), 0.26, 0.09, 'tire', '#151515', verts=12).rotation_euler = (
            math.pi / 2, 0, a)
    k.box((x, 0.5, z), (1.3, 0.35, 0.3), f'accent_scooter_{col[1:]}', col, group='props', rot_deg=deg)
    k.box((x - dx * 0.25, 0.78, z - dz * 0.25), (0.6, 0.1, 0.28), 'seat', '#1a1a1a', group='props', rot_deg=deg)
    k.box((x + dx * 0.9, 0.95, z + dz * 0.9), (0.08, 0.5, 0.6), 'steel', '#b8bcc0', group='props', rot_deg=deg)
# Next door's tall white gate pillars and canopy, and its white wall along the north.
for x in (130.6, 133.4):
    k.box((x, 3.0, 113.0), (0.7, 6.0, 0.7), *WHITE, group='nextdoor', collide=True)
k.box((132.0, 3.6, 113.0), (3.8, 0.3, 1.6), *WHITE, group='nextdoor')
k.box((132.0, 3.85, 113.0), (3.4, 0.2, 1.3), *WHITE, group='nextdoor')
k.box((147.0, 1.4, 113.2), (27.0, 2.8, 0.3), *WHITE, group='nextdoor', collide=True)
k.box((147.0, 2.85, 113.2), (27.2, 0.1, 0.4), *WHITE, group='nextdoor')

# ---------------------------------------------------------------- south: the lot gate and wall
# White perimeter wall along the far side of the driveway, back to the lot.
k.box((151.0, 1.3, 85.6), (40.0, 2.6, 0.25), *WHITE, group='lot', collide=True)
for x in range(132, 171, 3):
    k.box((x, 1.35, 85.6), (0.35, 2.7, 0.35), *WHITE, group='lot')
# The black steel gate at the street, swung open against the wall.
steel_fence(128.4, 86.0, 128.4, 88.6, 2.2)
steel_fence(128.6, 88.8, 131.0, 90.2, 2.2)
for z in (85.8, 88.8):
    k.box((128.4, 1.2, z), (0.18, 2.4, 0.18), 'fence_black', '#1a1a1a', group='lot', collide=True)

k.finish()
k.export()
if PREVIEW:
    PREVIEW.mkdir(parents=True, exist_ok=True)
    k.preview(PREVIEW / 'kyo_street.png', eye=(121.0, 1.7, 89.0), look=(145.0, 5.0, 102.0), lens=24)
    k.preview(PREVIEW / 'kyo_front.png', eye=(118.0, 1.7, 101.0), look=(145.0, 4.5, 101.0), lens=24)
    k.preview(PREVIEW / 'kyo_terrace.png', eye=(131.0, 1.6, 98.0), look=(140.0, 1.6, 103.0), lens=24)
