"""Roadside traffic for Pass 1: a PH tricycle and a motorcycle, each with a seated rider.

Run headless: Blender --background --factory-startup --python tools/vehicle_builders/build-roadside-traffic.py
or inside a running Blender (it works in its own scene, "RoadsideBuild", and leaves others alone).

Sources (reference-assets/, credits in assets/vehicles/traffic/README.md):
  * tricycle/      "Tricycle" by kurtcamarines, CC-BY-NC-4.0 (non-commercial!)
  * motorcycle/    "motorcycle" by Chenchanchong, CC-BY-4.0
  * gangster_dealer_musculo/  "Gangster Dealer Musculo" by EntropyNine, CC-BY-4.0 (the riders)

Like the car builders, this keeps the reference meshes and only:
  * fits each to real size and our frame (forward -Y in Blender = glTF +Z, up Z, ground at 0,
    the bike's centreline on x = 0; the vehicle's right is -X),
  * samples each face's texture colour and maps it to named flat materials MangaArt's car shader
    understands (paint, tire, rim, chrome, glass, headlight, taillight, amber, trim, plus extra
    flat colours), so the toon/ink pass colours them; decimates; flat-shades,
  * splits the wheels into their own nodes (origin on the hub) so the game can spin them,
  * poses the rigged character onto the seat with IK (hands on the grips, feet on the pegs),
    gives him a shirt (and the motorcyclist a helmet), applies the pose and decimates,
  * adds anchor nodes `headlight` and `taillight`, exports a GLB per vehicle.
"""
import math
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

try:
    ROOT = Path(__file__).resolve().parents[2]
except NameError:
    ROOT = Path('/Users/sean/pang-daily')
REF = ROOT / 'reference-assets'
OUT = ROOT / 'assets/vehicles/traffic'
OUT.mkdir(parents=True, exist_ok=True)
PREVIEW = Path(sys.argv[sys.argv.index('--preview') + 1]) if '--preview' in sys.argv else None


# ---------------------------------------------------------------- scene plumbing
def fresh_scene():
    if bpy.app.background:
        sc = bpy.context.scene
    else:
        sc = bpy.data.scenes.get('RoadsideBuild') or bpy.data.scenes.new('RoadsideBuild')
        bpy.context.window.scene = sc
    for o in list(sc.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    return sc


def import_ref(name):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(REF / name / 'scene.gltf'))
    return [o for o in bpy.data.objects if o not in before]


def bake_transforms(objs):
    """Meshes keep their world shape with identity transforms and no parents; the rest goes."""
    meshes = [o for o in objs if o.type == 'MESH']
    for o in meshes:
        mw = o.matrix_world.copy()
        o.data = o.data.copy()
        o.data.transform(mw)
        o.parent = None
        o.matrix_world = Matrix.Identity(4)
    for o in objs:
        if o.type != 'MESH':
            bpy.data.objects.remove(o, do_unlink=True)
    return meshes


def join(meshes, name):
    with bpy.context.temp_override(active_object=meshes[0], selected_editable_objects=meshes,
                                   selected_objects=meshes):
        bpy.ops.object.join()
    o = meshes[0]
    o.name = name
    return o


def transform(obj, m):
    obj.data.transform(m)
    obj.data.update()


def extents(obj, faces=None):
    vs = np.empty(len(obj.data.vertices) * 3, dtype=np.float32)
    obj.data.vertices.foreach_get('co', vs)
    vs = vs.reshape(-1, 3)
    return vs.min(0), vs.max(0)


# ---------------------------------------------------------------- materials
MATS = {}


def material(name, color, metallic=0.0, roughness=0.6):
    m = bpy.data.materials.get(name)
    if m is not None and not m.get('roadside'):
        m.name = name + '_src'     # a reference material with our name: step it aside
        m = None
    if m is None:
        m = bpy.data.materials.new(name)
        m['roadside'] = True
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        if n.type == 'TEX_IMAGE':
            nt.nodes.remove(n)
    bs = nt.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value = (*color, 1)
    bs.inputs['Metallic'].default_value = metallic
    bs.inputs['Roughness'].default_value = roughness
    m.diffuse_color = (*color, 1)
    MATS[name] = m
    return m


