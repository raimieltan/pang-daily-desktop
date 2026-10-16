"""Banwa Dalagan GSR: the Evo V reference model cut into the Dalagan modular contract.

Run: Blender --background --factory-startup --python tools/vehicle_builders/build-dalagan-evo.py

Geometry is "Mitsubishi Lancer Evolution 5 Stylized Toon" by Ponter (CC-BY-4.0,
reference-assets/mitsubishi_lancer_evolution_5_stylized_toon/). This builder:
  * fits it to our axles (front Z 1.28, rear Z -1.22) with a small lengthwise scale,
  * reads each face's palette colour and maps it to our named materials (paint, glass, trim,
    tire, rim, lamps...) so MangaArt's car shader colours it; the baked toon shades collapse to
    one `paint`, which is what lets the player's paint colour apply,
  * cuts faces into the removable slots (hood, fenders, bumpers, skirts, trunk, wing, lip, chin)
    under attach frames, plus the fixed detail nodes CarVisual looks up (headlight_l/r,
    taillight_l/r, wheel_fl/fr/rl/rr),
  * flat-shades everything, keeps the Dalagan engine bay, exports, validates.
Coordinates in this file are the glTF frame: X = vehicle left, Y up, Z forward. Metres.
"""
import bpy
import bmesh
import json
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
REF = ROOT / 'reference-assets/mitsubishi_lancer_evolution_5_stylized_toon/scene.gltf'
ENGINE_SOURCE = ROOT / 'assets/vehicles/banwa_dalagan_1996_modular.glb'
OUT = ROOT / 'assets/vehicles/dalagan_evo'
OUT.mkdir(parents=True, exist_ok=True)
GLB = OUT / 'dalagan_evo_modular.glb'

C = lambda p: Vector((p[0], -p[2], p[1]))   # glTF frame -> Blender
G = lambda p: (p[0], p[2], -p[1])            # Blender -> glTF frame

FZ, RZ = 1.28, -1.22
REF_FZ, REF_RZ = 1.218, -1.256               # reference axles, measured from its rims
SCALE_Z = (FZ - RZ) / (REF_FZ - REF_RZ)


def fit(p):
    """Reference glTF-frame point -> our frame: axles land exactly on the sim's."""
    return (p[0], p[1], FZ + (p[2] - REF_FZ) * SCALE_Z)


# ---------------------------------------------------------------- source scene
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ENGINE_SOURCE))
KEEP = {'vehicle_root', 'attach_engine', 'engine_stock', 'battery', 'airbox', 'intake',
        'strut_towers', 'strut_caps', 'radiator_fins'}
for o in list(bpy.data.objects):
    if o.name not in KEEP:
        bpy.data.objects.remove(o, do_unlink=True)
ROOT_NODE = bpy.data.objects['vehicle_root']
MATS = {m.name: m for m in bpy.data.materials}

before = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(REF))
ref_objs = [o for o in bpy.data.objects if o not in before and o.type == 'MESH']
bpy.context.view_layer.update()


def material(name, color, metallic=0.0, roughness=0.5):
    m = MATS.get(name) or bpy.data.materials.new(name)
    MATS[name] = m
    m.use_nodes = True
    m.diffuse_color = (*color, 1)
    bs = m.node_tree.nodes.get('Principled BSDF')
    for n in list(m.node_tree.nodes):
        if n.type == 'TEX_IMAGE':
            m.node_tree.nodes.remove(n)
    bs.inputs['Base Color'].default_value = (*color, 1)
    bs.inputs['Metallic'].default_value = metallic
    bs.inputs['Roughness'].default_value = roughness
    return m


for args in [('paint', (.98, .33, .13), .3, .4), ('glass', (.027, .052, .060), .28, .23),
             ('trim', (.035, .036, .038), 0, .6), ('tire', (.025, .025, .025), 0, .9),
             ('rim', (.45, .45, .45), .65, .32), ('rim_dark', (.10, .10, .10), .5, .5),
             ('headlight', (1.0, .96, .67), .25, .26), ('amber', (.9, .45, .08), .1, .3),
             ('taillight', (.58, .02, .02), .18, .29), ('reverse', (.9, .9, .9), .1, .3),
             ('plate', (.85, .85, .80), 0, .5), ('chrome', (.8, .8, .82), 1, .2),
             ('engine_metal', (.5, .5, .5), .7, .4), ('engine_dark', (.06, .06, .065), .2, .7),
             ('caliper', (.55, .03, .03), .2, .4)]:
    material(*args)


