# Alien Fusion: CRUNCH PINCER v5 (Phase 1 rebuild, 28 Oct 2026; plan design/08-REBUILD-PLAN.md, method card
# Flagship/Polish Kit/cards/creature-from-reference.md). Built to its ChatGPT reference pack, design/concepts/pincer/:
#   A-hero-chatgpt.png (the look: a stone crab) . BC-model-sheet-top-chatgpt.png (front / side / TOP: MEASURED) .
#   I-pose-sheet (the sideways tripod scuttle).
# The Colossus v4 / Ram v5 method: fused faceted boulders, the creases glow as magma seams; faceted amber crystals (a
# row round the shell's front edge, two big ones on top, the pincer tips, the feet); glowing slit eyes on stalks.
# Scale: the front view, ground (y 465 in the crop) to the top crystals' tips (y 55) = 410 px -> 3.6 studs,
#   0.0088 studs/px; centre line x 335 (front = -Y, left = +X). Leg spread from the top view.
# Rig (20 bones): Root, Body, Arm / Claw / Pinch (the lower jaw opens) x L R, Leg / Shin x L1-3 R1-3 (1 = front).
#   blender --background --factory-startup --python pincer_v5.py -- <assets_dir> [norender]
# Writes blender/aliens/crunch_f2_v5.blend (collection CrunchF2), textures/aliens/crunch_f2_v5_*.png, shots/33-pincer-v5*.png
import os, sys, math, random
_here = os.path.dirname(os.path.abspath(__file__))
_src = open(os.path.join(_here, "aliens_forms.py"), encoding="utf-8").read()
_src = _src[:_src.index("for race, fn in ((\"squish\", squish)")]
_norender = "norender" in sys.argv
sys.argv = [sys.argv[0], "--", sys.argv[sys.argv.index("--") + 1], "none"]
exec(compile(_src, "aliens_forms.py", "exec"))
import mathutils
V = Vector
rnd = random.Random(23)
reset()
BAKE_EXT = 0.12
shots = os.path.join(root, "..", "shots")

# legs: (front / back offset y, its spread dy (top view: the front pair angles forward, the back pair back))
LEGS = {1: (-0.3, -0.45), 2: (0.3, 0.0), 3: (0.9, 0.45)}   # (audit r1: attached a little further back)
HIP, KNEE, ANK = 1.4, 2.35, 2.9                             # (audit r1: spread ~20 % further out; the shell is wider)
CX, CR, CZ = 2.45, (0.85, 0.98), 2.2                        # the claw C: centre x, radii (x, z), centre height

# (audit r1: the shell ~20 % wider and ~10 % flatter)
B = [((0, 0.1, 1.9), (1.74, 1.35, 0.77)), ((0, 0.25, 2.4), (1.32, 1.0, 0.45)), ((0, -0.95, 1.72), (1.4, 0.45, 0.52)),
     ((0, 0.1, 1.25), (1.3, 1.0, 0.35)), ((0, 1.0, 1.85), (1.3, 0.5, 0.55)), ((0, -1.22, 1.42), (0.5, 0.22, 0.2))]
for sx in (-1, 1):
    B += [((sx * 1.38, 0.1, 1.78), (0.65, 0.9, 0.55)),
          # the claw arm: shoulder, elbow
          ((sx * 1.5, -0.65, 1.5), (0.42, 0.42, 0.4)), ((sx * 1.95, -1.0, 1.55), (0.44, 0.44, 0.42)),
          # (audit r1: the eyes sunk in dark stone sockets on short stalks, under a low grumpy brow)
          ((sx * 0.57, -1.12, 2.4), (0.27, 0.22, 0.27)), ((sx * 0.5, -1.25, 2.66), (0.33, 0.17, 0.12))]
    # the claw: a big stone C, its opening toward the body (front view), a long crystal finger at each end
    # (audit r1: the opening ~40 % bigger)
    for i in range(7):
        a = math.radians(-120 + i * 40)
        B.append(((sx * (CX + CR[0] * math.cos(a)), -1.35, CZ + CR[1] * math.sin(a)), (0.44, 0.42, 0.42)))
    # (r1: legs were bead chains: 4 overlapping boulders per segment, chunkier, as the sheet's 3-boulder legs)
    for k, (y, dy) in LEGS.items():
        hip, knee, ank = V((sx * HIP, y, 1.35)), V((sx * KNEE, y + dy * 0.5, 1.6)), V((sx * ANK, y + dy, 0.45))
        for f in (0.0, 0.33, 0.66, 1.0):
            B.append((tuple(hip.lerp(knee, f)), (0.38 - 0.04 * f,) * 3))
        for f in (0.33, 0.66, 1.0):
            B.append((tuple(knee.lerp(ank, f)), (0.33 - 0.06 * f, 0.33 - 0.06 * f, 0.36)))


