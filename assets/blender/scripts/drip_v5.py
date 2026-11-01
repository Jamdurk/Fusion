# Alien Fusion: SQUISH DRIP v5 (Phase 1 rebuild, 28 Oct 2026; plan design/08-REBUILD-PLAN.md, method card
# Flagship/Polish Kit/cards/creature-from-reference.md). Built to its ChatGPT reference pack, design/concepts/drip/:
#   A-hero-chatgpt.png (the look: a goo droplet that hops) . B-model-sheet-chatgpt.png (front / side / back: MEASURED).
# Scale: the front view, ground (y 782 in the sheet) to the top of the curl (y 130) = 652 px -> 2.3 studs,
#   0.00353 studs/px; centre line x 315 (front = -Y, left = +X).
# Rig (9 bones): Root, Body (the round bottom) -> Top (the tapering top) -> Curl, Lid, FootL / FootR, ArmL / ArmR.
#   blender --background --factory-startup --python drip_v5.py -- <assets_dir> [norender]
# Writes blender/aliens/squish_f1_v5.blend (collection SquishF1), textures/aliens/squish_f1_v5_*.png, shots/36-drip-v5*.png
import os, sys, math, random
_here = os.path.dirname(os.path.abspath(__file__))
_src = open(os.path.join(_here, "aliens_v2.py"), encoding="utf-8").read()
_src = _src[:_src.index("for race, fn in ((\"squish\", squish_v2)")]
_norender = "norender" in sys.argv
sys.argv = [sys.argv[0], "--", sys.argv[sys.argv.index("--") + 1], "none"]
exec(compile(_src, "aliens_v2.py", "exec"))
V = Vector
reset()
H = 2.3
BAKE_EXT = 0.12
shots = os.path.join(root, "..", "shots")


def curve(ctrl, n):
    c = [V(ctrl[0]) * 2 - V(ctrl[1])] + [V(q) for q in ctrl] + [V(ctrl[-1]) * 2 - V(ctrl[-2])]
    out = []
    for i in range(n):
        u = i / (n - 1) * (len(ctrl) - 1)
        k = min(int(u), len(ctrl) - 2); f = u - k
        p0, p1, p2, p3 = c[k], c[k + 1], c[k + 2], c[k + 3]
        out.append(tuple(0.5 * (2 * p1 + (-p0 + p2) * f + (2 * p0 - 5 * p1 + 4 * p2 - p3) * f * f + (-p0 + 3 * p1 - 3 * p2 + p3) * f ** 3)))
    return out


# ---- the droplet (front + side views): a round bottom tapering up into the curled tip, which rolls over to its left
goo = [ellipsoid((0, 0, 0.9), (0.88, 0.8, 0.78), 40),            # (r1: a rounder, wider bottom like the sheet)
       ellipsoid((0, 0.02, 1.38), (0.62, 0.58, 0.56), 36)]
# (r1: a thinner, tighter hook with a clear bead, not a stubby horn)
CURL = [(0, 0.05, 1.6), (0.0, 0.08, 1.98), (0.08, 0.1, 2.22), (0.3, 0.1, 2.32), (0.5, 0.1, 2.22), (0.56, 0.1, 2.02)]
pts = curve(CURL, 20)
goo += chain(pts, [0.36 * (1 - i / 19) ** 1.1 + 0.05 for i in range(20)], 16)
goo.append(ellipsoid(CURL[-1], (0.14, 0.13, 0.14), 14))             # the round bead at the curl's end
for sx in (-1, 1):
    goo.append(ellipsoid((sx * 0.86, -0.02, 0.68), (0.17, 0.16, 0.17), 16))     # nub arm
    goo.append(ellipsoid((sx * 0.4, -0.1, 0.17), (0.32, 0.38, 0.17), 20))       # nub foot (longer forward)
gm, socks = goo_material(0.0, H, {"belly": (0.2, 0.06, 0.55, 1), "mid": (0.0, 0.4, 0.95, 1), "top": (0.25, 0.85, 1.0, 1),
                                  "cavity": (0.45, 0.1, 0.8, 1), "mottle": 0.18, "veins": True})
# (the race's veins + glowing dots, kept fine on a small body: the Brute / Twin audit numbers)
for n in gm.node_tree.nodes:
    if n.type == "MATH" and n.operation == "LESS_THAN":
        if abs(n.inputs[1].default_value - 0.016) < 1e-4:
            n.inputs[1].default_value = 0.014
        elif abs(n.inputs[1].default_value - 0.08) < 1e-4:
            dots = n
    if n.type == "MAP_RANGE" and abs(n.inputs[1].default_value - 0.06) < 1e-4:
        n.inputs[1].default_value = 0.05; n.inputs[2].default_value = 0.014
