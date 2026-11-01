# Alien Fusion: the TITAN redo's K-sheet effect meshes (29 Oct 2026; spec design/20-TITAN-REDO-SPEC 8, reference
# design/concepts/titan/attacks-v2/K-effects-chatgpt.png). Built procedurally to the spec sizes, in ROBLOX MODEL SPACE
# (x right, y up, -z forward), one OBJ. Goo pieces get UVs inside the GooSkin patch (GooMesh.PATCH: the Twin texture's
# pure-goo square with bright cracks), so they wear the SQUISH skin; rocks and glow pieces are re-materialled in Studio.
#   titanCrown1     K1  8 x 4 x 7     splash crown: thick rimmed bowl + 8 blunt rising arms
#   titanCrack1     K2  10 x 0.14     broken slab: 17 fracture plates with gaps (rock)  + titanCrackGlow1 (cyan under them)
#   titanRock1-4    K3  ~1            irregular faceted rocks
#   titanDrop1-3    K4  0.5-0.9       glossy tear shapes, thick tips
#   titanBall1      K5  3             lobed goo ball
#   titanSplat1     K6  10 x 5 x 10   low wide crown + 3 broad sideways sheets
#   titanPuddle1    K7  10 x 0.25     irregular puddle, raised lip, 6 bubble domes
#   titanWave1      K8  12 x 10 x 5   curling wave: thick body, hollow-looking crest, crest lip 1.2
#   titanSplashWall1 K9 14 x 11 x 4   breaking splash wall with blunt spikes + hanging bulbs
#   titanFlood1     K10 12 x 0.25 x 30 long irregular strip, raised edges, bumps
#   titanMelt1      K11 13 x 0.22 x 12 the collapsed Titan puddle, 4 big bubble domes
#   titanMote1      K12 0.62          matter mote, a subtle lobe
#   titanShockSeg1  functional: 1 x 1 x 1 lumpy curved ridge, laid 12 round a 120-degree arc
#   titanWhip1      functional: crescent ribbon, 0.55 wide
#   titanFoam1      functional: 12 x 1.6 x 2 crest lobes
#   titanGather1    functional: 12 x 5.5 x 4 goo gathering wall
#   titanCollapse1 / titanMeltHeap1  J4: the Titan's OWN mesh sagged (horns droop, dome caves) / melted to a heap,
#                   its own UVs (wears the Titan's SurfaceAppearance)
#   blender --background --factory-startup aliens/squish_f4_v5.blend --python titan_k.py -- <out_dir>
import bpy, bmesh, sys, os, math, random
from mathutils import Vector, Matrix, noise

out_dir = sys.argv[sys.argv.index("--") + 1]
random.seed(11)
objs = []
PATCH = (0.89, 0.985, 0.39, 0.485)
TAU = 2 * math.pi

def nz(p, f=1.0, s=0.0):
    return noise.noise(Vector((p[0] * f + s, p[1] * f + 2 * s, p[2] * f - s)))

def patch_uv(bm, scale=3.0):
    uvl = bm.loops.layers.uv.verify()
    for f in bm.faces:
        n = f.normal; ax = max(range(3), key=lambda i: abs(n[i]))
        for l in f.loops:
            p = l.vert.co
            a, b = [(p.y, p.z), (p.x, p.z), (p.x, p.y)][ax]
            u, v = (a / scale) % 1, (b / scale) % 1
            # (PATCH is in Roblox UV space, v down from the top; OBJ v runs up from the bottom: flip, or the mesh
            # samples the wrong rows of the texture (first import came out black-striped))
            l[uvl].uv = (PATCH[0] + (PATCH[1] - PATCH[0]) * (0.05 + 0.9 * u), 1 - (PATCH[2] + (PATCH[3] - PATCH[2]) * (0.05 + 0.9 * v)))

def new_obj(name, bm, uv=True):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.normal_update()
    if uv: patch_uv(bm)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(ob)
    objs.append(ob); return ob

