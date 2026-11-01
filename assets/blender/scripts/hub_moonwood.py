# Alien Fusion hub: the MOONWOOD FOREST kit (30 Oct 2026). Built to match the ChatGPT references
#   design\concepts\hub\C2-moonwood-tree-sheet-chatgpt.png (the 3 trees + pod cluster + moss + spore),
#   C-moonwood-forest-chatgpt.png (look), C3-moonwood-layout-chatgpt.png (layout), I-nature-kit-chatgpt.png.
# Each tree = 4 meshes so Roblox can colour them: <tree>Bark (pearly white, twisted trunk + branches + roots),
# <tree>Canopy (lilac cloud blobs + leaf-blade fringe), <tree>Pods (pale husks + stems), <tree>PodGlow (violet glowing
# drops). Bark + Canopy get baked textures in hub_moonwood_tex.py. Budget (ChatGPT pack audit): 600-1,800 tris
# per tree. Authored in ROBLOX space (x right, y up, z), 1 unit = 1 stud, base of the trunk at the origin.
#   blender --background --factory-startup --python hub_moonwood.py -- <out_dir>
import bpy, bmesh, math, os, random, sys
from mathutils import Vector, Matrix, noise

out_dir = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "."
for o in list(bpy.data.objects): bpy.data.objects.remove(o, do_unlink=True)
objs = []
TAU = 2 * math.pi

def new_obj(name, bm, smooth=True):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(ob)
    objs.append((ob, smooth)); return ob

def icosphere(bm, c, r, sub=1, amp=0.0, seed=0.0, squash=(1, 1, 1)):
    vs = bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=1.0, matrix=Matrix.Identity(4), calc_uvs=False)["verts"]
    for v in vs:
        d = v.co.copy(); k = 1 + amp * noise.noise(d * 1.6 + Vector((seed, 2 * seed, -seed)))
        v.co = Vector((c[0] + d.x * r * squash[0] * k, c[1] + d.y * r * squash[1] * k, c[2] + d.z * r * squash[2] * k))
    return vs

def tube(bm, pts, rads, sides=7, twist=0.0, cap=True):
    """a smooth tube along pts with radii rads; twist (rad per ring) gives the rope-twisted bark of C2"""
    rings = []
    for i, p in enumerate(pts):
        d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        up = Vector((0, 1, 0)) if abs(d.y) < 0.9 else Vector((1, 0, 0))
        s1 = d.cross(up).normalized(); s2 = s1.cross(d).normalized()
        ring = []
        for k in range(sides):
            a = TAU * k / sides + twist * i
            bump = 1 + 0.12 * math.cos(3 * a)                 # 3 rope strands
            ring.append(bm.verts.new(p + (s1 * math.cos(a) + s2 * math.sin(a)) * rads[i] * bump))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(sides):
            bm.faces.new((rings[i][k], rings[i][(k + 1) % sides], rings[i + 1][(k + 1) % sides], rings[i + 1][k]))
    if cap:
        tip = bm.verts.new(pts[-1] + (pts[-1] - pts[-2]).normalized() * rads[-1] * 0.5)
        for k in range(sides): bm.faces.new((rings[-1][k], rings[-1][(k + 1) % sides], tip))

def bezier(p0, p1, p2, n):
    return [p0 * (1 - t) ** 2 + p1 * 2 * t * (1 - t) + p2 * t * t for t in (i / (n - 1) for i in range(n))]

