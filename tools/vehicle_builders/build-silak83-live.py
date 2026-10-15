"""Banwa Silak 1983 (Lancer EX "box type") built live in Blender from photos.

Run inside the open Blender session (Blender MCP draft_script exec) or with
Blender --background --python. Coordinates are authored in the game's glTF
frame (X left, Y up, Z forward) and converted with C().

Real car: 4225 L x 1620 W x 1385 H mm, wheelbase 2440 mm. Axles follow the
game contract (z=+1.28/-1.22, tire radius 0.30, track 1.456) so overhangs
are trimmed slightly to keep the real overall length.
"""
import bpy
import bmesh
from mathutils import Vector

C = lambda p: Vector((p[0], -p[2], p[1]))
COLL = 'Silak83'
FZ, RZ, TIRE_R, TRACK_X = 1.28, -1.22, 0.30, 0.728
ARCH_R = 0.335          # tight arch for the lowered, tucked stance
FLARE_R, FLARE_X = 0.435, 0.872

PALETTE = {
    'paint': ((0.86, 0.865, 0.85), 0.05, 0.3),   # white, per the A172 build sheet
    'glass': ((0.03, 0.04, 0.05), 0.0, 0.08),
    'trim': ((0.025, 0.025, 0.028), 0.0, 0.6),
    'tire': ((0.018, 0.018, 0.02), 0.0, 0.9),
    'rim': ((0.72, 0.73, 0.74), 0.8, 0.3),
    'rim_dark': ((0.08, 0.08, 0.09), 0.3, 0.5),
    'headlight': ((0.50, 0.55, 0.60), 0.7, 0.12),   # clear glass over chrome reflector
    'amber': ((0.95, 0.42, 0.05), 0.0, 0.25),
    'taillight': ((0.55, 0.02, 0.02), 0.0, 0.25),
    'chrome': ((0.85, 0.85, 0.86), 1.0, 0.15),
}


def material(name):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    color, metallic, rough = PALETTE[name]
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*color, 1)
    bsdf.inputs['Metallic'].default_value = metallic
    bsdf.inputs['Roughness'].default_value = rough
    return mat


def collection():
    coll = bpy.data.collections.get(COLL)
    if coll:
        for ob in list(coll.objects):
            bpy.data.objects.remove(ob, do_unlink=True)
    else:
        coll = bpy.data.collections.new(COLL)
        bpy.context.scene.collection.children.link(coll)
    return coll


def obj_from_bm(name, bm, mats, coll):
    me = bpy.data.meshes.new(name)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(material(m))
    for p in me.polygons:
        p.use_smooth = False
    ob = bpy.data.objects.new(name, me)
    coll.objects.link(ob)
    return ob


def loft(bm, rings, cap=True, mat=0):
    verts = [[bm.verts.new(C(p)) for p in ring] for ring in rings]
    n = len(rings[0])
    for a, b in zip(verts, verts[1:]):
        for i in range(n):
            f = bm.faces.new((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]))
            f.material_index = mat
    if cap:
        bm.faces.new(verts[0]).material_index = mat
        bm.faces.new(list(reversed(verts[-1]))).material_index = mat
    return verts


def box(bm, lo, hi, mat):
    (x0, y0, z0), (x1, y1, z1) = lo, hi
    ring = lambda z: [(x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z)]
    loft(bm, [ring(z0), ring(z1)], mat=mat)


def mirrored_box(bm, lo, hi, mat):
    box(bm, lo, hi, mat)
    box(bm, (-hi[0], lo[1], lo[2]), (-lo[0], hi[1], hi[2]), mat)


# --- lower body: lofted cross-sections read off the side/3-4 photos --------
# (z, half width, sill y, deck/hood y)
BODY_STATIONS = [
    # traced from the side-view drawing, scaled so its axles land on ours
    (2.000, 0.755, 0.30, 0.760),
    (1.960, 0.795, 0.26, 0.775),   # hood leading edge
    (1.700, 0.808, 0.23, 0.855),
    (1.350, 0.810, 0.22, 0.900),
    (0.870, 0.810, 0.21, 0.945),   # cowl
    (-0.400, 0.810, 0.20, 0.950),
    (-1.620, 0.810, 0.21, 0.962),  # rear window base
    (-1.940, 0.806, 0.22, 0.915),  # deck slopes to the tail
    (-2.060, 0.798, 0.24, 0.895),
    (-2.150, 0.785, 0.27, 0.870),  # rolled-over trailing edge
    (-2.190, 0.765, 0.31, 0.840),
]