def blob(bm, c, r, sub=2, amp=0.0, f=1.0, seed=0.0):
    vs = bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=1.0, matrix=Matrix.Identity(4), calc_uvs=False)["verts"]
    for v in vs:
        d = v.co.copy(); k = 1 + amp * nz(d, f, seed)
        v.co = Vector((c[0] + d.x * r[0] * k, c[1] + d.y * r[1] * k, c[2] + d.z * r[2] * k))
    return vs

def tube(bm, pts, rads, sides=8, flat=1.0, bulb=1.0):
    rings = []
    for i, p in enumerate(pts):
        d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        up = Vector((0, 1, 0)) if abs(d.y) < 0.9 else Vector((1, 0, 0))
        s1 = d.cross(up).normalized(); s2 = s1.cross(d).normalized()
        rings.append([bm.verts.new(p + (s1 * math.cos(a) + s2 * math.sin(a) * flat) * rads[i]) for a in (TAU * k / sides for k in range(sides))])
    for i in range(len(rings) - 1):
        for k in range(sides):
            bm.faces.new((rings[i][k], rings[i][(k + 1) % sides], rings[i + 1][(k + 1) % sides], rings[i + 1][k]))
    bm.faces.new(rings[0][::-1])
    tip = bm.verts.new(pts[-1] + (pts[-1] - pts[-2]).normalized() * rads[-1] * 0.6)
    for k in range(sides): bm.faces.new((rings[-1][k], rings[-1][(k + 1) % sides], tip))
    if bulb > 0:                                              # (a rounded drop on the end: goo arms end blunt, never pointed)
        # (r3: sub 2, sub 1 read faceted; made after the tip faces: a sub-2 icosphere op invalidates loose verts)
        d = (pts[-1] - pts[-2]).normalized()
        blob(bm, pts[-1] + d * rads[-1] * 0.4, (rads[-1] * 1.25 * bulb,) * 3, sub=2)

def lathe(bm, prof, segs=24, rf=None):
    rows = []
    for (r, y) in prof:
        if r < 1e-4: rows.append([bm.verts.new((0, y, 0))]); continue
        row = []
        for k in range(segs):
            a = TAU * k / segs; m = rf(a) if rf else 1.0
            row.append(bm.verts.new((math.cos(a) * r * m, y, math.sin(a) * r * m)))
        rows.append(row)
    for i in range(len(rows) - 1):
        A, B = rows[i], rows[i + 1]
        for k in range(segs):
            if len(A) == 1: bm.faces.new((A[0], B[(k + 1) % segs], B[k]))
            elif len(B) == 1: bm.faces.new((A[k], A[(k + 1) % segs], B[0]))
            else: bm.faces.new((A[k], A[(k + 1) % segs], B[(k + 1) % segs], B[k]))

def sweep(bm, ts, section, axis="x", cap=True):
    """closed cross-sections (lists of (u, y), same count) at each t, joined; axis x: (t, y, u); axis z: (u, y, t)"""
    loops = []
    for t in ts:
        sec = section(t)
        loops.append([bm.verts.new((t, y, u) if axis == "x" else (u, y, t)) for (u, y) in sec])
    n = len(loops[0])
    for i in range(len(loops) - 1):
        for k in range(n):
            bm.faces.new((loops[i][k], loops[i][(k + 1) % n], loops[i + 1][(k + 1) % n], loops[i + 1][k]))
    if cap:
        bm.faces.new(loops[0][::-1]); bm.faces.new(loops[-1])

def ring_noise(amp, f, seed):
    return lambda a: 1 + amp * noise.noise(Vector((math.cos(a) * f, math.sin(a) * f, seed)))

def domes(bm, n, rmin, rmax, R, y0, seed):
    rnd = random.Random(seed)
    for i in range(n):
        a = rnd.uniform(0, TAU); d = rnd.uniform(0.15, 0.75) * R; r = rnd.uniform(rmin, rmax)
        blob(bm, (math.cos(a) * d, y0, math.sin(a) * d), (r, r * 0.75, r), sub=2)