def canopy_blob(bm, c, rx, ry, seed):
    """(r2) a puffy cauliflower cloud like C2: a core dome + 5 lumps round its top edge + 1 on top, flat-ish underside"""
    r = random.Random(seed)
    def lump(cc, sx, sy):
        vs = icosphere(bm, cc, 1.0, sub=1, amp=0.12, seed=seed + cc[0], squash=(sx, sy, sx))
        for v in vs:
            if v.co.y < c[1] - ry * 0.3: v.co.y = c[1] - ry * 0.3 + (v.co.y - (c[1] - ry * 0.3)) * 0.4
    # (r3, ChatGPT forest audit r1: 3 big smooth masses per blob, not many small puffs)
    def smooth_lump(cc, sx, sy):
        vs = icosphere(bm, cc, 1.0, sub=2, amp=0.07, seed=seed + cc[0], squash=(sx, sy, sx))
        for v in vs:
            if v.co.y < c[1] - ry * 0.3: v.co.y = c[1] - ry * 0.3 + (v.co.y - (c[1] - ry * 0.3)) * 0.4
    smooth_lump(c, rx * 0.82, ry * 0.9)
    # (r4, James: "very Robloxy"; reference C4 panel 3: a fringe of drooping pointed leaves under the canopy rim)
    # leaves rooted just inside the core lump's lower rim, hanging outward + down, in 2 staggered rings
    # (r6, ChatGPT texture audit r1: the 8-tri diamonds read as "crystals / teeth" -> each leaf is a thin flat BLADE that
    # curves out then down (2 stations + base + tip, a thin lens so it shows from both sides; 16 tris), ~25 % fewer.
    # Vertex float "leafT" (0 = rest of the canopy, 0.02 base .. 1 tip) lets hub_moonwood_tex.py paint each blade's own
    # violet-base -> lilac -> pale-tip gradient instead of the box-projected leaf tile.)
    lt = bm.verts.layers.float.get("leafT") or bm.verts.layers.float.new("leafT")
    down = Vector((0, -1, 0))
    n = max(6, int(round(1.5 * rx)))
    for k in range(2 * n):
        inner = k >= n
        a0 = TAU * (k % n + (0.5 if inner else 0)) / n + r.uniform(-0.1, 0.1)
        out = Vector((math.cos(a0), 0, math.sin(a0)))
        side = Vector((-math.sin(a0), 0, math.cos(a0)))
        base = Vector(c) + out * rx * (0.66 if inner else 0.76) + Vector((0, -ry * (0.28 if inner else 0.24), 0))
        L = min(2.0, 0.9 + 0.12 * rx) * r.uniform(0.85, 1.15) * (0.8 if inner else 1.0)
        W = L * 0.8; TH = L * 0.015                                   # (r7: wider + flatter, read as cones at 0.6 / 0.035)
        o1 = 0.55 if inner else 0.85                                  # inner ring hangs steeper
        d1 = (out * o1 + down * 0.5).normalized(); d2 = (out * o1 * 0.5 + down).normalized(); d3 = (out * 0.12 + down).normalized()
        s1 = base + d1 * L * 0.4; s2 = s1 + d2 * L * 0.35; tp = s2 + d3 * L * 0.25
        b0 = bm.verts.new(base); bt = bm.verts.new(tp); b0[lt] = 0.02; bt[lt] = 1.0
        rings = []
        for (p, d, w, t) in ((s1, d1, W * 0.5, 0.4), (s2, d2, W * 0.38, 0.75)):
            nr = side.cross(d).normalized()
            if nr.y < 0: nr = -nr                                     # "top" of the blade faces up / out
            ring = [bm.verts.new(p + side * w), bm.verts.new(p + nr * TH), bm.verts.new(p - side * w), bm.verts.new(p - nr * TH)]
            for v in ring: v[lt] = t
            rings.append(ring)
        A, B = rings
        for j in range(4):
            bm.faces.new((b0, A[j], A[(j + 1) % 4]))
            bm.faces.new((A[j], B[j], B[(j + 1) % 4], A[(j + 1) % 4]))
            bm.faces.new((B[(j + 1) % 4], B[j], bt))
    a = r.uniform(0, TAU)
    smooth_lump((c[0] + math.cos(a) * rx * 0.45, c[1] + ry * 0.2, c[2] + math.sin(a) * rx * 0.45), rx * 0.55, ry * 0.7)
    smooth_lump((c[0] - math.cos(a) * rx * 0.4, c[1] + ry * 0.35, c[2] - math.sin(a) * rx * 0.4), rx * 0.5, ry * 0.65)

