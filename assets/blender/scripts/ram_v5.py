# Alien Fusion: CRUNCH RAM v5 (Phase 1 rebuild, 28 Oct 2026; plan design/08-REBUILD-PLAN.md, method card
# Flagship/Polish Kit/cards/creature-from-reference.md). Built to its ChatGPT reference pack, design/concepts/ram/:
#   A-hero-chatgpt.png (the look) . B-model-sheet-chatgpt.png (front / side / back: MEASURED) .
#   CDF-head-hoof-top-chatgpt.png (head + curled crystal horns; a leg: stacked boulders on a split hoof; top view:
#   the crystal spine row, wide shoulders and hips) . I-pose-sheet (the heavy trot).
# The Colossus v4 method: ~50 faceted boulders fused by a light remesh, the creases glow as magma seams (seam_stone);
# faceted amber crystals down the spine and tail, two curled faceted crystal horns, slit eyes, a chest core.
# Scale: the side view, ground (y 668) to the tallest crystal's tip (y 30) = 638 px -> 7.2 studs, 0.0113 studs/px;
#   y = (x_px - 1020) * 0.0113 in the sheet's own pixels (front = -Y), z = (668 - y_px) * 0.0113.
# Rig: 17 bones: Root, Chest (front half) + Head, Hips (back half) + Tail, and per leg Leg / Shin / Foot (FL FR BL BR),
#   so the animator plants each hoof (planted-foot IK, trot: diagonal pairs).
#   blender --background --factory-startup --python ram_v5.py -- <assets_dir> [norender]
# Writes blender/aliens/crunch_f3_v5.blend (collection CrunchF3), textures/aliens/crunch_f3_v5_*.png, shots/31-ram-v5*.png
import os, sys, math, random
_here = os.path.dirname(os.path.abspath(__file__))
_src = open(os.path.join(_here, "aliens_forms.py"), encoding="utf-8").read()
_src = _src[:_src.index("for race, fn in ((\"squish\", squish)")]
_norender = "norender" in sys.argv
sys.argv = [sys.argv[0], "--", sys.argv[sys.argv.index("--") + 1], "none"]
exec(compile(_src, "aliens_forms.py", "exec"))
import mathutils
V = Vector
rnd = random.Random(31)
reset()
BAKE_EXT = 0.2
shots = os.path.join(root, "..", "shots")

# boulders: (centre, radii). Left = +X. Measured off the side + front views
B = [
    # front half: the shoulder hump, withers, brisket, shoulder blades
    ((0, -1.0, 3.75), (1.75, 1.25, 1.35)),
    ((0, -0.9, 4.7), (1.25, 1.0, 0.65)),
    ((0, -2.0, 2.85), (1.35, 0.95, 1.0)),
    # the barrel, back, belly
    ((0, 0.55, 3.55), (1.75, 1.25, 1.2)),
    ((0, 0.9, 4.35), (1.15, 1.2, 0.6)),
    ((0, 0.6, 2.6), (1.25, 1.5, 0.55)),
    # the rump: two big glutes (back view), its top, the tail root
    ((0, 2.5, 4.05), (1.05, 1.0, 0.6)),
    ((0, 3.75, 3.85), (0.5, 0.6, 0.45)),
    ((0, 4.35, 3.8), (0.38, 0.5, 0.36)),
    # the neck + head: a heavy crown, a long blunt muzzle, the brow, the jaw
    ((0, -2.55, 4.15), (1.0, 0.9, 0.95)),
    ((0, -3.25, 4.55), (1.05, 0.95, 0.72)),
    ((0, -3.55, 3.5), (1.25, 1.15, 1.15)),           # (r1: the head was lost behind the horns: ~20 % bigger, forward)
    # (audit r1: a narrower muzzle (-15 %), the heavy brow ~25 % further forward: an aggressive ram, not a rock pig)
    ((0, -4.55, 3.0), (0.72, 0.85, 0.68)),
    ((0, -4.62, 3.98), (1.05, 0.55, 0.4)),
    ((0, -4.1, 2.5), (0.68, 0.85, 0.46)),
]
for sx in (-1, 1):
    B += [
        ((sx * 1.45, -1.55, 3.4), (0.85, 0.95, 1.05)),        # shoulder blade
        ((sx * 1.5, 0.45, 3.45), (0.85, 1.2, 1.0)),           # ribs
        ((sx * 0.95, 2.75, 3.2), (1.05, 1.15, 1.1)),          # glute
        ((sx * 0.9, -3.8, 3.05), (0.55, 0.65, 0.6)),          # cheek
        # front leg: upper, knee, shin, hoof + the split toes (leg close-up)
        # (audit r1: lower legs ~15 % longer: the knee / hock higher; front hooves ~20 % broader, the split deeper)
        ((sx * 1.75, -1.15, 2.85), (0.85, 0.9, 0.9)),
        ((sx * 1.8, -0.95, 1.9), (0.7, 0.75, 0.55)),
        ((sx * 1.85, -1.15, 1.15), (0.66, 0.72, 0.6)),
        ((sx * 1.88, -1.35, 0.42), (1.1, 1.08, 0.44)),
        ((sx * 1.88 + 0.52, -2.15, 0.32), (0.5, 0.58, 0.32)),
        ((sx * 1.88 - 0.52, -2.15, 0.32), (0.5, 0.58, 0.32)),
        # hind leg: thigh, hock (bent back), shin, hoof + toes
        ((sx * 1.6, 3.0, 2.7), (0.9, 1.05, 1.0)),
        ((sx * 1.8, 3.55, 1.78), (0.66, 0.72, 0.55)),
        ((sx * 1.85, 3.35, 1.1), (0.62, 0.68, 0.55)),
        ((sx * 1.88, 3.15, 0.4), (0.98, 0.98, 0.42)),
        ((sx * 1.88 + 0.48, 2.45, 0.3), (0.47, 0.52, 0.3)),
        ((sx * 1.88 - 0.48, 2.45, 0.3), (0.47, 0.52, 0.3)),
    ]