# ---- K1 slam crown: rimmed bowl (r 3.9) + 8 blunt arms rising to 2.6-4.0; then squeezed to 7 deep
bm = bmesh.new()
lathe(bm, [(0, 0.02), (1.6, 0.08), (2.8, 0.30), (3.6, 0.75), (3.95, 0.55), (3.7, 0.12), (3.2, 0.0)], 28, ring_noise(0.10, 1.4, 3))
rnd = random.Random(5)
for i in range(8):
    # (r3, ChatGPT: "angular crystalline columns": each arm is now a smooth curve (7 rings of 12 sides, radius easing
    # 0.95 -> 0.45 into a round bulb), and the four outer arms (every other one) lean ~25 deg further out)
    a = TAU * i / 8 + rnd.uniform(-0.18, 0.18)
    outer = (i % 2 == 0)
    r0, h = (2.6 if outer else 3.0) + rnd.uniform(-0.2, 0.15), rnd.uniform(2.6, 3.6) * (0.9 if outer else 1.0)
    lean = rnd.uniform(0.5, 1.0) + (h * 0.47 if outer else 0.0)
    pts, rads = [], []
    for k in range(7):
        u = k / 6
        rr = r0 + lean * u * u                               # (bends outward more toward the top: a splash, not a post)
        pts.append(Vector((math.cos(a) * rr, 0.5 + h * u, math.sin(a) * rr)))
        rads.append(0.95 - 0.5 * u ** 0.8)
    tube(bm, pts, rads, 10, bulb=1.25)
for v in bm.verts: v.co.x *= 8.6 / 11.2; v.co.z *= (7 / 8) * (8.6 / 11.2)   # (r3: back to the 8.6 footprint after the outward lean)
new_obj("titanCrown1", bm)

# ---- K2 crack disc: fracture plates (centre + 6 + 10), 0.12 gaps, 0.10-0.14 thick; glow disc under them
bm = bmesh.new()
def plate(r0, r1, a0, a1, h):
    g = 0.06
    pts = []
    for (r, a) in ((r0, a0), (r0, a1), (r1, a1), (r1, a0)):
        pts.append((r, a))
    ring = []
    for (r, a) in [(r0 + g, a0), (r0 + g, (a0 + a1) / 2), (r0 + g, a1), (r1 - g, a1), (r1 - g, (a0 + a1) / 2), (r1 - g, a0)]:
        aa = a + (g / max(r, 0.5)) * (1 if a == a0 else -1 if a == a1 else 0)
        rr = r * (1 + 0.06 * noise.noise(Vector((math.cos(aa) * 2, math.sin(aa) * 2, 0.3))))
        ring.append((math.cos(aa) * rr, math.sin(aa) * rr))
    top = [bm.verts.new((x, h, z)) for (x, z) in ring]; bot = [bm.verts.new((x, 0, z)) for (x, z) in ring]
    bm.faces.new(top); bm.faces.new(bot[::-1])
    for k in range(len(ring)): bm.faces.new((bot[k], bot[(k + 1) % len(ring)], top[(k + 1) % len(ring)], top[k]))
cr = [bm.verts.new((math.cos(TAU * k / 6) * 1.25, 0.14, math.sin(TAU * k / 6) * 1.25)) for k in range(6)]
cb = [bm.verts.new((v.co.x, 0, v.co.z)) for v in cr]
bm.faces.new(cr); bm.faces.new(cb[::-1])
for k in range(6): bm.faces.new((cb[k], cb[(k + 1) % 6], cr[(k + 1) % 6], cr[k]))
for k in range(6): plate(1.4, 3.1, TAU * k / 6 + 0.25, TAU * (k + 1) / 6 + 0.25, rnd.uniform(0.10, 0.14))
for k in range(10): plate(3.25, 4.95 + rnd.uniform(-0.25, 0.05), TAU * k / 10, TAU * (k + 1) / 10, rnd.uniform(0.08, 0.13))
new_obj("titanCrack1", bm)
bm = bmesh.new(); lathe(bm, [(0, 0.03), (4.85, 0.03), (4.85, 0.0), (0, 0.0)], 24); new_obj("titanCrackGlow1", bm)

# ---- K3 rocks: 4 faceted irregular chunks (~1 stud)
for i in range(4):
    bm = bmesh.new()
    blob(bm, (0, 0, 0), (0.55, 0.42 + 0.08 * i, 0.5), sub=1, amp=0.35, f=1.6, seed=7 * i)
    new_obj("titanRock%d" % (i + 1), bm)