def lathe(bm, c, prof, sides, size, rot=0.0):
    """a closed surface of revolution round the vertical through c; prof = [(radius, y)], radius 0 = a pole"""
    rows = []
    for (r, y) in prof:
        if r < 1e-4: rows.append([bm.verts.new(c + Vector((0, y * size, 0)))]); continue
        rows.append([bm.verts.new(c + Vector((math.cos(TAU * k / sides + rot) * r * size, y * size, math.sin(TAU * k / sides + rot) * r * size))) for k in range(sides)])
    for i in range(len(rows) - 1):
        A, B = rows[i], rows[i + 1]
        for k in range(sides):
            if len(A) == 1: bm.faces.new((A[0], B[(k + 1) % sides], B[k]))
            elif len(B) == 1: bm.faces.new((A[k], A[(k + 1) % sides], B[0]))
            else: bm.faces.new((A[k], A[(k + 1) % sides], B[(k + 1) % sides], B[k]))

def pod(bm, glow, top, size, rng):
    """a hanging seed-pod (r6, ChatGPT texture audit r1: the solid Neon diamonds looked artificial): a thin curved stem,
    an elongated pale lilac HUSK (non-Neon, keeps its shape in shadow, mesh <tree>Pods) and a smaller glowing violet
    DROP (Neon, mesh <tree>PodGlow) whose lower half hangs out of the husk. ~90 tris."""
    c = top - Vector((0, size * 0.9, 0))
    sw = Vector((rng.uniform(-1, 1), 0, rng.uniform(-1, 1))).normalized() * size * 0.25
    tube(bm, bezier(top, top.lerp(c, 0.5) + sw, c + Vector((0, size * 0.05, 0)), 4), [size * 0.07, size * 0.06, size * 0.05, size * 0.045], 3, cap=False)
    lathe(bm, c, [(0.0, 0.08), (0.2, -0.05), (0.36, -0.35), (0.42, -0.75), (0.0, -0.72)], 6, size)          # husk (bowl, closed)
    lathe(glow, c, [(0.0, -0.4), (0.33, -0.55), (0.34, -0.95), (0.24, -1.35), (0.0, -1.75)], 6, size, rot=TAU / 12)  # drop
    return c

def roots(bm, n, r0, rng):
    for i in range(n):
        a = TAU * i / n + rng.uniform(-0.3, 0.3)
        d = Vector((math.cos(a), 0, math.sin(a)))
        pts = bezier(Vector((0, 1.6, 0)) + d * r0 * 0.4, Vector((0, 0.6, 0)) + d * r0 * 1.1, Vector((0, -0.3, 0)) + d * r0 * 2.4, 5)
        tube(bm, pts, [r0 * 0.55, r0 * 0.45, r0 * 0.32, r0 * 0.2, r0 * 0.1], 5)

def tree(name, spec, seed):
    """spec: trunk (list of control points), trunk radii, branches [(start t, end point, radius)], canopies [(c, rx, ry)]"""
    rng = random.Random(seed)
    bark, can, pods, glow = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    T = spec["trunk"]
    pts = bezier(Vector(T[0]), Vector(T[1]), Vector(T[2]), 11)
    # (r2: thicker, flared at the base like C2)
    tube(bark, pts, [spec["r0"] * (1.35 - 0.35 * min(1, i / 2)) * (1 - 0.5 * i / 10) for i in range(11)], 9, twist=spec.get("twist", 0.3))
    roots(bark, spec.get("roots", 5), spec["r0"], rng)
    for (t, end, r) in spec["branches"]:
        i = int(t * 10); s = pts[i]
        mid = s.lerp(Vector(end), 0.5) + Vector((0, 1.2, 0))
        tube(bark, bezier(s, mid, Vector(end), 5), [r, r * 0.85, r * 0.7, r * 0.55, r * 0.45], 6, twist=0.3)
    for j, (c, rx, ry) in enumerate(spec["canopies"]):
        canopy_blob(can, c, rx, ry, seed + j)
        # 1-2 pods under each canopy blob, on its rim
        for q in range(spec.get("pods_per", 2)):
            a = rng.uniform(0, TAU); rr = rx * rng.uniform(0.55, 0.85)
            pod(pods, glow, Vector((c[0] + math.cos(a) * rr, c[1] - ry * 0.3, c[2] + math.sin(a) * rr)), rng.uniform(1.7, 2.2), rng)
    new_obj(name + "Bark", bark); new_obj(name + "Canopy", can); new_obj(name + "Pods", pods); new_obj(name + "PodGlow", glow)