# ---------------------------------------------------------------- face classification
def palette(obj):
    for n in obj.data.materials[0].node_tree.nodes:
        if n.type == 'TEX_IMAGE':
            img = n.image
            return img, img.size[0], img.size[1], list(img.pixels)


WHEELS = {}
rims = next(o for o in ref_objs if o.data.materials[0].name.startswith('1EVO5_Rims'))
for name, sx, sz in (('wheel_fl', 1, 1), ('wheel_fr', -1, 1), ('wheel_rl', 1, -1), ('wheel_rr', -1, -1)):
    pts = [fit(G(rims.matrix_world @ v.co)) for v in rims.data.vertices]
    pts = [p for p in pts if p[0] * sx > 0 and p[2] * sz > 0]
    WHEELS[name] = tuple((min(p[i] for p in pts) + max(p[i] for p in pts)) / 2 for i in range(3))
WHEEL_R = 0.335


def wheel_of(c):
    for name, w in WHEELS.items():
        if c[0] * w[0] > 0 and math.hypot(c[1] - w[1], c[2] - w[2]) < WHEEL_R and abs(c[0]) > 0.55:
            return name
    return None


def body_material(rgb):
    r, g, b = rgb
    return 'paint' if r >= 0.30 else 'trim'


def classify_material(src, rgb, c, n):
    """Reference material + palette colour -> one of our material names."""
    if src.startswith('1EVO5_Calipers'):
        return 'caliper'
    if src.startswith('1EVO5_Rims'):
        return 'rim' if rgb[0] > 0.3 else 'rim_dark'
    if src.startswith('RREVO5_Blinker'):
        return 'amber'
    if src.startswith('RREVO5_BrakeLight'):
        return 'taillight'
    if src.startswith('RREVO5_ReverseLights'):
        return 'reverse'
    if src.startswith('RREVO5_FogLights') or src.startswith('RREVO5_HeadLights'):
        return 'headlight' if c[2] > 0 else 'plate'
    if src.startswith('RREVO5_Body'):
        return body_material(rgb)
    if src.startswith('RRBaseMatWM'):
        return 'trim'
    # RRBaseMatGeneral: black greenhouse, tires, wells, trim, plates, exhaust.
    if rgb[0] > 0.25:
        return 'plate'
    if wheel_of(c):
        return 'tire'
    if rgb[0] >= 0.06 and c[2] < 0:
        return 'chrome'
    if c[1] > 0.88 and n[1] > -0.2 and abs(c[0]) < 0.84:
        return 'glass'
    return 'trim'


def classify_node(src, mat, c, n):
    """Which node (slot part or fixed detail) a face belongs to, from its centre and normal."""
    x, y, z = c
    ax = abs(x)
    side = 'l' if x > 0 else 'r'
    if src.startswith('1EVO5_Rims') or mat == 'tire':
        return wheel_of(c) or 'shell_base'
    if src.startswith('1EVO5_Calipers'):
        return 'shell_base'
    if mat in ('headlight', 'amber') and z > 1.6 and y > 0.5:
        return ('headlight_' + side) if mat == 'headlight' else ('indicator_' + ('1' if x > 0 else '-1'))
    if mat in ('taillight', 'reverse', 'amber') and z < -1.6:
        return 'taillight_' + side
    if mat == 'amber':
        return 'fender_f' + side + '_stock' if z > 0.6 else 'shell_base'
    if mat == 'glass':
        if z > 0.12 and ax < 0.62 and n[2] > 0.05:
            return 'windshield'
        if z < -0.85 and ax < 0.62 and n[2] < -0.05:
            return 'rear_glass'
        return ('window_front_' if z > -0.32 else 'window_rear_') + ('1' if x > 0 else '-1')
    if ax > 0.80 and 0.82 < y < 1.02 and 0.35 < z < 0.95:
        return 'mirror_' + side
    if y > 1.07 and z < -1.80:
        return 'spoiler_rear_stock'
    if z > 1.70 and y < 0.555:
        if y < 0.215 and z > 1.95:
            return 'chin_front_stock' if ax < 0.35 else 'lip_front_stock'
        return 'bumper_front_stock'
    if z < -1.72 and y < 0.62:
        return 'bumper_rear_stock'
    if y > 0.78 and z > 0.98 and ax < 0.58:
        return 'hood_stock'
    if y > 0.95 and z < -1.68 and ax < 0.64 and n[1] > 0.4:
        return 'trunk_stock'
    if y < 0.30 and ax > 0.62 and -0.88 < z < 0.93 and src.startswith('RREVO5_Body'):
        return 'sideskirt_' + side + '_stock'
    if ax > 0.58 and 0.82 < z <= 1.80 and y < 0.95 and (y >= 0.30 or z > 0.93):
        return 'fender_f' + side + '_stock'
    return 'shell_base'


