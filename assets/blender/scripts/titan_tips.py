# Alien Fusion: where the Titan's four tentacle TIPS really are (ChatGPT build audit r2: "confirm a physical mesh-tip
# marker ... not only the third-bone origin"). For each Tent??3 bone: the vertex weighted mostly to it that lies farthest
# from the bone's head, printed in ROBLOX MODEL SPACE (x right, y up, -z forward) next to the bone head, at rest.
#   blender --background --factory-startup aliens/squish_f4_v5.blend --python titan_tips.py
import bpy
from mathutils import Matrix, Vector
TO_RBX = Matrix(((-1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
src = next(o for o in bpy.data.objects if o.type == "MESH" and o.parent == arm)
for name in ("TentFL3", "TentFR3", "TentBL3", "TentBR3"):
    b = arm.data.bones[name]
    head = TO_RBX @ (arm.matrix_world @ b.head_local)
    gi = src.vertex_groups[name].index
    best, bd = None, -1
    for v in src.data.vertices:
        w = next((g.weight for g in v.groups if g.group == gi), 0)
        if w < 0.6: continue
        p = TO_RBX @ (src.matrix_world @ v.co)
        d = (p - head).length
        if d > bd: best, bd = p, d
    print("TIP", name, "head", tuple(round(c, 3) for c in head), "tip", tuple(round(c, 3) for c in best), "len", round(bd, 3))
# the UNDERSIDE at each tip bone: the lowest vertex weighted to it (>= 0.5) within 2 studs of the bone head, at rest
for name in ("TentFL3", "TentFR3", "TentBL3", "TentBR3"):
    b = arm.data.bones[name]
    head = TO_RBX @ (arm.matrix_world @ b.head_local)
    low = None
    for v in src.data.vertices:
        p = TO_RBX @ (src.matrix_world @ v.co)
        w = next((g.weight for g in v.groups if g.group == src.vertex_groups[name].index), 0)
        if w >= 0.5 and (p - head).length <= 2.0 and (low is None or p.y < low.y): low = p
    print("UNDER", name, "head y", round(head.y, 3), "lowest y", round(low.y, 3), "-> underside", round(head.y - low.y, 3), "below the bone head")
