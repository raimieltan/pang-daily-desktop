"""Shared Blender helpers for the reference-model car builders (build-*.py).

A builder imports a CC-BY reference model, fits it to the sim's axles, sorts every face into a
node (slot part, fixed detail or wheel) with one of our material names, then calls `finish()`,
which writes the modular GLB in the Dalagan contract, mounting_interfaces.json, validation.json,
the editable .blend and preview renders. See assets/vehicles/dalagan_evo/README.md for the contract.

Coordinates are the glTF frame: X = vehicle left, Y up, Z forward. Metres.
"""
import bpy
import bmesh
import json
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
ENGINE_SOURCE = ROOT / 'assets/vehicles/banwa_dalagan_1996_modular.glb'
FZ, RZ = 1.28, -1.22                       # sim axles (handling_presets wheelbaseM 2.5)
WHEEL_NAMES = ('wheel_fl', 'wheel_fr', 'wheel_rl', 'wheel_rr')

C = lambda p: Vector((p[0], -p[2], p[1]))   # glTF frame -> Blender
G = lambda p: (p[0], p[2], -p[1])            # Blender -> glTF frame

MATS = {}
PARTS = {}      # node -> (verts, faces, mats)
WHEELS = {}     # wheel node -> centre
ROOT_NODE = None

MATERIALS = [('paint', (.98, .33, .13), .3, .4), ('glass', (.027, .052, .060), .28, .23),
             ('trim', (.035, .036, .038), 0, .6), ('tire', (.025, .025, .025), 0, .9),
             ('rim', (.45, .45, .45), .65, .32), ('rim_dark', (.10, .10, .10), .5, .5),
             ('headlight', (1.0, .96, .67), .25, .26), ('amber', (.9, .45, .08), .1, .3),
             ('taillight', (.58, .02, .02), .18, .29), ('reverse', (.9, .9, .9), .1, .3),
             ('plate', (.85, .85, .80), 0, .5), ('chrome', (.8, .8, .82), 1, .2),
             ('engine_metal', (.5, .5, .5), .7, .4), ('engine_dark', (.06, .06, .065), .2, .7),
             ('caliper', (.55, .03, .03), .2, .4)]


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


def start():
    """Empty scene with the 1996 Dalagan engine bay and our materials. Returns vehicle_root."""
    global ROOT_NODE
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(ENGINE_SOURCE))
    keep = {'vehicle_root', 'attach_engine', 'engine_stock', 'battery', 'airbox', 'intake',
            'strut_towers', 'strut_caps', 'radiator_fins'}
    for o in list(bpy.data.objects):
        if o.name not in keep:
            bpy.data.objects.remove(o, do_unlink=True)
    MATS.update({m.name: m for m in bpy.data.materials})
    for args in MATERIALS:
        material(*args)
    ROOT_NODE = bpy.data.objects['vehicle_root']
    return ROOT_NODE


_IMPORTED = []