# 1 TALL THIN (~35 high): one rope-twisted trunk, 2 side branches, 4 stacked round canopies
tree("mwTall", {
    "trunk": [(0, 0, 0), (2.6, 14, 0.8), (0.4, 27, -0.4)], "r0": 1.75, "roots": 5,
    "branches": [(0.55, (5.5, 21.5, 1.0), 0.7), (0.7, (-4.5, 24.5, -1.2), 0.6)],
    "canopies": [((0.4, 30.0, -0.4), 6.2, 3.8), ((5.8, 23.0, 1.0), 4.6, 2.9), ((-4.8, 26.0, -1.2), 4.4, 2.8)],
    "pods_per": 1}, 3)
# 2 WIDE UMBRELLA (~28 high, ~34 wide): a leaning trunk that splits into 3 big boughs under a broad canopy
tree("mwWide", {
    "trunk": [(0, 0, 0), (-3.4, 9, 0.4), (0.8, 17, 0)], "r0": 3.0, "roots": 6,
    "branches": [(0.75, (-11.5, 20.5, 1.5), 1.0), (0.75, (10.5, 21.0, -1.0), 1.0), (0.85, (2.0, 22.5, -5.0), 0.8)],
    "canopies": [((0.8, 24.0, 0), 10.0, 3.8), ((-12.5, 22.5, 1.5), 7.5, 3.1), ((11.5, 23.0, -1.0), 7.5, 3.1), ((2.0, 24.0, -7.0), 6.5, 2.8)],
    "pods_per": 1}, 7)
# 3 TWISTED LOW (~16 high, ~22 wide): a trunk that crawls sideways, then rises into 3 low canopies
tree("mwLow", {
    "trunk": [(0, 0, 0), (7.5, 2.5, 0.5), (11.0, 7.5, 0)], "r0": 2.3, "roots": 5, "twist": 0.0,
    "branches": [(0.45, (-2.5, 7.5, 1.0), 0.75), (0.8, (15.5, 8.5, -1.5), 0.6)],
    "canopies": [((11.0, 10.6, 0), 6.4, 2.9), ((-3.0, 10.0, 1.0), 5.4, 2.6), ((16.0, 9.8, -1.5), 4.6, 2.3)],
    "pods_per": 1}, 11)

# the ELDER tree (the forest landmark in C3; ChatGPT forest audit r2: "same tree but larger" -> its own mesh): the wide
# tree's design with an 18 % wider canopy, an extra low sweeping side branch carrying its own canopy, and 3 pods per
# canopy instead of 1. Placed at x2.4 in Roblox.
tree("mwElder", {
    "trunk": [(0, 0, 0), (-3.4, 9, 0.4), (0.8, 17, 0)], "r0": 3.2, "roots": 7,
    "branches": [(0.75, (-13.5, 20.5, 1.5), 1.05), (0.75, (12.5, 21.0, -1.0), 1.05), (0.85, (2.0, 22.5, -6.0), 0.85),
                 (0.4, (16.5, 12.5, 6.5), 0.9)],
    "canopies": [((0.8, 24.0, 0), 11.8, 4.2), ((-14.8, 22.5, 1.5), 8.8, 3.4), ((13.6, 23.0, -1.0), 8.8, 3.4),
                 ((2.0, 24.0, -8.2), 7.6, 3.1), ((17.5, 14.8, 7.0), 6.6, 2.8)],
    "pods_per": 3}, 19)

