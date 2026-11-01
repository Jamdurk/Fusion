# Alien Fusion: SQUISH DRIP v5 post-process for animation batch 4 (28 Oct 2026; ChatGPT spec
# design/16-DRIP-BATCH4-SPEC-chatgpt-raw.md, section 1 "three rig/asset requirements"). Run AFTER drip_v5.py:
#   blender --background --factory-startup aliens/squish_f1_v5.blend --python drip_batch4.py -- <roblox_ready_dir>
# 1. DentL / DentR bones (children of Body) at model (-+0.78, 0.82, 0.02) = Blender (+-0.78, 0.02, 0.82) (Blender +X =
#    its left): every body vertex within 0.55 of the dent point leans on that bone (smooth falloff, up to 0.9), the eye
#    patch (within 0.62 of the eye centre) and the feet left alone. Clean + limit 4 + normalize. Saves the .blend.
# 2. Two static presentation meshes from the game mesh (same UVs: they wear the Drip's own skin, eye and all)
#    -> <roblox_ready>/drip-shapes.obj, one group each:
#    - DripPancake: the Drip tipped onto its back so the EYE FACES UP, squashed to 2.10 wide x 1.80 deep x 0.22 high
#      (BOING failed: "a genuine pancake with the eye on its upper surface").
#    - DripMeltCap: the Drip with its lid SHUT, sunk into a low mound 2.20 x 1.90 x 0.65, its bottom spreading wider
#      than its top (DEFEAT 1.30-2.05: "a low mound transitioning into a shallow puddle, the closed eye embedded").
import bpy, sys, os, math, bmesh
from mathutils import Vector, Matrix

out_dir = sys.argv[sys.argv.index("--") + 1]
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
lo = next(o for o in bpy.data.objects if o.type == "MESH" and o.parent == arm)
EYE = Vector((0.0, -0.62, 1.10))

# ---- 1. dent bones
DENTS = {"DentL": Vector((0.78, 0.02, 0.82)), "DentR": Vector((-0.78, 0.02, 0.82))}
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
eb = arm.data.edit_bones
for n, p in DENTS.items():
    if n in eb:
        eb.remove(eb[n])
    b = eb.new(n)
    b.head = p
    b.tail = p + Vector((0.0, 0.0, 0.25))
    b.parent = eb["Body"]
bpy.ops.object.mode_set(mode="OBJECT")
gi = {g.name: g.index for g in lo.vertex_groups}
avoid = {gi[n] for n in ("Lid", "FootL", "FootR") if n in gi}
for n, p in DENTS.items():
    g = lo.vertex_groups.get(n) or lo.vertex_groups.new(name=n)
    hit = 0
    for v in lo.data.vertices:
        d = (v.co - p).length
        if d >= 0.55 or (v.co - EYE).length < 0.62:
            continue
        old = {e.group: e.weight for e in v.groups}
        if any(old.get(a, 0) > 0.3 for a in avoid):
            continue
        u = 1 - d / 0.55
        w = 0.9 * u * u * (3 - 2 * u)
        for k, ow in old.items():
            lo.vertex_groups[k].add([v.index], ow * (1 - w), "REPLACE")
        g.add([v.index], w, "REPLACE")
        hit += 1
    print("DENT", n, hit)
bpy.ops.object.select_all(action="DESELECT")
lo.select_set(True); bpy.context.view_layer.objects.active = lo
bpy.ops.object.vertex_group_clean(group_select_mode="ALL", limit=0.01)
bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
if os.environ.get("DRIP_SAVE", "1") == "1":
    bpy.ops.wm.save_mainfile()
print("DENT_SAVED", bpy.data.filepath)

# ---- 2. presentation meshes
def snapshot(name, lid_shut):
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"; pb.rotation_euler = (0, 0, 0)
    if lid_shut:
        arm.pose.bones["Lid"].rotation_euler = (math.radians(LID_ANGLE), 0, 0)
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(lo.evaluated_get(dg), depsgraph=dg)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    for m in lo.data.materials:
        ob.data.materials.append(m)
    for pb in arm.pose.bones:
        pb.rotation_euler = (0, 0, 0)
    return ob

def fit(bm, w, d, h):
    xs = [v.co.x for v in bm.verts]; ys = [v.co.y for v in bm.verts]; zs = [v.co.z for v in bm.verts]
    cx, cy, z0 = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, min(zs)
    sx, sy, sz = w / (max(xs) - min(xs)), d / (max(ys) - min(ys)), h / (max(zs) - min(zs))
    for v in bm.verts:
        v.co.x = (v.co.x - cx) * sx; v.co.y = (v.co.y - cy) * sy; v.co.z = (v.co.z - z0) * sz

def finish(ob, bm):
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.normal_update()
    bm.to_mesh(ob.data); bm.free()
    for p in ob.data.polygons:
        p.use_smooth = True

LID_ANGLE = float(os.environ.get("DRIP_LID_ANGLE", "-175"))

pan = snapshot("DripPancake", False)
bm = bmesh.new(); bm.from_mesh(pan.data)
bmesh.ops.rotate(bm, verts=bm.verts, cent=Vector((0, 0, 1.25)), matrix=Matrix.Rotation(math.radians(-90), 3, "X"))   # (front -Y -> up +Z)
fit(bm, 2.10, 1.80, 0.22)
finish(pan, bm)

cap = snapshot("DripMeltCap", True)
bm = bmesh.new(); bm.from_mesh(cap.data)
fit(bm, 1.0, 1.0, 1.0)                                   # (unit box: x, y in -0.5..0.5, z in 0..1)
for v in bm.verts:
    h = v.co.z
    spread = 1.0 + 0.55 * (1 - h) ** 2                  # (the bottom slumps out wider than the top)
    v.co.x *= spread; v.co.y *= spread
    if h > 0.62:                                         # (the curl slumps into the mound, it does not stand up)
        h = 0.62 + (h - 0.62) * 0.22
        v.co.x *= 1.25; v.co.y *= 1.25
    v.co.z = h ** 1.25                                   # (weight sinks low)
fit(bm, 2.20, 1.90, 0.65)
finish(cap, bm)

bpy.ops.object.select_all(action="DESELECT")
for ob in (pan, cap):
    ob.select_set(True)
bpy.context.view_layer.objects.active = pan
bpy.ops.wm.obj_export(filepath=os.path.join(out_dir, "drip-shapes.obj"), export_selected_objects=True,
                      forward_axis="NEGATIVE_Z", up_axis="Y", export_materials=True, export_uv=True, export_normals=True,
                      export_object_groups=True, export_smooth_groups=False, apply_modifiers=False)
for ob in (pan, cap):
    print("SHAPE", ob.name, len(ob.data.vertices), tuple(round(x, 2) for x in ob.dimensions))
print("DRIP_B4_OK")
