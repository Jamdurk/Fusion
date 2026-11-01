# Alien Fusion: SQUISH TITAN v5 (Phase 1 rebuild, 28 Oct 2026; plan design/08-REBUILD-PLAN.md, method card
# Flagship/Polish Kit/cards/creature-from-reference.md). Built to its ChatGPT reference pack, design/concepts/titan/:
#   A-hero-chatgpt.png (the look) . B-model-sheet-chatgpt.png (front / side / back: MEASURED) .
#   CDH-top-face-tentacle-chatgpt.png (top view: tentacle + horn layout; face: eye, brow, 2 upper + 4 lower fangs;
#   one tentacle: thick base, spiral tip, big sucker dots on its outer side) . I-pose-sheet (the slide).
# Scale: the front view is 405 px tall (ground to horn tips) in the 1000-px gridded copy -> 14 studs, 0.0346 studs/px.
#   blender --background --factory-startup --python titan_v5.py -- <assets_dir> [norender]
# Writes blender/aliens/squish_f4_v5.blend (collection SquishF4), textures/aliens/squish_f4_v5_*.png, shots/30-titan-v5*.png
import os, sys, math, random
_here = os.path.dirname(os.path.abspath(__file__))
_src = open(os.path.join(_here, "aliens_v2.py"), encoding="utf-8").read()
_src = _src[:_src.index("for race, fn in ((\"squish\", squish_v2)")]
_norender = "norender" in sys.argv
sys.argv = [sys.argv[0], "--", sys.argv[sys.argv.index("--") + 1], "none"]
exec(compile(_src, "aliens_v2.py", "exec"))            # aliens_v2 helpers (+ everything in aliens_forms.py)
V = Vector
rnd = random.Random(5)
reset()
H = 14.0
BAKE_EXT = 0.5                                           # (longer bake rays: see aliens_forms.bake)
shots = os.path.join(root, "..", "shots")


def horn(base, tip_dir, length, r0, curl):
    """a thick rounded goo horn: a wide base tapering to a blunt tip that bends BACK and out (audit round 1: the
    tips bend backwards, wide bases, no sharp triangles)"""
    d = V(tip_dir).normalized()
    out = V((base[0], base[1] - 0.2, 0))
    back = (out.normalized() * 0.6 if out.length > 0.3 else V()) + V((0, 1.0, -0.15))
    pts, radii = [], []
    p = V(base)
    n = 8
    for i in range(n + 1):
        t = i / n
        pts.append(tuple(p)); radii.append(max(0.48, r0 * (1 - t) ** 0.5))     # (r3: inflated jelly cones, round tips)
        p = p + (d + back.normalized() * curl * t).normalized() * (length / n)
    return chain(pts, radii, 16)


def curve(ctrl, n):
    """n points along a Catmull-Rom curve through ctrl (smooth tentacles: chain() of far-apart points went lumpy)"""
    c = [V(ctrl[0]) * 2 - V(ctrl[1])] + [V(q) for q in ctrl] + [V(ctrl[-1]) * 2 - V(ctrl[-2])]
    out = []
    for i in range(n):
        u = i / (n - 1) * (len(ctrl) - 1)
        k = min(int(u), len(ctrl) - 2); f = u - k
        p0, p1, p2, p3 = c[k], c[k + 1], c[k + 2], c[k + 3]
        out.append(tuple(0.5 * (2 * p1 + (-p0 + p2) * f + (2 * p0 - 5 * p1 + 4 * p2 - p3) * f * f + (-p0 + 3 * p1 - 3 * p2 + p3) * f ** 3)))
    return out


# ---- body: the dome flows down into a waist and out into the scalloped goo skirt (front view + top view)
# (audit round 1: a swollen, squat dome, lower half ~22 % wider, ~10 % lower; a skirt ~35 % wider, one rounded puddle)
goo = [ellipsoid((0, 0.2, 6.9), (5.6, 4.9, 4.3), 48),
       ellipsoid((0, 0.1, 3.6), (5.3, 4.7, 2.8), 40),
       ellipsoid((0, 0.1, 0.85), (7.6, 7.0, 1.0), 56)]
for k in range(12):                                     # the puddle's soft scalloped edge (top view)
    a = k / 12 * 2 * math.pi + 0.2
    goo.append(ellipsoid((math.cos(a) * 7.0, 0.1 + math.sin(a) * 6.4, 0.55), (2.2, 2.0, 0.6), 24))
goo.append(brow((0.25, -4.35, 10.3), (2.45, 1.15, 0.95), -10, -20))     # the heavy brow, thick + round, lower on its right
# ---- 7 curved horns (top view: a ring of 6 + a big one at the back; front view: tips curl back / out)
for (x, y, z, dx, dy, dz, ln, r0) in ((0.0, -0.3, 10.9, 0.0, 0.1, 1.0, 3.4, 1.35),        # (exactly six: audit round 1; r2: longer, the dome hid them)
                                      (-2.7, -0.2, 10.2, -0.4, 0.1, 1.0, 3.0, 1.2), (2.7, -0.2, 10.2, 0.4, 0.1, 1.0, 3.0, 1.2),
                                      (-4.6, 0.3, 8.5, -0.85, 0.1, 0.7, 2.6, 1.1), (4.6, 0.3, 8.5, 0.85, 0.1, 0.7, 2.6, 1.1),
                                      (0.0, 3.2, 9.9, 0.0, 0.6, 0.8, 2.8, 1.15)):
    goo += horn((x, y, z), (dx, dy, dz), ln, r0, 1.7 if ln >= 3.0 else 1.25)   # (r3: the tall three curl back harder)
