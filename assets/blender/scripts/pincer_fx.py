# Alien Fusion: the PINCER's FX meshes (batch 6, 29 Oct 2026; spec design/18-PINCER-BATCH6-SPEC 8.2, reference sheet K).
# Built from the Pincer's own game mesh so they wear its skin (UVs kept) and fit its real claws:
#   pincerGuardL1 / pincerGuardR1  FX_GuardSheen: the claw's crystal faces, pushed out 0.06 along their normals (a thin
#                                  conformal shell; Roblox shows it as a faint amber overlay on the claw bone)
#   pincerClawL1 / pincerClawR1    FX_DetachedClaw: the real Arm + Claw + Pinch geometry, rigid
#   pincerRubble1                  FX_PincerRubble: the body + legs, squashed to 1.05 high and spread 1.2x (a low
#                                  fractured shell; Roblox adds the crack flashes)
#   sweepRibbon1..3                FX_SweepRibbon: a 140 deg amber slash, radius 3.8, 0.70 tall, 0.10 thick, in 3
#                                  sections revealed in turn (each tapers at its outer ends)
# Everything is exported in ROBLOX MODEL SPACE (x = -bx, y = bz - 0.05, z = by: fitted on the bones) so a part's rest
# place is its bounding-box centre printed here (CENTRE lines).
#   blender --background --factory-startup aliens/crunch_f2_v5.blend --python pincer_fx.py -- <out_dir>
import bpy, bmesh, sys, os, math
from mathutils import Vector, Matrix

out_dir = sys.argv[sys.argv.index("--") + 1]
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
src = next(o for o in bpy.data.objects if o.type == "MESH" and o.parent == arm)
gi = {g.index: g.name for g in src.vertex_groups}
# Blender world -> Roblox model space
TO_RBX = Matrix(((-1, 0, 0, 0), (0, 0, 1, -0.05), (0, 1, 0, 0), (0, 0, 0, 1)))

def part_of(groups, push=0.0, squash=None, name="x"):
    """a new object from the src faces whose verts are mostly in `groups`"""
    bm = bmesh.new(); bm.from_mesh(src.data)
    dl = bm.verts.layers.deform.active
    def w(v): return sum(x for k, x in v[dl].items() if gi.get(k) in groups) if dl else 0
    keep = {f for f in bm.faces if sum(w(v) for v in f.verts) / len(f.verts) > 0.5}
    # (claw / guard parts: drop faces near the body centre (|x| < 0.9): the rig weights a body chunk to PinchR, and it hung
    # in the air beside the detached claw, audit r1)
    if any(g.startswith("Pinch") for g in groups) and len(groups) <= 3:
        mw0 = src.matrix_world
        keep = {f for f in keep if abs((mw0 @ f.calc_center_median()).x) > 0.9}
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f not in keep], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.transform(src.matrix_world)
    if push:
        bm.normal_update()
        for v in bm.verts: v.co += v.normal * push
    if squash:
        zs = [v.co.z for v in bm.verts]
        z0, z1 = min(zs), max(zs)
        c = sum((v.co for v in bm.verts), Vector()) / len(bm.verts)
        for v in bm.verts:
            v.co.x = c.x + (v.co.x - c.x) * squash[1]
            v.co.y = c.y + (v.co.y - c.y) * squash[1]
            v.co.z = (v.co.z - z0) / (z1 - z0) * squash[0]
    bm.transform(TO_RBX)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(ob)
    return ob

objs = []
for s in "LR":
    objs.append(part_of({"Claw" + s, "Pinch" + s}, push=0.06, name="pincerGuard" + s + "1"))
    objs.append(part_of({"Arm" + s, "Claw" + s, "Pinch" + s}, name="pincerClaw" + s + "1"))
objs.append(part_of({"Root", "Body"} | {f"{p}{s}{i}" for p in ("Leg", "Shin") for s in "LR" for i in "123"},
                    squash=(1.05, 1.2), name="pincerRubble1"))

