# Alien Fusion: SQUISH TWIN v5 (Phase 1 rebuild, 28 Oct 2026; plan design/08-REBUILD-PLAN.md, method card
# Flagship/Polish Kit/cards/creature-from-reference.md). Built to its ChatGPT reference pack, design/concepts/twin/:
#   A-hero-chatgpt.png (the look: an upright goo peanut on a puddle) . B-model-sheet-chatgpt.png (front / side / back:
#   MEASURED) . I-pose-sheet (the bounce-slide).
# Scale: the front view, ground (y 832 in the sheet) to the peak tips (y 78) = 754 px -> 4.4 studs, 0.00584 studs/px;
#   centre line x 335 (front = -Y, left = +X).
# Rig (11 bones): Root, Base (the puddle), Body (lower lobe) -> Top (waist + head), Lid, TendL1-3 / TendR1-3.
#   blender --background --factory-startup --python twin_v5.py -- <assets_dir> [norender]
# Writes blender/aliens/squish_f2_v5.blend (collection SquishF2), textures/aliens/squish_f2_v5_*.png, shots/34-twin-v5*.png
import os, sys, math, random
_here = os.path.dirname(os.path.abspath(__file__))
_src = open(os.path.join(_here, "aliens_v2.py"), encoding="utf-8").read()
_src = _src[:_src.index("for race, fn in ((\"squish\", squish_v2)")]
_norender = "norender" in sys.argv
sys.argv = [sys.argv[0], "--", sys.argv[sys.argv.index("--") + 1], "none"]
exec(compile(_src, "aliens_v2.py", "exec"))
V = Vector
rnd = random.Random(2)
reset()
H = 4.4
BAKE_EXT = 0.2
shots = os.path.join(root, "..", "shots")


def horn(base, tip_dir, length, r0, curl, out):
    """a sharp goo peak: wide base, curving up and out to a point (the sheet's twin peaks)"""
    d = V(tip_dir).normalized()
    pts, radii = [], []
    p = V(base)
    n = 8
    for i in range(n + 1):
        t = i / n
        pts.append(tuple(p)); radii.append(max(0.05, r0 * (1 - t) ** 0.85))
        p = p + (d + V((out, 0.15, 0)) * curl * t).normalized() * (length / n)
    return chain(pts, radii, 14)


def curve(ctrl, n):
    c = [V(ctrl[0]) * 2 - V(ctrl[1])] + [V(q) for q in ctrl] + [V(ctrl[-1]) * 2 - V(ctrl[-2])]
    out = []
    for i in range(n):
        u = i / (n - 1) * (len(ctrl) - 1)
        k = min(int(u), len(ctrl) - 2); f = u - k
        p0, p1, p2, p3 = c[k], c[k + 1], c[k + 2], c[k + 3]
        out.append(tuple(0.5 * (2 * p1 + (-p0 + p2) * f + (2 * p0 - 5 * p1 + 4 * p2 - p3) * f * f + (-p0 + 3 * p1 - 3 * p2 + p3) * f ** 3)))
    return out


# ---- body (front + side views): the puddle with a scalloped rim, the bigger lower lobe, the pinched waist, the head
# (audit r1: the puddle ~25 % wider and flat, one continuous irregular sheet, not stacked petals; the lower lobe ~12 %
# bigger)
goo = [ellipsoid((0, 0, 0.16), (1.95, 1.78, 0.2), 48),
       ellipsoid((0, 0, 1.28), (1.1, 1.0, 0.98), 40),
       ellipsoid((0, 0, 0.55), (1.12, 1.02, 0.42), 36),        # (r1: the lobe melts into the puddle, no seam)
       ellipsoid((0, 0, 2.1), (0.66, 0.62, 0.42), 32),
       ellipsoid((0, -0.02, 2.95), (0.98, 0.92, 0.78), 40)]
for k in range(7):
    a = k / 7 * 2 * math.pi + 0.3
    rr = 1.75 + 0.2 * ((k * 5) % 3) / 2
    goo.append(ellipsoid((math.cos(a) * rr, math.sin(a) * rr * 0.92, 0.12), (0.62, 0.55, 0.15), 20))
