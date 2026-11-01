# Alien Fusion hub: the CRATER LANDMARK (30 Oct 2026). Built to match the ChatGPT reference pack:
#   design\concepts\hub\B-crater-landmark-chatgpt.png (look), B2-crater-modelling-sheet-chatgpt.png (pieces),
#   A-master-map-chatgpt.png (placement). Spec: design\map-review\reference-pack-audit-r1.txt section 4, scaled x1.3
#   because the terrain crater that already exists is ~130 across (rim ~65-70 from the centre), not 85.
# Authored in ROBLOX space (x right, y up, z), 1 unit = 1 stud, origin = the crater floor centre.
# Every piece is its own object: Roblox gives each its material (dark metal / Neon) and the client animates the ring,
# halo, orb and rocks (anchored, no physics).
#   blender --background --factory-startup --python hub_crater.py -- <out_dir>
import bpy, bmesh, math, os, random, sys
from mathutils import Vector, Matrix, noise

out_dir = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "."
for o in list(bpy.data.objects): bpy.data.objects.remove(o, do_unlink=True)
objs = []          # (object, smooth normals?)
TAU = 2 * math.pi
rnd = random.Random(7)

def new_obj(name, bm, smooth=False):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(ob)
    objs.append((ob, smooth)); return ob

def quad_grid(bm, P, nu, nv, closed_v=False):
    """P(i, j) -> Vector for i in 0..nu, j in 0..nv; returns the vert grid (faces made)"""
    g = [[bm.verts.new(P(i, j)) for j in range(nv + 1)] for i in range(nu + 1)]
    for i in range(nu):
        for j in range(nv):
            bm.faces.new((g[i][j], g[i + 1][j], g[i + 1][j + 1], g[i][j + 1]))
    return g

def solid_patch(bm, outer, inner, nu, nv):
    """a thick curved plate: outer(i,j) and inner(i,j) surfaces joined at their 4 edges"""
    a = quad_grid(bm, outer, nu, nv)
    b = quad_grid(bm, inner, nu, nv)
    for f in bm.faces[-nu * nv:]: f.normal_flip()
    for i in range(nu):
        for j in (0, nv):
            bm.faces.new((a[i][j], b[i][j], b[i + 1][j], a[i + 1][j]))
    for j in range(nv):
        for i in (0, nu):
            bm.faces.new((a[i][j], a[i][j + 1], b[i][j + 1], b[i][j]))

def icosphere(bm, c, r, sub=2, amp=0.0, seed=0.0, squash=(1, 1, 1)):
    vs = bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=1.0, matrix=Matrix.Identity(4), calc_uvs=False)["verts"]
    for v in vs:
        d = v.co.copy(); k = 1 + amp * noise.noise(d * 1.7 + Vector((seed, 2 * seed, -seed)))
        v.co = Vector((c[0] + d.x * r * squash[0] * k, c[1] + d.y * r * squash[1] * k, c[2] + d.z * r * squash[2] * k))
    return vs

def transform(verts, M):
    for v in verts: v.co = M @ v.co

# ---------------- the crashed SHELL: an ellipsoid split into 6 orange-peel plates around its long (x) axis, the +z
# side peeled open so the violet core shows (B2 front + side views). 55 long x 34 wide x 32 visible high.
RX, RY, RZ, CY = 27.5, 20.0, 17.0, 12.0          # radii + centre height above the crater floor (bottom buried)
T = 3.0                                          # plate thickness
# (r2, after the first preview read as a closed rugby ball: B2 shows the plates STANDING UP round the core like the
# petals of a cracked shell, fanned open and twisted like a pinwheel (top view), the front open the most)
RY = 24.0                                        # (taller petals than the old ellipsoid)
FRONT = math.radians(90)                         # the most open side faces +z
seams = bmesh.new()
def petal_pt(th, la, s, twist):
    th = th + twist * (la + 0.45)                # pinwheel: the petal swirls as it rises
    return Vector((RX * math.cos(la) * math.cos(th) * s, CY + RY * math.sin(la) * s, RZ * math.cos(la) * math.sin(th) * s))