# the sweep ribbon: 140 deg about +Y, centred on forward -Z, radius 3.8, band y 1.30-2.00 (claw height), thickness
# 0.10; 3 sections of 46.7 deg; section ends taper to 30 % height. Section 1 = the start of the swing (-X side for the
# default sweep toward +X)
R, T, Y0, Y1 = 3.8, 0.10, 1.30, 2.00
for k in range(3):
    a0 = math.radians(-70 + k * 140 / 3); a1 = math.radians(-70 + (k + 1) * 140 / 3)
    bm = bmesh.new(); rows = []
    N = 10
    for i in range(N + 1):
        a = a0 + (a1 - a0) * i / N
        u = (k * N + i) / (3 * N)                                  # (0..1 along the whole arc)
        h = 0.3 + 0.7 * math.sin(math.pi * min(1, max(0, u)) ) ** 0.6  # (taper at both ends of the whole arc)
        mid, half = (Y0 + Y1) / 2, (Y1 - Y0) / 2 * h
        d = Vector((math.sin(a), 0, -math.cos(a)))
        ring = []
        for rr, yy in ((R - T / 2, mid - half), (R + T / 2, mid - half), (R + T / 2, mid + half), (R - T / 2, mid + half)):
            ring.append(bm.verts.new(Vector((d.x * rr, yy, d.z * rr))))
        rows.append(ring)
    for i in range(N):
        a, b = rows[i], rows[i + 1]
        for j in range(4):
            bm.faces.new((a[j], a[(j + 1) % 4], b[(j + 1) % 4], b[j]))
    bm.faces.new(rows[0][::-1]); bm.faces.new(rows[-1])
    me = bpy.data.meshes.new("sweepRibbon%d" % (k + 1)); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new("sweepRibbon%d" % (k + 1), me); bpy.context.scene.collection.objects.link(ob)
    objs.append(ob)

# (these are already in Roblox model space: export with the identity axis mapping, and give each its own o / g / usemtl)
path = os.path.join(out_dir, "pincer-fx.obj")
with open(path, "w") as f:
    f.write("# Alien Fusion pincer FX (pincer_fx.py)\n")
    vo, to, no = 1, 1, 1
    for ob in objs:
        me = ob.data
        me.calc_loop_triangles()
        uv = me.uv_layers.active.data if me.uv_layers.active else None
        f.write(f"o {ob.name}\ng {ob.name}\nusemtl {ob.name}\n")
        for v in me.vertices: f.write("v %.5f %.5f %.5f\n" % (v.co.x, v.co.y, v.co.z))
        nuv = 0
        if uv:
            for l in me.loops: f.write("vt %.5f %.5f\n" % (uv[l.index].uv.x, uv[l.index].uv.y)); nuv += 1
        for t in me.loop_triangles:
            vs = [t.vertices[i] + vo for i in range(3)]
            if uv:
                ls = [t.loops[i] + to for i in range(3)]
                # (TO_RBX keeps handedness (det +1): the winding stays. v1 flipped it and the parts came out inside-out)
                order = (0, 1, 2)
                f.write("f " + " ".join(f"{vs[i]}/{ls[i]}" for i in order) + "\n")
            else:
                f.write("f %d %d %d\n" % tuple(vs))
        vo += len(me.vertices); to += nuv
        xs = [v.co.x for v in me.vertices]; ys = [v.co.y for v in me.vertices]; zs = [v.co.z for v in me.vertices]
        print("CENTRE", ob.name, round((min(xs) + max(xs)) / 2, 3), round((min(ys) + max(ys)) / 2, 3), round((min(zs) + max(zs)) / 2, 3),
              "SIZE", round(max(xs) - min(xs), 3), round(max(ys) - min(ys), 3), round(max(zs) - min(zs), 3), "tris", len(me.loop_triangles))
print("WROTE", path)
