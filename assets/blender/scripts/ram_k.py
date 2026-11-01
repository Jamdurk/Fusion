# Alien Fusion: the RAM's K-sheet effect meshes (batch 7 r2, 29 Oct 2026; ChatGPT r1 audit: the shared star / strips /
# ring substitutes were rejected, "the large authored silhouettes are mandatory"). Built procedurally to the spec sizes
# (design/19-RAM-BATCH7-SPEC 7), in ROBLOX MODEL SPACE (x right, y up, -z forward), one OBJ:
#   ramGoreBlades1   K1: 7 tapered asymmetric crystal blades fanned from one oblique contact centre (amber, Neon)
#   ramGoreSplint1   K1: 5 shorter grey rock splinters from the same centre        (both: bounds ~3.2 x 2.2 x 1.3, +z = normal)
#   ramCrackDisc1    K2: broken two-hoof centre + 9 branching veins + 5 outer splits, 10 x 0.07 x 10 (orange Neon)
#   ramDustBank1     K2: low uneven annular dust wall, 8 rising lips, open centre, 10 x 0.8 x 10 (grey)
#   ramStunSwirl1    K3: a crooked 1.3-turn oval swirl + 4 five-pointed stars, 1.65 x 0.32 x 1.65 (amber)
#   ramChargeDust1   K4: a torn trail of 5 connected swept-up dust fins, 4.8 x 1.25 x 7.0 (grey; +z = behind)
#   ramStreaksO1 / ramStreaksG1  K4: 5 tapered arcs (3 orange, 2 grey), 4.5 x 1.0 x 5.8 (+z = behind)
#   ramRubblePile1   K5: 14 boulders cut from the Ram's own mesh (its skin), settled into a long low pile 8.8 x 1.5 x 6.3
#   ramRubbleMid1    J4: 9 bigger masses from its mesh, 7.5 x 2.8 x 5.5 (the transition)
#   blender --background --factory-startup aliens/crunch_f3_v5.blend --python ram_k.py -- <out_dir>
import bpy, bmesh, sys, os, math, random
from mathutils import Vector, Matrix

out_dir = sys.argv[sys.argv.index("--") + 1]
random.seed(7)
objs = []

def new_obj(name, bm):
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(ob)
    objs.append(ob); return ob

def blade(bm, base, tip, w, t, twist=0.0):
    """a tapered 4-sided crystal blade from base to tip, w wide, t thick at the base"""
    d = (tip - base).normalized()
    side = d.cross(Vector((0, 1, 0)))
    if side.length < 1e-3: side = d.cross(Vector((1, 0, 0)))
    side.normalize()
    up = side.cross(d).normalized()
    side = (side * math.cos(twist) + up * math.sin(twist)).normalized(); up = side.cross(d).normalized()
    mid = base + (tip - base) * 0.3
    ring0 = [base + side * w * 0.3, base + up * t * 0.5, base - side * w * 0.3, base - up * t * 0.5]
    ring1 = [mid + side * w * 0.5, mid + up * t * 0.5, mid - side * w * 0.5, mid - up * t * 0.5]
    v0 = [bm.verts.new(p) for p in ring0]; v1 = [bm.verts.new(p) for p in ring1]; vt = bm.verts.new(tip)
    bm.faces.new(v0[::-1])
    for i in range(4):
        bm.faces.new((v0[i], v0[(i + 1) % 4], v1[(i + 1) % 4], v1[i]))
        bm.faces.new((v1[i], v1[(i + 1) % 4], vt))

# ---- K1 gore burst: normal = +z (out of the surface). Blades fan in a cone, asymmetric (longer to one side)
bm = bmesh.new(); bs = bmesh.new()
C = Vector((0, 0, 0))
for i in range(7):
    a = -1.25 + 2.5 * i / 6 + random.uniform(-0.12, 0.12)
    L = random.uniform(1.0, 1.65) * (1.15 if a > 0 else 0.9)
    tip = Vector((math.sin(a) * 1.55 * L / 1.6, random.uniform(-0.6, 1.0), 0.35 + math.cos(a) * 0.95 * L / 1.6))
    blade(bm, C + Vector((random.uniform(-0.1, 0.1), random.uniform(-0.1, 0.1), 0)), tip, random.uniform(0.18, 0.26), random.uniform(0.05, 0.16), random.uniform(-0.6, 0.6))