def body_ring(z, hw, ybot, ytop):
    half = [
        (hw - 0.07, ybot),
        (hw - 0.01, ybot + 0.10),
        (hw, ytop - 0.17),   # character crease / beltline shoulder
        (hw - 0.012, ytop - 0.03),
        (hw - 0.05, ytop),
    ]
    ring = [(0.0, ybot)]
    ring += [(x, y) for x, y in half]
    ring += [(0.0, ytop)]
    ring += [(-x, y) for x, y in reversed(half)]
    return [(x, y, z) for x, y in ring]


def build_body(coll):
    bm = bmesh.new()
    loft(bm, [body_ring(*s) for s in BODY_STATIONS])
    ob = obj_from_bm('body_lower', bm, ['paint'], coll)
    # wheel arches: cut round openings around each axle
    for z in (FZ, RZ):
        for side in (1, -1):
            bm = bmesh.new()
            bmesh.ops.create_cone(bm, cap_ends=True, segments=24, radius1=ARCH_R,
                                  radius2=ARCH_R, depth=0.36)
            cut_me = bpy.data.meshes.new('arch_cut')
            bm.to_mesh(cut_me)
            bm.free()
            cut_me.materials.append(material('paint'))
            cut = bpy.data.objects.new('arch_cut', cut_me)
            coll.objects.link(cut)
            cut.rotation_euler = (0, 1.5708, 0)
            cut.location = C((side * 0.82, TIRE_R + 0.015, z))
            mod = ob.modifiers.new('arch', 'BOOLEAN')
            mod.operation = 'DIFFERENCE'
            mod.object = cut
            mod.solver = 'EXACT'
            bpy.context.view_layer.update()
            dg = bpy.context.evaluated_depsgraph_get()
            ob_eval = ob.evaluated_get(dg)
            new_me = bpy.data.meshes.new_from_object(ob_eval)
            ob.modifiers.remove(mod)
            old = ob.data
            ob.data = new_me
            bpy.data.meshes.remove(old)
            bpy.data.objects.remove(cut, do_unlink=True)
    return ob


# --- greenhouse: belt points, roof points, inset glass --------------------
def build_cabin(coll):
    bm = bmesh.new()
    belt_x, roof_x = 0.772, 0.655
    prof = {                 # (z, y, half width) along the greenhouse side
        'A': (0.870, 0.945, belt_x),    # windshield base
        'B': (0.180, 1.390, roof_x),    # roof front
        'C': (-1.000, 1.390, roof_x),   # roof rear
        'E': (-1.140, 1.360, roof_x + 0.005),  # rounded rear header
        'D': (-1.620, 0.962, belt_x),   # rear window base
    }
    pts = {(k, s): bm.verts.new(C((s * x, y, z)))
           for k, (z, y, x) in prof.items() for s in (1, -1)}
    b0 = bm.verts.new(C((0, 1.408, 0.19)))     # roof crown
    c0 = bm.verts.new(C((0, 1.408, -1.01)))
    P = lambda k, s: pts[k, s]
    windshield = bm.faces.new([P('A', 1), P('B', 1), b0, P('B', -1), P('A', -1)])
    bm.faces.new([P('B', 1), P('C', 1), c0, P('C', -1), P('B', -1), b0])     # roof
    bm.faces.new([P('C', 1), P('E', 1), P('E', -1), P('C', -1), c0])         # header
    backlight = bm.faces.new([P('E', 1), P('D', 1), P('D', -1), P('E', -1)])  # one pane
    sides = [bm.faces.new([P(k, s) for k in 'ABCED']) for s in (1, -1)]
    glass_faces = [windshield, backlight] + sides
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.normal_update()
    res = bmesh.ops.inset_individual(bm, faces=glass_faces, thickness=0.05, depth=-0.008)
    for f in glass_faces:
        f.material_index = 1
    side = set(sides)
    for f in res['faces']:
        if any(o in side for e in f.edges for o in e.link_faces):
            f.material_index = 2   # black window surround
    return obj_from_bm('cabin', bm, ['paint', 'glass', 'trim'], coll)


