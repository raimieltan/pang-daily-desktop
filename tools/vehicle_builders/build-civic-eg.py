"""Banwa Hiraya EG: the 1991 Civic EG6 reference model in the Dalagan modular contract.

Run: Blender --background --factory-startup --python tools/vehicle_builders/build-civic-eg.py

Geometry is "1991 Honda Civic EG6" by rifdanzz (CC-BY-4.0, 1991_honda_civic_eg6/). The source
already ships its panels as separate objects, so faces are sorted by source object (then by side)
rather than by seam planes. Lamp colours come from the source's photo texture; the plate texture is
dropped for our plain plate. Shared steps live in modular_kit.py.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import modular_kit as kit  # noqa: E402

REF = kit.ROOT / '1991_honda_civic_eg6/scene.gltf'
OUT = kit.ROOT / 'assets/vehicles/civic_eg'

kit.start()
ref = kit.import_reference(REF)
# Source units: wheel centres at Z 247.2 / -269.1, tire contact at Y -90.9.
fit = kit.Fit(front_z=247.185, rear_z=-269.135, ground_y=-90.91)
kit.set_wheels({
    name: [p for o in ref if o.name.startswith('Circle') for p in kit.world_points(o, fit)
           if p[0] * sx > 0 and p[2] * sz > 0]
    for name, sx, sz in (('wheel_fl', 1, 1), ('wheel_fr', -1, 1), ('wheel_rl', 1, -1), ('wheel_rr', -1, -1))
})


def lamp(rgb, rear):
    r, g, b = rgb
    if min(rgb) > 0.95:
        return 'taillight' if rear else 'headlight'   # the texture's white margin, not a lens
    if r > 0.45 and 0.22 < g < 0.75 and b < 0.35 and r - b > 0.35:
        return 'amber'
    if r > 0.3 and g < 0.22 and b < 0.25:
        return 'taillight' if rear else 'amber'
    return 'reverse' if rear else 'headlight'


# Source object (name prefix) -> node, material. A node with {s} gets the side: l/r.
RULES = [
    ('Circle', None, None),                                        # wheels: tire / rim
    ('Plane.001', 'trunk_stock', 'plate'),                         # rear plate sits on the hatch
    ('Plane.002', 'bumper_front_stock', 'plate'),
    ('Cube_', 'bumper_rear_stock', 'chrome'),                      # exhaust
    ('front fender.001', 'shell_base', 'trim'),                    # side moulding
    ('front fender_Material.002', 'shell_base', 'trim'),           # arch liners
    ('front fender_', 'fender_f{s}_stock', 'paint'),
    ('frontbumper.001', 'hood_stock', 'paint'),
    ('frontbumper.003', 'lip_front_stock', 'paint'),
    ('frontbumper.004', 'chin_front_stock', 'paint'),
    ('frontbumper.005', 'bumper_front_stock', 'trim'),             # grille and lower intake
    ('frontbumper_', 'bumper_front_stock', 'paint'),
    ('lampudepan', 'headlight_{s}', 'lamp'),
    ('lampuseindepan', 'indicator_{n}', 'lamp'),
    ('mainbody.001_Window', 'windshield', 'glass'),
    ('mainbody.002_Window', 'window_front_{n}', 'glass'),
    ('mainbody.003_Window', 'window_rear_{n}', 'glass'),
    ('mainbody.004', 'taillight_{s}', 'lamp'),
    ('mainbody.007_Material.001', 'mirror_{s}', 'chrome'),
    ('mainbody.007', 'mirror_{s}', 'trim'),
    ('mainbody_Car', 'shell_base', 'paint'),
    ('mainbody', 'shell_base', 'trim'),                            # cowl, frames, pillars, surrounds
    ('rear bumper', 'bumper_rear_stock', 'paint'),
    ('sideskirt', 'sideskirt_{s}_stock', 'paint'),
    ('spoiler', 'spoiler_rear_stock', 'paint'),
    ('trunk.001_Window', 'rear_glass', 'glass'),
    ('trunk.001', 'shell_base', 'trim'),
    ('trunk_', 'trunk_stock', 'paint'),
]


def classify(f):
    side = 'l' if f.c[0] > 0 else 'r'
    for prefix, node, mat in RULES:
        if not f.src.startswith(prefix):
            continue
        if prefix == 'Circle':
            return kit.wheel_of(f.c), ('tire' if 'Material.005' in f.src else 'rim')
        if mat == 'lamp':
            mat = lamp(f.rgb, f.c[2] < 0)
            if mat == 'reverse' and abs(f.c[0]) > 0.6:
                mat = 'taillight'   # the reverse lens is the inner lower block only
            if node.startswith('headlight') and mat == 'amber':
                node = 'indicator_{n}'
        return node.format(s=side, n='1' if f.c[0] > 0 else '-1'), mat
    raise ValueError('unclassified source object ' + f.src)


for o in ref:
    kit.add_reference(o, fit, classify)
kit.remove(ref)

floor = kit.fit_engine('hood_stock')
hood_lo, hood_hi = kit.bbox(kit.PARTS['hood_stock'][0])
kit.engine_bay(-0.58, 0.58, min(floor - 0.02, 0.3), hood_lo[1] - 0.01, hood_lo[2] + 0.02, hood_hi[2] - 0.12)

kit.finish(OUT, 'civic_eg_modular',
           design='Banwa Hiraya EG (Civic EG6) / reference geometry, Dalagan modular contract',
           credit='Based on "1991 Honda Civic EG6" by rifdanzz, CC-BY-4.0, '
                  'https://sketchfab.com/3d-models/1991-honda-civic-eg6-f81da34570b145deb463fa091604d251',
           preview_title='Hiraya EG', smooth_angle=32)