for i in range(5):
    a = random.uniform(-1.4, 1.4)
    tip = Vector((math.sin(a) * 0.9, random.uniform(-0.55, 0.6), 0.2 + math.cos(a) * 0.55))
    blade(bs, C, tip, random.uniform(0.22, 0.32), random.uniform(0.12, 0.2), random.uniform(-1, 1))
new_obj("ramGoreBlades1", bm); new_obj("ramGoreSplint1", bs)

# ---- K2 crack disc (flat, y = 0..0.07): a broken centre (two hoof marks) + 9 branching veins + 5 outer splits
bm = bmesh.new()
def strip(p0, p1, w0, w1):
    d = (p1 - p0); d.y = 0
    if d.length < 1e-4: return
    n = Vector((-d.z, 0, d.x)).normalized()
    vs = [bm.verts.new(p0 + n * w0 / 2), bm.verts.new(p1 + n * w1 / 2), bm.verts.new(p1 - n * w1 / 2), bm.verts.new(p0 - n * w0 / 2)]
    top = [bm.verts.new(v.co + Vector((0, 0.07, 0))) for v in vs]
    bm.faces.new(top); bm.faces.new(vs[::-1])
    for i in range(4): bm.faces.new((vs[i], vs[(i + 1) % 4], top[(i + 1) % 4], top[i]))
for hx in (-0.9, 0.9):                                    # the two hoof craters: short broken spokes
    for k in range(6):
        a = k / 6 * 2 * math.pi + random.uniform(-0.2, 0.2)
        c = Vector((hx, 0, 0))
        strip(c + Vector((math.cos(a), 0, math.sin(a))) * 0.25, c + Vector((math.cos(a), 0, math.sin(a))) * random.uniform(0.6, 0.9), 0.22, 0.10)
for i in range(9):
    a = i / 9 * 2 * math.pi + random.uniform(-0.18, 0.18)
    p = Vector((math.cos(a), 0, math.sin(a))) * 0.9
    r = 0.9; w = 0.30
    while r < 4.9:
        step = random.uniform(0.6, 1.0)
        a += random.uniform(-0.35, 0.35)
        q = p + Vector((math.cos(a), 0, math.sin(a))) * step
        r = Vector((q.x, 0, q.z)).length
        strip(p, q, w, w * 0.8); w *= 0.8
        if random.random() < 0.45 and r < 4.2:               # a branch
            b = a + random.choice((-1, 1)) * random.uniform(0.5, 0.9)
            strip(q, q + Vector((math.cos(b), 0, math.sin(b))) * random.uniform(0.6, 1.1), w * 0.8, 0.04)
        p = q
for i in range(5):                                         # outer splits
    a = random.uniform(0, 2 * math.pi)
    p = Vector((math.cos(a), 0, math.sin(a))) * random.uniform(4.0, 4.6)
    strip(p, p + Vector((math.cos(a + 0.4), 0, math.sin(a + 0.4))) * 0.7, 0.12, 0.04)
new_obj("ramCrackDisc1", bm)

# ---- K2 dust bank: an annular wall r 4.3..5.0, height 0.35..0.8 with 8 lips, thicker on one side
bm = bmesh.new(); N = 64; rows = []
for i in range(N):
    a = i / N * 2 * math.pi
    lip = max(0.0, math.cos(a * 8 + 0.4)) ** 3
    h = 0.35 + 0.45 * lip * (1.0 if math.cos(a) > -0.3 else 0.7)
    r0, r1 = 4.25 + 0.1 * math.sin(a * 5), 5.0
    d = Vector((math.cos(a), 0, math.sin(a)))
    rows.append([bm.verts.new(d * r0), bm.verts.new(d * r1), bm.verts.new(d * (r1 - 0.15) + Vector((0, h, 0))), bm.verts.new(d * (r0 + 0.25) + Vector((0, h * 0.8, 0)))])
for i in range(N):
    a, b = rows[i], rows[(i + 1) % N]
    for j in range(4): bm.faces.new((a[j], b[j], b[(j + 1) % 4], a[(j + 1) % 4]))
new_obj("ramDustBank1", bm)

