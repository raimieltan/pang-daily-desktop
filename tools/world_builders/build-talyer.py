"""Talyer ni Ruel, for the hub: Ruel's open-front shed on the barangay street.

Run headless: Blender --background --factory-startup --python tools/world_builders/build-talyer.py
Add `-- --preview <dir>` to render check images. Output: assets/world/talyer.glb.

From the Babylon greybox (`talyer()` in the old hubLayout.ts), whose placement it keeps: a 33 m
open-front shed facing the street (south, -z), hollow-block back and side walls, a rusty GI roof on
steel posts overhanging the apron. Left bay: a budget spray booth (washable panels, open front,
bright strips). Right bay: a two-post lift with a drive-in gap. Along the back: workbenches, a tool
cabinet, calendars, spare bumpers, an engine block, drums, tyre stacks, a stand fan, a welder.
East of the shed: the tambay corner (plastic chairs, a table, a cooler, beer crates) behind bollards,
and Ruel's errand corkboard on the bay wall. Tarp sign on posts at the street.
Layout units as in the Babylon hub (x east, y up, z north). GLB origin: (24, 0, 150), the middle of
the shed's open front.
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from kit import Kit  # noqa: E402

PREVIEW = Path(sys.argv[sys.argv.index('--preview') + 1]) if '--preview' in sys.argv else None

k = Kit('talyer', (24.0, 150.0))

ROOF_Y = 4.4
BLOCK = ('hollow_block', '#a39e92')
POST = ('post', '#5d6166')
RUST = ('accent_gi_rust', '#8a4f2c')
CONCRETE = ('concrete', '#b9b4aa')
OIL = ('concrete_oily', '#8d887e')
YELLOW = ('accent_lift_yellow', '#c49a32')
PANEL = ('booth_panel', '#d4d7cf')
INK = ('frame_ink', '#141414')
WOOD = ('wood', '#7a5434')

# ---------------------------------------------------------------- slab and shed
k.box((26, 0.01, 150), (42, 0.02, 10), *CONCRETE, group='ground')
k.box((24, 0.012, 160), (32, 0.02, 16), *OIL, group='ground')
k.box((45, 0.012, 157), (9, 0.02, 16), *CONCRETE, group='ground')
# Oil stains on the bay floor.
for (x, z, s) in ((16, 157, 1.6), (31.5, 158, 2.0), (27, 163, 1.0), (34, 154, 0.8)):
    k.box((x, 0.022, z), (s, 0.005, s * 0.7), 'stain', '#5b5750', group='ground', rot_deg=x * 17)

k.box((24, ROOF_Y / 2, 168.2), (33, ROOF_Y, 0.3), *BLOCK, group='building', collide=True)
for x in (7.8, 40.2):
    k.box((x, ROOF_Y / 2, 160), (0.3, ROOF_Y, 16.6), *BLOCK, group='building', collide=True)
# Block courses on the back wall, so the hollow blocks read in ink.
for y in (0.4, 0.8, 1.2, 1.6, 2.0, 2.4, 2.8, 3.2, 3.6, 4.0):
    k.box((24, y, 168.04), (33, 0.015, 0.01), 'block_line', '#7e796f', group='building')
# A painted stripe along the back wall at bench height.
k.box((24, 1.2, 168.03), (33, 0.3, 0.02), 'accent_wall_stripe', '#5a3c2a', group='building')

# Rusty GI roof: corrugations as thin ridges on a slab, sloping slightly to the back.
roof = k.box((24, ROOF_Y + 0.15, 159), (35, 0.08, 20), *RUST, group='roof')
for i in range(36):
    k.box((24 - 17.5 + i + 0.5, ROOF_Y + 0.21, 159), (0.08, 0.05, 20), 'gi_ridge', '#6d3d22', group='roof')
k.box((24, ROOF_Y + 0.05, 149.1), (35.2, 0.25, 0.12), *RUST, group='roof')
# Steel posts on the front and a beam.
for x in (8, 16, 24, 32, 40):
    k.box((x, ROOF_Y / 2, 150.4), (0.25, ROOF_Y, 0.25), *POST, group='building', collide=True)
k.box((24, ROOF_Y - 0.1, 150.4), (33, 0.22, 0.2), *POST, group='building')
# Bay divider stub wall.
k.box((24, 0.5, 164), (0.4, 1.0, 8), *BLOCK, group='building', collide=True)

# The shed name painted across the front beam.
k.text('TALYER NI RUEL', (24, ROOF_Y - 0.1, 150.27), 0.17, 'accent_sign_red', '#b8322a', facing='-y',
       depth=0.02)

# ---------------------------------------------------------------- left bay: budget spray booth
for x in (12.8, 19.2):
    k.box((x, 1.6, 161), (0.12, 3.2, 8), *PANEL, group='booth', collide=True)
    k.box((x + (0.08 if x < 16 else -0.08), 1.5, 161), (0.05, 0.15, 6), 'lamp_strip', '#f2f2d7', group='booth')
k.box((16, 1.6, 165), (6.5, 3.2, 0.12), *PANEL, group='booth', collide=True)
k.box((16, 3.25, 161), (6.5, 0.12, 8.1), 'booth_ceiling', '#c5c9c2', group='booth')
k.box((16, 2.6, 164.9), (1.5, 0.6, 0.06), 'booth_filter', '#505c59', group='booth')
k.box((16, 3.17, 160), (0.12, 0.05, 1.2), 'lamp_tube', '#f6f6e4', group='booth')
# Masking paper roll on a stand by the booth.
k.cyl((11.5, 0, 158.5), 0.03, 1.1, *POST)
k.cyl((11.5, 1.1, 158.5), 0.12, 0.5, 'paper', '#e8e2d0').rotation_euler = (0, math.pi / 2, 0)

# ---------------------------------------------------------------- right bay: two-post lift
for x in (28.5, 35.5):
    k.box((x, 1.5, 157), (0.3, 3.0, 0.3), *YELLOW, group='lift', collide=True)
    k.box((x, 0.03, 157), (0.6, 0.06, 0.6), *YELLOW, group='lift')
    for dz in (-0.8, 0.8):
        k.box((x + (0.6 if x < 32 else -0.6), 0.45, 157 + dz), (1.0, 0.06, 0.1), *YELLOW, group='lift')
k.box((32, 2.95, 157), (7.3, 0.15, 0.2), *YELLOW, group='lift')
for x in (31.2, 32.8):
    k.box((x, 0.04, 157), (0.32, 0.08, 5.5), 'track_steel', '#52575a', group='lift')

# Fluorescent battens under the roof.
for (x, z) in ((16, 158), (32, 158), (16, 152.5), (32, 152.5), (44, 153)):
    y = ROOF_Y - 0.25 if x < 41 else 2.8
    k.box((x, y, z), (0.1, 0.05, 1.25), 'lamp_tube', '#f6f6e4', group='lights')
    k.box((x, y + 0.04, z), (0.16, 0.03, 1.3), *POST, group='lights')

# ---------------------------------------------------------------- props along the back


def workbench(x, z):
    k.box((x, 0.9, z), (2.4, 0.08, 0.8), *WOOD, group='props')
    for dx in (-1.1, 1.1):
        for dz in (-0.33, 0.33):
            k.box((x + dx, 0.45, z + dz), (0.06, 0.9, 0.06), *POST, group='props')
    k.box((x, 0.25, z), (2.3, 0.04, 0.7), *WOOD, group='props')
    k.box((x - 0.6, 1.02, z), (0.5, 0.18, 0.25), 'accent_vise_blue', '#2a5cb0', group='props')
    k.box((x, 1.6, z + 0.38), (2.2, 1.0, 0.03), 'pegboard', '#8a7a62', group='props')
    for i in range(7):
        k.box((x - 0.9 + i * 0.3, 1.55 + (i % 2) * 0.15, z + 0.35), (0.04, 0.32, 0.02), *INK, group='props')


workbench(14, 167.2)
workbench(34, 167.2)
k.box((19, 0.7, 167.4), (1.0, 1.4, 0.55), 'accent_cabinet_red', '#a31f1f', group='props', collide=True)
for i in range(5):
    k.box((19, 0.25 + i * 0.25, 167.12), (0.9, 0.02, 0.01), *INK, group='props')
for (x, y) in ((11, 1.7), (29, 1.8)):
    k.box((x, y, 168.02), (0.45, 0.65, 0.02), 'calendar', '#f2efe6', group='props')
    k.box((x, y + 0.18, 168.0), (0.45, 0.25, 0.02), 'accent_calendar', '#d13a2a', group='props')
# Spare bumpers leaning on the back wall.
for (x, col) in ((36, '#a31f1f'), (31, '#dadddf')):
    k.box((x, 0.6, 167.75), (1.7, 0.45, 0.25), f'accent_bumper_{col[1:]}', col, group='props', rot_deg=0)
# Engine block on a pallet.
k.box((27, 0.08, 165), (1.2, 0.16, 1.0), *WOOD, group='props')
k.box((27, 0.55, 165), (0.8, 0.75, 0.6), 'engine', '#4a4d50', group='props')
k.box((27, 1.0, 165), (0.7, 0.18, 0.5), 'engine', '#3a3d40', group='props')


def drum(x, z, col):
    k.cyl((x, 0, z), 0.29, 0.88, f'accent_drum_{col[1:]}', col, verts=12)
    for y in (0.29, 0.58):
        k.cyl((x, y, z), 0.3, 0.03, 'drum_hoop', '#2a2a2a', verts=12)


drum(9.4, 166.8, '#2d4e7a')
drum(10.2, 167.1, '#7a4a2e')
drum(39, 163, '#2f5d3a')
for z in (163.6, 164.2):
    k.collider((39, 0.45, z), (0.6, 0.9, 0.6))


def tyre(x, y, z, upright=False, deg=0.0):
    t = k.cyl((x, y, z), 0.32, 0.22, 'tire', '#1a1a1a', verts=14)
    if upright:
        t.rotation_euler = (math.pi / 2, 0, math.radians(deg))
    return t


# Tyre stacks by the front corner and in the back.
for (x, z, n) in ((9.2, 153, 5), (9.3, 154.4, 4), (38.8, 166.5, 6)):
    for i in range(n):
        tyre(x + (i % 2) * 0.03, i * 0.22, z)
    k.collider((x, n * 0.11, z), (0.66, n * 0.22, 0.66))
for (z, deg) in ((161, 0), (162.2, 5)):
    tyre(10, 0.32, z, upright=True, deg=deg)
# Stand fan.
k.cyl((22.5, 0, 166), 0.22, 0.04, *POST, verts=10)
k.cyl((22.5, 0, 166), 0.02, 1.2, *POST, verts=6)
k.cyl((22.5, 1.2, 166), 0.25, 0.12, 'fan_cage', '#d8d8d4', verts=12).rotation_euler = (math.pi / 2, 0, 0.3)
# Welding set and a trolley jack in the lift bay.
k.box((38.5, 0.4, 158), (0.5, 0.6, 0.8), 'accent_welder_blue', '#2a4f8a', group='props')
k.box((28, 0.12, 155), (0.4, 0.15, 1.2), 'accent_jack_red', '#b8322a', group='props')
k.cyl((28, 0, 154.2), 0.02, 0.9, *POST, verts=6).rotation_euler = (math.radians(-40), 0, 0)

# ---------------------------------------------------------------- the tambay corner
k.box((45, 1.2, 165), (9, 2.4, 0.3), *BLOCK, group='building', collide=True)
k.box((44.5, 2.75, 157.5), (9, 0.08, 9), *RUST, group='roof')
for (x, z) in ((40.6, 153.2), (49.2, 153.2), (49.2, 161.8)):
    k.box((x, 1.36, z), (0.12, 2.72, 0.12), *POST, group='building')


def plastic_chair(x, z, deg, col):
    a = math.radians(deg)
    fx, fz = math.cos(a), math.sin(a)
    m = f'accent_chair_{col[1:]}'
    k.box((x, 0.42, z), (0.44, 0.04, 0.44), m, col, group='props', rot_deg=deg)
    k.box((x - fx * 0.21, 0.68, z - fz * 0.21), (0.04, 0.5, 0.44), m, col, group='props', rot_deg=deg)
    for sx, sz in ((0.19, 0.19), (-0.19, 0.19), (0.19, -0.19), (-0.19, -0.19)):
        k.box((x + sx, 0.21, z + sz), (0.04, 0.42, 0.04), m, col, group='props')


for (x, z, deg, col) in ((43, 155, 210, '#c23a2a'), (45.8, 155.5, 160, '#e7e4dc'), (44, 157.8, 250, '#2a5cb0'),
                         (45.6, 157.6, 300, '#c23a2a')):
    plastic_chair(x, z, deg, col)
k.box((44.6, 0.7, 156.5), (0.8, 0.04, 0.8), 'accent_table_white', '#e7e4dc', group='props')
k.cyl((44.6, 0, 156.5), 0.05, 0.7, 'accent_table_white', '#e7e4dc', verts=6)
k.box((47.5, 0.25, 159), (0.7, 0.5, 0.45), 'accent_cooler_blue', '#2a5cb0', group='props')
k.box((47.5, 0.52, 159), (0.72, 0.06, 0.47), 'cooler_lid', '#e7e4dc', group='props')
for i in range(3):
    k.box((47.8, 0.15 + i * 0.3, 161), (0.45, 0.3, 0.35), 'accent_crate_yellow', '#c9a227', group='props')
for x in (41, 44, 47):
    k.cyl((x, 0, 149.2), 0.12, 0.7, 'bollard', '#d8d6ce', verts=8)
    k.cyl((x, 0.55, 149.2), 0.125, 0.08, 'accent_sign_red', '#b8322a', verts=8)
    k.collider((x, 0.35, 149.2), (0.24, 0.7, 0.24))
# Ruel's errand corkboard on the bay's east wall, facing the waiting corner.
k.box((40.38, 1.55, 154), (0.06, 0.8, 1.1), 'cork', '#9a6b3f', group='props')
for (z, y) in ((153.75, 1.65), (154.25, 1.5)):
    k.box((40.42, y, z), (0.02, 0.3, 0.24), 'paper', '#f1ece0', group='props')

# ---------------------------------------------------------------- tarp sign at the street
for x in (1.0, 5.0):
    k.cyl((x, 0, 147), 0.05, 2.6, *POST, verts=6)
k.box((3.0, 2.0, 147), (4.2, 1.1, 0.02), 'tarp', '#e8e2d0', group='signs')
k.text('TALYER', (3.0, 2.25, 146.98), 0.34, 'accent_sign_red', '#b8322a', facing='-y', depth=0.01)
k.text('CHANGE OIL · TUNE UP · PINTURA', (3.0, 1.85, 146.98), 0.1, 'frame_ink', '#141414', facing='-y',
       depth=0.01)
k.text('VULCANIZING', (3.0, 1.65, 146.98), 0.1, 'accent_sign_blue', '#2a5cb0', facing='-y', depth=0.01)

k.finish()
k.export()
if PREVIEW:
    PREVIEW.mkdir(parents=True, exist_ok=True)
    k.preview(PREVIEW / 'talyer_street.png', eye=(10.0, 1.7, 136.0), look=(26.0, 2.0, 158.0), lens=22)
    k.preview(PREVIEW / 'talyer_bays.png', eye=(24.0, 1.7, 145.0), look=(24.0, 1.8, 165.0), lens=20)
