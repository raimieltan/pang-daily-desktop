"""Shared helpers for the hub building builders (Kyo Coffee, the talyer).

Coordinates: the builders are written in the Babylon hub's layout units (docs/archive/HUB_LAYOUT.md):
x east, y up, z north, metres. `Kit(origin)` turns those into Blender (X east, Y north, Z up) around
`origin` = (x, z) on the ground, so the GLB's origin is that point; glTF then maps Blender Y to -Z,
which is Godot's north. Place the GLB at Godot (x, 0, -z) to put it back in hub coordinates.

Materials carry their intent in the name (game/world/world_kit.gd maps them):
  * plain names            -> manga world tone; lit value from the colour's brightness
  * world preset names     -> that preset ("concrete", "gravel", "leaves", "grass", "dirt", "post")
  * "accent_*"             -> a flat spot colour (signs, pink posts)
  * "lamp_*"               -> a glowing colour (lit glass, sign letters, bulbs)
Objects named "*-colonly" become invisible static colliders on import.
"""
import math
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/world'
OUT.mkdir(parents=True, exist_ok=True)


def hexcol(h):
    h = h.lstrip('#')
    srgb = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb]
    return (*lin, 1.0)


def _detach(o):
    for c in list(o.users_collection):
        c.objects.unlink(o)