# ---- K4 drops: tear shapes, the THICK end down (they fall), 3 sizes
for i, s in enumerate((0.9, 0.7, 0.5)):
    bm = bmesh.new()
    lathe(bm, [(0, -0.5 * s), (0.32 * s, -0.42 * s), (0.45 * s, -0.18 * s), (0.36 * s, 0.12 * s), (0.18 * s, 0.38 * s), (0, 0.55 * s)], 12)
    new_obj("titanDrop%d" % (i + 1), bm)

# ---- K5 bomb ball: 3 across, big rounded lobes
bm = bmesh.new(); blob(bm, (0, 0, 0), (1.5, 1.5, 1.5), sub=3, amp=0.045, f=1.3, seed=2); new_obj("titanBall1", bm)   # (r2: rounder)

# ---- K6 bomb splat: low wide crown (r 5, 0.6 high) + 7 short arms + 3 broad sideways sheets (flattened tubes)
bm = bmesh.new()
lathe(bm, [(0, 0.05), (2.5, 0.12), (4.2, 0.45), (5.0, 0.62), (4.9, 0.25), (4.4, 0.0)], 28, ring_noise(0.12, 1.2, 9))
for i in range(7):
    a = TAU * i / 7 + rnd.uniform(-0.2, 0.2); r0 = 4.1; h = rnd.uniform(2.2, 4.2)
    pts = [Vector((math.cos(a) * r0, 0.45, math.sin(a) * r0)), Vector((math.cos(a) * (r0 + 0.3), 0.45 + h * 0.5, math.sin(a) * (r0 + 0.3))),
           Vector((math.cos(a) * (r0 + 0.65), 0.45 + h, math.sin(a) * (r0 + 0.65)))]
    tube(bm, pts, [0.90, 0.62, 0.45], 8, bulb=1.2)          # (r2: fat blunt arms, as K6)
for i in range(3):
    a = TAU * i / 3 + 0.5
    pts = [Vector((math.cos(a) * r, 0.25 + 0.9 * math.sin(math.pi * (r - 1.5) / 4.0), math.sin(a) * r)) for r in (1.5, 2.6, 3.7, 4.8)]
    tube(bm, pts, [1.05, 0.95, 0.8, 0.6], 10, flat=0.5, bulb=0.9)   # (r2: sheets ~1 stud thick at the base, as K6)
new_obj("titanSplat1", bm)

# ---- K7 sticky puddle: irregular outline, raised lip, 6 bubble domes
bm = bmesh.new()
lathe(bm, [(0, 0.12), (3.6, 0.14), (4.6, 0.25), (5.0, 0.12), (4.9, 0.0)], 32, ring_noise(0.13, 1.8, 4))
domes(bm, 6, 0.35, 0.75, 4.2, 0.12, 6)
new_obj("titanPuddle1", bm)

# ---- K8 tsunami wave (r2, ChatGPT build audit r1: "reads like a vertical slab"): a C-shaped breaking curl. The crest
# overhangs the front face by ~4.3 studs (tip at z -5.0), the hollow under it is ~4 deep, the lip ~1.3 thick, the base 4.4
# deep (2.0 back to -2.4 front); 6 big foam lobes ride the lip. Swept across 12 with a little crest wobble
# (r3, ChatGPT: still "a vertical wall": the crest now overhangs the front face by ~5.8 (tip z -6.9), the hollow is ~5.5
# deep, and the whole upper third rolls forward (the back rises in a curve into the crest, not straight up))
def wave_sec(x):
    w = 0.25 * noise.noise(Vector((x * 0.35, 0.7, 1.1)))
    h = 10.0 + 0.45 * noise.noise(Vector((x * 0.3, 2.0, 0.4)))
    return [(2.0, 0.0), (1.9, 2.5), (1.4, 5.0), (0.5 + w, 7.3), (-0.9 + w, h - 0.8), (-2.6 + w, h), (-4.4 + w, h - 0.4),
            (-5.9 + w, h - 1.3), (-6.7 + w, h - 2.5), (-6.9 + w, h - 3.4), (-6.3 + w, h - 4.2), (-5.0 + w, h - 4.4),
            (-3.6 + w, h - 4.3), (-2.3 + w, h - 4.6), (-1.4, 4.8), (-1.1, 3.8), (-1.4, 2.6), (-2.0, 1.3), (-2.4, 0.0)]
