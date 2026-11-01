# Alien Fusion: SQUISH TWIN BOING flight body, round 2 (batch 3 audit r2, 28 Oct 2026; ChatGPT: "round the flight
# body's pointed silhouette. The eye must remain visually identifiable"). Replaces part 2 of twin_dent_flight.py:
#   blender --background --factory-startup aliens/squish_f2_v5.blend --python twin_flight_round.py -- <roblox_ready_dir>
# Same pose (tendrils spread), puddle (Base-weighted verts) removed, then:
#  - the puddle hole closed (a fan cap pulled up a little into a soft belly),
#  - the silhouette rounded: 4 passes of a gentle vertex smooth on everything except the eye (within 0.42 of the Lid
#    bone), so the horn tips and the cut rim go soft while the eye keeps its bulge,
#  - flattened 1.45 x wide / 0.65 x tall about its middle, smooth shading, normals recomputed AFTER the squash
#    (round 1 exported the unsquashed normals: flat-looking facets in Studio).
# The .blend is NOT saved. -> <roblox_ready>/twin-flight.obj (static, same UVs: wears the Twin's own skin).
import bpy, sys, os, math, bmesh
from mathutils import Vector

out_dir = sys.argv[sys.argv.index("--") + 1]
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
lo = next(o for o in bpy.data.objects if o.type == "MESH" and o.name == "SquishF2")
gi = {g.name: g.index for g in lo.vertex_groups}

bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="POSE")
for s, sx in (("L", 1), ("R", -1)):                          # (tendrils spread out wide and a little forward)
    for seg, ang in ((1, 55), (2, 18), (3, 10)):
        pb = arm.pose.bones.get("Tend" + s + str(seg))
        if pb:
            pb.rotation_mode = "XYZ"
            pb.rotation_euler = (0, 0, math.radians(ang) * sx)
bpy.ops.object.mode_set(mode="OBJECT")
bpy.context.view_layer.update()
eye = arm.matrix_world @ arm.data.bones["Lid"].head_local
dg = bpy.context.evaluated_depsgraph_get()
me = bpy.data.meshes.new_from_object(lo.evaluated_get(dg), depsgraph=dg)
fl = bpy.data.objects.new("TwinFlight", me)
bpy.context.scene.collection.objects.link(fl)

bm = bmesh.new(); bm.from_mesh(me)
dl = bm.verts.layers.deform.active
base_i = gi.get("Base")
kill = [v for v in bm.verts if dl is not None and base_i is not None and v[dl].get(base_i, 0) > 0.5]
bmesh.ops.delete(bm, geom=kill, context="VERTS")
# close the hole(s) the puddle left: each open boundary loop gets a centre vertex + a fan, pulled up 0.12 (a belly)
bm.verts.ensure_lookup_table()
edges = [e for e in bm.edges if e.is_boundary]
seen, loops = set(), []
for e in edges:
    if e in seen:
        continue
    loop, stack = set(), [e]
    while stack:
        x = stack.pop()
        if x in loop:
            continue
        loop.add(x); seen.add(x)
        for v in x.verts:
            for y in v.link_edges:
                if y.is_boundary and y not in loop:
                    stack.append(y)
    loops.append(loop)
capped = 0
for loop in loops:
    if len(loop) < 6:
        continue
    res = bmesh.ops.holes_fill(bm, edges=list(loop), sides=0)
    for f in res.get("faces", []):
        r = bmesh.ops.poke(bm, faces=[f])
        for v in r["verts"]:
            v.co.z += 0.12
        capped += 1
# round the silhouette (not the eye)
keep = {v for v in bm.verts if (v.co - eye).length < 0.42}
soft = [v for v in bm.verts if v not in keep]
for _ in range(4):
    bmesh.ops.smooth_vert(bm, verts=soft, factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
# flatten round the body's middle: 1.45 x wide (X, Y), 0.65 x tall (Z)
zs = [v.co.z for v in bm.verts]
zc = (min(zs) + max(zs)) / 2
for v in bm.verts:
    v.co.x *= 1.45; v.co.y *= 1.45; v.co.z = zc + (v.co.z - zc) * 0.65
bmesh.ops.triangulate(bm, faces=bm.faces[:])
bm.normal_update()
bm.to_mesh(me); bm.free()
for p in me.polygons:
    p.use_smooth = True
try:
    me.free_normals_split()
except Exception:
    pass
if hasattr(me, "has_custom_normals") and me.has_custom_normals:
    bpy.context.view_layer.objects.active = fl
    fl.select_set(True)
    bpy.ops.mesh.customdata_custom_splitnormals_clear()
fl.data.materials.clear()
for m in lo.data.materials:
    fl.data.materials.append(m)
print("FLIGHT verts", len(me.vertices), "tris", len(me.polygons), "killed puddle", len(kill), "caps", capped, "eye kept", len(keep))
bpy.ops.object.select_all(action="DESELECT")
fl.select_set(True); bpy.context.view_layer.objects.active = fl
bpy.ops.wm.obj_export(filepath=os.path.join(out_dir, "twin-flight.obj"), export_selected_objects=True,
                      forward_axis="NEGATIVE_Z", up_axis="Y", export_materials=False, export_uv=True, export_normals=True,
                      export_smooth_groups=False, apply_modifiers=False)
print("FLIGHT_OK")