# ---- K3 stun swirl: a crooked 1.3-turn oval (a thin square tube) + 4 five-pointed stars on it
bm = bmesh.new(); M = 60; prev = None
def ring_at(p, d, s):
    side = d.cross(Vector((0, 1, 0))).normalized(); up = Vector((0, 1, 0))
    return [bm.verts.new(p + side * s), bm.verts.new(p + up * s), bm.verts.new(p - side * s), bm.verts.new(p - up * s)]
pts = []
for i in range(M + 1):
    u = i / M; a = u * 1.3 * 2 * math.pi
    r = 0.62 + 0.12 * math.sin(a * 1.5)
    pts.append(Vector((math.cos(a) * r, 0.03 * math.sin(a * 3) + u * 0.12, math.sin(a) * r * 0.82)))
for i in range(M):
    d = (pts[i + 1] - pts[i]).normalized()
    cur = ring_at(pts[i], d, 0.045)
    if prev:
        for j in range(4): bm.faces.new((prev[j], prev[(j + 1) % 4], cur[(j + 1) % 4], cur[j]))
    prev = cur
for k in range(4):
    c = pts[int((k + 0.5) / 4 * M)] + Vector((0, 0.06, 0))
    outer = []; ctr_t = bm.verts.new(c + Vector((0, 0.05, 0))); ctr_b = bm.verts.new(c - Vector((0, 0.05, 0)))
    for j in range(10):
        a = j / 10 * 2 * math.pi; r = 0.17 if j % 2 == 0 else 0.07
        outer.append(bm.verts.new(c + Vector((math.cos(a) * r, 0, math.sin(a) * r))))
    for j in range(10):
        bm.faces.new((ctr_t, outer[j], outer[(j + 1) % 10])); bm.faces.new((ctr_b, outer[(j + 1) % 10], outer[j]))
new_obj("ramStunSwirl1", bm)

# ---- K4 charge dust ribbon: +z = behind; a torn trail 4.8 wide, 7 long, 5 fins rising toward the back (up to 1.25)
bm = bmesh.new(); grid = []; NX, NZ = 9, 14
for iz in range(NZ):
    z = iz / (NZ - 1) * 7.0
    row = []
    for ix in range(NX):
        x = (ix / (NX - 1) - 0.5) * 4.8 * (0.35 + 0.65 * min(1, z / 3.5)) * (1 - 0.25 * max(0, (z - 5.5) / 1.5))
        fin = max(0.0, math.cos((ix / (NX - 1) - 0.5) * 5 * math.pi)) ** 2
        y = (0.15 + 1.1 * fin * min(1, z / 4.5)) * (1 - max(0, (z - 6.0) / 1.0)) + 0.05 * random.random()
        row.append(bm.verts.new(Vector((x, y, z))))
    grid.append(row)
for iz in range(NZ - 1):
    for ix in range(NX - 1):
        if random.random() < 0.06 and iz > 6: continue          # torn holes toward the tail
        bm.faces.new((grid[iz][ix], grid[iz][ix + 1], grid[iz + 1][ix + 1], grid[iz + 1][ix]))
        pass                                                      # (one-sided: Roblox shows it from above; DoubleSided set in Studio)
new_obj("ramChargeDust1", bm)

# ---- K4 speed streaks: 5 tapered arcs trailing back, 3 orange (O) + 2 grey (G)
for nm, idxs in (("ramStreaksO1", (0, 2, 4)), ("ramStreaksG1", (1, 3))):
    bm = bmesh.new()
    for k in idxs:
        x0 = (k / 4 - 0.5) * 4.5; y0 = 0.2 + 0.8 * ((k * 37) % 5) / 4
        prev = None; S = 12
        for i in range(S + 1):
            u = i / S
            p = Vector((x0 * (1 - 0.15 * u), y0 + 0.15 * math.sin(u * math.pi), u * 5.8))
            w = 0.10 * (1 - u) + 0.04 * u
            cur = [bm.verts.new(p + Vector((w, 0, 0))), bm.verts.new(p + Vector((0, w * 0.6, 0))), bm.verts.new(p - Vector((w, 0, 0))), bm.verts.new(p - Vector((0, w * 0.6, 0)))]
            if prev:
                for j in range(4): bm.faces.new((prev[j], prev[(j + 1) % 4], cur[(j + 1) % 4], cur[j]))
            prev = cur
    new_obj(nm, bm)