# ---- 4 tentacles: thick at the skirt, tapering, tips curling up into a spiral (front + top + tentacle close-up)
tent = {}
for name, sx, sy in (("FL", -1, -1), ("FR", 1, -1), ("BL", -1, 1), ("BR", 1, 1)):
    # (audit round 1: bases ~40 % thicker, reach ~50 % longer, every tip curled UP into a round C)
    if sy < 0:      # front pair: out and forward along the ground, the tip rolling up and back over itself
        ctrl = [(sx * 3.2, -2.6, 1.7), (sx * 5.0, -4.8, 1.4), (sx * 5.6, -7.6, 1.4), (sx * 4.9, -10.0, 1.8),
                (sx * 4.0, -10.9, 3.4), (sx * 3.9, -9.8, 4.9), (sx * 4.3, -8.6, 4.8)]
    else:           # back pair: out to the sides, curling up beside the body, the tip rolling inward
        ctrl = [(sx * 3.6, 2.0, 1.7), (sx * 6.2, 3.0, 1.5), (sx * 8.3, 2.8, 2.5), (sx * 9.0, 2.0, 4.6),
                (sx * 8.5, 1.4, 6.6), (sx * 7.3, 1.5, 7.4), (sx * 6.6, 2.0, 6.6)]
    pts = curve(ctrl, 22)
    rads = [2.15 * (1 - i / 21) ** 0.9 + 0.66 * (i / 21) for i in range(22)]   # (r3: a bulbous rounded tip)
    goo += chain(pts, rads, 20)
    tent[name] = ctrl
gm, socks = goo_material(0.0, H, {"belly": (0.2, 0.06, 0.55, 1), "mid": (0.0, 0.42, 0.95, 1), "top": (0.25, 0.88, 1.0, 1),
                                  "cavity": (0.45, 0.1, 0.8, 1), "mottle": 0.18, "veins": True})
# (the hero's veins are thick crackling lines: thicker core + halo than the v2 goo, and the dots under the skin glow)
for n in gm.node_tree.nodes:
    if n.type == "MATH" and n.operation == "LESS_THAN":
        if abs(n.inputs[1].default_value - 0.016) < 1e-4:
            n.inputs[1].default_value = 0.026
        elif abs(n.inputs[1].default_value - 0.08) < 1e-4:
            dots = n
    if n.type == "MAP_RANGE" and abs(n.inputs[1].default_value - 0.06) < 1e-4:
        n.inputs[1].default_value = 0.09; n.inputs[2].default_value = 0.026
t = gm.node_tree
dm = t.nodes.new("ShaderNodeMath"); dm.operation = "MULTIPLY"; t.links.new(dots.outputs[0], dm.inputs[0]); dm.inputs[1].default_value = 0.7
mx = t.nodes.new("ShaderNodeMath"); mx.operation = "MAXIMUM"; t.links.new(socks["emit"], mx.inputs[0]); t.links.new(dm.outputs[0], mx.inputs[1])
socks["emit"] = mx.outputs[0]
for n in t.nodes:                                       # (the dots: glowing cyan, not mint)
    if n.type == "MIX" and n.data_type == "RGBA" and tuple(round(c, 2) for c in n.inputs[7].default_value) == (0.6, 1.0, 0.85, 1.0):
        n.inputs[7].default_value = (0.55, 1.0, 1.0, 1)

g = join(goo); g.name = "goo"
remesh(g, H / 130.0, 4)
# (audit round 1: the mouth is a CAVITY in the goo, not a disc on it: cut it out, the dark inner mouth fills its back)
cut = ellipsoid((0, -5.05, 4.9), (2.6, 1.45, 2.05), 32); bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)   # (r2: ~20 % wider)
sel(g); bm_ = g.modifiers.new("mouth", "BOOLEAN"); bm_.operation = "DIFFERENCE"; bm_.object = cut; bm_.solver = "EXACT"
apply_mods(g); bpy.data.objects.remove(cut)
sel(g); sm_ = g.modifiers.new("sm", "SMOOTH"); sm_.iterations = 2; sm_.factor = 0.5; apply_mods(g)
displace(g, "CLOUDS", 0.35 * H / 2.5, 0.006 * H)
bpy.ops.object.shade_smooth()