for k in range(6):
    t0, t1 = math.radians(60 * k + 5), math.radians(60 * (k + 1) - 5)
    tm = (t0 + t1) / 2
    L0, L1 = math.radians(-28), math.radians(rnd.uniform(58, 74))      # buried base .. ragged open top
    sI = (min(RX, RZ) - T) / min(RX, RZ)
    def surf(i, j, s, t0=t0, t1=t1, L0=L0, L1=L1):
        return petal_pt(t0 + (t1 - t0) * j / 5, L0 + (L1 - L0) * i / 12, s, 0.32)
    bm = bmesh.new()
    solid_patch(bm, lambda i, j: surf(i, j, 1.0), lambda i, j: surf(i, j, sI), 12, 5)
    # open the petal outward about a hinge at its buried base (front petals open most), plus a small break tilt
    face = max(0.0, math.cos(tm - FRONT))
    ang = math.radians(10 + 34 * face ** 2 + rnd.uniform(-3, 3))
    base = petal_pt(tm, L0, 1.0, 0.32)
    hinge = Vector((-math.sin(tm), 0, math.cos(tm)))                 # tangent round the shell = the hinge line
    M = Matrix.Translation(base) @ Matrix.Rotation(-ang, 4, hinge) @ Matrix.Translation(-base)
    transform(bm.verts, M)
    new_obj("crShellPlate%d" % (k + 1), bm)
    # glowing seams: one up the petal's middle, two across it (B2: cyan lines on every plate)
    def strip(a0, a1, b0, b1, n, along_lat):
        def P(i, j, s):
            if along_lat:
                return M @ petal_pt(a0 + (a1 - a0) * j, b0 + (b1 - b0) * i / n, s, 0.32)
            return M @ petal_pt(a0 + (a1 - a0) * i / n, b0 + (b1 - b0) * j, s, 0.32)
        solid_patch(seams, lambda i, j: P(i, j, 1 + 0.35 / min(RX, RZ)), lambda i, j: P(i, j, 1 - 0.05 / min(RX, RZ)), n, 1)
    strip(tm - 0.022, tm + 0.022, L0 + 0.25, L1 - 0.12, 10, True)
    for la in (math.radians(8), math.radians(36)):
        strip(t0 + 0.06, t1 - 0.06, la - 0.02, la + 0.02, 6, False)
new_obj("crShellSeams", seams)

# the exposed CORE: a violet sphere inside the split + a triangle lattice cage just outside it
bm = bmesh.new(); icosphere(bm, (0, 11.0, 2.0), 8.0, sub=3); new_obj("crCore", bm, smooth=True)
bm = bmesh.new(); icosphere(bm, (0, 11.0, 2.0), 8.4, sub=2)
bmesh.ops.wireframe(bm, faces=bm.faces[:], thickness=0.35, offset=0.0, use_replace=True, use_even_offset=True)
new_obj("crCoreLattice", bm)

# rubble round the shell base (one merged mesh): chunky faceted rocks half sunk in the floor
bm = bmesh.new()
for i in range(26):
    a = rnd.uniform(0, TAU); r = rnd.uniform(0.85, 1.25)
    x, z = math.cos(a) * RX * r, math.sin(a) * RZ * r * 1.15
    s = rnd.uniform(1.2, 3.2)
    icosphere(bm, (x, s * 0.25, z), s, sub=1, amp=0.35, seed=i, squash=(1.0, 0.75, 0.9))
new_obj("crRubble", bm)

# ---------------- the broken RING: 4 thick blocky arc segments (radius 24, 4.5 wide, 3.2 tall) with gaps, each a little
# offset / tilted (broken), held above the shell. Authored around its own centre (0, 0, 0): Roblox places it at +46.
RR, RW, RH = 24.0, 4.5, 3.2
strips = bmesh.new()
for s in range(4):
    a0 = math.radians(90 * s + 9); a1 = math.radians(90 * s + 81)
    def P(i, j, a0=a0, a1=a1):
        a = a0 + (a1 - a0) * i / 12
        corners = [(RR - RW / 2, -RH / 2), (RR + RW / 2, -RH / 2), (RR + RW / 2, RH / 2), (RR - RW / 2, RH / 2)]
        r, y = corners[j % 4]
        return Vector((math.cos(a) * r, y, math.sin(a) * r))
    bm = bmesh.new()
    rings = [[bm.verts.new(P(i, j)) for j in range(4)] for i in range(13)]
    for i in range(12):
        for j in range(4):
            bm.faces.new((rings[i][j], rings[i + 1][j], rings[i + 1][(j + 1) % 4], rings[i][(j + 1) % 4]))
    bm.faces.new(rings[0][::-1]); bm.faces.new(rings[12])
    bmesh.ops.bevel(bm, geom=bm.edges[:], offset=0.35, segments=1, affect="EDGES")
    M = Matrix.Translation((0, rnd.uniform(-1.2, 1.2), 0)) @ Matrix.Rotation(math.radians(rnd.uniform(-5, 5)), 4,
        Vector((math.cos((a0 + a1) / 2), 0, math.sin((a0 + a1) / 2))).cross(Vector((0, 1, 0))))
    transform(bm.verts, M)
    new_obj("crRing%d" % (s + 1), bm)
    # two light strips on the OUTER face of this segment (B2: cyan strips), seen from far away
    for c in (0.3, 0.72):
        ac0, ac1 = a0 + (a1 - a0) * (c - 0.12), a0 + (a1 - a0) * (c + 0.12)
        def Q(i, j, lift, ac0=ac0, ac1=ac1):
            a = ac0 + (ac1 - ac0) * i / 4
            y = -0.55 + 1.1 * j
            r = RR + RW / 2 + lift
            return M @ Vector((math.cos(a) * r, y, math.sin(a) * r))
        solid_patch(strips, lambda i, j: Q(i, j, 0.3), lambda i, j: Q(i, j, -0.05), 4, 1)