# Straight seam planes (point, normal) cut through the painted body before faces are assigned,
# so every removable panel ends on a clean edge instead of following long source triangles.
SEAMS = [((0.58, 0, 0), (1, 0, 0)), ((-0.58, 0, 0), (1, 0, 0)), ((0.64, 0, 0), (1, 0, 0)), ((-0.64, 0, 0), (1, 0, 0)),
         ((0, 0, 0.98), (0, 0, 1)), ((0, 0, 0.82), (0, 0, 1)), ((0, 0, 1.70), (0, 0, 1)), ((0, 0, 1.80), (0, 0, 1)),
         ((0, 0, -1.68), (0, 0, 1)), ((0, 0, -1.72), (0, 0, 1)), ((0, 0, -1.80), (0, 0, 1)),
         ((0, 0, -0.88), (0, 0, 1)), ((0, 0, 0.93), (0, 0, 1)),
         ((0, 0.555, 0), (0, 1, 0)), ((0, 0.62, 0), (0, 1, 0)), ((0, 0.30, 0), (0, 1, 0)), ((0, 0.215, 0), (0, 1, 0)),
         ((0, 1.07, 0), (0, 1, 0)), ((0, 0.95, 0), (0, 1, 0))]
PARTS = {}   # node -> (verts, faces, mats)
MAT_NAMES = []
for o in ref_objs:
    src = o.data.materials[0].name
    img, w, h, px = palette(o)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    uvl = bm.loops.layers.uv.active
    mw = o.matrix_world
    for v in bm.verts:
        v.co = C(fit(G(mw @ v.co)))
    mat_layer = bm.faces.layers.int.new('mat')
    bm.normal_update()
    for f in bm.faces:
        u = sum(l[uvl].uv[0] for l in f.loops) / len(f.loops)
        v = sum(l[uvl].uv[1] for l in f.loops) / len(f.loops)
        i = (min(h - 1, max(0, int((v % 1) * h))) * w + min(w - 1, max(0, int((u % 1) * w)))) * 4
        mat = classify_material(src, px[i:i + 3], G(f.calc_center_median()), G(f.normal))
        if mat not in MAT_NAMES:
            MAT_NAMES.append(mat)
        f[mat_layer] = MAT_NAMES.index(mat)
    if src.startswith('RREVO5_Body'):
        for co, no in SEAMS:
            geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
            bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-5, plane_co=C(co), plane_no=C(no))
        bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    bm.normal_update()
    for f in bm.faces:
        mat = MAT_NAMES[f[mat_layer]]
        c, n = G(f.calc_center_median()), G(f.normal)
        node = classify_node(src, mat, c, n)
        vs, fs, ms = PARTS.setdefault(node, ([], [], []))
        base = len(vs)
        vs.extend(G(v.co) for v in f.verts)
        fs.append(tuple(range(base, base + len(f.verts))))
        ms.append(mat)
    bm.free()
for o in ref_objs:
    bpy.data.objects.remove(o, do_unlink=True)
for o in [o for o in bpy.data.objects if o.type == 'EMPTY' and o.name not in KEEP]:
    bpy.data.objects.remove(o, do_unlink=True)


# ---------------------------------------------------------------- engine bay walls (the reference is hollow under the hood)
def box(lo, hi):
    x, y, z = lo
    X, Y, Z = hi
    v = [(x, y, z), (X, y, z), (X, Y, z), (x, Y, z), (x, y, Z), (X, y, Z), (X, Y, Z), (x, Y, Z)]
    f = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    return v, f


