# Goo Marsh kit: preview renders to compare with the ChatGPT sheets (D2b sizes / views, D3 materials).
# Run AFTER hub_goomarsh.py (geometry; flat colours by kind) or hub_goomarsh_tex.py (baked maps) in the same session:
#   blender -b --factory-startup --python hub_goomarsh.py [--python hub_goomarsh_tex.py] --python hub_goomarsh_preview.py -- <assets> <mode> <out_dir> [tag]
# Shots (orthographic, mid-grey background, soft even light like the sheets): giant front / side / from below, the
# small mushrooms, the goo pieces, the pools from above at 40 deg, + 2 perspective close-ups at eye height.
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
bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND"); bg.inputs[0].default_value = (0.22, 0.22, 0.23, 1); bg.inputs[1].default_value = 1.6
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); sc.collection.objects.link(sun)
sun.data.energy = 2.2; sun.rotation_euler = (math.radians(50), 0, math.radians(-35))

KINDCOL = {"stalk": (0.80, 0.76, 0.93), "goo": (0.03, 0.70, 1.0), "gill": (0.48, 0.23, 1.0), "rock": (0.18, 0.18, 0.2),
           "crystal": (0.08, 0.83, 1.0), "tunnel": (0.6, 0.3, 1.0), "pool": (0.02, 0.67, 1.0)}
kit = {o.name: o for o in bpy.data.objects if o.type == "MESH" and not o.name.endswith("_hi")}
if TAG == "geo":
    for name, o in kit.items():
        kind = next((k for k in KINDCOL if k in o.get("kind", "")), None) or (
            "stalk" if "Stalk" in name else "gill" if "Gills" in name else "rock" if "Rock" in name else
            "crystal" if "Crystal" in name else "tunnel" if "Tunnel" in name else
            "pool" if any(k in name for k in ("Pool", "Film", "Stream")) else "goo")
        m = bpy.data.materials.new(name + "_prev"); m.use_nodes = True
        b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        b.inputs["Base Color"].default_value = KINDCOL[kind] + (1,); b.inputs["Roughness"].default_value = 0.5
        o.data.materials.clear(); o.data.materials.append(m)

def show(names, offset=Vector((0, 0, 0)), rotz=0.0):
    """link copies of the named pieces at an offset (rotated round z), return them"""
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
    cam.location = loc; d = Vector(look) - Vector(loc); cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam; sc.render.filepath = os.path.join(OUT, f"{TAG}-{fname}.png")
    bpy.ops.render.render(write_still=True); bpy.data.objects.remove(cam)
    print("SHOT", sc.render.filepath)

def shot(fname, groups, loc, look, ortho=None, lens=35):
    hide_all(); made = []
    for g in groups: made += show(*g)
    cam_shot(fname, loc, look, ortho, lens)
    for o in made: bpy.data.objects.remove(o)

G = ["gmGiantStalk", "gmGiantCap", "gmGiantGills"]
shot("1-giant-front", [(G,)], (0, -120, 18), (0, 0, 18), ortho=48)
shot("2-giant-side", [(G,)], (120, 0, 18), (0, 0, 18), ortho=48)
shot("3-giant-below", [(G,)], (0.001, 0, -80), (0, 0, 0), ortho=46)
shot("4-small", [(["gmTrumpetStalk", "gmTrumpetCap", "gmTrumpetGills"], Vector((-14, 0, 0))),
                 (["gmUmbrellaStalk", "gmUmbrellaCap", "gmUmbrellaGills"], Vector((4, 0, 0))),
                 (["gmSproutStalk", "gmSproutCap", "gmSproutGills"], Vector((17, 0, 0)))], (0, -100, 7), (0, 0, 7), ortho=40)
shot("5-goo", [(["gmBlobA"], Vector((-22, 0, 0))), (["gmBlobB"], Vector((-12, 0, 0))),
               (["gmVeinRock", "gmVeinCrystal", "gmVeinGoo"], Vector((-2, 0, 0))), (["gmNestShell", "gmNestTunnel"], Vector((24, 0, 0))),
               (["gmRockA"], Vector((-24, 10, 0))), (["gmRockB"], Vector((-14, 10, 0))), (["gmRockC"], Vector((-4, 12, 0)))],
     (0, -100, 26), (0, 0, 5), ortho=64)
shot("6-pools", [(["gmPoolA"], Vector((-28, 0, 0))), (["gmPoolB"], Vector((28, 0, 0))), (["gmFilmA"], Vector((-28, 40, 0))),
                 (["gmFilmB"], Vector((6, 40, 0))), (["gmStreamA"], Vector((34, 40, 0))), (["gmDrape"], Vector((0, 70, 0)))],
     (0, -70, 80), (0, 25, 0), ortho=120)
shot("7-giant-eye", [(G,), (["gmBlobA"], Vector((-10, -14, 0))), (["gmSproutStalk", "gmSproutCap", "gmSproutGills"], Vector((8, -16, 0)))],
     (6, -42, 5), (0, 0, 20), lens=22)
shot("8-nest-eye", [(["gmNestShell", "gmNestTunnel"],), (["gmPoolB"], Vector((-10, -40, -0.2)))], (12, -46, 6), (0, 0, 5), lens=24)
