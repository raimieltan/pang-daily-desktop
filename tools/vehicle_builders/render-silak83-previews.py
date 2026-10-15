"""Preview renders of the exported Silak83 GLB: assembled views, panel removal, exploded.

Run: Blender --background --factory-startup --python tools/vehicle_builders/render-silak83-previews.py
Renders the delivered GLB (not the builder scene) into assets/vehicles/lancer/previews/.
"""
import bpy
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
GLB = ROOT / 'assets/vehicles/lancer/lancer_box_1983_modular.glb'
OUT = ROOT / 'assets/vehicles/lancer/previews'
OUT.mkdir(parents=True, exist_ok=True)
C = lambda p: Vector((p[0], -p[2], p[1]))

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(GLB))
sc = bpy.context.scene
sc.render.engine = 'BLENDER_WORKBENCH'
sc.display.shading.light = 'STUDIO'
sc.display.shading.color_type = 'MATERIAL'
sc.display.shading.show_cavity = True
sc.render.resolution_x, sc.render.resolution_y = 1200, 800
cd = bpy.data.cameras.new('cam')
cam = bpy.data.objects.new('cam', cd)
sc.collection.objects.link(cam)
sc.camera = cam
attach = {o.name[7:]: o for o in sc.objects if o.name.startswith('attach_')}
home = {k: o.location.copy() for k, o in attach.items()}


def shot(name, eye, target=(0, 0.6, 0), lens=40, hide=(), explode=0.0):
    for k, o in attach.items():
        o.location = home[k]
        for c in o.children_recursive:
            c.hide_render = k in hide
        if explode and k != 'engine':
            d = Vector(home[k])
            d.z = max(d.z, 0.4)          # lift everything a little
            o.location = home[k] + d.normalized() * explode
    e, t = C(eye), C(target)
    cam.location = e
    cam.rotation_euler = (e - t).to_track_quat('Z', 'Y').to_euler()
    cd.lens = lens
    sc.render.filepath = str(OUT / f'{name}.png')
    bpy.ops.render.render(write_still=True)


FL, RL = (3.4, 1.5, 4.6), (3.0, 1.6, -4.8)
shot('01_front_left', FL)
shot('02_rear_left', RL)
shot('03_left_side', (7.5, 0.8, 0), lens=45)
shot('04_front', (0, 0.9, 7.0), lens=50)
shot('05_rear', (0, 1.0, -7.0), lens=50)
shot('06_hood_removed', FL, hide={'hood'})
shot('07_fenders_flares_removed', FL, hide={'fender_fl', 'fender_fr', 'overfender_rl', 'overfender_rr'})
shot('08_bumpers_lips_removed', FL, hide={'bumper_front', 'bumper_rear', 'chin_front', 'lip_front'})
shot('09_trunk_spoiler_removed', RL, hide={'trunk', 'spoiler_rear'})
shot('10_exploded', (4.6, 2.6, 5.6), explode=0.45)
print('SILAK_PREVIEWS_DONE')