def import_reference(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    bpy.context.view_layer.update()
    _IMPORTED.extend(o for o in bpy.data.objects if o not in before)
    return [o for o in bpy.data.objects if o not in before and o.type == 'MESH']


def remove(_objs=None):
    """Delete everything the reference import brought in (meshes and its node hierarchy)."""
    for o in _IMPORTED:
        bpy.data.objects.remove(o, do_unlink=True)
    _IMPORTED.clear()


class Fit:
    """Uniform scale + offset from the reference's glTF frame to ours: its front/rear axle
    centres land on the sim's, its tire contact plane on Y = 0, its centreline on X = 0."""

    def __init__(self, front_z, rear_z, ground_y, centre_x=0.0, stretch_z=1.0):
        self.s = (FZ - RZ) / (front_z - rear_z)
        self.front_z, self.ground_y, self.centre_x = front_z, ground_y, centre_x
        # Optional extra lengthwise stretch about the wheelbase centre (kept 1 unless needed).
        self.stretch_z = stretch_z

    def __call__(self, p):
        s = self.s
        z = FZ + (p[2] - self.front_z) * s
        mid = (FZ + RZ) / 2
        return ((p[0] - self.centre_x) * s, (p[1] - self.ground_y) * s, mid + (z - mid) * self.stretch_z)


def world_points(obj, fit):
    return [fit(G(obj.matrix_world @ v.co)) for v in obj.data.vertices]


def bbox(points):
    return ([min(p[i] for p in points) for i in range(3)], [max(p[i] for p in points) for i in range(3)])


def set_wheels(points_by_wheel):
    """points_by_wheel: wheel node -> fitted points of its tire. Centre = bbox centre."""
    for name, pts in points_by_wheel.items():
        lo, hi = bbox(pts)
        WHEELS[name] = tuple((lo[i] + hi[i]) / 2 for i in range(3))


def wheel_of(c):
    best, bd = None, 9.0
    for name, w in WHEELS.items():
        d = math.dist(c, w)
        if c[0] * w[0] > 0 and d < bd:
            best, bd = name, d
    return best if bd < 0.6 else None


def texture_sampler(obj):
    """Face -> mean RGB of the base-colour texture over the face's UV corners, or None."""
    mat = obj.data.materials[0] if obj.data.materials else None
    img = None
    if mat and mat.node_tree:
        img = next((n.image for n in mat.node_tree.nodes if n.type == 'TEX_IMAGE' and n.image), None)
    if img is None:
        return None
    w, h = img.size
    px = list(img.pixels)

    def sample(face, uvl):
        acc = [0.0, 0.0, 0.0]
        pts = [l[uvl].uv for l in face.loops]
        cu = sum(p[0] for p in pts) / len(pts)
        cv = sum(p[1] for p in pts) / len(pts)
        samples = [(cu, cv)] + [((p[0] + cu) / 2, (p[1] + cv) / 2) for p in pts]
        for u, v in samples:
            i = (min(h - 1, max(0, int((v % 1) * h))) * w + min(w - 1, max(0, int((u % 1) * w)))) * 4
            for k in range(3):
                acc[k] += px[i + k]
        return tuple(a / len(samples) for a in acc)
    return sample


def base_color(obj):
    mat = obj.data.materials[0] if obj.data.materials else None
    if mat and mat.node_tree:
        b = mat.node_tree.nodes.get('Principled BSDF')
        if b:
            return tuple(b.inputs['Base Color'].default_value[:3])
    return (0.5, 0.5, 0.5)


def add_reference(obj, fit, classify, seams=()):
    """Sort every face of a reference mesh. classify(face_ctx) -> (node, material) where face_ctx
    has .c (centre), .n (normal), .rgb (texture or base colour), .src (object name)."""
    sampler = texture_sampler(obj)
    flat = base_color(obj)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    uvl = bm.loops.layers.uv.active
    mw = obj.matrix_world
    for v in bm.verts:
        v.co = C(fit(G(mw @ v.co)))
    rgb_layer = [bm.faces.layers.float.new(k) for k in 'rgb']
    for f in bm.faces:
        rgb = sampler(f, uvl) if (sampler and uvl) else flat
        for layer, val in zip(rgb_layer, rgb):
            f[layer] = val
    for co, no in seams:
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-5, plane_co=C(co), plane_no=C(no))
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    bm.normal_update()

    class Face:
        pass
    for f in bm.faces:
        if f.calc_area() < 1e-10:
            continue
        ctx = Face()
        ctx.c, ctx.n, ctx.src = G(f.calc_center_median()), G(f.normal), obj.name
        ctx.rgb = tuple(f[layer] for layer in rgb_layer)
        node, mat = classify(ctx)
        if node is None:
            continue
        add_face(node, [G(v.co) for v in f.verts], mat)
    bm.free()


def add_face(node, verts, mat):
    vs, fs, ms = PARTS.setdefault(node, ([], [], []))
    base = len(vs)
    vs.extend(verts)
    fs.append(tuple(range(base, base + len(verts))))
    ms.append(mat)


def add_box(node, lo, hi, mat):
    x, y, z = lo
    X, Y, Z = hi
    v = [(x, y, z), (X, y, z), (X, Y, z), (x, Y, z), (x, y, Z), (X, y, Z), (X, Y, Z), (x, Y, Z)]
    for f in [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]:
        add_face(node, [v[i] for i in f], mat)


def engine_bay(lo_x, hi_x, floor_y, top_y, rear_z, front_z):
    """Dark walls so the reference's hollow nose reads as an engine bay with the hood off."""
    t = 0.02
    for lo, hi in [((lo_x, floor_y, rear_z), (hi_x, floor_y + t, front_z)),
                   ((lo_x - t, floor_y, rear_z), (lo_x, top_y, front_z)),
                   ((hi_x, floor_y, rear_z), (hi_x + t, top_y, front_z)),
                   ((lo_x, floor_y, rear_z - t), (hi_x, top_y + 0.06, rear_z)),
                   ((lo_x, floor_y, front_z), (hi_x, top_y - 0.04, front_z + t))]:
        add_box('shell_base', lo, hi, 'engine_dark')