vs, fs, ms = PARTS['shell_base']
for lo, hi in [((-0.58, 0.34, 0.92), (0.58, 0.36, 1.86)), ((-0.60, 0.34, 0.92), (-0.58, 0.72, 1.84)),
               ((0.58, 0.34, 0.92), (0.60, 0.72, 1.84)), ((-0.58, 0.34, 0.90), (0.58, 0.80, 0.92)),
               ((-0.58, 0.34, 1.84), (0.58, 0.70, 1.86))]:
    bv, bf = box(lo, hi)
    s = len(vs)
    vs.extend(bv)
    fs.extend(tuple(s + i for i in f) for f in bf)
    ms.extend(['engine_dark'] * 6)


# ---------------------------------------------------------------- attach frames
def bounds(node):
    vs = PARTS[node][0]
    return [min(p[i] for p in vs) for i in range(3)], [max(p[i] for p in vs) for i in range(3)]


def frame(node, pick):
    lo, hi = bounds(node)
    return tuple(round(pick(lo, hi, i), 4) for i in range(3))


mid = lambda lo, hi, i: (lo[i] + hi[i]) / 2
SLOT_FRAMES = {
    'hood': frame('hood_stock', lambda lo, hi, i: (0, hi[1], lo[2])[i]),        # cowl hinge
    'trunk': frame('trunk_stock', lambda lo, hi, i: (0, hi[1], hi[2])[i]),      # front hinge
    'fender_fl': frame('fender_fl_stock', mid), 'fender_fr': frame('fender_fr_stock', mid),
    'bumper_front': frame('bumper_front_stock', lambda lo, hi, i: (0, mid(lo, hi, 1), mid(lo, hi, 2))[i]),
    'bumper_rear': frame('bumper_rear_stock', lambda lo, hi, i: (0, mid(lo, hi, 1), mid(lo, hi, 2))[i]),
    'sideskirt_l': frame('sideskirt_l_stock', mid), 'sideskirt_r': frame('sideskirt_r_stock', mid),
    'chin_front': frame('chin_front_stock', lambda lo, hi, i: (0, mid(lo, hi, 1), mid(lo, hi, 2))[i]),
    'lip_front': frame('lip_front_stock', lambda lo, hi, i: (0, mid(lo, hi, 1), mid(lo, hi, 2))[i]),
    'spoiler_rear': frame('spoiler_rear_stock', lambda lo, hi, i: (0, lo[1], mid(lo, hi, 2))[i]),
}
for slot, t in SLOT_FRAMES.items():
    e = bpy.data.objects.new('attach_' + slot, None)
    bpy.context.collection.objects.link(e)
    e.parent = ROOT_NODE
    e.location = C(t)
SLOT_FRAMES['engine'] = tuple(round(c, 4) for c in G(bpy.data.objects['attach_engine'].matrix_world.translation))


def boundary_loops(bm):
    loops, used = [], set()
    for e in bm.edges:
        if not e.is_boundary or e in used:
            continue
        start, v, loop = e.verts[0], e.verts[1], [e.verts[0]]
        used.add(e)
        while v != start:
            loop.append(v)
            nxt = [x for x in v.link_edges if x.is_boundary and x not in used]
            if not nxt:
                break
            used.add(nxt[0])
            v = nxt[0].other_vert(v)
        loops.append([[round(c, 5) for c in G(vv.co)] for vv in loop])
    return sorted(loops, key=len, reverse=True)


INTERFACES = {}
for node, (vs, fs, ms) in PARTS.items():
    if node.endswith('_stock'):
        slot = node[:-6]
        parent = bpy.data.objects['attach_' + slot]
        org = C(SLOT_FRAMES[slot])
    elif node in WHEELS:
        parent, org = ROOT_NODE, C(WHEELS[node])
    else:
        parent, org = ROOT_NODE, Vector()
    names = list(dict.fromkeys(ms))
    bm = bmesh.new()
    bv = [bm.verts.new(C(p)) for p in vs]
    for f, m in zip(fs, ms):
        try:
            bm.faces.new([bv[i] for i in f]).material_index = names.index(m)
        except ValueError:
            pass
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.dissolve_degenerate(bm, dist=1e-7, edges=bm.edges)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
    if node.endswith('_stock'):
        INTERFACES[node] = boundary_loops(bm)
    bmesh.ops.translate(bm, verts=bm.verts, vec=-org)
    mesh = bpy.data.meshes.new(node)
    bm.to_mesh(mesh)
    bm.free()
    for n in names:
        mesh.materials.append(MATS[n])
    for p in mesh.polygons:
        p.use_smooth = False
    obj = bpy.data.objects.new(node, mesh)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    bpy.context.view_layer.update()
    obj.matrix_world.translation = org

