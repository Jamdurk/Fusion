# Alien Fusion: the PINCER's contact points (batch 6, 29 Oct 2026; spec design/18-PINCER-BATCH6-SPEC 2.2).
# Prints bone heads (to fit Blender -> Roblox model space against the bones measured in Play) and, from the skin:
# UpperTip L/R = the ClawL/R-weighted vertex farthest from the ClawL/R head along its claw direction, LowerTip = the same
# for PinchL/R, Toe L1-3 / R1-3 = the lowest ShinX-weighted vertex.
#   blender --background --factory-startup aliens/crunch_f2_v5.blend --python pincer_points.py
import bpy
from mathutils import Vector

arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
me = next(o for o in bpy.data.objects if o.type == "MESH" and o.parent == arm)
gi = {g.index: g.name for g in me.vertex_groups}
mw = me.matrix_world
for b in arm.data.bones:
    h = arm.matrix_world @ b.head_local
    t = arm.matrix_world @ b.tail_local
    print("BONE", b.name, tuple(round(x, 3) for x in h), "tail", tuple(round(x, 3) for x in t))

def owned(v, name):
    return sum(g.weight for g in v.groups if gi.get(g.group) == name)

def far(name, origin, d):
    best, bs = None, -1e9
    for v in me.data.vertices:
        if owned(v, name) > 0.5:
            p = mw @ v.co
            s = (p - origin).dot(d)
            if s > bs: best, bs = p, s
    return best

for side in "LR":
    claw = arm.data.bones["Claw" + side]
    ch = arm.matrix_world @ claw.head_local
    pinch = arm.data.bones["Pinch" + side]
    ph = arm.matrix_world @ pinch.head_local
    # the claw's pointing direction: from the arm root through the claw head, flattened a little toward the front
    arm_h = arm.matrix_world @ arm.data.bones["Arm" + side].head_local
    d = (ch - arm_h).normalized()
    up = far("Claw" + side, ch, d)
    lo = far("Pinch" + side, ph, d)
    print("UPPERTIP", side, tuple(round(x, 3) for x in up))
    print("LOWERTIP", side, tuple(round(x, 3) for x in lo))
    for i in "123":
        best = None
        for v in me.data.vertices:
            if owned(v, "Shin" + side + i) > 0.5:
                p = mw @ v.co
                if best is None or p.z < best.z: best = p
        print("TOE", side + i, tuple(round(x, 3) for x in best))
# (29 Oct, second pass: the most FORWARD vertex of each group (Blender -Y = Roblox -Z): the jaw tips, not the top crystal)
for side in "LR":
    for g in ("Claw" + side, "Pinch" + side, "Arm" + side):
        best = None
        for v in me.data.vertices:
            if owned(v, g) > 0.5:
                p = mw @ v.co
                if best is None or p.y < best.y: best = p
        ys = [ (mw @ v.co) for v in me.data.vertices if owned(v, g) > 0.5 ]
        print("FWD", g, tuple(round(x, 3) for x in best), "n", len(ys),
              "zrange", round(min(p.z for p in ys), 2), round(max(p.z for p in ys), 2),
              "xrange", round(min(p.x for p in ys), 2), round(max(p.x for p in ys), 2),
              "yrange", round(min(p.y for p in ys), 2), round(max(p.y for p in ys), 2))
# (third pass: the C-claw stands in the front plane; its fixed blade ENDS at its lowest outer point, the pinch closes on it)
for side in "LR":
    cl = [mw @ v.co for v in me.data.vertices if owned(v, "Claw" + side) > 0.5]
    end = min(cl, key=lambda p: p.z)
    pv = [mw @ v.co for v in me.data.vertices if owned(v, "Pinch" + side) > 0.5]
    near = min(pv, key=lambda p: (p - end).length)
    print("JAW", side, "bladeEnd", tuple(round(x, 3) for x in end), "pinchNear", tuple(round(x, 3) for x in near), "gap", round((near - end).length, 3))