def end_taper(x, xa, xb):
    # (r3: the ends shrink to ~12 % (a rounded roll-off) instead of 65 %: the flat end caps read as big crystal facets
    # from every 3/4 view)
    e = min(1.0, max(0.0, abs(x) - xa) / (xb - xa))
    return 1 - 0.88 * e ** 1.6
bm = bmesh.new(); sweep(bm, [-6 + 12 * i / 40 for i in range(41)], wave_sec, "x")
for v in bm.verts:                                        # (the ends round off: a wave, not a slab)
    k = end_taper(v.co.x, 3.6, 6.0)                       # (toward a point 2 up, not the ground: a rounded end, not a beak)
    v.co.y = 2.0 + (v.co.y - 2.0) * k; v.co.z = -2.4 + (v.co.z + 2.4) * k
for k in range(6):                                        # (foam lobes on the lip)
    x = -4.6 + 9.2 * k / 5 + random.Random(k).uniform(-0.3, 0.3)
    t = end_taper(x, 3.6, 6.0)
    blob(bm, (x, 2.0 + 7.3 * t, -2.4 + (-5.4 + 2.4) * t), (1.0 * (0.5 + 0.5 * t), 0.85 * (0.5 + 0.5 * t), 0.95 * (0.5 + 0.5 * t)), sub=2, amp=0.15, f=1.5, seed=20 + k)
new_obj("titanWave1", bm)

# ---- K9 splash wall: 14 wide, up to 11 high, 4 deep at the base; blunt spikes + hanging bulbs on the tips
def wall_sec(x, H, T, spikes):
    s = 0.5 + 0.5 * math.cos(x * spikes)
    # (r4, ChatGPT build audit r3: "two adjacent objects", not one collapse: the base is now 6.5 deep (was 4) with one broad
    # lower sheet ~4.7 thick at 0.35 h, and the spikes lean BACK over the incoming wave (+z), the big ones ~2.2 at the top)
    h = H * (0.62 + 0.38 * s) * (1 - 0.25 * (abs(x) / 7) ** 2)
    t = T * (0.6 + 0.4 * s)
    D = 6.5
    L = 2.2 * (0.55 + 0.45 * s)
    def ln(y): return L * (y / h) ** 1.6
    return [(D / 2, 0.0), (D * 0.36 + ln(h * 0.35), h * 0.35), (t * 0.22 + ln(h * 0.7), h * 0.7), (ln(h), h),
            (-t * 0.25 + ln(h * 0.85), h * 0.85), (-D * 0.33 + ln(h * 0.5), h * 0.5), (-D * 0.45 + ln(h * 0.2), h * 0.2), (-D / 2, 0.0)]
bm = bmesh.new(); sweep(bm, [-7 + 14 * i / 41 for i in range(42)], lambda x: wall_sec(x, 11, 4, 2.3), "x")
for v in bm.verts:                                        # (r3: same rounded roll-off at the ends as the wave)
    k = end_taper(v.co.x, 5.0, 7.0)
    v.co.y *= k; v.co.z *= k
for k in range(6):
    # (r3: a bulb ON each spike tip (peaks of cos(2.3 x)); they were at the outline height and floated between spikes)
    rnd.uniform(-0.3, 0.3)                                # (keeps the shared random stream as before for later meshes)
    if k == 5: continue
    x = (k - 2) * TAU / 2.3
    top = wall_sec(x, 11, 4, 2.3)[3]; e = end_taper(x, 5.0, 7.0)
    blob(bm, (x, top[1] * e - 0.2, top[0] * e), (0.55, 0.7, 0.55), sub=2)
new_obj("titanSplashWall1", bm)