def fit_engine(hood_node, clearance=0.03):
    """Drop the kept Dalagan engine (and bay parts) so every one of them clears the hood's
    underside above its own footprint. Returns the lowest bay-part point (glTF Y) afterwards."""
    hood = PARTS[hood_node][0]
    names = ['engine_stock', 'battery', 'airbox', 'intake', 'strut_towers', 'strut_caps', 'radiator_fins']
    objs = [bpy.data.objects[n] for n in names if n in bpy.data.objects]
    bpy.context.view_layer.update()
    drop = 0.0
    for o in objs:
        pts = [G(o.matrix_world @ v.co) for v in o.data.vertices]
        lo, hi = bbox(pts)
        above = [p[1] for p in hood if lo[0] - .05 <= p[0] <= hi[0] + .05 and lo[2] - .05 <= p[2] <= hi[2] + .05]
        if above:
            drop = max(drop, hi[1] - (min(above) - clearance))
    # Move the engine's attach frame (the replaceable part stays at local zero) and the loose parts.
    attach = bpy.data.objects['attach_engine']
    for o in [attach] + [o for o in objs if o.parent != attach]:
        o.location.z -= drop
    bpy.context.view_layer.update()
    return min((o.matrix_world @ v.co).z for o in objs for v in o.data.vertices)


# ---------------------------------------------------------------- frames, nodes, export
mid = lambda lo, hi, i: (lo[i] + hi[i]) / 2
CENTRED_X = lambda lo, hi, i: (0, mid(lo, hi, 1), mid(lo, hi, 2))[i]
SLOT_PICKS = {
    'hood': lambda lo, hi, i: (0, hi[1], lo[2])[i],          # cowl hinge
    'trunk': lambda lo, hi, i: (0, hi[1], hi[2])[i],         # front hinge
    'fender_fl': mid, 'fender_fr': mid, 'sideskirt_l': mid, 'sideskirt_r': mid,
    'bumper_front': CENTRED_X, 'bumper_rear': CENTRED_X, 'chin_front': CENTRED_X, 'lip_front': CENTRED_X,
    'spoiler_rear': lambda lo, hi, i: (0, lo[1], mid(lo, hi, 2))[i],   # wing foot
}


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


def finish(out_dir, stem, design, credit, preview_title, smooth_angle=None):
    """smooth_angle (degrees): smooth-shade with hard edges above it, for sources modelled smooth.
    None keeps every face flat, as the faceted Evo source wants."""
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    glb = out_dir / f'{stem}.glb'
    slot_frames = {}
    for slot, pick in SLOT_PICKS.items():
        node = slot + '_stock'
        if node not in PARTS:
            continue
        lo, hi = bbox(PARTS[node][0])
        slot_frames[slot] = tuple(round(pick(lo, hi, i), 4) for i in range(3))
        e = bpy.data.objects.new('attach_' + slot, None)
        bpy.context.collection.objects.link(e)
        e.parent = ROOT_NODE
        e.location = C(slot_frames[slot])
    bpy.context.view_layer.update()
    slot_frames['engine'] = tuple(round(c, 4) for c in G(bpy.data.objects['attach_engine'].matrix_world.translation))

    interfaces = {}
    for node, (vs, fs, ms) in PARTS.items():
        if node.endswith('_stock'):
            slot = node[:-6]
            parent, org = bpy.data.objects['attach_' + slot], C(slot_frames[slot])
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
            interfaces[node] = boundary_loops(bm)
        bmesh.ops.translate(bm, verts=bm.verts, vec=-org)
        mesh = bpy.data.meshes.new(node)
        bm.to_mesh(mesh)
        bm.free()
        for n in names:
            mesh.materials.append(MATS[n])
        for p in mesh.polygons:
            p.use_smooth = smooth_angle is not None
        if smooth_angle is not None:
            mesh.set_sharp_from_angle(angle=math.radians(smooth_angle))
        obj = bpy.data.objects.new(node, mesh)
        bpy.context.collection.objects.link(obj)
        obj.parent = parent
        bpy.context.view_layer.update()
        obj.matrix_world.translation = org

    for m in list(bpy.data.materials):
        if m.users == 0:
            bpy.data.materials.remove(m)
    for img in list(bpy.data.images):
        bpy.data.images.remove(img)
    ROOT_NODE['design'] = design
    ROOT_NODE['credit'] = credit
    ROOT_NODE['seamVersion'] = 2
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format='GLB', use_selection=True, export_yup=True,
                              export_extras=True, export_materials='EXPORT', export_cameras=False,
                              export_lights=False)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / f'assets/vehicles/source/{stem}.blend'))
    doc = {
        'version': 2,
        'axes': {'up': '+Y', 'forward': '+Z', 'left': '+X'},
        'slots': {k: list(v) for k, v in slot_frames.items()},
        'panel_boundary_loops_world': interfaces,
        'notes': 'Panel mesh local edge coordinates are the canonical seam; use stock geometry as template. '
                 'All frames have identity rotation and unit scale.',
    }
    (out_dir / 'mounting_interfaces.json').write_text(json.dumps(doc, indent=1) + '\n')
    validate(glb, doc, out_dir)
    render_previews(glb, out_dir / 'previews', preview_title)