def boulder(c, r):
    """a rounded, faceted boulder: an icosphere (2 subdivisions), each vertex nudged so no two are alike"""
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.0, location=(0, 0, 0))
    o = bpy.context.object
    for v in o.data.vertices:
        v.co *= rnd.uniform(0.93, 1.06)
    o.scale = r
    o.rotation_euler = (rnd.uniform(-0.25, 0.25), rnd.uniform(-0.25, 0.25), rnd.uniform(0, math.pi))
    o.location = c
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return o


body = join([boulder(c, r) for c, r in B]); body.name = "rock"
remesh(body, 0.045, 1)
displace(body, "CLOUDS", 0.45, 0.025)
bpy.ops.object.shade_smooth()

# slit eyes under the brow (glowing), the chest core under the chin (front view)
glow = []
for sx in (-1, 1):
    e = ellipsoid((sx * 0.62, -4.45, 3.62), (0.31, 0.12, 0.11), 12); e.rotation_euler = (0, math.radians(-16 * sx), 0)   # (r1: ~40 % bigger)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    glow.append(e)
sink_eyes(body, glow, 0.5)
glow = join(glow)
# the chest core (audit r1: "a clearly defined, recessed, faceted amber core ~0.65 studs wide, centred between the
# front shoulders"; the first one read as a tongue): a faceted gem set into the brisket, glowing
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1.0, location=(0, -2.82, 2.85))
core = bpy.context.object; core.scale = (0.34, 0.2, 0.4); core.rotation_euler = (0, 0, math.radians(30))
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
sel(core); bpy.ops.object.shade_flat()


def crystal_at(a, d, r, h):
    q = V((0, 0, 1)).rotation_difference(V(d).normalized())
    return crystal(tuple(a), r, h, q.to_euler())


def tube(path, radii, sides=7):
    """a faceted crystal tube along path (the ram horns: low-poly, flat-shaded, a blunt capped tip)"""
    bm = bmesh.new()
    rings = []
    prev_n = None
    for i, p in enumerate(path):
        p = V(p)
        t = (V(path[min(i + 1, len(path) - 1)]) - V(path[max(i - 1, 0)])).normalized()
        n = prev_n if prev_n is not None else t.orthogonal().normalized()
        n = (n - t * n.dot(t)).normalized(); prev_n = n
        b = t.cross(n)
        rings.append([bm.verts.new(p + (n * math.cos(k * 2 * math.pi / sides) + b * math.sin(k * 2 * math.pi / sides)) * radii[i])
                      for k in range(sides)])
    for a, c in zip(rings, rings[1:]):
        for k in range(sides):
            j = (k + 1) % sides
            bm.faces.new((a[k], a[j], c[j], c[k]))
    bm.faces.new(rings[0][::-1])
    tip = bm.verts.new(V(path[-1]) + (V(path[-1]) - V(path[-2])).normalized() * radii[-1] * 0.8)
    for k in range(sides):
        bm.faces.new((rings[-1][k], rings[-1][(k + 1) % sides], tip))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("horn"); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new("horn", me); bpy.context.scene.collection.objects.link(o)
    return o