t = gm.node_tree
dm = t.nodes.new("ShaderNodeMath"); dm.operation = "MULTIPLY"; t.links.new(dots.outputs[0], dm.inputs[0]); dm.inputs[1].default_value = 0.7
mx = t.nodes.new("ShaderNodeMath"); mx.operation = "MAXIMUM"; t.links.new(socks["emit"], mx.inputs[0]); t.links.new(dm.outputs[0], mx.inputs[1])
socks["emit"] = mx.outputs[0]
for n in list(t.nodes):
    if n.type == "TEX_VORONOI" and n.feature == "DISTANCE_TO_EDGE":
        n.inputs["Scale"].default_value = 2.2
        src = n.inputs["Vector"].links[0].from_socket
        wn = t.nodes.new("ShaderNodeTexNoise"); wn.inputs["Scale"].default_value = 2.2; wn.inputs["Detail"].default_value = 5
        t.links.new(src, wn.inputs["Vector"])
        wc = t.nodes.new("ShaderNodeVectorMath"); wc.operation = "SUBTRACT"; t.links.new(wn.outputs["Color"], wc.inputs[0]); wc.inputs[1].default_value = (0.5, 0.5, 0.5)
        ws = t.nodes.new("ShaderNodeVectorMath"); ws.operation = "SCALE"; t.links.new(wc.outputs[0], ws.inputs[0]); ws.inputs["Scale"].default_value = 0.4
        wa = t.nodes.new("ShaderNodeVectorMath"); wa.operation = "ADD"; t.links.new(src, wa.inputs[0]); t.links.new(ws.outputs[0], wa.inputs[1])
        t.links.new(wa.outputs[0], n.inputs["Vector"])
    if n.type == "MIX" and n.data_type == "RGBA" and tuple(round(c, 2) for c in n.inputs[7].default_value) == (0.4, 1.0, 1.0, 1.0):
        n.inputs[7].default_value = (0.15, 0.8, 1.0, 1)
    if n.type == "MIX" and n.data_type == "RGBA" and tuple(round(c, 2) for c in n.inputs[7].default_value) == (0.6, 1.0, 0.85, 1.0):
        n.inputs[7].default_value = (0.55, 1.0, 1.0, 1)

g = join(goo); g.name = "goo"
remesh(g, H / 160.0, 4)
# the cheeky grin: a mouth cut in under the eye
cut = ellipsoid((0.0, -0.9, 0.58), (0.36, 0.32, 0.15), 24)       # (r1: an open grin, not a lip disc)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
sel(g); bm_ = g.modifiers.new("mouth", "BOOLEAN"); bm_.operation = "DIFFERENCE"; bm_.object = cut; bm_.solver = "EXACT"
apply_mods(g); bpy.data.objects.remove(cut)
displace(g, "CLOUDS", 0.35 * H / 2.5, 0.005 * H)
bpy.ops.object.shade_smooth()

EYE, EYE_R = (0.07, -0.56, 1.12), 0.5  # (r1: bigger, forward: white shows round the iris)
#                   # (front view: the huge eye fills most of the face)
sclera, iris, pupil, catch = goo_eye(EYE, EYE_R, False, (0.5, 0.2, 0.92, 1))
for o in (iris, pupil):
    o.scale.x *= 0.82; o.scale.z *= 0.82
mouth = ellipsoid((0.0, -0.6, 0.58), (0.33, 0.1, 0.13), 16)      # (the dark inside, behind the lips)
fangs = [fang((-0.13, -0.78, 0.71), 0.055, 0.13)]
em = flat_material("sclera", (0.95, 0.97, 1.0, 1), 0.08)
im = flat_material("iris", (0.5, 0.2, 0.92, 1), 0.06)
pm = flat_material("pupil", (0.01, 0.01, 0.02, 1), 0.04)
cm_ = flat_material("catch", (1, 1, 1, 1), 0.05)
mm = flat_material("mouth", (0.16, 0.02, 0.3, 1), 0.3)
fm = flat_material("fang", (0.95, 0.94, 0.88, 1), 0.25)
lm = flat_material("lid", (0.0, 0.4, 0.95, 1), 0.15)
parts = [(gm, socks, g), (em[0], em[1], sclera), (im[0], im[1], iris), (pm[0], pm[1], pupil), (cm_[0], cm_[1], catch),
         (mm[0], mm[1], mouth), (fm[0], fm[1], join(fangs))]