# ---- K5 rubble: boulders cut from the Ram's own mesh (its skin), clustered, shrunk to blocks, settled into a pile
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
src = next(o for o in bpy.data.objects if o.type == "MESH" and o.parent == arm)
TO_RBX = Matrix(((-1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
def rubble(name, k, footprint, height, shrink):
    bm = bmesh.new(); bm.from_mesh(src.data); bm.transform(TO_RBX @ src.matrix_world)
    bm.faces.ensure_lookup_table()
    cents = [f.calc_center_median() for f in bm.faces]
    seeds = random.sample(cents, k)
    for _ in range(6):                                     # k-means on the face centres
        groups = [[] for _ in range(k)]
        for i, c in enumerate(cents):
            j = min(range(k), key=lambda s: (c - seeds[s]).length_squared); groups[j].append(i)
        seeds = [sum((cents[i] for i in g), Vector()) / len(g) if g else seeds[s] for s, g in enumerate(groups)]
    out = bmesh.new()
    uvl = bm.loops.layers.uv.active; ouv = out.loops.layers.uv.new("UVMap")
    for s, g in enumerate(groups):
        if not g: continue
        c = seeds[s]
        # place: spread over the footprint, low
        px = random.uniform(-footprint[0] / 2 + 0.8, footprint[0] / 2 - 0.8); pz = random.uniform(-footprint[1] / 2 + 0.8, footprint[1] / 2 - 0.8)
        rot = Matrix.Rotation(random.uniform(0, 6.28), 3, "Y") @ Matrix.Rotation(random.uniform(-0.6, 0.6), 3, "X")
        vmap = {}
        pts = []
        for i in g:
            f = bm.faces[i]
            vs = []
            for l in f.loops:
                v = l.vert
                if v.index not in vmap:
                    p = rot @ ((v.co - c) * shrink)
                    vmap[v.index] = out.verts.new(p); pts.append(vmap[v.index])
                vs.append(vmap[v.index])
            try:
                nf = out.faces.new(vs)
                for l, ol in zip(f.loops, nf.loops): ol[ouv].uv = l[uvl].uv
            except ValueError: pass
        if not pts: continue
        miny = min(p.co.y for p in pts); maxy = max(p.co.y for p in pts)
        sy = min(1.0, height / max(0.01, maxy - miny))
        for p in pts: p.co = Vector((p.co.x + px, (p.co.y - miny) * sy, p.co.z + pz))
    bm.free()
    return new_obj(name, out)
rubble("ramRubblePile1", 14, (6.3, 8.8), 1.5, 0.55)
rubble("ramRubbleMid1", 9, (5.5, 7.5), 2.8, 0.75)

# ---- export (already Roblox space)
path = os.path.join(out_dir, "ram-k.obj")
with open(path, "w") as fo:
    vo, to = 1, 1
    for ob in objs:
        me = ob.data; me.calc_loop_triangles()
        uv = me.uv_layers.active.data if me.uv_layers.active else None
        fo.write(f"o {ob.name}\ng {ob.name}\nusemtl {ob.name}\n")
        for v in me.vertices: fo.write("v %.5f %.5f %.5f\n" % tuple(v.co))
        nuv = 0
        if uv:
            for l in me.loops: fo.write("vt %.5f %.5f\n" % (uv[l.index].uv.x, uv[l.index].uv.y)); nuv += 1
        for t in me.loop_triangles:
            if uv: fo.write("f " + " ".join(f"{t.vertices[i] + vo}/{t.loops[i] + to}" for i in range(3)) + "\n")
            else: fo.write("f %d %d %d\n" % tuple(t.vertices[i] + vo for i in range(3)))
        vo += len(me.vertices); to += nuv
        xs = [v.co.x for v in me.vertices]; ys = [v.co.y for v in me.vertices]; zs = [v.co.z for v in me.vertices]
        print("CENTRE", ob.name, round((min(xs) + max(xs)) / 2, 3), round((min(ys) + max(ys)) / 2, 3), round((min(zs) + max(zs)) / 2, 3),
              "SIZE", round(max(xs) - min(xs), 3), round(max(ys) - min(ys), 3), round(max(zs) - min(zs), 3), "tris", len(me.loop_triangles))
print("WROTE", path)
