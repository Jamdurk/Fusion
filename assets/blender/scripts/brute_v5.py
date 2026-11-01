# Alien Fusion: SQUISH BRUTE v5 (Phase 1 rebuild, 28 Oct 2026; plan design/08-REBUILD-PLAN.md, method card
# Flagship/Polish Kit/cards/creature-from-reference.md). Built to its ChatGPT reference pack, design/concepts/brute/:
#   A-hero-chatgpt.png (the look: a goo GORILLA) . B-model-sheet-chatgpt.png (front / side / back, knuckle stance: MEASURED)
#   . I-pose-sheet (the knuckle-walk).
# Scale: ground (y 735) to the tallest spine tip (y 72) in the sheet = 663 px -> 7.0 studs, 0.0106 studs/px; the front
#   view's centre line is x 385, the side view's body centre x 1000 (front = -Y, left = +X).
# Rig (20 bones): Root, Hips, Chest, Head, Lid, and four IK limbs named for the animator's planted-foot solver: the
#   ARMS are the front legs (LegF* = upper arm, ShinF* = forearm, FootF* = the knuckle-fist; the elbow bends BACK),
#   the short legs the hind ones (LegB* thigh, ShinB*, FootB*, knees forward).
#   blender --background --factory-startup --python brute_v5.py -- <assets_dir> [norender]
# Writes blender/aliens/squish_f3_v5.blend (collection SquishF3), textures/aliens/squish_f3_v5_*.png, shots/32-brute-v5*.png
import os, sys, math, random
_here = os.path.dirname(os.path.abspath(__file__))
_src = open(os.path.join(_here, "aliens_v2.py"), encoding="utf-8").read()
_src = _src[:_src.index("for race, fn in ((\"squish\", squish_v2)")]
_norender = "norender" in sys.argv
sys.argv = [sys.argv[0], "--", sys.argv[sys.argv.index("--") + 1], "none"]
exec(compile(_src, "aliens_v2.py", "exec"))
V = Vector
rnd = random.Random(3)
reset()
H = 7.0
BAKE_EXT = 0.3
shots = os.path.join(root, "..", "shots")


def horn(base, tip_dir, length, r0, curl):
    """a thick goo spine: wide base, blunt tip bending back (the Titan's jelly cone)"""
    d = V(tip_dir).normalized()
    pts, radii = [], []
    p = V(base)
    n = 8
    for i in range(n + 1):
        t = i / n
        pts.append(tuple(p)); radii.append(max(0.16, r0 * (1 - t) ** 0.75))
        p = p + (d + V((0, 1.0, -0.2)) * curl * t).normalized() * (length / n)
    return chain(pts, radii, 16)


goo = []
# ---- torso (side view: the shoulder hump, the chest that carries the face, belly, rump, pelvis; front: traps, pecs)
for c, r in (((0, 0.2, 4.3), (2.0, 1.4, 1.35)), ((0, -0.6, 3.7), (1.75, 1.0, 1.25)), ((0, 0.1, 2.85), (1.3, 1.05, 0.9)),
             ((0, 1.5, 3.05), (1.2, 1.0, 1.0)), ((0, 1.3, 2.45), (1.1, 0.8, 0.7)), ((0, -1.4, 3.65), (1.2, 0.6, 1.0))):
    goo.append(ellipsoid(c, r, 40))
for sx in (-1, 1):
    for c, r in (((1.2, 0.1, 5.0), (1.1, 0.95, 0.65)),          # trapezius (audit r1: shoulders ~15 % bigger)
                 ((2.25, -0.3, 4.3), (1.15, 1.12, 1.12)),       # shoulder ball
                 ((0.9, -1.05, 3.85), (0.85, 0.6, 0.75)),       # pec
                 # the arm: upper, the huge forearm, wrist, the knuckle-fist (front view x +-2.6; side view ahead, y -1.6)
                 ((2.45, -0.65, 3.4), (0.85, 0.85, 1.0)),
                 ((2.6, -1.1, 2.3), (1.0, 0.95, 1.05)),
                 ((2.65, -1.4, 1.45), (0.97, 0.95, 0.7)),         # (r1: one smooth goo mass into the fist)
                 ((2.65, -1.65, 0.72), (1.32, 1.15, 0.72)),       # (r1: fist ~15 % wider, flatter contact)
                 # the short legs: thigh, shin, the stubby foot (side view: under the rump, y +1.2)
                 ((0.95, 1.2, 2.0), (0.7, 0.75, 0.85)),
                 ((0.95, 1.2, 1.25), (0.6, 0.64, 0.62)),          # (r1: a shorter ankle)
                 ((0.95, 1.1, 0.38), (0.82, 1.05, 0.4))):        # (r1: feet ~20 % bigger, under the hips)
        goo.append(ellipsoid((sx * c[0], c[1], c[2]), r, 28))
    for k in (-1, 0, 1):                                          # knuckles + toes
        goo.append(ellipsoid((sx * 2.65 + k * 0.62, -2.5, 0.46), (0.46, 0.42, 0.42), 16))
        goo.append(ellipsoid((sx * 0.95 + k * 0.38, 0.12, 0.26), (0.3, 0.34, 0.27), 12))
