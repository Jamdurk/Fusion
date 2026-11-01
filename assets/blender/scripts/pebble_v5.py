# Alien Fusion: CRUNCH PEBBLE v5 (Phase 1 rebuild, 28 Oct 2026; plan design/08-REBUILD-PLAN.md, method card
# Flagship/Polish Kit/cards/creature-from-reference.md). Built to its ChatGPT reference pack, design/concepts/pebble/:
#   A-hero-chatgpt.png (the look: a little stone beetle) . BC-model-sheet-top-chatgpt.png (front / side / TOP: MEASURED).
# The Ram / Pincer method: faceted fused boulders, magma seams in the creases (the split down the shell's middle is the
# brightest), faceted amber crystals (two rows on the wing-cases, a forward horn on the head, the feet), slit eyes.
# Scale: the front view, ground (y 655) to the crystal tips (y 170) = 485 px -> 2.4 studs, 0.00495 studs/px; centre
#   x 305 (front = -Y, left = +X). Length from the side view, leg spread from the top view.
# Rig (15 bones): Root, Body, Head, Leg / Shin x L1-3 R1-3 (1 = front).
#   blender --background --factory-startup --python pebble_v5.py -- <assets_dir> [norender]
# Writes blender/aliens/crunch_f1_v5.blend (collection CrunchF1), textures/aliens/crunch_f1_v5_*.png, shots/35-pebble-v5*.png
import os, sys, math, random
_here = os.path.dirname(os.path.abspath(__file__))
_src = open(os.path.join(_here, "aliens_forms.py"), encoding="utf-8").read()
_src = _src[:_src.index("for race, fn in ((\"squish\", squish)")]
_norender = "norender" in sys.argv
sys.argv = [sys.argv[0], "--", sys.argv[sys.argv.index("--") + 1], "none"]
exec(compile(_src, "aliens_forms.py", "exec"))
import mathutils
V = Vector
rnd = random.Random(41)
reset()
BAKE_EXT = 0.08
shots = os.path.join(root, "..", "shots")

LEGS = {1: (-0.75, -0.2), 2: (0.15, 0.0), 3: (0.95, 0.25)}     # (y of the hip, the foot's spread fore / aft: top view)
HIP, KNEE, ANK = 0.9, 1.22, 1.36                      # (r1: short chunky legs, the body low)

# the two wing-case halves meet down the middle (the seam), over an underbody; the head + snout in front
# (r1: two slabs read boxy: each wing-case is now 3 rounded boulders + an edge row, a round dome like the sheet)
# (audit r1: two CONTINUOUS rounded wing-case halves, 4 big boulders each, apart enough that the seam down the middle
# is one clear recessed glowing channel, front to back; the head ~15 % bigger)
B = [((0, 0.3, 0.8), (0.95, 1.15, 0.4)), ((0, -0.75, 0.98), (0.75, 0.35, 0.4)),
     ((0, -1.18, 0.8), (0.76, 0.63, 0.57)), ((0, -1.68, 0.7), (0.44, 0.36, 0.34))]
for sx in (-1, 1):
    B += [((sx * 0.62, -0.62, 1.22), (0.55, 0.5, 0.5)), ((sx * 0.64, 0.05, 1.36), (0.56, 0.52, 0.58)),   # a wing-case half
          ((sx * 0.64, 0.7, 1.33), (0.55, 0.5, 0.55)), ((sx * 0.58, 1.25, 1.12), (0.48, 0.42, 0.45)),
          ((sx * 0.98, -0.35, 0.98), (0.4, 0.45, 0.38)), ((sx * 1.0, 0.4, 1.0), (0.4, 0.45, 0.4)),     # its rounded edge
          ((sx * 0.95, 1.1, 0.93), (0.36, 0.4, 0.36)),
          ((sx * 0.46, -1.5, 1.02), (0.27, 0.2, 0.15))]                                                # brow ridge
    # (audit r1: two distinct mandibles curving down and in, ~20 % of the head's width)
    for f, (x, y, z, r) in enumerate(((0.24, -1.88, 0.55, 0.13), (0.2, -2.02, 0.42, 0.11), (0.12, -2.08, 0.3, 0.09))):
        B.append(((sx * x, y, z), (r, r * 1.2, r)))
    for k, (y, dy) in LEGS.items():
        # (audit r1: two angular boulders per leg with a pronounced elbow, readable from above)
        hip, knee, ank = V((sx * HIP, y, 0.68)), V((sx * KNEE, y + dy * 0.5, 0.74)), V((sx * ANK, y + dy, 0.24))
        for f in (0.0, 0.6, 1.0):
            B.append((tuple(hip.lerp(knee, f)), (0.26, 0.26, 0.26)))
        for f in (0.45, 1.0):
            B.append((tuple(knee.lerp(ank, f)), (0.23, 0.23, 0.25)))