def boulder(c, r):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1.0, location=(0, 0, 0))   # (audit r1: larger facets)
    o = bpy.context.object
    for v in o.data.vertices:
        v.co *= rnd.uniform(0.93, 1.06)
    o.scale = r
    o.rotation_euler = (rnd.uniform(-0.25, 0.25), rnd.uniform(-0.25, 0.25), rnd.uniform(0, math.pi))
    o.location = c
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return o


body = join([boulder(c, r) for c, r in B]); body.name = "rock"
remesh(body, 0.03, 1)
displace(body, "CLOUDS", 0.3, 0.018)
bpy.ops.object.shade_smooth()


def crystal_at(a, d, r, h):
    q = V((0, 0, 1)).rotation_difference(V(d).normalized())
    return crystal(tuple(a), r, h, q.to_euler())


cry = []
# two big crystals on top (top view: x +-0.57, a little behind the middle; front view tips 3.6 up), leaning out
# (audit r1: bases ~35 % wider, the two different, not matching pillars)
cry.append(crystal_at(V((0.55, 0.3, 2.62)), (0.3, 0.1, 1), 0.41, 1.0))
cry.append(crystal_at(V((-0.5, 0.35, 2.62)), (-0.18, -0.05, 1), 0.38, 1.22))
# the row round the shell's front edge and sides (front + top views): crystals pointing out and up
for i in range(8):                                        # (r1: 15 read as teeth; audit r1: ~25 % fewer again, bigger)
    a = math.radians(200 + i * (140 / 7))
    p = V((math.cos(a) * 1.62, 0.1 + math.sin(a) * 1.26, 2.05 + 0.15 * math.sin(a * 2)))
    out = V((math.cos(a), math.sin(a), 1.1))
    cry.append(crystal_at(p, out, 0.2 + 0.03 * (i % 2), 0.6 + 0.16 * ((i * 7) % 3) / 2))
# the pincers: long crystal fingers at the two ends of the C, pointing at each other across the opening
# (audit r1: ~60 % bigger, elongated)
for sx in (-1, 1):
    top = V((sx * (CX + CR[0] * math.cos(math.radians(120))), -1.35, CZ + CR[1] * math.sin(math.radians(120))))
    bot = V((sx * (CX + CR[0] * math.cos(math.radians(-120))), -1.35, CZ + CR[1] * math.sin(math.radians(-120))))
    cry.append(crystal_at(top, (-sx * 0.45, -0.15, -1), 0.32, 1.0))      # (r2: down into the C, not across the face)
    cry.append(crystal_at(bot, (-sx * 0.45, -0.15, 1), 0.29, 0.9))
    # crystal-tipped feet, pointing down (audit r1: ~30 % longer)
    for k, (y, dy) in LEGS.items():
        cry.append(crystal_at(V((sx * (ANK + 0.02), y + dy, 0.8)), (sx * 0.15, dy * 0.25, -1), 0.22, 0.9))
cry = join(cry)
# glowing slit eyes sunk in their sockets (audit r1: ~30 % smaller, narrower pupils)
glow, dark = [], []
for sx in (-1, 1):
    glow.append(ellipsoid((sx * 0.57, -1.3, 2.4), (0.15, 0.08, 0.15), 14))
    dark.append(ellipsoid((sx * 0.57, -1.37, 2.4), (0.025, 0.03, 0.12), 8))