goo.append(brow((0.15, -0.84, 3.42), (0.72, 0.34, 0.26), 18, -15))      # the brow, lowered on its left (+X)
for sx in (-1, 1):            # the twin peaks, curving up and out (audit r1: ~20 % wider bases, more curve, one taller)
    goo += horn((sx * 0.47, 0.0, 3.55), (sx * 0.15, 0.05, 1), 1.08 if sx > 0 else 0.95, 0.38, 0.9, sx)
# ---- the tendril arms: thin, wavy, hanging out from the waist, ending in a rounded blob
tents = {}
for sx, s in ((1, "L"), (-1, "R")):
    # (audit r1: ~40 % longer, ~30 % thinner, two gentle S-curves, the tips ~50 % smaller; clear of the puddle)
    ctrl = [(sx * 0.62, 0, 2.2), (sx * 1.0, -0.05, 2.08), (sx * 1.35, -0.1, 1.8), (sx * 1.42, -0.05, 1.42),
            (sx * 1.72, -0.1, 1.18), (sx * 1.92, -0.15, 1.3), (sx * 2.1, -0.15, 1.08)]
    pts = curve(ctrl, 20)
    goo += chain(pts, [0.14 - 0.04 * (i / 19) for i in range(20)], 12)
    goo.append(ellipsoid(ctrl[-1], (0.15, 0.14, 0.16), 14))
    tents[s] = [ctrl[0], ctrl[1], ctrl[2], ctrl[3], ctrl[4], ctrl[6]]

gm, socks = goo_material(0.0, H, {"belly": (0.18, 0.05, 0.5, 1), "mid": (0.0, 0.3, 0.85, 1), "top": (0.1, 0.6, 0.95, 1),   # (r1: deeper)
                                  "cavity": (0.4, 0.08, 0.75, 1), "mottle": 0.18, "veins": True})
# (the Titan's thicker veins + glowing dots: the same race; a deeper cyan top for F2, rules section 6)
for n in gm.node_tree.nodes:
    if n.type == "MATH" and n.operation == "LESS_THAN":
        if abs(n.inputs[1].default_value - 0.016) < 1e-4:
            n.inputs[1].default_value = 0.013              # (audit r1: ~40 % narrower)
        elif abs(n.inputs[1].default_value - 0.08) < 1e-4:
            dots = n
    if n.type == "MAP_RANGE" and abs(n.inputs[1].default_value - 0.06) < 1e-4:
        n.inputs[1].default_value = 0.05; n.inputs[2].default_value = 0.013
t = gm.node_tree
dm = t.nodes.new("ShaderNodeMath"); dm.operation = "MULTIPLY"; t.links.new(dots.outputs[0], dm.inputs[0]); dm.inputs[1].default_value = 0.7
mx = t.nodes.new("ShaderNodeMath"); mx.operation = "MAXIMUM"; t.links.new(socks["emit"], mx.inputs[0]); t.links.new(dm.outputs[0], mx.inputs[1])
socks["emit"] = mx.outputs[0]
# (audit r1: finer branching electric cyan, the Brute's noise-warped vein cells)
for n in list(t.nodes):
    if n.type == "TEX_VORONOI" and n.feature == "DISTANCE_TO_EDGE":
        n.inputs["Scale"].default_value = 2.4
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
remesh(g, H / 150.0, 4)
# the grin: a mouth cut in under the eye
cut = ellipsoid((0.03, -1.0, 2.3), (0.6, 0.34, 0.17), 24)   # (audit r1: a bigger curved grin)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
sel(g); bm_ = g.modifiers.new("mouth", "BOOLEAN"); bm_.operation = "DIFFERENCE"; bm_.object = cut; bm_.solver = "EXACT"
apply_mods(g); bpy.data.objects.remove(cut)
displace(g, "CLOUDS", 0.35 * H / 2.5, 0.006 * H)
bpy.ops.object.shade_smooth()

EYE, EYE_R = (0.17, -0.68, 2.95), 0.62  # (audit r1: less sunk, so the white shows round the iris)                    # (front view: the big eye just right of centre, under the brow)
sclera, iris, pupil, catch = goo_eye(EYE, EYE_R, False, (0.5, 0.2, 0.92, 1))
for o in (iris, pupil):                                   # (audit r1: the iris ~45 % of the eye's width)
    o.scale.x *= 0.75; o.scale.z *= 0.75