def boulder(c, r):
    # (big facets (the Pincer audit), but the big shell boulders stay round enough to read as a dome)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2 if max(r) > 0.5 else 1, radius=1.0, location=(0, 0, 0))
    o = bpy.context.object
    for v in o.data.vertices:
        v.co *= rnd.uniform(0.93, 1.06)
    o.scale = r
    o.rotation_euler = (rnd.uniform(-0.25, 0.25), rnd.uniform(-0.25, 0.25), rnd.uniform(0, math.pi))
    o.location = c
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return o


body = join([boulder(c, r) for c, r in B]); body.name = "rock"
remesh(body, 0.02, 1)
displace(body, "CLOUDS", 0.2, 0.012)
bpy.ops.object.shade_smooth()


def crystal_at(a, d, r, h):
    q = V((0, 0, 1)).rotation_difference(V(d).normalized())
    return crystal(tuple(a), r, h, q.to_euler())


cry = []
for sx in (-1, 1):
    # two rows of crystal spikes on each wing-case (front + top views), pointing up and out
    # (audit r1: ~25 % shorter, wider bases, tilted out 15-25 deg: two distinct rows, not pillars)
    for x, y, z, h, r, out in ((0.62, -0.6, 1.66, 0.36, 0.18, 36), (0.66, 0.08, 1.85, 0.42, 0.19, 32), (0.64, 0.72, 1.82, 0.38, 0.18, 34),
                               (0.58, 1.27, 1.52, 0.3, 0.16, 38), (1.12, -0.3, 1.3, 0.32, 0.16, 74), (1.15, 0.5, 1.32, 0.32, 0.16, 74)):
        cry.append(crystal_at(V((sx * x, y, z - 0.1)), (sx * math.sin(math.radians(out)), 0.05, math.cos(math.radians(out))), r, h + 0.1))
    for k, (y, dy) in LEGS.items():                               # crystal-tipped feet
        cry.append(crystal_at(V((sx * (ANK + 0.05), y + dy, 0.3)), (sx * 0.55, dy * 0.3, -1), 0.13, 0.58))   # (r2: pointed claws, not boots)   # (r1: ~30 % bigger, out)
cry.append(crystal_at(V((0, -1.8, 0.88)), (0, -0.8, 0.55), 0.19, 0.92))   # (r2: a narrower base: the face shows)   # (audit r1: the horn on the snout, ~35 deg up, ~40 % longer)   # the horn, forward and up off the head
cry = join(cry)
# (audit r1: recessed angled ALMOND eyes with dark vertical slit pupils, not round dots)
glow, dark = [], []
for sx in (-1, 1):
    # (audit r2: ~75 % bigger, further out from the horn so both read from the front)
    e = ellipsoid((sx * 0.44, -1.6, 0.84), (0.25, 0.08, 0.13), 14); e.rotation_euler = (0, math.radians(-22 * sx), 0)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    glow.append(e)
sink_eyes(body, glow, 0.55)
for e in glow:
    c = sum((v.co for v in e.data.vertices), Vector()) / len(e.data.vertices)
    ymin = min(v.co.y for v in e.data.vertices)
    d = ellipsoid((c.x, ymin + 0.02, c.z), (0.035, 0.025, 0.11), 8)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    dark.append(d)
glow, dark = join(glow), join(dark)

