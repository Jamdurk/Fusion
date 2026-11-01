# Alien Fusion: the RAM's DEFEAT meshes (batch 7, 29 Oct 2026; spec design/19-RAM-BATCH7-SPEC 6 + 7, sheet K5), from the
# Ram's own game mesh so they wear its skin:
#   ramHornL1 / ramHornR1   the real horns (Head-weighted verts more than 1.0 from the Head joint, one side each),
#                           detached and rigid (spec: "pre-bake the same identifiable curled horn geometry")
#   ramRubble1              everything but the horns, squashed to 1.5 high and spread 1.15x: the long low pile
# Exported in ROBLOX MODEL SPACE (x = -bx, y = bz - c, z = by; c from the Root bone) with the winding kept (det +1); the
# 3D importer turns parts 180 deg about Y, so a part's rest place is pivot * (its CENTRE) * yaw 180.
#   blender --background --factory-startup aliens/crunch_f3_v5.blend --python ram_fx.py -- <out_dir>
import bpy, bmesh, sys, os
from mathutils import Vector, Matrix

out_dir = sys.argv[sys.argv.index("--") + 1]
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
src = next(o for o in bpy.data.objects if o.type == "MESH" and o.parent == arm)
gi = {g.index: g.name for g in src.vertex_groups}
for b in ("Root", "Chest", "Head", "FootFL"):
    print("BONE", b, tuple(round(x, 3) for x in (arm.matrix_world @ arm.data.bones[b].head_local)))
headP = arm.matrix_world @ arm.data.bones["Head"].head_local
TO_RBX = Matrix(((-1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))

def build(name, keep_face, squash=None):
    bm = bmesh.new(); bm.from_mesh(src.data)
    bm.transform(src.matrix_world)
    dl = bm.verts.layers.deform.active
    keep = {f for f in bm.faces if keep_face(f, dl)}
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f not in keep], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    if squash:
        zs = [v.co.z for v in bm.verts]; z0, z1 = min(zs), max(zs)
        c = sum((v.co for v in bm.verts), Vector()) / len(bm.verts)
        for v in bm.verts:
            v.co.x = c.x + (v.co.x - c.x) * squash[1]; v.co.y = c.y + (v.co.y - c.y) * squash[1]
            v.co.z = (v.co.z - z0) / (z1 - z0) * squash[0]
    bm.transform(TO_RBX)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(ob)
    return ob

def head_w(v, dl): return sum(x for k, x in v[dl].items() if gi.get(k) == "Head") if dl else 0
def is_horn(f, dl, side):
    vs = f.verts
    if sum(head_w(v, dl) for v in vs) / len(vs) < 0.5: return False
    c = sum((v.co for v in vs), Vector()) / len(vs)
    return (c - headP).length > 1.0 and (c.x - headP.x) * side > 0.35
objs = [build("ramHornL1", lambda f, dl: is_horn(f, dl, 1)),     # (Blender +X = Roblox -X = its left)
        build("ramHornR1", lambda f, dl: is_horn(f, dl, -1)),
        build("ramRubble1", lambda f, dl: not (is_horn(f, dl, 1) or is_horn(f, dl, -1)), squash=(1.5, 1.15))]

path = os.path.join(out_dir, "ram-fx.obj")
with open(path, "w") as fo:
    fo.write("# Alien Fusion ram FX (ram_fx.py)\n")
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
            fo.write("f " + " ".join(f"{t.vertices[i] + vo}/{t.loops[i] + to}" for i in range(3)) + "\n")
        vo += len(me.vertices); to += nuv
        xs = [v.co.x for v in me.vertices]; ys = [v.co.y for v in me.vertices]; zs = [v.co.z for v in me.vertices]
        print("CENTRE", ob.name, round((min(xs) + max(xs)) / 2, 3), round((min(ys) + max(ys)) / 2, 3), round((min(zs) + max(zs)) / 2, 3),
              "SIZE", round(max(xs) - min(xs), 3), round(max(ys) - min(ys), 3), round(max(zs) - min(zs), 3), "tris", len(me.loop_triangles))
print("WROTE", path)
# (the hook sockets: each horn's most forward vertex (Roblox -Z) and its lowest-forward one, in model space)
for ob in objs[:2]:
    vs = [v.co for v in ob.data.vertices]
    f = min(vs, key=lambda p: p.z)
    print("HOOK", ob.name, tuple(round(x, 3) for x in f), "top", round(max(p.y for p in vs), 2))
