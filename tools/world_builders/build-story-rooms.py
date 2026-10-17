"""Story mode's rooms: the clinic, Pang's rented room and Jolo's family home (docs/story, S14, S32).

Run headless: Blender --background --factory-startup --python tools/world_builders/build-story-rooms.py
Add `-- --preview <dir>` to render check images. Output: assets/world/story_{clinic,rented_room,jolo_home}.glb.

Each is a stage set, not a building: a floor, three walls and what is in the room, open on the south
side (-z) where the story camera stands (scenes/story_room.gd frames them); the room scene's
lamps light it. Layout units (x east, y up, z north), metres; the
GLB origin is the middle of the open side, on the floor.
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from kit import Kit  # noqa: E402

PREVIEW = Path(sys.argv[sys.argv.index('--preview') + 1]) if '--preview' in sys.argv else None
H = 2.7
FRONT = 2.2
INK = ('frame_ink', '#141414')
POST = ('post', '#5d6166')
WOOD = ('wood', '#7a5434')
DARK_WOOD = ('wood_dark', '#4a3524')
PAPER = ('paper', '#f1ece0')
SHEET = ('bed_sheet', '#e4e1d8')


def shell(k, w, d, wall, floor, tiles=None):
    """Floor, ceiling, back and side walls (w wide, d deep), a skirting line and floor tile joints.
    Floor, ceiling and side walls run FRONT metres out past the open side, round the camera, so
    no sky shows at the edges of the frame."""
    z0 = -FRONT
    k.box((0, -0.01, (z0 + d) / 2), (w + 0.4, 0.02, d - z0 + 0.4), *floor, group='room')
    k.box((0, H + 0.05, (z0 + d) / 2), (w + 0.4, 0.1, d - z0 + 0.4), 'ceiling', '#bdb8ac', group='room')
    k.box((0, H / 2, d + 0.06), (w + 0.24, H, 0.12), *wall, group='room')
    for x in (-w / 2 - 0.06, w / 2 + 0.06):
        k.box((x, H / 2, (z0 + d) / 2), (0.12, H, d - z0 + 0.24), *wall, group='room')
    k.box((0, 0.05, d - 0.005), (w, 0.1, 0.01), 'skirting', '#6b665c', group='room')
    for x in (-w / 2 + 0.005, w / 2 - 0.005):
        k.box((x, 0.05, d / 2), (0.01, 0.1, d), 'skirting', '#6b665c', group='room')
    if tiles:
        n = int(w / tiles)
        for i in range(1, n + 1):
            k.box((-w / 2 + i * tiles, 0.002, d / 2), (0.012, 0.004, d), 'tile_joint', '#8d887e', group='room')
        for j in range(1, int(d / tiles) + 1):
            k.box((0, 0.002, j * tiles), (w, 0.004, 0.012), 'tile_joint', '#8d887e', group='room')


def window(k, x, y, z, w, h, facing='back', slats=True):
    """A window in a wall: frame, sill, jalousie slats (or grille bars), night beyond."""
    if facing == 'back':
        k.box((x, y, z - 0.02), (w, h, 0.02), 'lamp_window_night', '#2a2d33', group='windows')
        for (cx, sx) in ((x - w / 2, 0.06), (x + w / 2, 0.06)):
            k.box((cx, y, z - 0.05), (sx, h + 0.06, 0.06), *DARK_WOOD, group='windows')
        for cy in (y - h / 2, y + h / 2):
            k.box((x, cy, z - 0.05), (w + 0.06, 0.06, 0.06), *DARK_WOOD, group='windows')
        k.box((x, y - h / 2 - 0.04, z - 0.1), (w + 0.16, 0.04, 0.14), *DARK_WOOD, group='windows')
        if slats:
            for i in range(int(h / 0.11)):
                k.box((x, y - h / 2 + 0.08 + i * 0.11, z - 0.07), (w - 0.06, 0.012, 0.09), 'glass_slat',
                      '#b9bec4', group='windows')
        else:
            for i in range(1, 6):
                k.box((x - w / 2 + i * w / 6, y, z - 0.08), (0.02, h, 0.02), *INK, group='windows')


def chair(k, x, z, deg, col, name):
    """Monobloc plastic chair facing `deg` (0 = +x)."""
    a = math.radians(deg)
    fx, fz = math.cos(a), math.sin(a)
    m = f'accent_chair_{name}'
    k.box((x, 0.42, z), (0.44, 0.04, 0.44), m, col, group='props', rot_deg=-deg)
    k.box((x - fx * 0.21, 0.68, z - fz * 0.21), (0.04, 0.5, 0.44), m, col, group='props', rot_deg=-deg)
    for sx, sz in ((0.19, 0.19), (-0.19, 0.19), (0.19, -0.19), (-0.19, -0.19)):
        k.box((x + sx, 0.21, z + sz), (0.04, 0.42, 0.04), m, col, group='props')


def stand_fan(k, x, z, deg=0.0):
    k.cyl((x, 0, z), 0.2, 0.04, *POST, verts=10)
    k.cyl((x, 0, z), 0.02, 1.15, *POST, verts=6)
    k.cyl((x, 1.15, z), 0.24, 0.1, 'fan_cage', '#d8d8d4', verts=14).rotation_euler = (math.pi / 2, 0, math.radians(deg))


# ================================================================= the clinic
def clinic():
    k = Kit('story_clinic', (0.0, 0.0))
    w, d = 4.6, 3.8
    shell(k, w, d, ('clinic_wall', '#d9dcd6'), ('clinic_floor', '#c3c2bb'), tiles=0.5)
    # A green dado band, hospital style, and the oxygen rail behind the bed.
    k.box((0, 0.6, d - 0.005), (w, 1.2, 0.01), 'clinic_dado', '#a3ab9e', group='room')
    k.box((-0.6, 1.45, d - 0.02), (2.2, 0.12, 0.04), *POST, group='room')
    for x in (-1.2, -0.4):
        k.box((x, 1.45, d - 0.05), (0.08, 0.08, 0.06), 'accent_gas_green', '#3d7a4a', group='room')
    window(k, 1.5, 1.6, d, 1.2, 1.0)
    # The bed: steel frame and rails, a thin mattress, the patient's blanket thrown back.
    bx, bz = -0.6, 2.4
    k.box((bx, 0.55, bz), (1.0, 0.08, 2.0), *POST, group='bed')
    for (dx, dz) in ((-0.45, -0.95), (0.45, -0.95), (-0.45, 0.95), (0.45, 0.95)):
        k.box((bx + dx, 0.28, bz + dz), (0.05, 0.56, 0.05), *POST, group='bed')
    k.box((bx, 0.66, bz), (0.94, 0.14, 1.94), *SHEET, group='bed')
    k.box((bx, 0.8, bz + 0.75), (0.6, 0.12, 0.35), 'pillow', '#f0eee8', group='bed')
    k.box((bx + 0.05, 0.76, bz - 0.3), (0.96, 0.06, 1.0), 'blanket', '#9aa3a8', group='bed', rot_deg=4)
    k.box((bx, 0.95, bz + 1.0), (1.0, 0.8, 0.05), *POST, group='bed')
    for side in (-1, 1):
        k.box((bx + side * 0.52, 0.9, bz + 0.2), (0.03, 0.04, 1.2), *POST, group='bed')
    # IV stand with its bag, a bedside cabinet with a cup and a phone, a plastic chair, a curtain rail.
    k.cyl((0.2, 0, 3.0), 0.22, 0.03, *POST, verts=5)
    k.cyl((0.2, 0, 3.0), 0.015, 1.9, *POST, verts=6)
    k.box((0.2, 1.75, 3.0), (0.16, 0.24, 0.04), 'iv_bag', '#dfe6e8', group='props')
    k.box((-1.6, 0.4, 3.2), (0.5, 0.8, 0.45), 'cabinet', '#c9c7bf', group='props')
    k.cyl((-1.7, 0.8, 3.15), 0.04, 0.1, 'cup', '#f2f0ea', verts=8)
    k.box((-1.5, 0.81, 3.25), (0.08, 0.012, 0.15), *INK, group='props')
    chair(k, 0.9, 1.6, 200, '#2a5cb0', 'blue')
    k.box((-2.0, 2.45, 1.6), (0.03, 0.03, 3.0), *POST, group='room')
    for i in range(9):
        k.box((-2.0, 1.35, 0.3 + i * 0.16), (0.03, 2.1, 0.12), 'curtain', '#b7c1bb', group='props', rot_deg=(i % 2) * 25)
    # Wall clock and the fluorescent tube above the bed.
    k.cyl((1.5, 2.35, d - 0.02), 0.16, 0.03, 'clock', '#f2f0ea', verts=16).rotation_euler = (math.pi / 2, 0, 0)
    k.box((1.5, 2.35, d - 0.06), (0.012, 0.11, 0.01), *INK, group='props')
    k.box((-0.6, 2.6, 2.4), (1.2, 0.05, 0.1), 'lamp_tube', '#f6f6e4', group='props')
    k.finish()
    k.export()
    if PREVIEW:
        k.preview(PREVIEW / 'clinic.png', eye=(1.4, 1.5, -1.6), look=(-0.6, 0.9, 2.4), lens=22)


# ================================================================= Pang's rented room
def rented_room():
    k = Kit('story_rented_room', (0.0, 0.0))
    w, d = 3.6, 3.2
    shell(k, w, d, ('room_wall', '#c9c1b0'), ('room_floor', '#8c8478'), tiles=0.3)
    # Water stain down the back wall, a calendar, a hook with a shirt.
    k.box((-1.2, 1.9, d - 0.004), (0.5, 0.9, 0.008), 'wall_stain', '#a39a88', group='room')
    k.box((0.35, 1.75, d - 0.01), (0.4, 0.55, 0.02), 'calendar', '#f2efe6', group='props')
    k.box((0.35, 1.93, d - 0.02), (0.4, 0.2, 0.02), 'accent_calendar', '#d13a2a', group='props')
    k.box((1.75, 1.55, 1.6), (0.04, 0.8, 0.55), 'shirt', '#5a5f66', group='props')
    window(k, -0.8, 1.55, d, 1.0, 0.9)
    # A single bed against the left wall, sheet half off, pillow.
    bx, bz = -1.25, 1.6
    k.box((bx, 0.2, bz), (0.95, 0.4, 1.95), *DARK_WOOD, group='bed')
    k.box((bx, 0.48, bz), (0.9, 0.16, 1.9), *SHEET, group='bed')
    k.box((bx, 0.62, bz + 0.72), (0.55, 0.1, 0.35), 'pillow', '#f0eee8', group='bed')
    k.box((bx + 0.15, 0.58, bz - 0.35), (0.85, 0.05, 0.9), 'blanket', '#6d6a63', group='bed', rot_deg=-8)
    k.box((bx + 0.5, 0.35, bz - 0.4), (0.04, 0.5, 0.7), 'blanket', '#6d6a63', group='bed', rot_deg=-6)
    # A small table: bills, an envelope, the phone face up, a pill bottle; a monobloc chair.
    tx, tz = 0.9, 2.5
    k.box((tx, 0.72, tz), (1.0, 0.04, 0.6), *WOOD, group='props')
    for (dx, dz) in ((-0.45, -0.25), (0.45, -0.25), (-0.45, 0.25), (0.45, 0.25)):
        k.box((tx + dx, 0.36, tz + dz), (0.04, 0.72, 0.04), *WOOD, group='props')
    for i, (dx, dz, r) in enumerate(((-0.25, 0.0, 8), (-0.1, 0.08, -14), (0.05, -0.05, 22))):
        k.box((tx + dx, 0.745 + i * 0.002, tz + dz), (0.21, 0.002, 0.29), *PAPER, group='props', rot_deg=r)
    k.box((tx + 0.3, 0.75, tz + 0.05), (0.08, 0.01, 0.16), *INK, group='props', rot_deg=10)
    k.box((tx + 0.3, 0.756, tz + 0.05), (0.065, 0.002, 0.13), 'lamp_phone', '#cfd6e0', group='props', rot_deg=10)
    k.cyl((tx + 0.42, 0.74, tz - 0.15), 0.03, 0.09, 'accent_pills', '#c26a2a', verts=8)
    chair(k, tx - 0.1, tz - 0.6, 90, '#c23a2a', 'red')
    stand_fan(k, 1.4, 0.8, -30)
    # A bare bulb on its flex and a door in the right wall.
    k.cyl((0.0, 2.3, 1.6), 0.006, 0.4, *INK, verts=4)
    k.ball((0.0, 2.28, 1.6), 0.06, 'lamp_bulb', '#ffe2a8')
    k.box((w / 2 - 0.004, 1.0, 2.6), (0.01, 2.0, 0.85), *DARK_WOOD, group='room')
    k.cyl((w / 2 - 0.03, 1.0, 2.3), 0.025, 0.04, *POST, verts=8).rotation_euler = (0, math.pi / 2, 0)
    k.finish()
    k.export()
    if PREVIEW:
        k.preview(PREVIEW / 'rented_room.png', eye=(0.8, 1.45, -1.4), look=(-0.4, 0.8, 2.0), lens=22)


# ================================================================= Jolo's family home
def jolo_home():
    k = Kit('story_jolo_home', (0.0, 0.0))
    w, d = 5.2, 4.0
    shell(k, w, d, ('home_wall', '#d6cfc0'), ('home_floor', '#a8a092'), tiles=0.4)
    window(k, 1.25, 1.5, d, 1.4, 1.1, slats=False)
    # The sala: a wooden sofa with cushions, a low table, a rattan chair.
    sx, sz = -0.6, 3.2
    k.box((sx, 0.4, sz), (2.0, 0.08, 0.7), *WOOD, group='props')
    k.box((sx, 0.75, sz + 0.33), (2.0, 0.6, 0.06), *WOOD, group='props')
    for dx in (-0.97, 0.97):
        k.box((sx + dx, 0.55, sz), (0.06, 0.3, 0.7), *WOOD, group='props')
        for dz in (-0.3, 0.3):
            k.box((sx + dx, 0.2, sz + dz), (0.06, 0.4, 0.06), *WOOD, group='props')
    for dx in (-0.5, 0.5):
        k.box((sx + dx, 0.5, sz - 0.02), (0.9, 0.12, 0.6), 'cushion', '#8f8a80', group='props')
    k.box((sx, 0.42, 2.0), (1.1, 0.04, 0.6), *DARK_WOOD, group='props')
    for (dx, dz) in ((-0.5, -0.25), (0.5, -0.25), (-0.5, 0.25), (0.5, 0.25)):
        k.box((sx + dx, 0.2, 2.0 + dz), (0.04, 0.4, 0.04), *DARK_WOOD, group='props')
    k.box((sx + 0.2, 0.445, 2.0), (0.45, 0.005, 0.3), 'doily', '#efe9db', group='props')
    # The files Pang brought, on the table.
    k.box((sx - 0.25, 0.46, 2.05), (0.24, 0.03, 0.32), 'accent_folder', '#c9a227', group='props', rot_deg=6)
    k.box((sx - 0.2, 0.47, 1.9), (0.06, 0.01, 0.08), *INK, group='props')
    # Against the left wall: the cabinet with the memorial, Jolo's photograph between candles, flowers.
    cx, cz = -w / 2 + 0.3, 1.6
    k.box((cx, 0.45, cz), (0.5, 0.9, 1.4), *DARK_WOOD, group='altar')
    k.box((cx + 0.1, 0.92, cz), (0.32, 0.04, 1.3), 'doily', '#efe9db', group='altar')
    k.box((cx + 0.02, 1.15, cz), (0.04, 0.42, 0.34), *INK, group='altar', rot_deg=0)
    k.box((cx + 0.045, 1.15, cz), (0.01, 0.34, 0.26), 'photo_jolo', '#bcb6aa', group='altar')
    for dz in (-0.35, 0.35):
        k.cyl((cx + 0.15, 0.94, cz + dz), 0.03, 0.2, 'candle', '#f4efe2', verts=8)
        k.ball((cx + 0.15, 1.17, cz + dz), 0.022, 'lamp_flame', '#ffb347', squash=1.6)
    k.cyl((cx + 0.15, 0.94, cz - 0.55), 0.06, 0.18, 'vase', '#5d6166', verts=10)
    for i in range(5):
        k.ball((cx + 0.15 + (i % 2) * 0.05, 1.18 + (i % 3) * 0.04, cz - 0.55 + (i - 2) * 0.04), 0.045,
               'accent_flower_white', '#f2efe6')
    # Family pictures on the back wall; a Santo Niño shelf; a clock.
    for (x, y, sw, sh) in ((-1.6, 1.9, 0.4, 0.5), (-1.05, 1.95, 0.3, 0.4), (-0.4, 1.85, 0.5, 0.35), (0.25, 1.95, 0.3, 0.4)):
        k.box((x, y, d - 0.015), (sw, sh, 0.03), *INK, group='props')
        k.box((x, y, d - 0.035), (sw - 0.06, sh - 0.06, 0.01), 'photo', '#a7a194', group='props')
    k.box((2.2, 1.6, d - 0.12), (0.4, 0.03, 0.22), *DARK_WOOD, group='props')
    k.cyl((2.2, 1.615, d - 0.12), 0.06, 0.3, 'accent_santo_nino', '#b8322a', verts=8, radius2=0.03)
    k.cyl((-2.1, 2.2, d - 0.02), 0.15, 0.03, 'clock', '#f2f0ea', verts=16).rotation_euler = (math.pi / 2, 0, 0)
    # The fan clicking in the corner, a TV on a stand, a doorway to the kitchen.
    stand_fan(k, 1.9, 1.2, 210)
    k.box((w / 2 - 0.3, 0.3, 3.3), (0.45, 0.6, 1.0), *DARK_WOOD, group='props')
    k.box((w / 2 - 0.3, 0.85, 3.3), (0.08, 0.5, 0.9), *INK, group='props')
    k.box((w / 2 - 0.01, 1.05, 2.1), (0.012, 2.2, 1.05), *DARK_WOOD, group='room')
    k.box((w / 2 - 0.02, 1.05, 2.1), (0.012, 2.1, 0.95), 'lamp_doorway', '#e8e0c8', group='room')
    k.finish()
    k.export()
    if PREVIEW:
        k.preview(PREVIEW / 'jolo_home.png', eye=(1.2, 1.5, -1.6), look=(-0.8, 0.9, 2.2), lens=20)


if PREVIEW:
    PREVIEW.mkdir(parents=True, exist_ok=True)
clinic()
rented_room()
jolo_home()