# violet DNA seed-pod CLUSTER (r3, ChatGPT forest audit r1: "flat neon blobs" -> 6 faceted crystal pods (opaque lilac,
# mesh mwPodClusterGlow) round a small bright CORE (neon, mwPodClusterCore), in pearly leaf cups (mwPodClusterCups))
bm, crys, core = bmesh.new(), bmesh.new(), bmesh.new()
rng = random.Random(17)
for i in range(7):
    centre = (i == 0)
    a = TAU * (i - 1) / 6 + rng.uniform(-0.2, 0.2); d = 0 if centre else 1.9
    s = 1.45 if centre else rng.uniform(0.85, 1.1)
    base = Vector((math.cos(a) * d, 0, math.sin(a) * d))
    tilt = Matrix.Rotation(0 if centre else math.radians(rng.uniform(18, 30)), 4, Vector((-math.sin(a), 0, math.cos(a))))
    # a faceted crystal pod: 6-sided bipyramid, pointed top
    ring = [base + tilt @ Vector((math.cos(TAU * k / 6) * 0.62 * s, 1.0 * s, math.sin(TAU * k / 6) * 0.62 * s)) for k in range(6)]
    top = base + tilt @ Vector((0, 2.9 * s, 0)); bot = base + tilt @ Vector((0, 0.1 * s, 0))
    rv = [crys.verts.new(p) for p in ring]; tv = crys.verts.new(top); bv = crys.verts.new(bot)
    for k in range(6):
        crys.faces.new((rv[k], rv[(k + 1) % 6], tv)); crys.faces.new((rv[(k + 1) % 6], rv[k], bv))
    for k in range(3):                                         # leaf cup petals
        b = a + TAU * k / 3
        petal = icosphere(bm, (0, 0, 0), 1.0, sub=1, squash=(0.55 * s, 1.15 * s, 0.2 * s))
        for v in petal: v.co = base + tilt @ (Matrix.Rotation(b, 3, "Y") @ (Matrix.Rotation(math.radians(-30), 3, "X") @ (v.co + Vector((0, 0.9 * s, 0.4 * s)))))
icosphere(core, (0, 1.6, 0), 0.75, sub=2)
new_obj("mwPodClusterCups", bm); new_obj("mwPodClusterGlow", crys, smooth=False); new_obj("mwPodClusterCore", core)

# MOSS patch: a low lumpy mat of blue-grey blobs (one mesh, scaled per copy)
bm = bmesh.new()
for i in range(7):
    a = rng.uniform(0, TAU); d = rng.uniform(0, 2.6)
    icosphere(bm, (math.cos(a) * d, 0.1, math.sin(a) * d), rng.uniform(1.0, 1.6), sub=1, amp=0.25, seed=i, squash=(1.0, 0.38, 1.0))
new_obj("mwMoss", bm)

# a floating SPORE (client effect later; one small orb)
bm = bmesh.new(); icosphere(bm, (0, 0, 0), 0.5, sub=2); new_obj("mwSpore", bm)

# ---------------- export (already Roblox space), smooth normals on everything (organic)
path = os.path.join(out_dir, "hub-moonwood.obj")
with open(path, "w") as fo:
    vo, no = 1, 1
    for ob, smooth in objs:
        me = ob.data; me.calc_loop_triangles()
        fo.write(f"o {ob.name}\ng {ob.name}\nusemtl {ob.name}\n")
        for v in me.vertices: fo.write("v %.4f %.4f %.4f\n" % tuple(v.co))
        if smooth:
            for v in me.vertices: fo.write("vn %.4f %.4f %.4f\n" % tuple(v.normal))
            for t in me.loop_triangles: fo.write("f " + " ".join(f"{t.vertices[i] + vo}//{t.vertices[i] + no}" for i in range(3)) + "\n")
            no += len(me.vertices)
        else:                                                  # (faceted: the crystal pods)
            for t in me.loop_triangles: fo.write("f %d %d %d\n" % tuple(t.vertices[i] + vo for i in range(3)))
        xs = [v.co.x for v in me.vertices]; ys = [v.co.y for v in me.vertices]; zs = [v.co.z for v in me.vertices]
        print("PIECE", ob.name, "size", round(max(xs) - min(xs), 1), round(max(ys) - min(ys), 1), round(max(zs) - min(zs), 1), "tris", len(me.loop_triangles))
        vo += len(me.vertices)
print("WROTE", path, "total", sum(len(o.data.loop_triangles) for o, _ in objs))