# ---- K10 flood lane: 12 x 30, raised edges, shallow bumps, wavy outline
def flood_sec(z):
    hw = 6.0 * (1 + 0.06 * noise.noise(Vector((0.3, z * 0.25, 0.8))))
    pts = []
    for i in range(13):
        u = -hw + 2 * hw * i / 12
        edge = max(0.0, abs(u) / hw - 0.75) / 0.25
        pts.append((u, 0.12 + 0.06 * noise.noise(Vector((u * 0.5, z * 0.5, 3.0))) + 0.08 * math.sin(math.pi * min(1, edge)) ))
    return [(hw, 0.0)] + pts[::-1] + [(-hw, 0.0)]
bm = bmesh.new(); sweep(bm, [-30 + 30 * i / 30 for i in range(31)], flood_sec, "z")
new_obj("titanFlood1", bm)

# ---- K11 melt puddle: 13 x 12, 4 big bubble domes
bm = bmesh.new()
lathe(bm, [(0, 0.10), (4.8, 0.12), (6.1, 0.22), (6.5, 0.08), (6.4, 0.0)], 32, ring_noise(0.12, 1.5, 12))
for v in bm.verts: v.co.z *= 12 / 13
domes(bm, 4, 0.6, 1.1, 5.0, 0.10, 13)
new_obj("titanMelt1", bm)

# ---- K12 matter mote
bm = bmesh.new(); blob(bm, (0, 0, 0), (0.31, 0.31, 0.31), sub=2, amp=0.08, f=2.0, seed=4); new_obj("titanMote1", bm)

# ---- functional: shock segment (1 long in x, 1 thick in z, 1 high), a lumpy mound with rounded ends
def shock_sec(x):
    # (r4, ChatGPT build audit r3: the rim read as a chain of beads: the ends are now FLAT and flush (the profile no
    # longer pinches to 0 at x = +-0.5); the end caps get their own verts so smooth normals do not darken the seam)
    return [(0.5, 0.0), (0.38, 0.45), (0.1, 0.95), (-0.2, 0.8), (-0.45, 0.3), (-0.5, 0.0)]
bm = bmesh.new(); sweep(bm, [-0.5 + i / 10 for i in range(11)], shock_sec, "x", cap=False)
for x0, flip in ((-0.5, True), (0.5, False)):
    cap = [bm.verts.new((x0, y, u)) for (u, y) in shock_sec(x0)]
    bm.faces.new(cap[::-1] if flip else cap)
for v in bm.verts:                                        # (a ring SLICE, not a box: the outer side (-z, the rim's outward
    v.co.x *= 1 - 0.2 * v.co.z                            # direction) 10 % longer, the inner 10 % shorter (thickness / radius
                                                          # ~0.2 at the peak): neighbours meet flush, no end cap pokes out)
new_obj("titanShockSeg1", bm)

# ---- functional: whip ribbon, a 100-degree crescent, radius 3, 0.55 wide, tapered ends
bm = bmesh.new()
pts = [Vector((math.cos(a) * 3, math.sin(a) * 3, 0)) for a in [math.radians(-50 + 100 * i / 10) for i in range(11)]]
tube(bm, pts, [0.06 + 0.22 * math.sin(math.pi * i / 10) for i in range(11)], 6, flat=0.25, bulb=0)
new_obj("titanWhip1", bm)

# ---- functional: foam crest, 12 x 1.6 x 2, a row of rounded lobes
bm = bmesh.new()
for k in range(9):
    x = -5.4 + 10.8 * k / 8
    blob(bm, (x, 0.8, rnd.uniform(-0.2, 0.2)), (0.85, 0.8, 1.0), sub=2, amp=0.15, f=1.5, seed=k)
new_obj("titanFoam1", bm)

# ---- functional: gather wall, 12 x 5.5 x 4, rounded lumpy top
bm = bmesh.new()
sweep(bm, [-6 + 12 * i / 24 for i in range(25)], lambda x: [(z * (1 - 0.3 * (abs(x) / 6) ** 2), y * (1 + 0.12 * noise.noise(Vector((x * 0.6, y, 2.2)))) * (1 - 0.3 * (abs(x) / 6) ** 2))
      for (z, y) in [(2.0, 0.0), (1.7, 2.4), (0.9, 4.6), (0.0, 5.5), (-0.9, 4.8), (-1.7, 2.6), (-2.0, 0.0)]], "x")