# --- wheels ----------------------------------------------------------------
def build_wheels(coll):
    """Rays Sebring-style deep-dish five-spoke on a low-profile tire."""
    import math
    global DM
    for name, z, s in (('wheel_fl', FZ, 1), ('wheel_fr', FZ, -1),
                       ('wheel_rl', RZ, 1), ('wheel_rr', RZ, -1)):
        bm = bmesh.new()
        segs = 24
        def ring(r, x):
            return [(x, TIRE_R + r * math.cos(2 * math.pi * i / segs),
                     z + r * math.sin(2 * math.pi * i / segs)) for i in range(segs)]
        w = 0.215 / 2
        xo = s * (TRACK_X + 0.025)   # wider offset: sits flush with the flares, pivot unchanged
        loft(bm, [ring(0.235, xo - w), ring(0.29, xo - w), ring(0.30, xo - w * 0.7),
                  ring(0.30, xo + w * 0.7), ring(0.29, xo + w), ring(0.235, xo + w)][::s], cap=False, mat=0)
        bm.faces.new([bm.verts.new(C(p)) for p in ring(0.235, xo - s * w)]).material_index = 2
        rim_x = xo + s * (w - 0.008)
        dish = 0.06
        # polished lip, then the barrel steps in to the spoke face
        loft(bm, [ring(0.235, rim_x), ring(0.205, rim_x), ring(0.20, rim_x - s * dish)], cap=False, mat=3)
        rimface = rim_x - s * dish
        loft(bm, [ring(0.20, rimface), ring(0.05, rimface)], cap=False, mat=2)
        DM_save, DM = DM, {'rim': 1, 'rim_dark': 2}
        five_spoke(bm, rimface, z, s, 'rim', r1=0.20, w0=0.036)
        loft(bm, [ring(0.06, rimface + s * 0.022), ring(0.045, rimface + s * 0.04)], mat=1)
        DM = DM_save
        obj_from_bm(name, bm, ['tire', 'rim', 'rim_dark', 'chrome'], coll)


def build_flares(coll):
    """Bolt-on style arch flares: a lip swept round each wheel opening."""
    import math
    bm = bmesh.new()
    for z in (FZ, RZ):
        for s in (1, -1):
            rings = []
            n = 16
            a0, a1 = math.radians(-12), math.radians(192)
            for k in range(n + 1):
                a = a0 + (a1 - a0) * k / n
                fade = min(1.0, min(k, n - k) / 3.0)        # blend into the body at the ends
                out = 0.80 + (FLARE_X - 0.80) * fade
                prof = [(FLARE_R, 0.795), (FLARE_R - 0.02, out - 0.008), (ARCH_R + 0.012, out),
                        (ARCH_R, out - 0.02), (ARCH_R, 0.795)]
                rings.append([(s * x, TIRE_R + 0.015 + r * math.sin(a), z + r * math.cos(a))
                              for r, x in prof])
            loft(bm, rings, mat=0)
    return obj_from_bm('flares', bm, ['paint'], coll)


# --- stage 2: trim, lamps, bumpers ----------------------------------------
DETAIL_MATS = ['trim', 'headlight', 'amber', 'taillight', 'chrome', 'paint']
DM = {m: i for i, m in enumerate(DETAIL_MATS)}