# ---- the heavy ASYMMETRIC brow (front view: lower on its left = +X)
goo.append(brow((0.15, -1.72, 5.15), (1.55, 0.55, 0.55), 14, -6))    # (r1: ~20 % thicker; James 28 Oct: shorter, no overhang on the face)
# (James 28 Oct: NO mouth: the sneer's lips, the mouth cut, the mouth and the fangs are gone)
# ---- three big swept-back goo spines down the back (side view)
# (r1: they hid in the hump: ~30 % longer + thicker, bases sunk less)
# (r2 audit: the tall one raked ~35 deg further back, ~15 % shorter; the small two spread further rearward)
for base, d, ln, r0 in (((0, -0.15, 5.45), (0, 1.1, 1), 2.2, 0.9), ((0, 1.2, 5.0), (0, 1, 0.55), 2.0, 0.78),
                        ((0, 2.0, 3.95), (0, 1, 0.1), 1.6, 0.62)):
    goo += horn(base, d, ln, r0, 0.6)

# (audit r1: the underside ~25 % darker)
gm, socks = goo_material(0.0, H, {"belly": (0.18, 0.05, 0.45, 1), "mid": (0.0, 0.42, 0.95, 1), "top": (0.25, 0.85, 1.0, 1),
                                  "cavity": (0.32, 0.07, 0.6, 1), "mottle": 0.18, "veins": True})
# (the Titan's thicker crackling veins + glowing cyan dots: the same race)
for n in gm.node_tree.nodes:
    if n.type == "MATH" and n.operation == "LESS_THAN":
        if abs(n.inputs[1].default_value - 0.016) < 1e-4:
            n.inputs[1].default_value = 0.0105              # (audit r1: veins ~60 % thinner than the Titan's)
        elif abs(n.inputs[1].default_value - 0.08) < 1e-4:
            dots = n
    if n.type == "MAP_RANGE" and abs(n.inputs[1].default_value - 0.06) < 1e-4:
        n.inputs[1].default_value = 0.04; n.inputs[2].default_value = 0.0105
t = gm.node_tree
dm = t.nodes.new("ShaderNodeMath"); dm.operation = "MULTIPLY"; t.links.new(dots.outputs[0], dm.inputs[0]); dm.inputs[1].default_value = 0.7
mx = t.nodes.new("ShaderNodeMath"); mx.operation = "MAXIMUM"; t.links.new(socks["emit"], mx.inputs[0]); t.links.new(dm.outputs[0], mx.inputs[1])
socks["emit"] = mx.outputs[0]
# (audit r1: 'white circuitry' -> crackling electricity: 2x the cells, the cell edges warped by noise so they branch
# irregularly, and the core a deeper cyan, not near-white)
for n in list(t.nodes):
    if n.type == "TEX_VORONOI" and n.feature == "DISTANCE_TO_EDGE":
        n.inputs["Scale"].default_value = 2.6
        src = n.inputs["Vector"].links[0].from_socket
        wn = t.nodes.new("ShaderNodeTexNoise"); wn.inputs["Scale"].default_value = 2.2; wn.inputs["Detail"].default_value = 5
        t.links.new(src, wn.inputs["Vector"])
        wc = t.nodes.new("ShaderNodeVectorMath"); wc.operation = "SUBTRACT"; t.links.new(wn.outputs["Color"], wc.inputs[0]); wc.inputs[1].default_value = (0.5, 0.5, 0.5)
        ws = t.nodes.new("ShaderNodeVectorMath"); ws.operation = "SCALE"; t.links.new(wc.outputs[0], ws.inputs[0]); ws.inputs["Scale"].default_value = 0.45
        wa = t.nodes.new("ShaderNodeVectorMath"); wa.operation = "ADD"; t.links.new(src, wa.inputs[0]); t.links.new(ws.outputs[0], wa.inputs[1])
        t.links.new(wa.outputs[0], n.inputs["Vector"])
    if n.type == "MIX" and n.data_type == "RGBA" and tuple(round(c, 2) for c in n.inputs[7].default_value) == (0.4, 1.0, 1.0, 1.0):
        n.inputs[7].default_value = (0.15, 0.8, 1.0, 1)