# ---------------------------------------------------------------- export
for m in list(bpy.data.materials):
    if m.users == 0:
        bpy.data.materials.remove(m)
for img in list(bpy.data.images):
    bpy.data.images.remove(img)
ROOT_NODE['design'] = 'Banwa Dalagan GSR (Evo V) / reference geometry, Dalagan modular contract'
ROOT_NODE['credit'] = ('Based on "Mitsubishi Lancer Evolution 5 Stylized Toon" by Ponter, CC-BY-4.0, '
                       'https://sketchfab.com/3d-models/mitsubishi-lancer-evolution-5-stylized-toon-c6f74d4645cb47aea7813f24bc59386f')
ROOT_NODE['seamVersion'] = 2
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(GLB), export_format='GLB', use_selection=True, export_yup=True,
                          export_extras=True, export_materials='EXPORT', export_cameras=False, export_lights=False)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / 'assets/vehicles/source/dalagan_evo_modular.blend'))
interfaces = {
    'version': 2,
    'axes': {'up': '+Y', 'forward': '+Z', 'left': '+X'},
    'slots': {k: list(v) for k, v in SLOT_FRAMES.items()},
    'panel_boundary_loops_world': INTERFACES,
    'notes': 'Panel mesh local edge coordinates are the canonical seam; use stock geometry as template. '
             'All frames have identity rotation and unit scale.',
}
(OUT / 'mounting_interfaces.json').write_text(json.dumps(interfaces, indent=1) + '\n')
print('EVO_EXPORT_COMPLETE')

# ---------------------------------------------------------------- validate the delivered GLB
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(GLB))
bpy.context.view_layer.update()
vehicle = list(bpy.context.scene.objects)
meshes = [o for o in vehicle if o.type == 'MESH']
points = [G(o.matrix_world @ v.co) for o in meshes for v in o.data.vertices]
report = {'generator': 'Blender ' + bpy.app.version_string, 'source': 'build-dalagan-evo.py', 'triangles': 0,
          'nodes': sorted(o.name for o in vehicle), 'materials': sorted(m.name for m in bpy.data.materials),
          'bounds_min': [round(min(p[i] for p in points), 4) for i in range(3)],
          'bounds_max': [round(max(p[i] for p in points), 4) for i in range(3)],
          'slots': {}, 'wheels': {}}
for o in meshes:
    o.data.calc_loop_triangles()
    report['triangles'] += len(o.data.loop_triangles)
for slot, expected in interfaces['slots'].items():
    parent = bpy.data.objects['attach_' + slot]
    part = bpy.data.objects[slot + '_stock']
    actual = G(parent.matrix_world.translation)
    assert max(abs(a - b) for a, b in zip(actual, expected)) < 1e-4, (slot, actual, expected)
    assert part.parent == parent and part.location.length < 1e-6, slot
    report['slots'][slot] = {'translation': [round(c, 4) for c in actual], 'part': part.name}
for name in ('wheel_fl', 'wheel_fr', 'wheel_rl', 'wheel_rr', 'headlight_l', 'headlight_r', 'taillight_l', 'taillight_r'):
    assert name in bpy.data.objects, name
for name in WHEELS:
    o = bpy.data.objects[name]
    pts = [G(o.matrix_world @ v.co) for v in o.data.vertices]
    report['wheels'][name] = {'origin': [round(c, 4) for c in G(o.matrix_world.translation)],
                              'radius': round((max(p[1] for p in pts) - min(p[1] for p in pts)) / 2, 4)}
(OUT / 'validation.json').write_text(json.dumps(report, indent=1) + '\n')
print('EVO_VALIDATION', json.dumps({k: report[k] for k in ('triangles', 'bounds_min', 'bounds_max', 'wheels')}))
print('EVO_NODES', report['nodes'])
