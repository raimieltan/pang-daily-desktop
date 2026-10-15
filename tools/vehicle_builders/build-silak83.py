"""Banwa Silak 1983 (Lancer EX "box type", A172 build): cut into the modular contract and export.

Run: Blender --background --factory-startup --python tools/vehicle_builders/build-silak83.py

The shape comes from build-silak83-live.py (traced from the side-view drawing, styled after the
"Lancer A172 JDM concept build" sheet). This builder:
  * runs that geometry, cuts the painted body along straight seam planes,
  * assigns every face to a removable slot part (hood, fenders, bumpers, skirts, trunk, ducktail,
    lip, chin, rear overfenders) under attach frames, or to a fixed node CarVisual looks up
    (headlight_l/r, taillight_l/r, wheel_fl/fr/rl/rr),
  * keeps the Dalagan engine bay, exports, then re-imports the GLB and validates it.
Coordinates in this file are the glTF frame: X = vehicle left, Y up, Z forward. Metres.
"""
import bpy
import bmesh
import json
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
LIVE = Path(__file__).with_name('build-silak83-live.py')
ENGINE_SOURCE = ROOT / 'assets/vehicles/banwa_dalagan_1996_modular.glb'
OUT = ROOT / 'assets/vehicles/lancer'
GLB = OUT / 'lancer_box_1983_modular.glb'

C = lambda p: Vector((p[0], -p[2], p[1]))   # glTF frame -> Blender
G = lambda p: (p[0], p[2], -p[1])            # Blender -> glTF frame
FZ, RZ, TRACK_X, TIRE_R = 1.28, -1.22, 0.728, 0.30
WHEELS = {'wheel_fl': (TRACK_X, TIRE_R, FZ), 'wheel_fr': (-TRACK_X, TIRE_R, FZ),
          'wheel_rl': (TRACK_X, TIRE_R, RZ), 'wheel_rr': (-TRACK_X, TIRE_R, RZ)}

# ---------------------------------------------------------------- source scene
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ENGINE_SOURCE))
KEEP = {'vehicle_root', 'attach_engine', 'engine_stock', 'battery', 'airbox', 'intake',
        'strut_towers', 'strut_caps', 'radiator_fins'}
for o in list(bpy.data.objects):
    if o.name not in KEEP:
        bpy.data.objects.remove(o, do_unlink=True)
ROOT_NODE = bpy.data.objects['vehicle_root']
for o in bpy.data.objects:
    o.select_set(False)

live = {'__name__': 'silak'}
exec(compile(LIVE.read_text(), str(LIVE), 'exec'), live)
SRC = list(bpy.data.collections['Silak83'].objects)
MATS = {m.name: m for m in bpy.data.materials}

# Straight seam planes (point, normal), so every removable panel ends on a clean edge.
SEAMS = {
    'body_lower': [((0.60, 0, 0), (1, 0, 0)), ((-0.60, 0, 0), (1, 0, 0)),
                   ((0.64, 0, 0), (1, 0, 0)), ((-0.64, 0, 0), (1, 0, 0)),
                   ((0.55, 0, 0), (1, 0, 0)), ((-0.55, 0, 0), (1, 0, 0)),
                   ((0, 0, 0.87), (0, 0, 1)), ((0, 0, 0.80), (0, 0, 1)), ((0, 0, 1.97), (0, 0, 1)),
                   ((0, 0, -0.88), (0, 0, 1)), ((0, 0, -1.62), (0, 0, 1)), ((0, 0, -2.16), (0, 0, 1)),
                   ((0, 0.30, 0), (0, 1, 0)), ((0, 0.70, 0), (0, 1, 0))],
    'cabin': [((0, 0, -0.31), (0, 0, 1))],
    'details': [((0.35, 0, 0), (1, 0, 0)), ((-0.35, 0, 0), (1, 0, 0))],
}