# ---- face (face close-up): one big eye, the mouth, 2 big upper fangs + 4 lower
EYE, EYE_R = (0.2, -3.75, 8.55), 1.84  # (recessed ~30 % into the dome: r1; r3: ~15 % bigger, up to clear the taller mouth)
sclera, iris, pupil, catch = goo_eye(EYE, EYE_R, False, (0.5, 0.2, 0.92, 1))
mouth = ellipsoid((0, -3.7, 4.9), (2.4, 0.42, 1.9), 24)   # (the dark inside, ~0.25 behind the lips: r2, it read as a small hole)
fangs = ([fang((x, -4.3, 6.5), 0.5, 1.1) for x in (-1.3, 1.3)] + [fang((x, -4.4, 6.6), 0.32, 0.65) for x in (-0.45, 0.45)] +
         [fang((x, -4.35, 3.25), 0.36, 0.8, up=True) for x in (-1.4, -0.5, 0.5, 1.4)])   # 8 blunt cartoon fangs
# ---- sucker dots: big glowing dots down each tentacle's outer side (tentacle close-up), cast onto the surface
spot_objs = []
for pts in tent.values():
    for i in range(len(pts) - 1):
        for f in (0.25, 0.75):
            c = V(pts[i]).lerp(V(pts[i + 1]), f)
            out = V((c.x, c.y - 0.1, 0)).normalized() + V((0, 0, 0.6))
            hit = g.ray_cast(c + out.normalized() * 4, -out.normalized())
            if hit[0]:
                loc, nrm = g.matrix_world @ hit[1], hit[2]
                r = 0.32 * (1.15 - i * 0.12)
                s = ellipsoid(tuple(loc - nrm * r * 0.4), (r, r, r * 0.5), 12)
                s.rotation_euler = nrm.to_track_quat("Z", "Y").to_euler()
                spot_objs.append(s)
print("SUCKERS", len(spot_objs))

em = flat_material("sclera", (0.95, 0.97, 1.0, 1), 0.08)
im = flat_material("iris", (0.5, 0.2, 0.92, 1), 0.06)
pm = flat_material("pupil", (0.01, 0.01, 0.02, 1), 0.04)
cm_ = flat_material("catch", (1, 1, 1, 1), 0.05)
mm = flat_material("mouth", (0.2, 0.03, 0.36, 1), 0.3)
fm = flat_material("fang", (0.95, 0.94, 0.88, 1), 0.25)
sm = glow_material((0.75, 1.0, 1.0, 1), (0.3, 0.95, 1.0, 1))
lm = flat_material("lid", (0.02, 0.42, 0.95, 1), 0.15)
parts = [(gm, socks, g), (em[0], em[1], sclera), (im[0], im[1], iris), (pm[0], pm[1], pupil), (cm_[0], cm_[1], catch),
         (mm[0], mm[1], mouth), (fm[0], fm[1], join(fangs)), (sm[0], sm[1], join(spot_objs))]
mats = [(gm, socks), em, im, pm, cm_, mm, fm, sm]
lid_slot = len(parts)
ec, er = V(EYE), EYE_R
parts.append((lm[0], lm[1], make_lid(tuple(ec), er))); mats.append(lm)
hi = build_high(parts); hi.name = "TitanV5_high"
lo = make_low(hi, "SquishF4", 14000)                   # (smooth goo silhouette: 9000 read faceted)
main = main_verts(lo)
lv = lid_verts(lo, lid_slot)
bake("squish_f4_v5", lo, hi, mats, 1024)
# rig: the dome bends over the skirt (Body -> Top), each tentacle a 3-bone chain for slow travelling waves, the lid
bones = [("Root", (0, 0, 0), (0, 0, 0.6), None),
         ("Body", (0, 0.1, 1.2), (0, 0.1, 5.4), "Root"),
         ("Top", (0, 0.2, 5.4), (0, 0.2, 11.2), "Body"),
         ("Lid", tuple(ec), tuple(ec + V((0, -er, 0))), "Top")]
for name, pts in tent.items():
    bones += [("Tent" + name + "1", pts[0], pts[2], "Body"), ("Tent" + name + "2", pts[2], pts[4], "Tent" + name + "1"),
              ("Tent" + name + "3", pts[4], pts[6], "Tent" + name + "2")]
arm, unw = rig("SquishF4", lo, bones)
strip_lid(lo, lv)
follow_surface(lo, main, 8)                             # (goo: soft blended skin)
rigid_parts(lo, main)                                   # (eye, fangs, suckers move solid)
lock_eye(lo, EYE, EYE_R, "Top", lv)                   # (James 28 Oct: the eye + the skin round it move solid, no jelly clipping)
assign_lid(lo, lv)
coll = bpy.data.collections.new("SquishF4"); bpy.context.scene.collection.children.link(coll)
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
target = V((0, 0, 6.2))
for tag, yaw, lens, res in () if _norender else (("", -30, 55, (1100, 1100)), ("-front", 0, 60, (1000, 1000)), ("-side", -90, 60, (1000, 1000))):
    cam.data.lens = lens
    sc.render.resolution_x, sc.render.resolution_y = res
    a = math.radians(yaw)
    d = V((math.sin(a), -math.cos(a), 0.18)).normalized()
    cam.location = target + d * 42
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.join(shots, f"30-titan-v5{tag}.png")
    bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(bdir, "squish_f4_v5.blend"))
print("TITAN_V5_OK tris", tris(lo), "unweighted", unw, "bones", len(arm.data.bones), "height", round(max(v.co.z for v in lo.data.vertices), 2))
