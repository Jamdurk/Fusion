# Alien Fusion: the PEBBLE's STONE BALL (batch 5, 29 Oct 2026; reference design/concepts/pebble/attacks/J2-curl-up).
# CURL UP and ROLL OUT swap the rigged Pebble for this static mesh (like the Drip's pancake). Built as a fresh round
# ball (icosphere) wrapped onto the Pebble's SHELL (its game mesh with the legs and head removed): every point goes out
# to max(the ball, the shell), so the shell's crystal cluster still sticks out on top; the UVs are copied from the shell
# (nearest face), so it wears the Pebble's own skin. (v1 squeezed the game mesh itself: the leg-tip crystals flew off.)
#   blender --background --factory-startup aliens/crunch_f1_v5.blend --python pebble_ball.py -- <roblox_ready_dir>
import bpy, sys, os, bmesh
from mathutils import Vector

out_dir = sys.argv[sys.argv.index("--") + 1]
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
lo = next(o for o in bpy.data.objects if o.type == "MESH" and o.parent == arm)
gi = {g.index: g.name for g in lo.vertex_groups}

# the shell: the game mesh minus the legs and the head
shell = bpy.data.objects.new("Shell", lo.data.copy())
bpy.context.scene.collection.objects.link(shell)
shell.matrix_world = lo.matrix_world
bm = bmesh.new(); bm.from_mesh(shell.data)
dl = bm.verts.layers.deform.active
kill = []
for v in bm.verts:
    w = {gi[k]: x for k, x in v[dl].items()} if dl else {}
    if sum(x for n, x in w.items() if n.startswith("Leg") or n.startswith("Shin") or n == "Head") > 0.5: kill.append(v)
bmesh.ops.delete(bm, geom=kill, context="VERTS")
bm.to_mesh(shell.data)
xs = [v.co.x for v in bm.verts]; ys = [v.co.y for v in bm.verts]; zs = [v.co.z for v in bm.verts]
C = Vector(((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, min(zs) + (max(zs) - min(zs)) * 0.42))
R = 0.5 * min(max(xs) - min(xs), max(ys) - min(ys)) * 0.95
bm.free()

bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=4, radius=R, location=C)
ball = bpy.context.active_object
ball.name = "PebbleBall"
# where the shell sticks out past the ball (the crystals), follow it
from mathutils.bvhtree import BVHTree
dg = bpy.context.evaluated_depsgraph_get()
tree = BVHTree.FromObject(shell, dg)
for v in ball.data.vertices:
    d = (v.co + ball.location) - C
    u = d.normalized()
    hit = tree.ray_cast(C + u * 0.01, u, 3.0)
    far = (hit[0] - C).length if hit[0] is not None else 0
    r = max(R, min(far, R * 1.55))
    v.co = (C + u * r) - ball.location
# UVs from the shell, ONE shell triangle per ball face (v2 per-corner nearest-face interpolation smeared corners of one
# face across different UV islands: the ball came out a gold stripe pattern in Studio, 29 Oct). Each ball face finds the
# shell triangle nearest its centre and maps its corners by barycentric coords in that triangle (clamped inside it)
from mathutils.geometry import barycentric_transform, closest_point_on_tri
sb = bmesh.new(); sb.from_mesh(shell.data)
bmesh.ops.triangulate(sb, faces=sb.faces[:])
sb.faces.ensure_lookup_table()
suv = sb.loops.layers.uv.active
stree = BVHTree.FromBMesh(sb)
mw = shell.matrix_world
uvl = ball.data.uv_layers.new(name=shell.data.uv_layers[0].name)
for poly in ball.data.polygons:
    cen = ball.matrix_world @ poly.center
    hit = stree.find_nearest(mw.inverted() @ cen)
    f = sb.faces[hit[2]]
    a, b, c = (l.vert.co for l in f.loops)
    ua, ub, uc = (l[suv].uv.to_3d() for l in f.loops)
    for li in poly.loop_indices:
        p = mw.inverted() @ (ball.matrix_world @ ball.data.vertices[ball.data.loops[li].vertex_index].co)
        q = closest_point_on_tri(p, a, b, c)
        uv = barycentric_transform(q, a, b, c, ua, ub, uc)
        uvl.data[li].uv = (uv.x, uv.y)
sb.free()
# sit it on the ground
zmin = min((ball.matrix_world @ v.co).z for v in ball.data.vertices)
ball.location.z -= zmin
for p in ball.data.polygons: p.use_smooth = True
bpy.ops.object.select_all(action="DESELECT")
ball.select_set(True); bpy.context.view_layer.objects.active = ball
bpy.ops.wm.obj_export(filepath=os.path.join(out_dir, "pebble-ball.obj"), export_selected_objects=True,
                      forward_axis="NEGATIVE_Z", up_axis="Y", export_materials=False, export_uv=True, export_normals=True,
                      export_smooth_groups=False, apply_modifiers=True)
print("BALL", len(ball.data.vertices), tuple(round(x, 2) for x in ball.dimensions), "R", round(R, 2))
