# Alien Fusion: STICK POINTS for the Drip (and later the Pebble) on every big form, from the real game mesh (29 Oct 2026).
# Why: in Roblox a MeshPart's collision hull is a convex wrap of its REST pose: across a Titan's fin tips it is a roof of
# air (Drips landed floating above its back), between a Brute's arm and body it is a wall of air. These points are on
# the actual skin, picked here once:
#   TOP  = up-facing (normal z > 0.35), the highest face in each 0.8-stud cell, >= 5 of its 8 neighbour cells within 0.8
#          (a fin tip has no flat neighbours) and nothing above it within 4 studs (exposed);
#   WALL = sideways-facing (|normal z| < 0.45), 22-62 % of the height, nothing outward along its normal within 3 studs
#          (not tucked between an arm and the body).
# Thinned to >= 0.9 apart. Written as Roblox model space (pivot-relative): Roblox = (-x, z + rootY, y); normals the same
# way. One run writes every form into src/ReplicatedStorage.AlienFusion.AttachPoints.module.luau:
#   for f in ...; blender --background --factory-startup aliens/<f>.blend --python attach_points.py -- <Form> <rootY> <out.json>
import bpy, sys, json, math, bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree

argv = sys.argv[sys.argv.index("--") + 1:]
form, root_y, out = argv[0], float(argv[1]), argv[2]
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
lo = next(o for o in bpy.data.objects if o.type == "MESH" and o.parent == arm)
dg = bpy.context.evaluated_depsgraph_get()
me = lo.evaluated_get(dg).to_mesh()
bm = bmesh.new(); bm.from_mesh(me); bm.transform(lo.matrix_world)
bm.faces.ensure_lookup_table()
tree = BVHTree.FromBMesh(bm)
zs = [v.co.z for v in bm.verts]
H = max(zs) - min(zs)
z0 = min(zs)

def exposed(p, n, dist):
    hit = tree.ray_cast(p + n * 0.06, n, dist)
    return hit[0] is None

# TOP
CELL = 0.8
cells = {}
for f in bm.faces:
    n = f.normal
    if f.calc_area() < 1e-4 or n.length < 0.5: continue          # (zero-area faces have no normal: a NaN Drip, measured)
    if n.z < 0.35: continue
    c = f.calc_center_median()
    k = (math.floor(c.x / CELL), math.floor(c.y / CELL))
    if k not in cells or c.z > cells[k][0].z: cells[k] = (c, n.copy())
top = []
for (i, j), (c, n) in cells.items():
    if c.z < z0 + 0.35 * H: continue
    good = 0
    for di in (-1, 0, 1):
        for dj in (-1, 0, 1):
            if di == 0 and dj == 0: continue
            nb = cells.get((i + di, j + dj))
            if nb is not None and abs(nb[0].z - c.z) <= 0.8: good += 1
    if good >= 5 and exposed(c, Vector((0, 0, 1)), 4.0): top.append((c, n))

# WALL
wall = []
for f in bm.faces:
    n = f.normal
    if f.calc_area() < 1e-4 or n.length < 0.5: continue
    if abs(n.z) > 0.45: continue
    c = f.calc_center_median()
    if not (z0 + 0.22 * H <= c.z <= z0 + 0.62 * H): continue
    if exposed(c, n, 3.0): wall.append((c, n.copy()))

# LOW = sideways-facing points 0.4-1.6 studs off the ground (a Pebble's horn reach: batch 5), exposed 2 studs outward
low = []
for f in bm.faces:
    n = f.normal
    if f.calc_area() < 1e-4 or n.length < 0.5: continue
    if abs(n.z) > 0.55: continue
    c = f.calc_center_median()
    if not (z0 + 0.4 <= c.z <= z0 + 1.6): continue
    if exposed(c, n, 2.0) and exposed(c, Vector((n.x, n.y, 0)).normalized(), 2.0): low.append((c, n.copy()))

def thin(pts, d):
    kept = []
    for c, n in sorted(pts, key=lambda t: (round(t[0].z, 1), t[0].x, t[0].y)):
        if all((c - k[0]).length >= d for k in kept): kept.append((c, n))
    return kept

def rb(c, n):
    return [round(-c.x, 3), round(c.z + root_y, 3), round(c.y, 3), round(-n.x, 3), round(n.z, 3), round(n.y, 3)]

top, wall, low = thin(top, 0.9), thin(wall, 0.9), thin(low, 0.7)
data = {}
try:
    with open(out) as fh: data = json.load(fh)
except Exception: pass
data[form] = {"top": [rb(c, n) for c, n in top], "wall": [rb(c, n) for c, n in wall], "low": [rb(c, n) for c, n in low], "H": round(H, 3)}
with open(out, "w") as fh: json.dump(data, fh)
print("POINTS", form, "top", len(top), "wall", len(wall), "low", len(low), "H", round(H, 2))