cry = []
# ---- the two curled crystal horns (side view: spiral centre y -2.2, z 3.7, ~1 stud out; front view: x +-2.0,
# the C opening toward the face). Root on the crown, up and back over the top, down behind, under, forward and up
for sx in (-1, 1):
    path, radii = [], []
    n = 26
    for i in range(n):
        t = i / (n - 1)
        a = math.radians(150 - 330 * t)                   # around the side plane: up-front, back over the top, under, forward
        R = 1.05 - 0.45 * t                                # (r1: thinner, tighter: the sheet's horns)
        x = sx * (0.95 + 1.25 * min(1, t * 3.0) - 0.3 * max(0, t - 0.7) / 0.3)
        path.append((x, -2.25 + math.cos(a) * R, 3.75 + math.sin(a) * R))
        radii.append(0.44 * (1 - t) ** 0.8 + 0.12)
    cry.append(tube(path, radii))
# ---- the crystal spine row (side + top views): tallest over the shoulders, shrinking to the rump, + flanking pairs
# (audit r1: the tallest ~15 % shorter with ~20 % wider bases, neighbours varied harder: not "manufactured pencils")
for y, z, h, r, lean in ((-1.45, 4.95, 1.9, 0.66, -14), (-0.6, 4.95, 1.3, 0.56, -8), (0.15, 4.75, 1.6, 0.54, -4),
                         (0.85, 4.65, 0.9, 0.42, 0), (1.5, 4.45, 1.15, 0.4, 4), (2.05, 4.35, 0.62, 0.3, 8),
                         (2.55, 4.3, 0.8, 0.3, 12), (3.0, 4.15, 0.42, 0.22, 18), (-2.75, 4.75, 1.0, 0.36, 20)):
    cry.append(crystal_at(V((0, y, z - 0.25)), (0, math.sin(math.radians(lean)), 1), r, h + 0.25))
for sx in (-1, 1):
    for x, y, z, h, r, out in ((0.75, -1.25, 4.8, 1.6, 0.45, 14), (1.45, -1.0, 4.45, 1.15, 0.4, 30), (1.9, -0.6, 4.0, 0.8, 0.32, 42),
                               (0.7, 0.0, 4.6, 1.05, 0.38, 20), (0.6, 1.1, 4.45, 0.75, 0.3, 22), (0.55, 2.2, 4.25, 0.55, 0.24, 26)):
        cry.append(crystal_at(V((sx * x, y, z - 0.2)), (sx * math.sin(math.radians(out)), 0.08, 1), r, h + 0.2))
# ---- the tail: a fan of crystals pointing back (side view), the biggest straight back
cry.append(crystal_at(V((0, 4.55, 3.85)), (0, 1, 0.12), 0.38, 1.5))
for sx in (-1, 1):
    cry.append(crystal_at(V((sx * 0.2, 4.3, 4.0)), (sx * 0.35, 0.85, 0.5), 0.26, 0.8))
    cry.append(crystal_at(V((sx * 0.15, 4.05, 4.1)), (sx * 0.2, 0.5, 0.9), 0.24, 0.65))
cry = join(cry)

# ---- materials (the Colossus v4 seam stone; amber crystals; the glow)
_ss = open(os.path.join(_here, "colossus_v4.py"), encoding="utf-8").read().split("# ---- materials\n")[1].split("\nsm = seam_stone()")[0]
# (audit r1: seams ~35 % thinner, no big glow patches (a tighter AO crease band), the basalt ~15 % darker)
for a, b in (("ck.inputs[1].default_value = 0.012; ck.inputs[2].default_value = 0.04", "ck.inputs[1].default_value = 0.008; ck.inputs[2].default_value = 0.026"),
             ("seam.inputs[1].default_value = 0.55; seam.inputs[2].default_value = 0.78", "seam.inputs[1].default_value = 0.42; seam.inputs[2].default_value = 0.6"),
             ("(0.16, 0.155, 0.15, 1)", "(0.136, 0.132, 0.128, 1)"), ("(0.33, 0.32, 0.305, 1)", "(0.28, 0.272, 0.26, 1)"),
             ("(0.36, 0.35, 0.33, 1)", "(0.31, 0.3, 0.285, 1)")):
    assert _ss.count(a) == 1, a
    _ss = _ss.replace(a, b)