new_obj("crRingStrips", strips)

# the cyan ORB in the ring's centre + its hex-ish lattice
bm = bmesh.new(); icosphere(bm, (0, 0, 0), 6.0, sub=3); new_obj("crOrb", bm, smooth=True)
bm = bmesh.new(); icosphere(bm, (0, 0, 0), 6.35, sub=2)
bmesh.ops.wireframe(bm, faces=bm.faces[:], thickness=0.3, offset=0.0, use_replace=True, use_even_offset=True)
new_obj("crOrbLattice", bm)

# the thin turning HALO (radius 29)
bm = bmesh.new()
for i in range(48):
    pass
ring = []
for i in range(64):
    a = TAU * i / 64
    ring.append([bm.verts.new(Vector((math.cos(a) * (29 + 0.35 * math.cos(b)), 0.35 * math.sin(b), math.sin(a) * (29 + 0.35 * math.cos(b)))))
                 for b in (TAU * k / 6 for k in range(6))])
for i in range(64):
    for k in range(6):
        bm.faces.new((ring[i][k], ring[(i + 1) % 64][k], ring[(i + 1) % 64][(k + 1) % 6], ring[i][(k + 1) % 6]))
new_obj("crHalo", bm, smooth=True)

# 3 floating ROCKS (chunky, faceted; one glowing crack each comes from a neon sliver)
for i in range(3):
    bm = bmesh.new(); icosphere(bm, (0, 0, 0), [1.6, 1.2, 0.9][i] * 1.3, sub=1, amp=0.4, seed=11 + i, squash=(1.0, 1.25, 0.9))
    new_obj("crRock%d" % (i + 1), bm)

# one DNA CRYSTAL cluster mesh (coloured cyan or amber per copy in Roblox): 6 hexagonal prisms with pointed tips
bm = bmesh.new()
for i in range(6):
    h = [5.2, 3.8, 3.2, 2.6, 2.2, 1.6][i]; w = [0.9, 0.75, 0.7, 0.6, 0.55, 0.45][i]
    a = TAU * i / 6 + rnd.uniform(-0.3, 0.3); d = 0 if i == 0 else rnd.uniform(0.9, 1.6)
    base = Vector((math.cos(a) * d, 0, math.sin(a) * d))
    tilt = Matrix.Rotation(math.radians(0 if i == 0 else rnd.uniform(14, 30)), 4, Vector((-math.sin(a), 0, math.cos(a))))
    bot = [bm.verts.new(base + tilt @ Vector((math.cos(TAU * k / 6) * w, -0.6, math.sin(TAU * k / 6) * w))) for k in range(6)]
    top = [bm.verts.new(base + tilt @ Vector((math.cos(TAU * k / 6) * w, h * 0.78, math.sin(TAU * k / 6) * w))) for k in range(6)]
    tip = bm.verts.new(base + tilt @ Vector((0, h, 0)))
    bm.faces.new(bot[::-1])
    for k in range(6):
        bm.faces.new((bot[k], bot[(k + 1) % 6], top[(k + 1) % 6], top[k]))
        bm.faces.new((top[k], top[(k + 1) % 6], tip))
new_obj("crCrystal", bm)

# ---------------- export (already Roblox space). Faceted pieces get no normals (Roblox shades them flat); smooth ones
# (core, orb, halo) get per-vertex normals.
path = os.path.join(out_dir, "hub-crater.obj")
with open(path, "w") as fo:
    vo, no = 1, 1
    for ob, smooth in objs:
        me = ob.data; me.calc_loop_triangles()
        fo.write(f"o {ob.name}\ng {ob.name}\nusemtl {ob.name}\n")
        for v in me.vertices: fo.write("v %.4f %.4f %.4f\n" % tuple(v.co))
        if smooth:
            for v in me.vertices: fo.write("vn %.4f %.4f %.4f\n" % tuple(v.normal))
        for t in me.loop_triangles:
            if smooth: fo.write("f " + " ".join(f"{t.vertices[i] + vo}//{t.vertices[i] + no}" for i in range(3)) + "\n")
            else: fo.write("f %d %d %d\n" % tuple(t.vertices[i] + vo for i in range(3)))
        xs = [v.co.x for v in me.vertices]; ys = [v.co.y for v in me.vertices]; zs = [v.co.z for v in me.vertices]
        print("PIECE", ob.name, "centre", round((min(xs) + max(xs)) / 2, 2), round((min(ys) + max(ys)) / 2, 2), round((min(zs) + max(zs)) / 2, 2),
              "size", round(max(xs) - min(xs), 2), round(max(ys) - min(ys), 2), round(max(zs) - min(zs), 2), "tris", len(me.loop_triangles))
        vo += len(me.vertices)
        if smooth: no += len(me.vertices)
print("WROTE", path, "total tris", sum(len(o.data.loop_triangles) for o, _ in objs))
