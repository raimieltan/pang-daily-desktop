"""Civic FD: the 2007 Civic Type R FD2 reference model in the Dalagan modular contract.

Run: Blender --background --factory-startup --python tools/vehicle_builders/build-civic-fd.py

Geometry is "2007 Honda Civic Type R FD2" by claries (CC-BY-4.0, 2007_honda_civic_type_r_fd2/).
The source lies along +X, so it is turned to face +Z before fitting. Its painted body is one
object, so (like the Evo) the body is cut along straight seam planes and faces are sorted by
position; glass, trim, lamps, grille, wing blade, tires and rims come from their own source
objects. Texture colours pick lamp lenses only; the badge and grille logo collapse to chrome.
Shared steps live in modular_kit.py.
"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix

sys.path.insert(0, str(Path(__file__).resolve().parent))
import modular_kit as kit  # noqa: E402

REF = kit.ROOT / '2007_honda_civic_type_r_fd2/scene.gltf'
OUT = kit.ROOT / 'assets/vehicles/civic-fd'

kit.start()
ref = kit.import_reference(REF)
top = next(o for o in kit._IMPORTED if o.parent is None)
top.matrix_world = Matrix.Rotation(-math.pi / 2, 4, 'Z') @ top.matrix_world   # nose +X -> +Z
bpy.context.view_layer.update()
OBJ = {o.name: o for o in ref}

# Axles from the rims (source units, after the turn); tire contact is at Y 0.
raw = kit.world_points(OBJ['Object_12'], lambda p: p)
cx = sum(p[0] for p in raw) / len(raw)
cz = sum(p[2] for p in raw) / len(raw)
quad = {}
for sx, sz in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
    lo, hi = kit.bbox([p for p in raw if (p[0] - cx) * sx > 0 and (p[2] - cz) * sz > 0])
    quad[sx, sz] = [(lo[i] + hi[i]) / 2 for i in range(3)]
front_z = (quad[1, 1][2] + quad[-1, 1][2]) / 2
rear_z = (quad[1, -1][2] + quad[-1, -1][2]) / 2
centre_x = sum(q[0] for q in quad.values()) / 4
fit = kit.Fit(front_z=front_z, rear_z=rear_z, ground_y=0.0, centre_x=centre_x)
rims = kit.world_points(OBJ['Object_12'], fit)
kit.set_wheels({
    name: [p for p in rims if p[0] * sx > 0 and p[2] * sz > 0]
    for name, sx, sz in (('wheel_fl', 1, 1), ('wheel_fr', -1, 1), ('wheel_rl', 1, -1), ('wheel_rr', -1, -1))
})
TIRE_R = 0.31


def tire_of(c):
    w = kit.wheel_of(c)
    if w and math.hypot(c[1] - kit.WHEELS[w][1], c[2] - kit.WHEELS[w][2]) < TIRE_R \
            and abs(c[0]) > abs(kit.WHEELS[w][0]) - 0.16:
        return w
    return None


# Straight cuts through the painted body so every removable panel ends on a clean edge.
SEAMS = [((x, 0, 0), (1, 0, 0)) for x in (0.70, -0.70, 0.62, -0.62)] + \
        [((0, 0, z), (0, 0, 1)) for z in (1.32, 1.66, 0.76, 0.92, -0.86, -1.60, -1.69)] + \
        [((0, y, 0), (0, 1, 0)) for y in (0.19, 0.26, 0.58, 0.62, 0.86, 1.00)]


def body_node(c, n):
    """Slot part or fixed node for a painted or black-trim body face, by position."""
    x, y, z = c
    ax = abs(x)
    side = 'l' if x > 0 else 'r'
    if ax > 0.74 and 0.78 < y < 1.0 and 0.45 < z < 0.80:
        return 'mirror_' + side
    if y > 1.0 and z < -1.69:
        return 'spoiler_rear_stock'
    if z > 1.66 and y < 0.58:
        if y < 0.19:
            return 'chin_front_stock' if ax < 0.35 else 'lip_front_stock'
        return 'bumper_front_stock'
    if z < -1.60 and y < 0.62:
        return 'bumper_rear_stock'
    if z > 1.32 and ax < 0.70 and y > 0.58:
        return 'hood_stock'
    if z < -1.69 and ax < 0.62 and y > 0.86 and n[1] > 0.3:
        return 'trunk_stock'
    if y < 0.26 and ax > 0.62 and -0.86 < z < 0.92:
        return 'sideskirt_' + side + '_stock'
    if 0.76 < z <= 1.66 and 0.26 <= y < 0.86 and (ax >= 0.70 or y < 0.58):
        return 'fender_f' + side + '_stock'
    return 'shell_base'


def classify(f):
    src, (x, y, z), (r, g, b) = f.src, f.c, f.rgb
    side = 'l' if x > 0 else 'r'
    lum = (r + g + b) / 3
    if src == 'Object_11':                      # tires, plus black body trim
        w = tire_of(f.c)
        return (w, 'tire') if w else (body_node(f.c, f.n), 'trim')
    if src == 'Object_12':
        return kit.wheel_of(f.c), ('rim' if lum > 0.55 and r - b < 0.15 else 'rim_dark')
    if src == 'Object_3':
        return body_node(f.c, f.n), 'paint'
    if src == 'Object_2':                       # mirror glass
        return 'mirror_' + side, 'chrome'
    if src == 'Object_5':                       # wing blade
        return 'spoiler_rear_stock', 'paint'
    if src == 'Object_6':                       # pillars, drip rails, cowl
        return 'shell_base', 'trim'
    if src == 'Object_7':
        if z > 0.9 and abs(x) < 0.66 and f.n[2] > 0.05:
            return 'windshield', 'glass'
        if z < -0.9 and abs(x) < 0.66 and f.n[2] < -0.05:
            return 'rear_glass', 'glass'
        return ('window_front_' if z > -0.25 else 'window_rear_') + ('1' if x > 0 else '-1'), 'glass'
    if src == 'Object_8':
        return 'headlight_' + side, 'headlight'
    if src == 'Object_4':                       # bumper intake mesh / side repeaters
        if z > 1.9:
            return 'bumper_front_stock', 'trim'
        return 'fender_f' + side + '_stock', 'amber'
    if src == 'Object_10':                      # grille bar (badge dropped to chrome)
        return 'bumper_front_stock', 'chrome'
    if src == 'Object_9':
        if r - g > 0.15:
            return 'taillight_' + side, 'taillight'
        return 'taillight_' + side, 'reverse' if lum > 0.4 else 'taillight'
    if src == 'Object_13':
        return 'bumper_rear_stock', 'chrome'
    raise ValueError('unclassified source object ' + src)


for o in ref:
    kit.add_reference(o, fit, classify, seams=SEAMS if o.name in ('Object_3', 'Object_11') else ())
kit.remove(ref)

floor = kit.fit_engine('hood_stock')
hood_lo, hood_hi = kit.bbox(kit.PARTS['hood_stock'][0])
kit.engine_bay(-0.62, 0.62, min(floor - 0.02, 0.3), hood_lo[1] - 0.01, hood_lo[2] + 0.02, hood_hi[2] - 0.12)

kit.finish(OUT, 'civic_fd_2007_modular',
           design='Civic FD (2007 Civic Type R FD2) / reference geometry, Dalagan modular contract',
           credit='Based on "2007 Honda Civic Type R FD2" by claries, CC-BY-4.0, '
                  'https://sketchfab.com/3d-models/2007-honda-civic-type-r-fd2-7da33a4102b848d5abe7f3bb7c445f46',
           preview_title='Civic FD', smooth_angle=35)