new_obj("titanGather1", bm)

# ---- J4 defeat shells from the Titan's OWN mesh (its UVs kept: it wears its own SurfaceAppearance)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
src = next(o for o in bpy.data.objects if o.type == "MESH" and o.parent == arm)
TO_RBX = Matrix(((-1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
def shell(name, deform, smooth_iters):
    bm = bmesh.new(); bm.from_mesh(src.data); bm.transform(TO_RBX @ src.matrix_world)
    H = max(v.co.y for v in bm.verts)
    for v in bm.verts: v.co = deform(v.co, H)
    for _ in range(smooth_iters): bmesh.ops.smooth_vert(bm, verts=bm.verts[:], factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    ob = new_obj(name, bm, uv=False)
    # (14k tris each is the whole FX budget: decimated to ~3k; the silhouette is what reads at phone size)
    dec = ob.modifiers.new("dec", "DECIMATE"); dec.ratio = 0.4   # (r2: 0.22 read as crumpled, faceted pieces)
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    ob.modifiers.clear(); ob.data = me
    return ob
def collapse(p, H):                                       # (dome caves: the top sinks most, the base spreads a little; horns droop)
    s = max(0.0, p.y / H)
    y = H * (0.62 * s - 0.10 * s * s)
    k = 1 + 0.08 * (1 - s) ** 2
    return Vector((p.x * k, y, p.z * k))
def melt(p, H):
    s = max(0.0, p.y / H)
    return Vector((p.x * (1.0 + 0.06 * (1 - s)), H * 0.34 * s ** 1.3, p.z * (1.0 + 0.06 * (1 - s))))
shell("titanCollapse1", collapse, 1)   # (r2: one smoothing pass, a continuous sagging mass)
shell("titanMeltHeap1", melt, 2)

# ---- export (already Roblox space)
path = os.path.join(out_dir, "titan-k.obj")
with open(path, "w") as fo:
    vo, to, no = 1, 1, 1
    for ob in objs:
        me = ob.data; me.calc_loop_triangles()
        uv = me.uv_layers.active.data if me.uv_layers.active else None
        fo.write(f"o {ob.name}\ng {ob.name}\nusemtl {ob.name}\n")
        for v in me.vertices: fo.write("v %.5f %.5f %.5f\n" % tuple(v.co))
        # (r3: smooth per-vertex normals; without vn Roblox shaded every face flat and the goo read as cut crystal)
        # (rock chips stay faceted: 20-tri rocks smoothed read as blobs)
        smooth = not ob.name.startswith("titanRock")
        if smooth:
            for v in me.vertices: fo.write("vn %.4f %.4f %.4f\n" % tuple(v.normal))
        nuv = 0
        if uv:
            for l in me.loops: fo.write("vt %.5f %.5f\n" % (uv[l.index].uv.x, uv[l.index].uv.y)); nuv += 1
        for t in me.loop_triangles:
            vt = [f"/{t.loops[i] + to}" if uv else "/" for i in range(3)]
            vn = [f"/{t.vertices[i] + no}" if smooth else "" for i in range(3)]
            fo.write("f " + " ".join(f"{t.vertices[i] + vo}{vt[i] if (uv or smooth) else ''}{vn[i]}" for i in range(3)) + "\n")
        vo += len(me.vertices); to += nuv
        if smooth: no += len(me.vertices)
        xs = [v.co.x for v in me.vertices]; ys = [v.co.y for v in me.vertices]; zs = [v.co.z for v in me.vertices]
        print("CENTRE", ob.name, round((min(xs) + max(xs)) / 2, 3), round((min(ys) + max(ys)) / 2, 3), round((min(zs) + max(zs)) / 2, 3),
              "SIZE", round(max(xs) - min(xs), 3), round(max(ys) - min(ys), 3), round(max(zs) - min(zs), 3), "tris", len(me.loop_triangles))
print("WROTE", path)
