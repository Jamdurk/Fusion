# Alien Fusion: the PINCER's jaw (batch 6, 29 Oct 2026): which turn of the Pinch bone (about its head, model axes) closes
# the lower jaw onto the fixed blade, and by how much. Prints the smallest pinch-to-blade gap for turns about X / Y / Z
# (Blender world axes) from -70 to +70 deg, and the open gap at the spec's opening angle.
#   blender --background --factory-startup aliens/crunch_f2_v5.blend --python pincer_jaw.py
import bpy, math
from mathutils import Matrix, Vector
from mathutils.kdtree import KDTree

arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
me = next(o for o in bpy.data.objects if o.type == "MESH" and o.parent == arm)
gi = {g.index: g.name for g in me.vertex_groups}
mw = me.matrix_world
def verts(name):
    return [mw @ v.co for v in me.data.vertices if sum(g.weight for g in v.groups if gi.get(g.group) == name) > 0.5]
for s in "LR":
    claw, pinch = verts("Claw" + s), verts("Pinch" + s)
    kd = KDTree(len(claw))
    for i, p in enumerate(claw): kd.insert(p, i)
    kd.balance()
    head = arm.matrix_world @ arm.data.bones["Pinch" + s].head_local
    rest = min(kd.find(p)[2] for p in pinch)
    print("JAW", s, "rest min gap", round(rest, 3), "pinch verts", len(pinch))
    for ax in "XYZ":
        best = (9, 0)
        for d in range(-70, 71, 2):
            R = Matrix.Rotation(math.radians(d), 4, ax)
            g = min(kd.find(head + (R @ (p - head).to_4d()).to_3d())[2] for p in pinch)
            if g < best[0]: best = (g, d)
        print("  axis", ax, "min gap", round(best[0], 3), "at", best[1], "deg")
# (the claw stands in the front plane (Blender XZ): its hinge is Blender Y = Roblox Z. The gap against the turn)
for s in "LR":
    claw, pinch = verts("Claw" + s), verts("Pinch" + s)
    kd = KDTree(len(claw))
    for i, p in enumerate(claw): kd.insert(p, i)
    kd.balance()
    head = arm.matrix_world @ arm.data.bones["Pinch" + s].head_local
    row = []
    for d in range(-60, 61, 10):
        R = Matrix.Rotation(math.radians(d), 4, "Y")
        g = min(kd.find(head + (R @ (p - head).to_4d()).to_3d())[2] for p in pinch)
        row.append(f"{d}:{g:.2f}")
    print("YSWEEP", s, " ".join(row))