# ---- materials: the Ram's seam stone with smaller cells for a small body; amber crystals; the glow
_ss = open(os.path.join(_here, "colossus_v4.py"), encoding="utf-8").read().split("# ---- materials\n")[1].split("\nsm = seam_stone()")[0]
for a, b in (("ck.inputs[1].default_value = 0.012; ck.inputs[2].default_value = 0.04", "ck.inputs[1].default_value = 0.008; ck.inputs[2].default_value = 0.026"),
             ("seam.inputs[1].default_value = 0.55; seam.inputs[2].default_value = 0.78", "seam.inputs[1].default_value = 0.42; seam.inputs[2].default_value = 0.6"),
             ("(0.16, 0.155, 0.15, 1)", "(0.136, 0.132, 0.128, 1)"), ("(0.33, 0.32, 0.305, 1)", "(0.28, 0.272, 0.26, 1)"),
             ("(0.36, 0.35, 0.33, 1)", "(0.31, 0.3, 0.285, 1)"), ("cv.inputs[\"Scale\"].default_value = 0.55", "cv.inputs[\"Scale\"].default_value = 1.6"),
             ("ao.inputs[\"Distance\"].default_value = 0.3", "ao.inputs[\"Distance\"].default_value = 0.15")):
    assert _ss.count(a) == 1, a
    _ss = _ss.replace(a, b)
exec(compile(_ss, "colossus_v4.py", "exec"))
sm = seam_stone()
cm = crystal_material(0.0, 2.4, (0.9, 0.26, 0.02, 1), (1.0, 0.62, 0.1, 1))
gm = glow_material((1.0, 0.85, 0.35, 1), (1.0, 0.5, 0.05, 1))
pm = flat_material("pupil", (0.05, 0.02, 0.01, 1), 0.3)
sel(cry); bpy.ops.object.shade_flat()
hi = build_high([(sm[0], sm[1], body), (cm[0], cm[1], cry), (gm[0], gm[1], glow), (pm[0], pm[1], dark)]); hi.name = "Pebble5_high"
lo = make_low(hi, "CrunchF1", 3500)
bv = body_verts(lo)
bake("crunch_f1_v5", lo, hi, [sm, cm, gm, pm], 512)
BONES = [("Root", (0, 0, 0), (0, 0, 0.4), None),
         ("Body", (0, 0.2, 0.65), (0, 0.2, 1.75), "Root"),
         ("Head", (0, -0.85, 0.85), (0, -1.8, 0.72), "Body")]
for sx, s in ((1, "L"), (-1, "R")):
    for k, (y, dy) in LEGS.items():
        hip, knee, ank = (sx * HIP, y, 0.68), (sx * KNEE, y + dy * 0.5, 0.74), (sx * ANK, y + dy, 0.03)
        BONES += [("Leg" + s + str(k), hip, knee, "Body"), ("Shin" + s + str(k), knee, ank, "Leg" + s + str(k))]
arm, unw = rig("CrunchF1", lo, BONES)
rigid_parts(lo, bv)


def pin_pieces(lo, main):
    """every loose piece to ONE bone: the horn + eyes to the Head, each foot crystal to its Shin, the rest to the Body"""
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
        if c.y < -1.4:
            bone = "Head"
        elif c.z < 0.4 and abs(c.x) > 1.0:
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
coll = bpy.data.collections.new("CrunchF1"); bpy.context.scene.collection.children.link(coll)
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
target = V((0, 0, 1.0))
for tag, yaw, lens, res in () if _norender else (("", -35, 55, (1100, 900)), ("-front", 0, 60, (1000, 800)), ("-side", -90, 55, (1100, 800))):
    cam.data.lens = lens
    sc.render.resolution_x, sc.render.resolution_y = res
    a = math.radians(yaw)
    d = V((math.sin(a), -math.cos(a), 0.2)).normalized()
    cam.location = target + d * 10
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.join(shots, f"35-pebble-v5{tag}.png")
    bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(bdir, "crunch_f1_v5.blend"))
print("PEBBLE_V5_OK tris", tris(lo), "unweighted", unw, "bones", len(arm.data.bones), "height", round(max(v.co.z for v in lo.data.vertices), 2))