for o in glow + dark:
    sel(o); bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
glow, dark = join(glow), join(dark)

# ---- materials: the Ram's darker seam stone (audit r1 values), amber crystals, the glow, the pupils
_ss = open(os.path.join(_here, "colossus_v4.py"), encoding="utf-8").read().split("# ---- materials\n")[1].split("\nsm = seam_stone()")[0]
for a, b in (("ck.inputs[1].default_value = 0.012; ck.inputs[2].default_value = 0.04", "ck.inputs[1].default_value = 0.008; ck.inputs[2].default_value = 0.026"),
             ("seam.inputs[1].default_value = 0.55; seam.inputs[2].default_value = 0.78", "seam.inputs[1].default_value = 0.42; seam.inputs[2].default_value = 0.6"),
             ("(0.16, 0.155, 0.15, 1)", "(0.136, 0.132, 0.128, 1)"), ("(0.33, 0.32, 0.305, 1)", "(0.28, 0.272, 0.26, 1)"),
             ("(0.36, 0.35, 0.33, 1)", "(0.31, 0.3, 0.285, 1)"), ("cv.inputs[\"Scale\"].default_value = 0.55", "cv.inputs[\"Scale\"].default_value = 1.1")):
    assert _ss.count(a) == 1, a
    _ss = _ss.replace(a, b)
exec(compile(_ss, "colossus_v4.py", "exec"))
sm = seam_stone()
cm = crystal_material(0.0, 3.6, (0.9, 0.26, 0.02, 1), (1.0, 0.62, 0.1, 1))
gm = glow_material((1.0, 0.8, 0.3, 1), (1.0, 0.5, 0.05, 1))
pm = flat_material("pupil", (0.05, 0.02, 0.01, 1), 0.3)
sel(cry); bpy.ops.object.shade_flat()
hi = build_high([(sm[0], sm[1], body), (cm[0], cm[1], cry), (gm[0], gm[1], glow), (pm[0], pm[1], dark)]); hi.name = "Pincer5_high"
lo = make_low(hi, "CrunchF2", 6000)
bv = body_verts(lo)
bake("crunch_f2_v5", lo, hi, [sm, cm, gm, pm], 1024)
BONES = [("Root", (0, 0, 0), (0, 0, 0.5), None),
         ("Body", (0, 0.1, 1.3), (0, 0.1, 2.6), "Root")]
for sx, s in ((1, "L"), (-1, "R")):
    BONES += [("Arm" + s, (sx * 1.45, -0.6, 1.5), (sx * 1.95, -1.05, 1.6), "Body"),
              ("Claw" + s, (sx * 1.95, -1.05, 1.6), (sx * CX, -1.35, CZ), "Arm" + s),
              ("Pinch" + s, (sx * 2.03, -1.38, 1.35), (sx * 1.55, -1.6, 1.6), "Claw" + s)]
    for k, (y, dy) in LEGS.items():
        hip, knee, ank = (sx * HIP, y, 1.35), (sx * KNEE, y + dy * 0.5, 1.6), (sx * ANK, y + dy, 0.2)
        BONES += [("Leg" + s + str(k), hip, knee, "Body"), ("Shin" + s + str(k), knee, ank, "Leg" + s + str(k))]
arm, unw = rig("CrunchF2", lo, BONES)
rigid_parts(lo, bv)