exec(compile(_ss, "colossus_v4.py", "exec"))
sm = seam_stone()
cm = crystal_material(3.2, 7.4, (0.9, 0.26, 0.02, 1), (1.0, 0.62, 0.1, 1))
gm = glow_material((1.0, 0.95, 0.5, 1), (1.0, 0.55, 0.05, 1))
sel(cry); bpy.ops.object.shade_flat()
hi = build_high([(sm[0], sm[1], body), (cm[0], cm[1], cry), (gm[0], gm[1], join([glow, core]))]); hi.name = "Ram5_high"
lo = make_low(hi, "CrunchF3", 8000)
bv = body_verts(lo)
bake("crunch_f3_v5", lo, hi, [sm, cm, gm], 1024)
LEGS = {"FL": (1, (1.75, -1.2, 3.45), (1.8, -0.85, 1.9), (1.85, -1.3, 0.58), "Chest"),
        "FR": (-1, (-1.75, -1.2, 3.45), (-1.8, -0.85, 1.9), (-1.85, -1.3, 0.58), "Chest"),
        "BL": (1, (1.7, 3.1, 3.3), (1.8, 3.65, 1.75), (1.85, 3.3, 0.58), "Hips"),
        "BR": (-1, (-1.7, 3.1, 3.3), (-1.8, 3.65, 1.75), (-1.85, 3.3, 0.58), "Hips")}
BONES = [("Root", (0, 0, 0), (0, 0, 0.8), None),
         ("Chest", (0, 0.4, 3.7), (0, -1.6, 3.9), "Root"),
         ("Head", (0, -2.3, 4.0), (0, -4.2, 3.4), "Chest"),
         ("Hips", (0, 0.4, 3.6), (0, 3.2, 3.6), "Root"),
         ("Tail", (0, 3.7, 3.85), (0, 5.4, 3.95), "Hips")]
for k, (sx, hip, knee, ank, par) in LEGS.items():
    BONES += [("Leg" + k, hip, knee, par), ("Shin" + k, knee, ank, "Leg" + k),
              ("Foot" + k, ank, (ank[0], ank[1] - 1.0, 0.25), "Shin" + k)]
arm, unw = rig("CrunchF3", lo, BONES)
rigid_parts(lo, bv)


def pin_pieces(lo, main):
    """(the Colossus lesson: loose crystals copying mixed weights turn against each other) pin each loose piece to ONE
    bone: the horns + eyes to the Head, the tail fan to the Tail, the spine crystals to the Chest / Hips by where they sit"""
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
        if c.y < -3.0 or (c.y < -2.0 and c.z > 3.2):            # (horns, eyes, crest; not the chest core below)
            bone = "Head"
        elif c.y > 3.6:
            bone = "Tail"
        elif c.z > 3.9:
            bone = "Chest" if c.y < 0.9 else "Hips"
        elif c.y < -2.0:
            bone = "Chest"                                   # (the chest core)
        else:
            continue
        for n in names:
            lo.vertex_groups[n].remove(verts)
        lo.vertex_groups[bone].add(verts, 1.0, "REPLACE")
        pinned[bone] = pinned.get(bone, 0) + 1
    print("PINNED", pinned)


pin_pieces(lo, bv)
coll = bpy.data.collections.new("CrunchF3"); bpy.context.scene.collection.children.link(coll)
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
target = V((0, 0.2, 3.3))
for tag, yaw, lens, res in () if _norender else (("", -40, 55, (1300, 1000)), ("-front", 0, 60, (1000, 1000)), ("-side", -90, 55, (1300, 1000))):
    cam.data.lens = lens
    sc.render.resolution_x, sc.render.resolution_y = res
    a = math.radians(yaw)
    d = V((math.sin(a), -math.cos(a), 0.16)).normalized()
    cam.location = target + d * 24
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.join(shots, f"31-ram-v5{tag}.png")
    bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(bdir, "crunch_f3_v5.blend"))
print("RAM_V5_OK tris", tris(lo), "unweighted", unw, "bones", len(arm.data.bones), "height", round(max(v.co.z for v in lo.data.vertices), 2))
for b in arm.data.bones:
    print("BONE", b.name, "head", tuple(round(x, 3) for x in b.head_local), "len", round(b.length, 3))