def classify(src, mat, c, n):
    """Which node (slot part or fixed detail) a face belongs to, from its centre and normal."""
    x, y, z = c
    ax = abs(x)
    side = 'l' if x > 0 else 'r'
    sgn = '1' if x > 0 else '-1'
    if src.startswith('wheel_'):
        return src
    if src == 'flares':
        return ('fender_f' + side if z > 0 else 'overfender_r' + side) + '_stock'
    if src == 'cabin':
        if mat != 'glass':
            return 'shell_base'
        if ax < 0.6 and z > 0.0 and n[2] > 0.1:
            return 'windshield'
        if ax < 0.6 and z < -1.0 and n[2] < -0.1:
            return 'rear_glass'
        return ('window_front_' if z > -0.31 else 'window_rear_') + sgn
    if src == 'details':
        if mat == 'headlight':
            return 'headlight_' + side
        if mat == 'amber' and z > 1.9:
            return 'indicator_' + sgn if y > 0.52 else 'bumper_front_stock'
        if mat in ('taillight', 'amber') and z < -2.1:
            return 'taillight_' + side
        if mat == 'chrome' and z < -2.0 and y < 0.33:
            return 'exhaust'
        if z > 1.97 and 0.55 < y < 0.77 and ax < 0.45:
            return 'grille'
        if z > 1.80 and y < 0.53:
            if y < 0.31 and mat == 'trim':
                return 'chin_front_stock' if ax < 0.35 else 'lip_front_stock'
            return 'bumper_front_stock'
        if z < -1.95 and y < 0.535:
            return 'bumper_rear_stock'
        if mat == 'trim' and z < -1.9 and y > 0.84 and ax < 0.75:
            return 'spoiler_rear_stock'
        if z < -2.15 and y > 0.52:
            return 'rear_panel'
        if ax > 0.76 and y > 0.94 and 0.5 < z < 0.62:
            return 'mirror_' + side
        if ax > 0.8 and 0.50 < y < 0.57 and z > 1.6:
            return 'fender_f' + side + '_stock'      # rub strip rides on the fender
        return 'shell_base'
    # body_lower
    if y > 0.70 and n[1] > 0.4 and 0.87 < z < 1.97 and ax < 0.60:
        return 'hood_stock'
    if y > 0.80 and n[1] > 0.3 and -2.16 < z < -1.62 and ax < 0.64:
        return 'trunk_stock'
    if ax > 0.60 and z > 0.80:
        return 'fender_f' + side + '_stock'
    if y < 0.30 and ax > 0.55 and -0.88 < z < 0.80:
        return 'sideskirt_' + side + '_stock'
    return 'shell_base'


PARTS = {}   # node -> (verts, faces, mats)


def add_face(node, pts, mat):
    vs, fs, ms = PARTS.setdefault(node, ([], [], []))
    base = len(vs)
    vs.extend(pts)
    fs.append(tuple(range(base, base + len(pts))))
    ms.append(mat)


for o in SRC:
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.transform(bm, matrix=o.matrix_world, verts=bm.verts)
    for co, no in SEAMS.get(o.name, []):
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-5, plane_co=C(co), plane_no=C(no))
    bm.normal_update()
    for f in bm.faces:
        mat = o.data.materials[f.material_index].name
        node = classify(o.name, mat, G(f.calc_center_median()), G(f.normal))
        add_face(node, [G(v.co) for v in f.verts], mat)
    bm.free()
for o in SRC:
    bpy.data.objects.remove(o, do_unlink=True)
for me in [me for me in bpy.data.meshes if me.users == 0]:
    bpy.data.meshes.remove(me)          # free the names so exported meshes match their nodes


# ---------------------------------------------------------------- engine bay / trunk tub (seen when panels come off)
def box(node, lo, hi, mat):
    x, y, z = lo
    X, Y, Z = hi
    v = [(x, y, z), (X, y, z), (X, Y, z), (x, Y, z), (x, y, Z), (X, y, Z), (X, Y, Z), (x, Y, Z)]
    for f in [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]:
        add_face(node, [v[i] for i in f], mat)


for lo, hi in [((-0.58, 0.34, 0.92), (0.58, 0.36, 1.86)), ((-0.60, 0.34, 0.92), (-0.58, 0.72, 1.84)),
               ((0.58, 0.34, 0.92), (0.60, 0.72, 1.84)), ((-0.58, 0.34, 0.88), (0.58, 0.86, 0.92)),
               ((-0.58, 0.34, 1.84), (0.58, 0.70, 1.86)),
               ((-0.62, 0.55, -2.10), (0.62, 0.57, -1.66))]:
    box('shell_base', lo, hi, 'engine_dark' if lo[2] > 0 else 'trim')