mats = [(gm, socks), em, im, pm, cm_, mm, fm]
lid_slot = len(parts)
ec, er = V(EYE), EYE_R
parts.append((lm[0], lm[1], make_lid(tuple(ec), er))); mats.append(lm)
hi = build_high(parts); hi.name = "DripV5_high"
lo = make_low(hi, "SquishF1", 3000)
main = main_verts(lo)
lv = lid_verts(lo, lid_slot)
bake("squish_f1_v5", lo, hi, mats, 512)
bones = [("Root", (0, 0, 0), (0, 0, 0.2), None),
         ("Body", (0, 0, 0.25), (0, 0, 1.3), "Root"),
         ("Top", (0, 0, 1.3), CURL[1], "Body"),
         ("Curl", CURL[1], CURL[-1], "Top"),
         ("Lid", tuple(ec), tuple(ec + V((0, -er, 0))), "Body")]
for sx, s in ((1, "L"), (-1, "R")):
    bones += [("Foot" + s, (sx * 0.4, 0.05, 0.38), (sx * 0.4, -0.35, 0.1), "Root"),
              ("Arm" + s, (sx * 0.62, 0, 0.7), (sx * 1.0, -0.02, 0.66), "Body")]
arm, unw = rig("SquishF1", lo, bones)
strip_lid(lo, lv)
follow_surface(lo, main, 6)
rigid_parts(lo, main)
lock_eye(lo, EYE, EYE_R, "Body", lv)                   # (James 28 Oct: the eye + the skin round it move solid, no jelly clipping)
assign_lid(lo, lv)
coll = bpy.data.collections.new("SquishF1"); bpy.context.scene.collection.children.link(coll)
for o in (arm, lo):
    for c in o.users_collection:
        c.objects.unlink(o)
    coll.objects.link(o)
hi.hide_render = True; hi.hide_set(True)

# ---- renders to hold against the sheets: hero 3/4, front, side
sc = bpy.context.scene
sc.render.engine = "CYCLES"; sc.cycles.samples = 96
gmat = lo.data.materials[0]; gt = gmat.node_tree; gb = gt.nodes["Principled BSDF"]
imgs = {n.image.name: n for n in gt.nodes if n.type == "TEX_IMAGE" and n.image}
emit_n = next((n for k, n in imgs.items() if k.endswith("_emit")), None)
col_n = next((n for k, n in imgs.items() if k.endswith("_color")), None)
if emit_n and col_n:
    gt.links.new(col_n.outputs["Color"], gb.inputs["Emission Color"])
    em2 = gt.nodes.new("ShaderNodeMath"); em2.operation = "MULTIPLY"; em2.inputs[1].default_value = 2.0
    gt.links.new(emit_n.outputs["Color"], em2.inputs[0]); gt.links.new(em2.outputs[0], gb.inputs["Emission Strength"])
try:
    sc.view_settings.view_transform = "Standard"
except TypeError:
    pass
sc.view_settings.exposure = -0.3
w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.5, 0.5, 0.52, 1); w.node_tree.nodes["Background"].inputs[1].default_value = 0.5
bpy.ops.mesh.primitive_plane_add(size=80, location=(0, 0, 0))
floor = bpy.context.object; fmat = bpy.data.materials.new("floor"); fmat.use_nodes = True
fmat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.62, 0.62, 0.64, 1); floor.data.materials.append(fmat)
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN")); sc.collection.objects.link(sun)
sun.data.energy = 3.0; sun.data.angle = math.radians(8); sun.rotation_euler = (math.radians(48), math.radians(-12), math.radians(-38))
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam")); sc.collection.objects.link(cam); sc.camera = cam
os.makedirs(shots, exist_ok=True)
target = V((0, 0, 1.1))
for tag, yaw, lens, res in () if _norender else (("", -30, 55, (1000, 1000)), ("-front", 0, 60, (1000, 1000)), ("-side", -90, 60, (1000, 1000))):
    cam.data.lens = lens
    sc.render.resolution_x, sc.render.resolution_y = res
    a = math.radians(yaw)
    d = V((math.sin(a), -math.cos(a), 0.16)).normalized()
    cam.location = target + d * 7.5
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.join(shots, f"36-drip-v5{tag}.png")
    bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(bdir, "squish_f1_v5.blend"))
print("DRIP_V5_OK tris", tris(lo), "unweighted", unw, "bones", len(arm.data.bones), "height", round(max(v.co.z for v in lo.data.vertices), 2))
