# Alien Fusion: SQUISH TWIN v5 post-process (batch 3 audit r1, 28 Oct 2026; ChatGPT: "add DentL and DentR" + "build the
# BOING flight corrective"). Run AFTER twin_v5.py:
#   blender --background --factory-startup aliens/squish_f2_v5.blend --python twin_dent_flight.py -- <roblox_ready_dir>
# 1. DentL / DentR bones (children of Body) at its sides, X = +-0.85 (Blender +X = its left), 1.45 up: every body vertex
#    within 0.65 of the dent point leans on that bone (smooth falloff, up to 0.9), so a HURT pushes a local dent in.
#    The eye / lid / puddle regions are left alone. Then clean + limit 4 + normalize (the exporter's 4-influence rule).
#    Saves the .blend (then: node blender.mjs export ... for the rigged FBX).
# 2. The FLIGHT body for the BOING apex: the mesh posed with its tendrils spread, the puddle (Base-weighted verts)
#    removed, flattened to 0.65 x the height and 1.45 x the width -> <roblox_ready>/twin-flight.obj (static, same UVs:
#    wears the Twin's own SurfaceAppearance).
import bpy, sys, os, math
from mathutils import Vector

out_dir = sys.argv[sys.argv.index("--") + 1]
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
lo = next(o for o in bpy.data.objects if o.type == "MESH" and o.name == "SquishF2")

# ---- 1. dent bones
DENTS = {"DentL": Vector((0.85, 0.0, 1.45)), "DentR": Vector((-0.85, 0.0, 1.45))}
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
eb = arm.data.edit_bones
for n, p in DENTS.items():
    if n in eb:
        eb.remove(eb[n])
    b = eb.new(n)
    b.head = p
    b.tail = p + Vector((0.0, 0.0, 0.3))
    b.parent = eb["Body"]
bpy.ops.object.mode_set(mode="OBJECT")

gi = {g.name: g.index for g in lo.vertex_groups}
avoid = {gi[n] for n in ("Base", "Lid") if n in gi}
for n, p in DENTS.items():
    g = lo.vertex_groups.get(n) or lo.vertex_groups.new(name=n)
    hit = 0
    for v in lo.data.vertices:
        d = (v.co - p).length
        if d >= 0.65:
            continue
        old = {e.group: e.weight for e in v.groups}
        if any(old.get(a, 0) > 0.3 for a in avoid):
            continue
        u = 1 - d / 0.65
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
bpy.ops.wm.save_mainfile()
print("DENT_SAVED", bpy.data.filepath)

# ---- 2. the flight body
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="POSE")
for s, sx in (("L", 1), ("R", -1)):                          # (tendrils spread out wide and a little forward)
    for seg, ang in ((1, 55), (2, 18), (3, 10)):
        pb = arm.pose.bones.get("Tend" + s + str(seg))
        if pb:
            pb.rotation_mode = "XYZ"
            pb.rotation_euler = (0, math.radians(ang) * sx * 0.0, math.radians(ang) * sx)
bpy.ops.object.mode_set(mode="OBJECT")
bpy.context.view_layer.update()
dg = bpy.context.evaluated_depsgraph_get()
ev = lo.evaluated_get(dg)
me = bpy.data.meshes.new_from_object(ev, depsgraph=dg)
fl = bpy.data.objects.new("TwinFlight", me)
bpy.context.scene.collection.objects.link(fl)
for pb in arm.pose.bones:                                     # (the .blend's rest pose is untouched: already saved)
    pb.rotation_euler = (0, 0, 0)
# drop the puddle: vertices mostly on Base
base_i = gi.get("Base")
import bmesh
bm = bmesh.new(); bm.from_mesh(me)
dl = bm.verts.layers.deform.active
kill = []
if dl is not None and base_i is not None:
    for v in bm.verts:
        if v[dl].get(base_i, 0) > 0.5:
            kill.append(v)
bmesh.ops.delete(bm, geom=kill, context="VERTS")
# flatten round the body's middle: 1.45 x wide (X, Y), 0.65 x tall (Z)
zs = [v.co.z for v in bm.verts]
zc = (min(zs) + max(zs)) / 2
for v in bm.verts:
    v.co.x *= 1.45; v.co.y *= 1.45; v.co.z = zc + (v.co.z - zc) * 0.65
bm.to_mesh(me); bm.free()
fl.data.materials.clear()
for m in lo.data.materials:
    fl.data.materials.append(m)
print("FLIGHT verts", len(me.vertices), "killed puddle", len(kill))
bpy.ops.object.select_all(action="DESELECT")
fl.select_set(True); bpy.context.view_layer.objects.active = fl
bpy.ops.wm.obj_export(filepath=os.path.join(out_dir, "twin-flight.obj"), export_selected_objects=True,
                      forward_axis="NEGATIVE_Z", up_axis="Y", export_materials=False, export_uv=True, export_normals=True,
                      apply_modifiers=False)
print("FLIGHT_OK")