mouth = ellipsoid((0.03, -0.78, 2.3), (0.56, 0.16, 0.13), 16)
fangs = [fang((-0.3, -0.9, 2.45), 0.08, 0.19), fang((0.36, -0.9, 2.45), 0.08, 0.19)]
em = flat_material("sclera", (0.95, 0.97, 1.0, 1), 0.08)
im = flat_material("iris", (0.5, 0.2, 0.92, 1), 0.06)
pm = flat_material("pupil", (0.01, 0.01, 0.02, 1), 0.04)
cm_ = flat_material("catch", (1, 1, 1, 1), 0.05)
mm = flat_material("mouth", (0.16, 0.02, 0.3, 1), 0.3)
fm = flat_material("fang", (0.95, 0.94, 0.88, 1), 0.25)
lm = flat_material("lid", (0.0, 0.38, 0.95, 1), 0.15)
parts = [(gm, socks, g), (em[0], em[1], sclera), (im[0], im[1], iris), (pm[0], pm[1], pupil), (cm_[0], cm_[1], catch),
         (mm[0], mm[1], mouth), (fm[0], fm[1], join(fangs))]
mats = [(gm, socks), em, im, pm, cm_, mm, fm]
lid_slot = len(parts)
ec, er = V(EYE), EYE_R
parts.append((lm[0], lm[1], make_lid(tuple(ec), er))); mats.append(lm)
hi = build_high(parts); hi.name = "TwinV5_high"
lo = make_low(hi, "SquishF2", 5000)
main = main_verts(lo)
lv = lid_verts(lo, lid_slot)
bake("squish_f2_v5", lo, hi, mats, 1024)
bones = [("Root", (0, 0, 0), (0, 0, 0.3), None),
         ("Base", (0, 0, 0.05), (0, 0, 0.45), "Root"),
         ("Body", (0, 0, 0.45), (0, 0, 2.0), "Base"),
         ("Top", (0, 0, 2.0), (0, 0, 3.75), "Body"),
         ("Lid", tuple(ec), tuple(ec + V((0, -er, 0))), "Top")]
for s, c in tents.items():
    bones += [("Tend" + s + "1", c[0], c[2], "Body"), ("Tend" + s + "2", c[2], c[4], "Tend" + s + "1"),
              ("Tend" + s + "3", c[4], c[5], "Tend" + s + "2")]
arm, unw = rig("SquishF2", lo, bones)
strip_lid(lo, lv)
follow_surface(lo, main, 6)


def pin_puddle(lo, main):
    """(Play test: heat weighting gave the puddle to Body + the tendrils, so every hop curled it up into a wall) the
    puddle belongs to Base alone below 0.34 studs, blending into the body's weights by 0.62"""
    base = lo.vertex_groups["Base"].index
    n = 0
    for v in lo.data.vertices:
        if v.index not in main or v.co.z >= 0.62:
            continue
        w = 1.0 if v.co.z < 0.34 else (0.62 - v.co.z) / 0.28
        old = {g.group: g.weight for g in v.groups}
        for gi, gw in old.items():
            lo.vertex_groups[gi].add([v.index], gw * (1 - w), "REPLACE")
        lo.vertex_groups[base].add([v.index], old.get(base, 0) * (1 - w) + w, "REPLACE")
        n += 1
    print("PUDDLE", n)


pin_puddle(lo, main)
rigid_parts(lo, main)
lock_eye(lo, EYE, EYE_R, "Top", lv)                   # (James 28 Oct: the eye + the skin round it move solid, no jelly clipping)
assign_lid(lo, lv)
coll = bpy.data.collections.new("SquishF2"); bpy.context.scene.collection.children.link(coll)
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
target = V((0, 0, 2.1))
for tag, yaw, lens, res in () if _norender else (("", -30, 55, (1000, 1000)), ("-front", 0, 60, (1000, 1000)), ("-side", -90, 60, (1000, 1000))):
    cam.data.lens = lens
    sc.render.resolution_x, sc.render.resolution_y = res
    a = math.radians(yaw)
    d = V((math.sin(a), -math.cos(a), 0.16)).normalized()
    cam.location = target + d * 14
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.join(shots, f"34-twin-v5{tag}.png")
    bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(bdir, "squish_f2_v5.blend"))
print("TWIN_V5_OK tris", tris(lo), "unweighted", unw, "bones", len(arm.data.bones), "height", round(max(v.co.z for v in lo.data.vertices), 2))