def pin_pieces(lo, main):
    """every loose piece to ONE bone (the Colossus lesson): the pincer crystals to Claw (upper) / Pinch (lower), each
    foot crystal to its leg's Shin, the rest (shell crystals, eyes) to the Body"""
    vs = lo.data.vertices
    parent = {v.index: v.index for v in vs if v.index not in main}
    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]; i = parent[i]
        return i
    for e in lo.data.edges:
        a, b = e.vertices
        if a in parent and b in parent:
            ra, rb = find(a), find(b)
            if ra != rb:
                parent[ra] = rb
    islands = {}
    for i in parent:
        islands.setdefault(find(i), []).append(i)
    names = [g.name for g in lo.vertex_groups]
    pinned = {}
    for verts in islands.values():
        c = sum((vs[i].co for i in verts), Vector()) / len(verts)
        s = "L" if c.x > 0 else "R"
        if abs(c.x) > 1.4 and c.y < -1.1 and c.z > 1.0:
            bone = ("Pinch" if c.z < 2.1 else "Claw") + s
        elif c.z < 0.75 and abs(c.x) > 1.8:
            k = min(LEGS, key=lambda n: abs(c.y - (LEGS[n][0] + LEGS[n][1])))
            bone = "Shin" + s + str(k)
        else:
            bone = "Body"
        for n in names:
            lo.vertex_groups[n].remove(verts)
        lo.vertex_groups[bone].add(verts, 1.0, "REPLACE")
        pinned[bone] = pinned.get(bone, 0) + 1
    print("PINNED", pinned)


pin_pieces(lo, bv)
coll = bpy.data.collections.new("CrunchF2"); bpy.context.scene.collection.children.link(coll)
for o in (arm, lo):
    for c in o.users_collection:
        c.objects.unlink(o)
    coll.objects.link(o)
hi.hide_render = True; hi.hide_set(True)

# ---- renders to hold against the sheets: hero 3/4, front, top
sc = bpy.context.scene
sc.render.engine = "CYCLES"; sc.cycles.samples = 96
gmat = lo.data.materials[0]; gt = gmat.node_tree; gb = gt.nodes["Principled BSDF"]
imgs = {n.image.name: n for n in gt.nodes if n.type == "TEX_IMAGE" and n.image}
emit_n = next((n for k, n in imgs.items() if k.endswith("_emit")), None)
col_n = next((n for k, n in imgs.items() if k.endswith("_color")), None)
if emit_n and col_n:
    gt.links.new(col_n.outputs["Color"], gb.inputs["Emission Color"])
    em = gt.nodes.new("ShaderNodeMath"); em.operation = "MULTIPLY"; em.inputs[1].default_value = 1.6
    gt.links.new(emit_n.outputs["Color"], em.inputs[0]); gt.links.new(em.outputs[0], gb.inputs["Emission Strength"])
try:
    sc.view_settings.view_transform = "Standard"
except TypeError:
    pass
sc.view_settings.exposure = -0.5
w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.5, 0.5, 0.52, 1); w.node_tree.nodes["Background"].inputs[1].default_value = 0.45
bpy.ops.mesh.primitive_plane_add(size=80, location=(0, 0, 0))
floor = bpy.context.object; fm = bpy.data.materials.new("floor"); fm.use_nodes = True
fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.62, 0.62, 0.64, 1); floor.data.materials.append(fm)
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN")); sc.collection.objects.link(sun)
sun.data.energy = 3.0; sun.data.angle = math.radians(8); sun.rotation_euler = (math.radians(48), math.radians(-12), math.radians(-38))
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam")); sc.collection.objects.link(cam); sc.camera = cam
os.makedirs(shots, exist_ok=True)
target = V((0, -0.2, 1.5))
for tag, yaw, pitch, lens, res in () if _norender else (("", -35, 0.35, 55, (1200, 900)), ("-front", 0, 0.12, 60, (1200, 800)), ("-top", 0, 6.0, 55, (1000, 1000))):
    cam.data.lens = lens
    sc.render.resolution_x, sc.render.resolution_y = res
    a = math.radians(yaw)
    d = V((math.sin(a), -math.cos(a), pitch)).normalized()
    cam.location = target + d * 16
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.join(shots, f"33-pincer-v5{tag}.png")
    bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(bdir, "crunch_f2_v5.blend"))
print("PINCER_V5_OK tris", tris(lo), "unweighted", unw, "bones", len(arm.data.bones), "height", round(max(v.co.z for v in lo.data.vertices), 2))