def slab(bm, quad, offset, mat):
    """Extrude a 4-point face (game frame) by an offset vector."""
    lo = [Vector(p) for p in quad]
    hi = [p + Vector(offset) for p in lo]
    vs = [bm.verts.new(C(p)) for p in lo + hi]
    faces = [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
    for f in faces:
        bm.faces.new([vs[i] for i in f]).material_index = DM[mat]


def rect_ring(z, x0, x1, y0, y1, ch=0.0):
    return [(x0, y0 + ch, z), (x0 + ch, y0, z), (x1 - ch, y0, z), (x1, y0 + ch, z),
            (x1, y1 - ch, z), (x1 - ch, y1, z), (x0 + ch, y1, z), (x0, y1 - ch, z)]


def build_details(coll):
    bm = bmesh.new()
    # front bumper: wraps round the corners, slight chamfer
    # body-colour bumper over a black lower lip, intercooler in the opening
    loft(bm, [rect_ring(1.82, -0.83, 0.83, 0.30, 0.52, 0.02),
              rect_ring(2.02, -0.818, 0.818, 0.295, 0.525, 0.03),
              rect_ring(2.085, -0.74, 0.74, 0.31, 0.51, 0.03)], mat=DM['paint'])
    loft(bm, [rect_ring(1.84, -0.82, 0.82, 0.20, 0.30, 0.01),
              rect_ring(2.06, -0.80, 0.80, 0.19, 0.30, 0.02),
              rect_ring(2.115, -0.70, 0.70, 0.19, 0.235, 0.015)], mat=DM['trim'])
    box(bm, (-0.42, 0.33, 2.083), (0.42, 0.465, 2.090), DM['trim'])
    box(bm, (-0.38, 0.345, 2.086), (0.38, 0.45, 2.093), DM['chrome'])
    for y in (0.37, 0.395, 0.42):
        box(bm, (-0.38, y, 2.093), (0.38, y + 0.006, 2.095), DM['trim'])
    # rear bumper
    loft(bm, [rect_ring(-2.255, -0.76, 0.76, 0.37, 0.52, 0.025),
              rect_ring(-2.21, -0.818, 0.818, 0.36, 0.53, 0.025),
              rect_ring(-2.00, -0.83, 0.83, 0.365, 0.525, 0.02)], mat=DM['paint'])
    loft(bm, [rect_ring(-2.245, -0.72, 0.72, 0.24, 0.37, 0.015),
              rect_ring(-2.20, -0.80, 0.80, 0.235, 0.37, 0.02),
              rect_ring(-2.00, -0.81, 0.81, 0.24, 0.37, 0.01)], mat=DM['trim'])
    # single exhaust tip, right rear
    import math
    ex = lambda zz, r: [(-0.48 + r * math.cos(2 * math.pi * k / 10), 0.26 + r * math.sin(2 * math.pi * k / 10), zz)
                        for k in range(10)]
    loft(bm, [ex(-2.30, 0.045), ex(-2.30, 0.035), ex(-2.10, 0.035)], cap=False, mat=DM['chrome'])
    nose, tail = 1.999, -2.189
    for s in (1, -1):
        X = lambda a, b: (a, b) if s > 0 else (-b, -a)
        # headlight, amber corner wrap, bumper signal
        x0, x1 = X(0.44, 0.69)
        box(bm, (x0, 0.55, nose - 0.01), (x1, 0.735, nose + 0.012), DM['headlight'])
        x0, x1 = X(0.69, 0.752)
        box(bm, (x0, 0.55, nose - 0.03), (x1, 0.735, nose + 0.008), DM['amber'])
        x0, x1 = X(0.50, 0.70)
        box(bm, (x0, 0.44, 2.08), (x1, 0.49, 2.092), DM['amber'])
        # tail lamps: red upper, amber lower, wrap to the quarter
        x0, x1 = X(0.43, 0.775)
        box(bm, (x0, 0.66, tail - 0.012), (x1, 0.81, tail + 0.01), DM['taillight'])
        box(bm, (x0, 0.53, tail - 0.012), (x1, 0.66, tail + 0.01), DM['amber'])
        # side rub strip, broken at the wheel arches
        for z0, z1 in ((1.665, 1.98), (-0.83, 0.895), (-2.17, -1.605)):
            x0, x1 = X(0.806, 0.824)
            box(bm, (x0, 0.505, z0), (x1, 0.56, z1), DM['trim'])
        # door shut lines
        for z, y0 in ((0.80, 0.27), (-0.27, 0.25), (-1.24, 0.75)):
            x0, x1 = X(0.809, 0.8135)
            box(bm, (x0, y0, z - 0.004), (x1, 0.93, z + 0.004), DM['trim'])
        # door handles
        for z in (-0.11, -1.06):
            x0, x1 = X(0.808, 0.825)
            box(bm, (x0, 0.78, z - 0.07), (x1, 0.81, z + 0.03), DM['trim'])
        # mirror: stalk + housing
        x0, x1 = X(0.77, 0.83)
        box(bm, (x0, 0.95, 0.53), (x1, 0.99, 0.59), DM['trim'])
        x0, x1 = X(0.81, 0.95)
        box(bm, (x0, 0.97, 0.51), (x1, 1.07, 0.60), DM['trim'])
        # black B-pillar on the side glass plane (belt x .772 @ y .935 -> roof x .655 @ y 1.38)
        bx = lambda y: 0.772 + (0.655 - 0.772) * (y - 0.945) / (1.39 - 0.945) + 0.004
        for z0, z1 in ((-0.355, -0.265), (-0.85, -0.83)):   # B-pillar, rear-door glass bar
            q = [(s * bx(0.95), 0.95, z0), (s * bx(0.95), 0.95, z1),
                 (s * bx(1.37), 1.37, z1), (s * bx(1.37), 1.37, z0)]
            slab(bm, q, (s * 0.01, 0, 0), 'trim')
    # grille with chrome bar
    box(bm, (-0.44, 0.56, nose - 0.01), (0.44, 0.76, nose + 0.008), DM['trim'])
    for y in (0.60, 0.645, 0.71):
        box(bm, (-0.43, y, nose + 0.008), (0.43, y + 0.012, nose + 0.014), DM['trim'])
    box(bm, (-0.43, 0.672, nose + 0.008), (0.43, 0.684, nose + 0.018), DM['chrome'])
    # black tail panel between the lamps
    box(bm, (-0.43, 0.53, tail - 0.012), (0.43, 0.81, tail + 0.006), DM['trim'])
    # ducktail on the deck lid trailing edge
    loft(bm, [[(-0.72, 0.913, -1.95), (0.72, 0.913, -1.95), (0.72, 0.923, -1.95), (-0.72, 0.923, -1.95)],
              [(-0.73, 0.868, -2.15), (0.73, 0.868, -2.15), (0.73, 0.94, -2.17), (-0.73, 0.94, -2.17)]],
         mat=DM['trim'])
    return obj_from_bm('details', bm, DETAIL_MATS, coll)


def five_spoke(bm, x, z, s, mat_spoke, r1=0.19, w0=0.03):
    import math
    for k in range(5):
        a = 2 * math.pi * k / 5
        for r0 in (0.05,):
            def P(r, t):
                return (x, TIRE_R + r * math.cos(a) - t * math.sin(a), z + r * math.sin(a) + t * math.cos(a))
            q = [P(r0, -w0), P(r0, w0), P(r1, w0 * 1.6), P(r1, -w0 * 1.6)]
            slab(bm, q, (s * 0.022, 0, 0), mat_spoke)


def frame_viewport(eye=(3.2, 1.5, 4.4), target=(0.0, 0.55, 0.0)):
    eye, target = C(eye), C(target)
    for area in bpy.context.screen.areas:
        if area.type != 'VIEW_3D':
            continue
        space = area.spaces.active
        space.shading.type = 'MATERIAL'
        r3d = space.region_3d
        r3d.view_perspective = 'PERSP'
        r3d.view_rotation = (eye - target).to_track_quat('Z', 'Y')
        r3d.view_location = target
        r3d.view_distance = (eye - target).length


def build():
    coll = collection()
    for o in list(bpy.context.scene.objects):
        if o.name in ('Cube',):
            bpy.data.objects.remove(o, do_unlink=True)
    build_body(coll)
    build_cabin(coll)
    build_wheels(coll)
    build_details(coll)
    build_flares(coll)
    return [o.name for o in coll.objects]


EYE = globals().get('EYE')
RESULT = build()
if EYE:
    frame_viewport(EYE)
print('built', RESULT)
