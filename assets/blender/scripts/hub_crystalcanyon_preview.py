# Crystal Canyon kit: preview renders to compare with the ChatGPT sheets (E2b sizes / views, E3 materials).
# Run AFTER hub_crystalcanyon.py (geometry; flat colours by kind) or hub_crystalcanyon_tex.py (baked maps) in one session:
#   blender -b --factory-startup --python hub_crystalcanyon.py [--python hub_crystalcanyon_tex.py] --python hub_crystalcanyon_preview.py -- <assets> <mode> <out_dir> [tag]
# Shots (orthographic, grey background, soft even light like the sheets, laid out like E2b) + 2 eye-level close-ups.
import bpy, math, os, sys
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
OUT = args[2]; TAG = args[3] if len(args) > 3 else "geo"
os.makedirs(OUT, exist_ok=True)
sc = bpy.context.scene
try: sc.render.engine = "CYCLES"
except TypeError: pass
sc.cycles.samples = 48; sc.cycles.device = "CPU"
sc.render.resolution_x, sc.render.resolution_y = 1200, 900
sc.view_settings.view_transform = "Standard"
w = bpy.data.worlds.new("grey"); sc.world = w; w.use_nodes = True
bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND"); bg.inputs[0].default_value = (0.3, 0.3, 0.31, 1); bg.inputs[1].default_value = 1.4
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); sc.collection.objects.link(sun)
sun.data.energy = 2.4; sun.rotation_euler = (math.radians(50), 0, math.radians(-35))

KINDCOL = {"crystal": (1.0, 0.45, 0.05), "basalt": (0.22, 0.22, 0.24), "tunnel": (1.0, 0.3, 0.05), "seam": (0.3, 0.2, 0.15)}
kit = {o.name: o for o in bpy.data.objects if o.type == "MESH" and not o.name.endswith("_hi")}
if TAG.startswith("geo"):
    for name, o in kit.items():
        m = bpy.data.materials.new(name + "_prev"); m.use_nodes = True
        b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        b.inputs["Base Color"].default_value = KINDCOL.get(o.get("kind", "basalt"), (0.5, 0.5, 0.5)) + (1,); b.inputs["Roughness"].default_value = 0.5
        o.data.materials.clear(); o.data.materials.append(m)

def show(names, offset=Vector((0, 0, 0)), rotz=0.0):
    out = []
    for n in names:
        src = kit[n]; c = src.copy(); c.data = src.data; sc.collection.objects.link(c); c.hide_render = False
        c.rotation_euler = (0, 0, rotz); c.location = offset; out.append(c)
    return out

def hide_all():
    for o in sc.objects:
        if o.type == "MESH": o.hide_render = True

def cam_shot(fname, loc, look, ortho=None, lens=35):
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam)
    if ortho: cam.data.type = "ORTHO"; cam.data.ortho_scale = ortho
    else: cam.data.lens = lens
    cam.data.clip_end = 2000
    cam.location = loc; d = Vector(look) - Vector(loc); cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam; sc.render.filepath = os.path.join(OUT, f"{TAG}-{fname}.png")
    bpy.ops.render.render(write_still=True); bpy.data.objects.remove(cam)
    print("SHOT", sc.render.filepath)

def shot(fname, groups, loc, look, ortho=None, lens=35):
    hide_all(); made = []
    for g in groups: made += show(*g)
    cam_shot(fname, loc, look, ortho, lens)
    for o in made: bpy.data.objects.remove(o)

SP = ["ccSpireRock", "ccSpireCrystal"]
shot("1-spire-front", [(SP,)], (0, -150, 27), (0, 0, 27), ortho=76)
shot("2-spire-side", [(SP,)], (150, 0, 27), (0, 0, 27), ortho=76)
shot("3-spire-top", [(SP,)], (0.001, 0, 150), (0, 0, 0), ortho=40)
shot("4-clusters", [(["ccClusterLRock", "ccClusterLCrystal"], Vector((-16, 0, 0))), (["ccClusterSRock", "ccClusterSCrystal"], Vector((-3, 0, 0))),
                    (["ccShardsCrystal", "ccShardsGravel"], Vector((7, 0, 0))), (["ccColumnA"], Vector((22, 4, 0))),
                    (["ccColumnB"], Vector((42, 4, 0)))], (13, -120, 12), (13, 0, 10), ortho=66)
shot("5-rocks-nest", [(["ccBoulderA"], Vector((-30, 0, 0))), (["ccBoulderB"], Vector((-23, 0, 0))), (["ccBoulderC"], Vector((-12, 0, 0))),
                      (["ccVeinRock", "ccVeinCrystal"], Vector((1, 0, 0))), (["ccNestRock", "ccNestTunnel", "ccNestCrystal"], Vector((26, 0, 0)))],
     (0, -120, 10), (0, 0, 6), ortho=78)
shot("6-seam-arch", [(["ccSeamA"], Vector((-24, -6, 0))), (["ccSeamB"], Vector((-24, 6, 0))), (["ccArch", "ccArchCrystal"], Vector((16, 0, 0)))],
     (0, -90, 60), (0, 0, 2), ortho=70)
shot("7-spire-eye", [(SP,), (["ccClusterLRock", "ccClusterLCrystal"], Vector((-16, -18, 0))), (["ccBoulderB"], Vector((12, -20, 0))),
                     (["ccShardsCrystal", "ccShardsGravel"], Vector((2, -26, 0)))], (8, -60, 5), (0, 0, 22), lens=22)
shot("8-nest-eye", [(["ccNestRock", "ccNestTunnel", "ccNestCrystal"],), (["ccSeamA"], Vector((0, -22, 0)), math.pi / 2)], (10, -42, 6), (0, 0, 5), lens=24)