def source_image(mat):
    """(pixels HxWx4, base colour, alpha) for a reference material."""
    if mat is None or not mat.use_nodes:
        return None, (0.5, 0.5, 0.5), 1.0
    bs = next((n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
    base = tuple(bs.inputs['Base Color'].default_value[:3]) if bs else (0.5, 0.5, 0.5)
    alpha = bs.inputs['Alpha'].default_value if bs else 1.0
    img = None
    if bs and bs.inputs['Base Color'].is_linked:
        n = bs.inputs['Base Color'].links[0].from_node
        while n and n.type != 'TEX_IMAGE' and n.inputs and any(i.is_linked for i in n.inputs):
            n = next(i for i in n.inputs if i.is_linked).links[0].from_node
        if n and n.type == 'TEX_IMAGE' and n.image:
            im = n.image
            w, h = im.size
            px = np.empty(w * h * 4, dtype=np.float32)
            im.pixels.foreach_get(px)
            img = px.reshape(h, w, 4)
    # (Blender 5 reports the default dithered method as HASHED, so only the alpha value counts.)
    return img, base, alpha


def face_colours(obj):
    """Per-face linear RGB (texture sampled at the face's UV centre and corners), alpha, src name."""
    me = obj.data
    uv = me.uv_layers.active
    cache = {}
    cols = np.zeros((len(me.polygons), 3), dtype=np.float32)
    alphas = np.ones(len(me.polygons), dtype=np.float32)
    srcs = []
    uvs = np.empty(len(me.loops) * 2, dtype=np.float32)
    if uv:
        uv.data.foreach_get('uv', uvs)
    uvs = uvs.reshape(-1, 2)
    for f in me.polygons:
        mat = me.materials[f.material_index] if me.materials else None
        key = mat.name if mat else '-'
        if key not in cache:
            cache[key] = source_image(mat)
        img, base, alpha = cache[key]
        srcs.append(key)
        alphas[f.index] = alpha
        if img is None or not uv:
            cols[f.index] = base
            continue
        h, w, _ = img.shape
        pts = [uvs[li] for li in f.loop_indices]
        pts.append(sum(pts) / len(pts))
        acc = np.zeros(4)
        for p in pts:
            x = int((p[0] % 1.0) * (w - 1))
            y = int((p[1] % 1.0) * (h - 1))
            acc += img[y, x]
        acc /= len(pts)
        cols[f.index] = acc[:3] * np.array(base)
    return cols, alphas, srcs


def assign(obj, names, colours, specials):
    """Give each face the material `names[i]`; plain palette names take the mean colour."""
    me = obj.data
    me.materials.clear()
    order = sorted(set(names))
    for n in order:
        if n in specials:
            material(n, *specials[n])
        else:
            idx = [i for i, k in enumerate(names) if k == n]
            c = colours[idx].mean(0)
            material(n, tuple(float(x) for x in c))
        me.materials.append(MATS[n])
    lookup = {n: i for i, n in enumerate(order)}
    me.polygons.foreach_set('material_index', [lookup[n] for n in names])
    me.update()
    if '--debug' in sys.argv:
        for n in order:
            ps = [f.center for f, k in zip(me.polygons, names) if k == n]
            lo = [min(p[a] for p in ps) for a in range(3)]
            hi = [max(p[a] for p in ps) for a in range(3)]
            print(f'  {obj.name}/{n:12s} {len(ps):6d}  x {lo[0]:5.2f}..{hi[0]:5.2f}  y {lo[1]:5.2f}..{hi[1]:5.2f}  z {lo[2]:5.2f}..{hi[2]:5.2f}')


SPECIALS = {
    'paint': ((0.05, 0.42, 0.42), 0.3, 0.4), 'glass': ((0.03, 0.05, 0.06), 0.3, 0.2),
    'trim': ((0.035, 0.036, 0.038), 0.0, 0.6), 'tire': ((0.025, 0.025, 0.025), 0.0, 0.9),
    'rim': ((0.45, 0.45, 0.45), 0.65, 0.3), 'chrome': ((0.8, 0.8, 0.82), 1.0, 0.2),
    'headlight': ((1.0, 0.96, 0.67), 0.25, 0.26), 'taillight': ((0.58, 0.02, 0.02), 0.18, 0.29),
    'amber': ((0.9, 0.45, 0.08), 0.1, 0.3), 'engine_metal': ((0.5, 0.5, 0.5), 0.7, 0.4),
    'engine_dark': ((0.06, 0.06, 0.065), 0.2, 0.7),
}


def palette(colours, k=8, seed=1):
    """k-means over colours (Lab-ish: plain RGB is fine at this scale) -> labels."""
    rng = np.random.default_rng(seed)
    c = colours ** (1 / 2.2)
    centers = c[rng.choice(len(c), size=min(k, len(c)), replace=False)]
    for _ in range(12):
        d = ((c[:, None, :] - centers[None]) ** 2).sum(-1)
        lab = d.argmin(1)
        for j in range(len(centers)):
            if (lab == j).any():
                centers[j] = c[lab == j].mean(0)
    return lab


def hue_sat_lum(c):
    c = np.asarray(c) ** (1 / 2.2)
    mx, mn = c.max(), c.min()
    lum = 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]
    sat = 0 if mx < 1e-4 else (mx - mn) / mx
    if mx - mn < 1e-4:
        hue = 0.0
    elif mx == c[0]:
        hue = ((c[1] - c[2]) / (mx - mn)) % 6
    elif mx == c[1]:
        hue = (c[2] - c[0]) / (mx - mn) + 2
    else:
        hue = (c[0] - c[1]) / (mx - mn) + 4
    return hue * 60, sat, lum


def decimate(obj, ratio):
    if ratio >= 1.0:
        return
    mod = obj.modifiers.new('dec', 'DECIMATE')
    mod.ratio = ratio
    mod.use_collapse_triangulate = True
    with bpy.context.temp_override(object=obj, active_object=obj):
        bpy.ops.object.modifier_apply(modifier=mod.name)


def flat(obj):
    obj.data.polygons.foreach_set('use_smooth', [False] * len(obj.data.polygons))
    obj.data.update()


def split_faces(obj, pick, name):
    """Moves faces where pick(face_centre, material_name) is true into a new object."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    mats = [m.name for m in obj.data.materials]
    keep = bmesh.new()
    take_idx = [f.index for f in bm.faces if pick(f.calc_center_median(), mats[f.material_index])]
    bm.free()
    if not take_idx:
        return None
    new = obj.copy()
    new.data = obj.data.copy()
    new.name = name
    bpy.context.scene.collection.objects.link(new)
    for target, keep_set in ((new, set(take_idx)), (obj, None)):
        bm = bmesh.new()
        bm.from_mesh(target.data)
        bm.faces.ensure_lookup_table()
        if keep_set is not None:
            dead = [f for f in bm.faces if f.index not in keep_set]
        else:
            s = set(take_idx)
            dead = [f for f in bm.faces if f.index in s]
        bmesh.ops.delete(bm, geom=dead, context='FACES')
        bm.to_mesh(target.data)
        bm.free()
    keep.free()
    return new


def set_origin(obj, point):
    obj.data.transform(Matrix.Translation(-point))
    obj.location = point


def empty(name, at, parent):
    e = bpy.data.objects.new(name, None)
    e.empty_display_size = 0.1
    bpy.context.scene.collection.objects.link(e)
    e.location = at
    e.parent = parent
    return e


# ---------------------------------------------------------------- rider
SHIRTS = {'tricycle': (0.75, 0.62, 0.12), 'motorcycle': (0.08, 0.2, 0.55)}


def build_rider(kind, seat, grips, pegs, lean_deg, helmet):
    """The rigged character, posed onto seat/grips/pegs, applied, coloured, decimated."""
    objs = import_ref('gangster_dealer_musculo')
    arm = next(o for o in objs if o.type == 'ARMATURE')
    drop = ('MOUTH', 'LACRIMAL', 'eyelash', 'Eye1')
    meshes = [o for o in objs if o.type == 'MESH' and o.data.polygons and o.data.materials
              and not any(k in o.data.materials[0].name for k in drop)]
    dead = [o for o in objs if o.type == 'MESH' and o not in meshes]
    objs = [o for o in objs if o not in dead]
    for o in dead:
        bpy.data.objects.remove(o, do_unlink=True)
    # This rig's rest pose is broken (the jeans' bind coordinates span 2 m); its animation's first
    # frame is the true standing pose. Bake that frame into the bones, drop the action, and pose
    # on top of it.
    act = arm.animation_data.action if arm.animation_data else None
    if act:
        bpy.context.scene.frame_set(int(act.frame_range[0]))
        bpy.context.view_layer.update()
    base = {pb.name: pb.matrix_basis.copy() for pb in arm.pose.bones}
    if arm.animation_data:
        arm.animation_data_clear()
    for pb in arm.pose.bones:
        pb.matrix_basis = base[pb.name]
    bpy.context.view_layer.update()
    B = lambda s: next(pb for pb in arm.pose.bones if pb.name.endswith(s))
    W = lambda pb: arm.matrix_world @ pb.head

    # Rest-pose colours (shirt by region) before anything moves.
    hip = W(B('CC_Base_Hip_03'))
    neck = W(B('NeckTwist01_038'))
    elbow_z = (W(B('L_Forearm_053')).z + W(B('R_Forearm_077')).z) / 2
    shirt = SHIRTS[kind]
    for o in meshes:
        cols, _, srcs = face_colours(o)
        dg = bpy.context.evaluated_depsgraph_get()
        ev = o.evaluated_get(dg).to_mesh()
        mw = o.matrix_world
        names = []
        for f, c in zip(ev.polygons, cols):
            p = mw @ f.center
            src = srcs[f.index]
            h, s, l = hue_sat_lum(c)
            if 'Body' in src and hip.z + 0.02 < p.z < neck.z - 0.04 and (abs(p.x - hip.x) < 0.2 or p.z > elbow_z + 0.03):
                names.append('shirt')
            elif 'Acs' in src:
                names.append('trim')
            elif 'Cloth' in src:
                names.append('boots' if p.z < hip.z - 0.85 else 'jeans')
            elif l > 0.15 and h < 50 and s > 0.15:
                names.append('skin')
            else:
                names.append('hair')
        o.evaluated_get(dg).to_mesh_clear()
        assign(o, names, cols, {'shirt': (shirt, 0.0, 0.8), 'jeans': ((0.06, 0.08, 0.13), 0.0, 0.8),
                                'boots': ((0.05, 0.035, 0.025), 0.0, 0.7), 'skin': ((0.42, 0.24, 0.15), 0.0, 0.6),
                                'hair': ((0.02, 0.018, 0.016), 0.0, 0.8), 'trim': SPECIALS['trim']})

    # Leg joints from the skin weights (vertices shared between the bones on each side of a joint).
    LEG = {'L': (('Hip_03', 'Pelvis_04'), ('L_Thigh_05', 'L_ThighTwist01_018', 'L_ThighTwist02_019'),
                 ('L_Calf_06', 'L_CalfTwist01_015', 'L_CalfTwist02_016', 'L_KneeShareBone_017'), ('L_Foot_07', 'L_ToeBase_09')),
           'R': (('Hip_03', 'Pelvis_04'), ('R_Thigh_020', 'R_ThighTwist01_021', 'R_ThighTwist02_022'),
                 ('R_Calf_023', 'R_CalfTwist01_033', 'R_CalfTwist02_034', 'R_KneeShareBone_032'), ('R_Foot_024', 'R_ToeBase_025'))}
    cloth = next(o for o in meshes if 'Cloth' in o.data.materials[0].name or any(
        m.name in ('jeans', 'boots') for m in o.data.materials))

    def joint(a_set, b_set):
        names = {i: g.name.split(':')[-1].replace('CC_Base_', '') for i, g in enumerate(cloth.vertex_groups)}
        # Positions as displayed (evaluated: the armature modifier is in the stack), same vertex order.
        ev = cloth.evaluated_get(bpy.context.evaluated_depsgraph_get())
        shown = ev.data.vertices
        acc, n = Vector(), 0
        for v in cloth.data.vertices:
            wa = sum(g.weight for g in v.groups if names[g.group] in a_set)
            wb = sum(g.weight for g in v.groups if names[g.group] in b_set)
            if wa > 0.2 and wb > 0.2:
                acc += cloth.matrix_world @ shown[v.index].co
                n += 1
        return acc / max(n, 1)
    if '--debug' in sys.argv:
        dg0 = bpy.context.evaluated_depsgraph_get()
        for o in meshes:
            ev = o.evaluated_get(dg0)
            zs = [(o.matrix_world @ v.co).z for v in ev.data.vertices]
            zr = [(o.matrix_world @ v.co).z for v in o.data.vertices]
            print(f'  mesh {o.data.materials[0].name[:24]:24s} shown z {min(zs):.2f}..{max(zs):.2f} raw z {min(zr):.2f}..{max(zr):.2f} mods {[m.type for m in o.modifiers]}')
    JOINTS = {}
    for side, (hip_set, thigh_set, calf_set, foot_set) in LEG.items():
        JOINTS[side] = (joint(hip_set, thigh_set), joint(thigh_set, calf_set), joint(calf_set, foot_set))
    # Place: the hip joints just above the saddle (sitting bones on it), on its front half.
    root = arm
    while root.parent:
        root = root.parent
    hips = (JOINTS['L'][0] + JOINTS['R'][0]) / 2
    shift = seat + Vector((0, 0.0, 0.05)) - hips
    root.location += shift
    bpy.context.view_layer.update()
    for side in JOINTS:
        JOINTS[side] = tuple(j + shift for j in JOINTS[side])
        if '--debug' in sys.argv:
            print(f'  joints {side}: ' + ' '.join(str(tuple(round(x, 2) for x in j)) for j in JOINTS[side]))

    def turn(pb, pivot, rot):
        """Rotates pose bone pb about a world pivot by world rotation rot (a 3x3)."""
        inv = arm.matrix_world.inverted()
        piv = inv @ pivot
        r = (inv.to_3x3() @ rot @ arm.matrix_world.to_3x3()).to_4x4()
        pb.matrix = Matrix.Translation(piv) @ r @ Matrix.Translation(-piv) @ pb.matrix
        bpy.context.view_layer.update()

    def aim(pb, child, goal):
        """Swings pb about its head so the joint `child` (a pose bone) lands on the line to goal."""
        h = W(pb)
        q = (W(child) - h).rotation_difference(goal - h)
        turn(pb, h, q.to_matrix())

    def two_bone(upper, lower, end, goal, pole):
        """Analytic two-bone solve: the middle joint bends toward `pole` (a world direction)."""
        hpt, mid, tip = W(upper), W(lower), W(end)
        la, lb = (mid - hpt).length, (tip - mid).length
        d = min((goal - hpt).length, la + lb - 1e-3)
        u = (goal - hpt).normalized()
        n = (pole - u * pole.dot(u)).normalized()
        cos_a = (la * la + d * d - lb * lb) / (2 * la * d)
        knee = hpt + u * la * cos_a + n * la * math.sqrt(max(0.0, 1 - cos_a * cos_a))
        aim(upper, lower, knee)
        aim(lower, end, goal)

    def leg(thigh, calf, sx, goal):
        """Two-bone solve for a leg. This rig's leg bones rest near the floor, away from the mesh's
        joints, so pivot on joints measured from the bind pose (hip, knee, ankle) instead of the
        bone heads; deformation is relative to rest, so that is exact."""
        hip_j, knee0, ankle0 = JOINTS['L' if sx > 0 else 'R']
        la, lb = (knee0 - hip_j).length, (ankle0 - knee0).length
        d = min((goal - hip_j).length, la + lb - 1e-3)
        u = (goal - hip_j).normalized()
        pole = Vector((sx * 0.2, -1.0, 0.5))
        n = (pole - u * pole.dot(u)).normalized()
        cos_a = (la * la + d * d - lb * lb) / (2 * la * d)
        knee = hip_j + u * la * cos_a + n * la * math.sqrt(max(0.0, 1 - cos_a * cos_a))
        r1 = (knee0 - hip_j).rotation_difference(knee - hip_j)
        turn(thigh, hip_j, r1.to_matrix())
        ankle1 = hip_j + r1 @ (ankle0 - hip_j)
        r2 = (ankle1 - knee).rotation_difference(goal - knee)
        turn(calf, knee, r2.to_matrix())

    # Lean the trunk toward the bars (positive about +X tips the head toward -Y, forward).
    # Lean forward from the waist until the hands can reach the grips (at least lean_deg).
    reach = sum((W(B(a)) - W(B(b))).length for a, b in (('L_Upperarm_052', 'L_Forearm_053'),
                                                         ('L_Forearm_053', 'L_Hand_057')))
    leaned = 0.0
    while leaned < 60.0:
        gap = max((W(B('L_Upperarm_052')) - grips['L']).length, (W(B('R_Upperarm_074')) - grips['R']).length)
        if leaned >= lean_deg and gap < reach * 0.95:
            break
        for name in ('Waist_035', 'Spine01_036'):
            pb = B(name)
            turn(pb, W(pb), Matrix.Rotation(math.radians(1.5), 3, 'X'))
        leaned += 3.0
    if '--debug' in sys.argv:
        print(f'  rider lean {leaned:.0f} deg')
    for s, sx in (('L', 1.0), ('R', -1.0)):   # the character's left is +X (he faces -Y)
        thigh, calf, foot = (B(f'{s}_Thigh_0{"5" if s == "L" else "20"}'), B(f'{s}_Calf_0{"6" if s == "L" else "23"}'),
                             B(f'{s}_Foot_0{"7" if s == "L" else "24"}'))
        leg(thigh, calf, sx, pegs[s])
        up, fore, hand = (B(f'{s}_Upperarm_0{"52" if s == "L" else "74"}'), B(f'{s}_Forearm_0{"53" if s == "L" else "77"}'),
                          B(f'{s}_Hand_0{"57" if s == "L" else "81"}'))
        two_bone(up, fore, hand, grips[s], Vector((sx * 0.8, 0.3, -0.5)))
    # Hands drift with the lean; re-solve, then apply the pose to the meshes.
    bpy.context.view_layer.update()
    if '--debug' in sys.argv:
        for nm, goal in (('L_Foot_07', pegs['L']), ('R_Foot_024', pegs['R']), ('L_Hand_057', grips['L']), ('R_Hand_081', grips['R'])):
            print(f'  rider {nm}: {tuple(round(x, 2) for x in W(B(nm)))} goal {tuple(round(x, 2) for x in goal)}')
        print(f'  rider hip {tuple(round(x, 2) for x in W(B("CC_Base_Hip_03")))} seat {tuple(round(x, 2) for x in seat)}')
        for nm in ('L_Thigh_05', 'L_ThighTwist01_018', 'L_ThighTwist02_019', 'L_Calf_06', 'L_CalfTwist02_016'):
            pb = B(nm)
            print(f'  bone {nm}: head {tuple(round(x, 2) for x in W(pb))} parent {pb.parent.name.split(":")[-1]} '
                  f'inherit_rot {pb.bone.use_inherit_rotation} cons {[c.type for c in pb.constraints]}')
    dg = bpy.context.evaluated_depsgraph_get()
    baked = []
    for o in meshes:
        ev = o.evaluated_get(dg)
        me = bpy.data.meshes.new_from_object(ev, depsgraph=dg)
        me.transform(o.matrix_world)
        nb = bpy.data.objects.new(o.name + '_posed', me)
        bpy.context.scene.collection.objects.link(nb)
        baked.append(nb)
    for o in objs:
        if o.name in bpy.data.objects:
            bpy.data.objects.remove(o, do_unlink=True)
    rider = join(baked, 'rider')
    if helmet:
        top = max((v.co for v in rider.data.vertices), key=lambda v: v.z)
        head_c = Vector((top.x, top.y + 0.02, top.z - 0.12))
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=9, radius=0.155, location=head_c)
        hel = bpy.context.active_object
        hel.scale = (1.0, 1.15, 1.0)
        bm = bmesh.new()
        bm.from_mesh(hel.data)
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -0.06 and v.co.y < 0.0], context='VERTS')
        bm.to_mesh(hel.data)
        bm.free()
        hel.data.transform(Matrix.Diagonal((1.0, 1.15, 1.0, 1.0)))
        hel.scale = (1, 1, 1)
        hel.data.transform(Matrix.Translation(hel.location))
        hel.location = (0, 0, 0)
        hel.data.materials.append(material('helmet', (0.6, 0.03, 0.02), 0.2, 0.3))
        rider = join([rider, hel], 'rider')
    decimate(rider, 6500 / max(len(rider.data.polygons), 1))
    flat(rider)
    return rider


# ---------------------------------------------------------------- vehicles
# Reference frame -> ours: the reference bikes face +X with up +Z; we want forward -Y.
TO_OURS = Matrix.Rotation(-math.pi / 2, 4, 'Z')


def finish(kind, body, wheels, rider, lamps):
    root = bpy.data.objects.new(kind, None)
    bpy.context.scene.collection.objects.link(root)
    for o in [body, *wheels, rider]:
        if o:
            o.parent = root
    for name, at in lamps.items():
        empty(name, at, root)
    lo, hi = extents(body)
    print(f'{kind}: body {len(body.data.polygons)} tris, rider {len(rider.data.polygons)}, '
          f'wheels {[w.name for w in wheels]}, extents x {lo[0]:.2f}..{hi[0]:.2f} '
          f'y {lo[1]:.2f}..{hi[1]:.2f} z {lo[2]:.2f}..{hi[2]:.2f}')
    for o in bpy.context.scene.objects:
        o.select_set(o == root or o.parent == root)
    path = OUT / f'{kind}.glb'
    bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', use_selection=True,
                              export_yup=True, export_extras=True, export_materials='EXPORT',
                              export_cameras=False, export_lights=False, export_apply=True)
    return root


def wheel_nodes(body, is_wheel, hubs):
    """Faces is_wheel(centre, material) nearest each hub become `wheel_<name>`, origin on the hub."""
    out = []
    for name, hub in hubs.items():
        others = [h for n, h in hubs.items() if n != name]

        def pick(c, m, hub=hub, others=others):
            if not is_wheel(c, m):
                return False
            d = (Vector(c) - hub).length
            return all(d < (Vector(c) - o).length for o in others) and d < 0.42
        w = split_faces(body, pick, 'wheel_' + name)
        if w:
            set_origin(w, hub)
            out.append(w)
    return out


def tricycle():
    fresh_scene()
    meshes = bake_transforms(import_ref('tricycle'))
    body = join(meshes, 'body')
    # Reference units: roof at 0.065 -> a 1.85 m roof. Bike centreline at y 0.0218, wheels on z 0.
    lo, hi = extents(body)
    s = 1.85 / (hi[2] - lo[2])
    transform(body, Matrix.Translation((0, 0, -lo[2] * s)) @ TO_OURS @ Matrix.Scale(s, 4)
              @ Matrix.Translation((0, -0.0218, 0)))
    cols, alphas, srcs = face_colours(body)
    me = body.data
    centres = [f.center.copy() for f in me.polygons]
    lo, hi = extents(body)
    front_y = lo[1]
    names = []
    rest = []
    for i, (c, a, src) in enumerate(zip(cols, alphas, srcs)):
        h, sat, l = hue_sat_lum(c)
        p = centres[i]
        sl = src.lower()
        if a < 0.9:
            names.append('glass')
        elif 'wheel' in sl:
            names.append('tire' if l < 0.3 else 'rim')
        elif sl in ('light', 'lights', 'material.001') and l > 0.55 and p.y < front_y + 0.5:
            names.append('headlight')
        elif sl in ('light', 'lights') and h < 20 and sat > 0.5:
            names.append('taillight' if p.y > front_y + 1.0 else 'amber')
        elif sl in ('light', 'lights') and 20 <= h < 50 and sat > 0.5:
            names.append('amber')
        elif 'silver' in sl or (sat < 0.12 and l > 0.6 and 'barako' in sl):
            names.append('chrome')
        elif 'black' in sl or 'grip' in sl:
            names.append('trim')
        elif 150 < h < 210 and sat > 0.25:
            names.append('paint')     # the teal sidecar: recoloured per instance in game
        else:
            names.append(None)
            rest.append(i)
    if rest:
        lab = palette(cols[rest], k=7)
        for j, i in enumerate(rest):
            names[i] = f'tri_{lab[j]}'
    assign(body, names, cols, SPECIALS)
    if '--debug' in sys.argv:
        import collections
        hist = collections.Counter()
        for i, n in enumerate(names):
            if n == 'tire':
                p = centres[i]
                hist[(round(p.x * 2) / 2, round(p.y * 10) / 10)] += 1
        print('  tire faces (x, y):', sorted(hist.items()))
    hubs_src = {}
    for i, n in enumerate(names):
        if n in ('tire', 'rim'):
            p = centres[i]
            key = 'side' if p.x < -0.45 else ('front' if p.y < 0.35 else 'rear')
            hubs_src.setdefault(key, []).append(p)
    hubs = {k: Vector([(min(v[a] for v in ps) + max(v[a] for v in ps)) / 2 for a in range(3)])
            for k, ps in hubs_src.items()}
    wheels = wheel_nodes(body, lambda c, m: m in ('tire', 'rim'), hubs)
    decimate(body, 14000 / max(len(body.data.polygons), 1))
    for o in [body, *wheels]:
        flat(o)
    grips = grip_points(body, 'trim', 0.95)
    seat = seat_point(body, hubs)
    pegs = {'L': Vector((0.22, seat.y - 0.42, 0.3)), 'R': Vector((-0.22, seat.y - 0.42, 0.3))}
    rider = build_rider('tricycle', seat, grips, pegs, 15, helmet=False)
    lamps = lamp_points(body)
    return finish('tricycle', body, wheels, rider, lamps)


def grip_points(body, mat_name, min_z):
    """The handlebar ends: outermost vertices of `mat_name` faces above min_z near the bars."""
    me = body.data
    mi = [m.name for m in me.materials].index(mat_name) if mat_name in [m.name for m in me.materials] else -1
    pts = [f.center for f in me.polygons if f.material_index == mi and f.center.z > min_z]
    front = min(p.y for p in pts)
    bar = [p for p in pts if p.y < front + 0.35 and abs(p.x) < 0.5]
    left = max(bar, key=lambda p: p.x)
    right = min(bar, key=lambda p: p.x)
    return {'L': left.copy() + Vector((-0.04, 0, 0)), 'R': right.copy() + Vector((0.04, 0, 0))}


def seat_point(body, hubs):
    """Top of the saddle: the highest bike-centreline faces between the axles, below the bars."""
    me = body.data
    skip = {i for i, m in enumerate(me.materials) if m.name in ('paint', 'glass', 'tire', 'rim')}
    fy, ry = hubs['front'].y, hubs['rear'].y
    # Behind the tank: the rear half of the wheelbase.
    pts = [f.center for f in me.polygons if f.material_index not in skip and abs(f.center.x) < 0.14
           and (fy + ry) / 2 + 0.05 < f.center.y < ry + 0.1 and f.center.z < 1.05]
    top = max(p.z for p in pts)
    saddle = [p for p in pts if p.z > top - 0.05]
    # Riders sit on the front of the saddle, by the tank.
    y = min(p.y for p in saddle) + 0.14
    if '--debug' in sys.argv:
        print(f'  seat top {top:.2f} at y {y:.2f}; hubs ' + ', '.join(f'{k} y {v.y:.2f}' for k, v in hubs.items()))
    return Vector((0.0, y, top))


def lamp_points(body):
    me = body.data
    names = [m.name for m in me.materials]
    out = {}
    for lamp in ('headlight', 'taillight'):
        if lamp in names:
            i = names.index(lamp)
            ps = [f.center for f in me.polygons if f.material_index == i]
            if ps:
                out[lamp] = sum(ps, Vector()) / len(ps)
    return out


def motorcycle():
    fresh_scene()
    meshes = bake_transforms(import_ref('motorcycle'))
    body = join(meshes, 'body')
    lo, hi = extents(body)
    # Already in metres (2.2 m long); trim to a 2.0 m commuter-ish bike, centre on the bike axis.
    s = 2.0 / (hi[0] - lo[0])
    cy = (lo[1] + hi[1]) / 2
    transform(body, TO_OURS @ Matrix.Scale(s, 4) @ Matrix.Translation((-(lo[0] + hi[0]) / 2, -cy, -lo[2])))
    cols, alphas, srcs = face_colours(body)
    me = body.data
    centres = [f.center.copy() for f in me.polygons]
    lo, hi = extents(body)
    # Wheel hubs: the tyres are the dark ring faces low at each end.
    hubs = {}
    radius = {}
    for name, sel in (('front', lambda p: p.y < lo[1] + 0.75), ('rear', lambda p: p.y > hi[1] - 0.75)):
        ring = [centres[i] for i in range(len(centres)) if sel(centres[i]) and centres[i].z < 0.75
                and hue_sat_lum(cols[i])[2] < 0.22 and abs(centres[i].x) < 0.12]
        ys = [p.y for p in ring]
        zs = [p.z for p in ring]
        hubs[name] = Vector((0.0, (min(ys) + max(ys)) / 2, (min(zs) + max(zs)) / 2))
        radius[name] = (max(zs) - min(zs)) / 2 + 0.01
    names = []
    rest = []
    for i, c in enumerate(cols):
        h, sat, l = hue_sat_lum(c)
        p = centres[i]
        near = min(((Vector((0, p.y, p.z)) - Vector((0, hb.y, hb.z))).length, n) for n, hb in hubs.items())
        if near[0] < radius[near[1]] and abs(p.x) < 0.13:
            # Tyre = the outer band (tread and sidewall); spokes, hub and rim inside it.
            names.append('tire' if near[0] > radius[near[1]] * 0.74 else 'rim')
        elif 35 < h < 70 and sat > 0.45 and l > 0.25:
            names.append('paint')     # the yellow tank and covers
        elif l > 0.62 and sat < 0.2 and p.z > 0.9 and p.y < lo[1] + 0.45:
            names.append('headlight')
        elif h < 15 and sat > 0.5 and p.y > hi[1] - 0.6:
            names.append('taillight')
        elif sat < 0.15 and l > 0.45:
            names.append('chrome')
        elif l < 0.08:
            names.append('trim')
        else:
            names.append(None)
            rest.append(i)
    if rest:
        lab = palette(cols[rest], k=6)
        for j, i in enumerate(rest):
            names[i] = f'moto_{lab[j]}'
    assign(body, names, cols, SPECIALS)
    wheels = wheel_nodes(body, lambda c, m: m in ('tire', 'rim') and abs(c.x) < 0.13, hubs)
    decimate(body, 12000 / max(len(body.data.polygons), 1))
    for w in wheels:
        decimate(w, 1500 / max(len(w.data.polygons), 1))
    for o in [body, *wheels]:
        flat(o)
    grips = grip_points(body, 'trim', 0.95) if 'trim' in [m.name for m in body.data.materials] else None
    seat = seat_point(body, hubs)
    pegs = {'L': Vector((0.22, seat.y - 0.4, 0.33)), 'R': Vector((-0.22, seat.y - 0.4, 0.33))}
    rider = build_rider('motorcycle', seat, grips, pegs, 15, helmet=True)
    lamps = lamp_points(body)
    return finish('motorcycle', body, wheels, rider, lamps)


def preview(root, path):
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.light = 'STUDIO'
    sc.display.shading.color_type = 'MATERIAL'
    sc.render.resolution_x, sc.render.resolution_y = 800, 600
    cam = bpy.data.objects.new('preview_cam', bpy.data.cameras.new('preview_cam'))
    sc.collection.objects.link(cam)
    sc.camera = cam
    for view, d in {'front34': Vector((-2.6, -3.4, 1.6)), 'side': Vector((-4.2, 0.2, 1.0)),
                    'rear34': Vector((2.4, 3.6, 1.8))}.items():
        cam.location = d
        cam.rotation_euler = (Vector((0, 0, 0.8)) - d).to_track_quat('-Z', 'Y').to_euler()
        sc.render.filepath = f'{path}_{root.name}_{view}.png'
        bpy.ops.render.render(write_still=True)


if __name__ == '__main__':
    which = [a for a in ('tricycle', 'motorcycle') if a in sys.argv] or ['tricycle', 'motorcycle']
    for kind in which:
        root = tricycle() if kind == 'tricycle' else motorcycle()
        if PREVIEW:
            preview(root, PREVIEW)