for name, rgb, metal, rough in (('engine_dark', (.06, .06, .065), .2, .7),):
    if name not in MATS:
        m = bpy.data.materials.new(name)
        m.diffuse_color = (*rgb, 1)
        MATS[name] = m


# ---------------------------------------------------------------- attach frames
def bounds(node):
    vs = PARTS[node][0]
    return [min(p[i] for p in vs) for i in range(3)], [max(p[i] for p in vs) for i in range(3)]


def frame(node, pick):
    lo, hi = bounds(node)
    return tuple(round(pick(lo, hi, i), 4) for i in range(3))


mid = lambda lo, hi, i: (lo[i] + hi[i]) / 2
centre_x0 = lambda lo, hi, i: (0, mid(lo, hi, 1), mid(lo, hi, 2))[i]
SLOT_FRAMES = {
    'hood': frame('hood_stock', lambda lo, hi, i: (0, hi[1], lo[2])[i]),        # cowl hinge
    'trunk': frame('trunk_stock', lambda lo, hi, i: (0, hi[1], hi[2])[i]),      # front hinge
    'fender_fl': frame('fender_fl_stock', mid), 'fender_fr': frame('fender_fr_stock', mid),
    'bumper_front': frame('bumper_front_stock', centre_x0),
    'bumper_rear': frame('bumper_rear_stock', centre_x0),
    'sideskirt_l': frame('sideskirt_l_stock', mid), 'sideskirt_r': frame('sideskirt_r_stock', mid),
    'chin_front': frame('chin_front_stock', centre_x0),
    'lip_front': frame('lip_front_stock', centre_x0),
    'spoiler_rear': frame('spoiler_rear_stock', lambda lo, hi, i: (0, lo[1], mid(lo, hi, 2))[i]),
    'overfender_rl': frame('overfender_rl_stock', mid), 'overfender_rr': frame('overfender_rr_stock', mid),
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
ROOT_NODE['design'] = 'Banwa Silak 1983 (Lancer EX box type, A172 JDM build) / Dalagan modular contract'
ROOT_NODE['seamVersion'] = 2
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(GLB), export_format='GLB', use_selection=True, export_yup=True,
                          export_extras=True, export_materials='EXPORT', export_cameras=False, export_lights=False)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / 'assets/vehicles/source/silak83_modular.blend'))
interfaces = {
    'version': 2,
    'axes': {'up': '+Y', 'forward': '+Z', 'left': '+X'},
    'slots': {k: list(v) for k, v in SLOT_FRAMES.items()},
    'wheels': {k: list(v) for k, v in WHEELS.items()},
    'panel_boundary_loops_world': INTERFACES,
    'notes': 'Panel mesh local edge coordinates are the canonical seam; use stock geometry as template. '
             'All frames have identity rotation and unit scale.',
}
(OUT / 'mounting_interfaces.json').write_text(json.dumps(interfaces, indent=1) + '\n')
print('SILAK_EXPORT_COMPLETE')

# ---------------------------------------------------------------- validate the delivered GLB
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(GLB))
bpy.context.view_layer.update()
vehicle = list(bpy.context.scene.objects)
meshes = [o for o in vehicle if o.type == 'MESH']
points = [G(o.matrix_world @ v.co) for o in meshes for v in o.data.vertices]
report = {'generator': 'Blender ' + bpy.app.version_string, 'source': 'build-silak83.py', 'triangles': 0,
          'draw_calls': sum(len(o.data.materials) for o in meshes),
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
for name, pivot in WHEELS.items():
    o = bpy.data.objects[name]
    origin = G(o.matrix_world.translation)
    assert max(abs(a - b) for a, b in zip(origin, pivot)) < 1e-4, (name, origin)
    pts = [G(o.matrix_world @ v.co) for v in o.data.vertices]
    report['wheels'][name] = {'origin': [round(c, 4) for c in origin],
                              'radius': round((max(p[1] for p in pts) - min(p[1] for p in pts)) / 2, 4)}
assert report['triangles'] < 30000 and report['draw_calls'] < 100 and len(report['materials']) <= 16, report
(OUT / 'validation.json').write_text(json.dumps(report, indent=1) + '\n')
print('SILAK_VALIDATED', report['triangles'], 'tris', report['draw_calls'], 'draws', len(report['materials']), 'mats')