for n in t.nodes:
    if n.type == "MIX" and n.data_type == "RGBA" and tuple(round(c, 2) for c in n.inputs[7].default_value) == (0.6, 1.0, 0.85, 1.0):
        n.inputs[7].default_value = (0.55, 1.0, 1.0, 1)

g = join(goo); g.name = "goo"
remesh(g, H / 140.0, 4)
displace(g, "CLOUDS", 0.35 * H / 2.5, 0.006 * H)
bpy.ops.object.shade_smooth()

EYE, EYE_R = (0.05, -1.5, 4.12), 1.1                     # (front view: the giant eye fills the face, slit pupil; r1: ~25 % bigger)
sclera, iris, pupil, catch = goo_eye(EYE, EYE_R, True, (0.5, 0.2, 0.92, 1))
em = flat_material("sclera", (0.95, 0.97, 1.0, 1), 0.08)
im = flat_material("iris", (0.5, 0.2, 0.92, 1), 0.06)
pm = flat_material("pupil", (0.01, 0.01, 0.02, 1), 0.04)
cm_ = flat_material("catch", (1, 1, 1, 1), 0.05)
lm = flat_material("lid", (0.02, 0.42, 0.95, 1), 0.15)
parts = [(gm, socks, g), (em[0], em[1], sclera), (im[0], im[1], iris), (pm[0], pm[1], pupil), (cm_[0], cm_[1], catch)]
mats = [(gm, socks), em, im, pm, cm_]
lid_slot = len(parts)
ec, er = V(EYE), EYE_R
parts.append((lm[0], lm[1], make_lid(tuple(ec), er))); mats.append(lm)
hi = build_high(parts); hi.name = "BruteV5_high"
lo = make_low(hi, "SquishF3", 9000)
main = main_verts(lo)
lv = lid_verts(lo, lid_slot)
bake("squish_f3_v5", lo, hi, mats, 1024)
LIMBS = {"FL": ((2.2, -0.3, 4.3), (2.62, -0.95, 2.5), (2.65, -1.45, 1.45), (2.65, -2.4, 0.45), "Chest"),
         "FR": ((-2.2, -0.3, 4.3), (-2.62, -0.95, 2.5), (-2.65, -1.45, 1.45), (-2.65, -2.4, 0.45), "Chest"),
         "BL": ((0.95, 1.25, 2.55), (0.95, 0.9, 1.45), (0.95, 1.2, 0.5), (0.95, 0.2, 0.22), "Hips"),
         "BR": ((-0.95, 1.25, 2.55), (-0.95, 0.9, 1.45), (-0.95, 1.2, 0.5), (-0.95, 0.2, 0.22), "Hips")}
bones = [("Root", (0, 0, 0), (0, 0, 0.6), None),
         ("Hips", (0, 1.2, 2.4), (0, 1.2, 3.2), "Root"),
         ("Chest", (0, 0.7, 3.1), (0, -0.4, 4.9), "Hips"),
         ("Head", (0, -0.9, 3.6), (0, -2.2, 3.9), "Chest"),
         ("Lid", tuple(ec), tuple(ec + V((0, -er, 0))), "Head")]
for k, (a, b, c, d, par) in LIMBS.items():
    bones += [("Leg" + k, a, b, par), ("Shin" + k, b, c, "Leg" + k), ("Foot" + k, c, d, "Shin" + k)]
arm, unw = rig("SquishF3", lo, bones)
strip_lid(lo, lv)
follow_surface(lo, main, 8)
rigid_parts(lo, main)
lock_eye(lo, EYE, EYE_R, "Head", lv)                   # (James 28 Oct: the eye + the skin round it move solid, no jelly clipping)
assign_lid(lo, lv)
coll = bpy.data.collections.new("SquishF3"); bpy.context.scene.collection.children.link(coll)
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
target = V((0, 0, 3.2))
for tag, yaw, lens, res in () if _norender else (("", -30, 55, (1100, 1000)), ("-front", 0, 60, (1000, 1000)), ("-side", -90, 60, (1000, 1000))):
    cam.data.lens = lens
    sc.render.resolution_x, sc.render.resolution_y = res
    a = math.radians(yaw)
    d = V((math.sin(a), -math.cos(a), 0.16)).normalized()
    cam.location = target + d * 22
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.join(shots, f"32-brute-v5{tag}.png")
    bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(bdir, "squish_f3_v5.blend"))
print("BRUTE_V5_OK tris", tris(lo), "unweighted", unw, "bones", len(arm.data.bones), "height", round(max(v.co.z for v in lo.data.vertices), 2))
for b in arm.data.bones:
    print("BONE", b.name, "head", tuple(round(x, 3) for x in b.head_local), "len", round(b.length, 3))