def validate(glb, doc, out_dir):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(glb))
    bpy.context.view_layer.update()
    vehicle = list(bpy.context.scene.objects)
    meshes = [o for o in vehicle if o.type == 'MESH']
    points = [G(o.matrix_world @ v.co) for o in meshes for v in o.data.vertices]
    report = {'generator': 'Blender ' + bpy.app.version_string, 'source': glb.stem, 'triangles': 0,
              'nodes': sorted(o.name for o in vehicle), 'materials': sorted(m.name for m in bpy.data.materials),
              'bounds_min': [round(min(p[i] for p in points), 4) for i in range(3)],
              'bounds_max': [round(max(p[i] for p in points), 4) for i in range(3)],
              'slots': {}, 'wheels': {}}
    for o in meshes:
        o.data.calc_loop_triangles()
        report['triangles'] += len(o.data.loop_triangles)
    for slot, expected in doc['slots'].items():
        parent = bpy.data.objects['attach_' + slot]
        part = bpy.data.objects[slot + '_stock']
        actual = G(parent.matrix_world.translation)
        assert max(abs(a - b) for a, b in zip(actual, expected)) < 1e-4, (slot, actual, expected)
        assert part.parent == parent and part.location.length < 1e-6, slot
        report['slots'][slot] = {'translation': [round(c, 4) for c in actual], 'part': part.name}
    for name in WHEEL_NAMES + ('headlight_l', 'headlight_r', 'taillight_l', 'taillight_r'):
        assert name in bpy.data.objects, name
    for name in WHEEL_NAMES:
        o = bpy.data.objects[name]
        pts = [G(o.matrix_world @ v.co) for v in o.data.vertices]
        report['wheels'][name] = {'origin': [round(c, 4) for c in G(o.matrix_world.translation)],
                                  'radius': round((max(p[1] for p in pts) - min(p[1] for p in pts)) / 2, 4)}
    (out_dir / 'validation.json').write_text(json.dumps(report, indent=1) + '\n')
    print('KIT_VALIDATION', json.dumps({k: report[k] for k in ('triangles', 'bounds_min', 'bounds_max', 'wheels')}))
    print('KIT_NODES', report['nodes'])


def render_previews(glb, out, title, paint=(0.9, 0.42, 0.1)):
    """Front-left, rear-left, side and exploded views of the delivered GLB (Eevee, flat colours)."""
    out.mkdir(parents=True, exist_ok=True)
    (out / '.gdignore').touch()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(glb))
    sc = bpy.context.scene
    if 'paint' in bpy.data.materials:
        bpy.data.materials['paint'].node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (*paint, 1)
    sc.render.engine = 'BLENDER_EEVEE'
    sc.render.resolution_x, sc.render.resolution_y = 1400, 900
    sc.view_settings.view_transform = 'Standard'
    world = bpy.data.worlds.new('w')
    world.use_nodes = True
    world.node_tree.nodes['Background'].inputs['Color'].default_value = (.045, .045, .05, 1)
    world.node_tree.nodes['Background'].inputs['Strength'].default_value = 4.0
    sc.world = world
    for rot, energy in (((0.9, 0.1, 0.7), 3.0), ((1.2, 0, -2.4), 1.2)):
        sun = bpy.data.objects.new('sun', bpy.data.lights.new('sun', 'SUN'))
        sun.data.energy = energy
        sun.rotation_euler = rot
        sc.collection.objects.link(sun)
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
    cam.data.lens = 50
    sc.collection.objects.link(cam)
    sc.camera = cam
    target = Vector((0, 0.05, 0.55))   # Blender frame: car centre, slightly up

    def shoot(name, az, el, dist=8.4):
        a, e = math.radians(az), math.radians(el)
        cam.location = target + Vector((math.cos(a) * math.cos(e), math.sin(a) * math.cos(e), math.sin(e))) * dist
        cam.rotation_euler = (target - cam.location).to_track_quat('-Z', 'Y').to_euler()
        sc.render.filepath = str(out / name)
        bpy.ops.render.render(write_still=True)

    # Blender frame: glTF +Z forward -> Blender -Y forward; glTF +X (left) -> Blender +X.
    shoot('01_front_left.png', -55, 18)
    shoot('02_rear_left.png', 55, 18)
    shoot('03_side.png', 0, 4)
    shoot('04_front.png', -90, 8)
    for o in bpy.data.objects:
        if o.name.startswith('attach_') and o.name != 'attach_engine':
            d = Vector(o.location)
            d.z = max(d.z, 0.4) - 0.4
            o.location += d.normalized() * 0.55 if d.length > 1e-6 else Vector((0, 0, 0.6))
    shoot('05_exploded.png', -55, 24, 9.5)
    print('KIT_PREVIEWS', title, out)