class Kit:
    def __init__(self, name, origin):
        self.name = name
        self.ox, self.oz = origin
        self.mats = {}
        # Headless: the factory scene. Live in the GUI: its own scene, so the user's scenes stay as
        # they are and a rebuild replaces only what the last run made.
        if bpy.app.background:
            sc = bpy.context.scene
        else:
            sc = bpy.data.scenes.get(f'{name}_build') or bpy.data.scenes.new(f'{name}_build')
            bpy.context.window.scene = sc
        for o in list(sc.objects):
            bpy.data.objects.remove(o, do_unlink=True)
        self.root = bpy.data.objects.new(name, None)
        sc.collection.objects.link(self.root)
        self.parts = {}

    # ---------------------------------------------------------------- materials
    def mat(self, name, color='#888888'):
        if name not in self.mats:
            m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
            m.diffuse_color = hexcol(color)
            m.use_nodes = True
            bsdf = m.node_tree.nodes.get('Principled BSDF')
            if bsdf:
                bsdf.inputs['Base Color'].default_value = hexcol(color)
                bsdf.inputs['Roughness'].default_value = 0.9
                if name.startswith('lamp_'):
                    bsdf.inputs['Emission Color'].default_value = hexcol(color)
                    bsdf.inputs['Emission Strength'].default_value = 1.0
            self.mats[name] = m
        return self.mats[name]

    # ---------------------------------------------------------------- placement
    def at(self, x, y, z):
        """Layout (x east, y up, z north) -> Blender location around the origin."""
        return Vector((x - self.ox, z - self.oz, y))

    def _group(self, group):
        if group not in self.parts:
            g = bpy.data.objects.new(f'{self.name}_{group}', None)
            bpy.context.scene.collection.objects.link(g)
            g.parent = self.root
            self.parts[group] = g
        return self.parts[group]

    def _link(self, obj, group):
        bpy.context.scene.collection.objects.link(obj)
        obj.parent = self._group(group)
        return obj

    def box(self, center, size, mat, color='#888888', group='building', collide=False, rot_deg=0.0):
        """Axis box in layout units: center (x, y, z), size (sx, sy, sz); rot_deg turns it about up."""
        cx, cy, cz = center
        sx, sy, sz = size
        bpy.ops.mesh.primitive_cube_add(size=1, location=self.at(cx, cy, cz))
        o = bpy.context.active_object
        o.scale = (sx, sz, sy)
        o.rotation_euler = (0, 0, math.radians(rot_deg))
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        o.data.materials.append(self.mat(mat, color))
        _detach(o)
        self._link(o, group)
        if collide:
            self.collider(center, size, rot_deg)
        return o

    def collider(self, center, size, rot_deg=0.0):
        cx, cy, cz = center
        sx, sy, sz = size
        bpy.ops.mesh.primitive_cube_add(size=1, location=self.at(cx, cy, cz))
        o = bpy.context.active_object
        self._ncol = getattr(self, '_ncol', 0) + 1
        o.name = f'{self.name}_wall{self._ncol:03d}-colonly'
        o.scale = (sx, sz, sy)
        o.rotation_euler = (0, 0, math.radians(rot_deg))
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        _detach(o)
        self._link(o, 'colliders')
        return o

    def cyl(self, base, radius, height, mat, color='#888888', group='props', verts=10, radius2=None):
        """Upright cylinder (or cone with radius2) standing on `base` (x, y, z)."""
        x, y, z = base
        if radius2 is None:
            bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=height,
                                                location=self.at(x, y + height / 2, z))
        else:
            bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius, radius2=radius2, depth=height,
                                            location=self.at(x, y + height / 2, z))
        o = bpy.context.active_object
        o.data.materials.append(self.mat(mat, color))
        _detach(o)
        return self._link(o, group)

    def ball(self, center, radius, mat, color='#888888', group='props', squash=1.0, subdiv=1):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdiv, radius=radius, location=self.at(*center))
        o = bpy.context.active_object
        o.scale = (1, 1, squash)
        bpy.ops.object.transform_apply(scale=True)
        o.data.materials.append(self.mat(mat, color))
        _detach(o)
        return self._link(o, group)

    def text(self, body, center, height, mat, color, facing='-x', depth=0.02, group='signs', align='CENTER',
             font=None):
        """Raised lettering `height` tall (cap height ~0.72 of the size), centred on `center`, reading
        left-to-right for someone facing it. `facing` is the direction the letters face."""
        curve = bpy.data.curves.new(f'{self.name}_txt', 'FONT')
        curve.body = body
        curve.size = height / 0.72
        curve.extrude = depth / 2
        curve.align_x = align
        curve.align_y = 'CENTER'
        if font:
            curve.font = font
        o = bpy.data.objects.new(f'{self.name}_txt', curve)
        bpy.context.scene.collection.objects.link(o)
        # Text lies in XY facing +Z; stand it up so it faces the requested way.
        yaw = {'-x': -90, '+x': 90, '-y': 0, '+y': 180}[facing]
        o.rotation_euler = (math.radians(90), 0, math.radians(yaw))
        o.location = self.at(*center)
        bpy.context.view_layer.objects.active = o
        o.select_set(True)
        bpy.ops.object.convert(target='MESH')
        o = bpy.context.active_object
        o.data.materials.clear()
        o.data.materials.append(self.mat(mat, color))
        _detach(o)
        o.select_set(False)
        return self._link(o, group)

    # ---------------------------------------------------------------- output
    def finish(self):
        """Join each group into one mesh per group (few draw calls), keep colliders separate."""
        for group, g in self.parts.items():
            kids = [c for c in g.children if c.type == 'MESH']
            if group == 'colliders' or len(kids) < 2:
                continue
            bpy.ops.object.select_all(action='DESELECT')
            for k in kids:
                k.select_set(True)
            bpy.context.view_layer.objects.active = kids[0]
            bpy.ops.object.join()
            kids[0].name = f'{self.name}_{group}_mesh'
        for o in bpy.context.scene.objects:
            if o.type == 'MESH':
                for p in o.data.polygons:
                    p.use_smooth = False

    def export(self):
        path = OUT / f'{self.name}.glb'
        bpy.ops.object.select_all(action='SELECT')
        bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', use_selection=False,
                                  export_apply=True, export_yup=True, export_materials='EXPORT', use_active_scene=True)
        print('exported', path)
        return path

    def preview(self, path, eye, look, lens=28, size=(1600, 1000)):
        """Workbench render from layout-space `eye` toward `look`, for checking against the spec."""
        sc = bpy.context.scene
        sc.render.engine = 'BLENDER_WORKBENCH'
        sc.display.shading.light = 'STUDIO'
        sc.display.shading.color_type = 'MATERIAL'
        sc.display.shading.show_cavity = True
        sc.display.shading.show_object_outline = True
        sc.render.resolution_x, sc.render.resolution_y = size
        cam_data = bpy.data.cameras.new('preview_cam')
        cam_data.lens = lens
        cam = bpy.data.objects.new('preview_cam', cam_data)
        sc.collection.objects.link(cam)
        cam.location = self.at(*eye)
        d = self.at(*look) - cam.location
        cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
        sc.camera = cam
        hidden = [o for o in sc.objects if o.name.endswith('-colonly')]
        for o in hidden:
            o.hide_render = True
        sc.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        for o in hidden:
            o.hide_render = False
        bpy.data.objects.remove(cam, do_unlink=True)
