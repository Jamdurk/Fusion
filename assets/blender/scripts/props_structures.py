# Alien Fusion: the built structures + quartz, modelled in Blender, textures baked from procedural materials (v2).
#   blender --background --factory-startup --python props_structures.py -- <assets_dir> [atlas]
# Collection "MoonStructures" (spaced along X, standing on Z = 0; static export bakes world pivots):
#   SpawnPad · MatterCore · MatterCore_Glow (Neon + team colour in Roblox) · MatterCore_Ring (spins in Roblox) ·
#   FusionReactor · Reactor_Glow (Neon in Roblox) · QuartzA/B/C
# Two-tone hard surface: an off-white HULL (panel variation, edge wear, cavity grime, top dust, painted markings) and
# a dark gunmetal TRIM (insets, arms, conduits). Both baked (colour / roughness / metal / normal incl. rounded edges)
# into one shared atlas. Curved parts are Blender curves with a bevel profile, converted to mesh.
import bpy, bmesh, math, os, sys, random
from mathutils import Vector, Matrix

argv = sys.argv[sys.argv.index("--") + 1:]
root = argv[0]
ATLAS = int(argv[1]) if len(argv) > 1 else 1024
blend_dir = os.path.join(root, "blender", "props"); tex_dir = os.path.join(root, "textures", "props")
os.makedirs(blend_dir, exist_ok=True); os.makedirs(tex_dir, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = 32
rnd = random.Random(9)
HULL, TRIM = 0, 1                                   # material slot indices
_PH = [bpy.data.materials.new("ph_hull"), bpy.data.materials.new("ph_trim")]   # placeholder slots so joins keep indices


def slots(me):
    me.materials.clear()
    for m in _PH:
        me.materials.append(m)


# ------------------------------------------------------------------ helpers
def new_obj(name, bm):
    me = bpy.data.meshes.new(name); slots(me); bm.to_mesh(me); bm.free()   # slots first: clearing materials resets indices
    o = bpy.data.objects.new(name, me); sc.collection.objects.link(o)
    return o


def ngon_prism(bm, sides, r0, z0, z1, r1=None, center=(0, 0), rot=0.0, mat=HULL):
    r1 = r0 if r1 is None else r1
    lo, hi = [], []
    for i in range(sides):
        a = rot + 2 * math.pi * i / sides
        lo.append(bm.verts.new((center[0] + r0 * math.cos(a), center[1] + r0 * math.sin(a), z0)))
        hi.append(bm.verts.new((center[0] + r1 * math.cos(a), center[1] + r1 * math.sin(a), z1)))
    fb = bm.faces.new(list(reversed(lo))); ft = bm.faces.new(hi)
    sides_f = []
    for i in range(sides):
        j = (i + 1) % sides
        sides_f.append(bm.faces.new((lo[i], lo[j], hi[j], hi[i])))
    for f in [fb, ft] + sides_f:
        f.material_index = mat
    return ft, sides_f


def inset_down(bm, face, thick, depth, mat=TRIM):
    """inset a face and push the middle down: a recessed panel; the recess gets `mat`"""
    r = bmesh.ops.inset_individual(bm, faces=[face], thickness=thick, depth=0.0)
    face.material_index = mat
    bmesh.ops.translate(bm, vec=(0, 0, -depth), verts=face.verts)
    return face


def curve_tube(name, pts, radius, res=10, mat=TRIM, taper=None):
    cu = bpy.data.curves.new(name, "CURVE"); cu.dimensions = "3D"
    sp = cu.splines.new("BEZIER"); sp.bezier_points.add(len(pts) - 1)
    for bp, p in zip(sp.bezier_points, pts):
        bp.co = p; bp.handle_left_type = bp.handle_right_type = "AUTO"
    cu.bevel_depth = radius; cu.bevel_resolution = 2; cu.resolution_u = res; cu.use_fill_caps = True
    if taper:
        for bp, r in zip(sp.bezier_points, taper):
            bp.radius = r
    o = bpy.data.objects.new(name, cu); sc.collection.objects.link(o)
    bpy.ops.object.select_all(action="DESELECT"); o.select_set(True); bpy.context.view_layer.objects.active = o
    bpy.ops.object.convert(target="MESH")
    o = bpy.context.object
    if len(o.data.materials) < 2:
        slots(o.data)
    for p in o.data.polygons:
        p.material_index = mat
    return o


def join(target, others):
    bpy.ops.object.select_all(action="DESELECT")
    for o in [target] + others:
        o.select_set(True)
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.join()
    return target


def finish(o, bevel=0.06, segs=2):
    if bevel:
        m = o.modifiers.new("bev", "BEVEL"); m.width = bevel; m.segments = segs; m.limit_method = "ANGLE"
        m.angle_limit = math.radians(35); m.harden_normals = True
    bpy.ops.object.select_all(action="DESELECT"); o.select_set(True); bpy.context.view_layer.objects.active = o
    for mm in list(o.modifiers):
        bpy.ops.object.modifier_apply(modifier=mm.name)
    bpy.ops.object.shade_smooth()
    if hasattr(o.data, "set_sharp_from_angle"):
        o.data.set_sharp_from_angle(angle=math.radians(40))
    return o


objs = {}

# ------------------------------------------------------------------ SpawnPad: hex deck with recessed panels + markings
bm = bmesh.new()
ngon_prism(bm, 6, 10.0, 0.0, 0.5, r1=9.7, rot=math.pi / 6)
top, _ = ngon_prism(bm, 6, 9.2, 0.5, 0.75, r1=9.0, rot=math.pi / 6)
# split the deck top into 6 wedge panels around a centre hex, each recessed a little
res = bmesh.ops.poke(bm, faces=[top])
for f in res["faces"]:
    inset_down(bm, f, 0.35, 0.06, mat=HULL)
for i in range(6):                                  # rim bollards (trim)
    a = math.pi / 6 + 2 * math.pi * i / 6
    ngon_prism(bm, 8, 0.45, 0.5, 1.6, r1=0.38, center=(9.35 * math.cos(a), 9.35 * math.sin(a)), mat=TRIM)
objs["SpawnPad"] = finish(new_obj("SpawnPad", bm), 0.05)

# ------------------------------------------------------------------ MatterCore: stepped plinth, 3 swept arms, glow core, ring
bm = bmesh.new()
ngon_prism(bm, 6, 6.4, 0.0, 0.9, r1=6.1)
t2, sides2 = ngon_prism(bm, 6, 5.2, 0.9, 1.9, r1=4.7)
for f in sides2:
    inset_down(bm, f, 0.22, 0.0, mat=TRIM)
    bmesh.ops.translate(bm, vec=f.normal * -0.12, verts=f.verts)
t3, _ = ngon_prism(bm, 12, 3.4, 1.9, 2.5, r1=3.0)
inset_down(bm, t3, 0.5, 0.15)
plinth = new_obj("MatterCore", bm)
arms = []
for i in range(3):
    a = 2 * math.pi * i / 3 + math.pi / 6
    c, s = math.cos(a), math.sin(a)
    pts = [(4.2 * c, 4.2 * s, 1.6), (4.9 * c, 4.9 * s, 4.5), (4.0 * c, 4.0 * s, 8.4), (2.2 * c, 2.2 * s, 10.4)]
    arms.append(curve_tube(f"arm{i}", pts, 0.55, taper=[1.25, 1.0, 0.8, 0.55]))
    # a collar where each arm meets the plinth
    bmc = bmesh.new(); ngon_prism(bmc, 8, 0.95, 1.5, 2.3, r1=0.85, center=(4.2 * c, 4.2 * s), mat=HULL); arms.append(new_obj(f"collar{i}", bmc))
objs["MatterCore"] = finish(join(plinth, arms), 0.04)
bm = bmesh.new(); bmesh.ops.create_uvsphere(bm, u_segments=32, v_segments=16, radius=2.2)
bmesh.ops.translate(bm, vec=(0, 0, 6.6), verts=bm.verts)
objs["MatterCore_Glow"] = new_obj("MatterCore_Glow", bm)
bm = bmesh.new()
ring_r, segs = 3.4, 64
for i in range(segs):                               # a torus-like band ring with 3 gaps
    if (i % (segs // 3)) < 2:
        continue
    a0, a1 = 2 * math.pi * i / segs, 2 * math.pi * (i + 1) / segs
    quad = []
    for (rr, zz) in ((ring_r - 0.25, -0.18), (ring_r + 0.25, -0.18), (ring_r + 0.25, 0.18), (ring_r - 0.25, 0.18)):
        quad.append((rr, zz))
    v0 = [bm.verts.new((rr * math.cos(a0), rr * math.sin(a0), 6.6 + zz)) for rr, zz in quad]
    v1 = [bm.verts.new((rr * math.cos(a1), rr * math.sin(a1), 6.6 + zz)) for rr, zz in quad]
    for k in range(4):
        f = bm.faces.new((v0[k], v0[(k + 1) % 4], v1[(k + 1) % 4], v1[k])); f.material_index = TRIM
    bm.faces.new(v0[::-1]).material_index = TRIM; bm.faces.new(v1).material_index = TRIM
objs["MatterCore_Ring"] = finish(new_obj("MatterCore_Ring", bm), 0.0)

# ------------------------------------------------------------------ FusionReactor: ringed platform, 4 arching pylons, conduits
bm = bmesh.new()
ngon_prism(bm, 32, 9.4, 0.0, 0.6, r1=9.1)
tA, sA = ngon_prism(bm, 32, 8.3, 0.6, 1.1, r1=8.0)
for f in sA[::2]:
    inset_down(bm, f, 0.08, 0.0, mat=TRIM)
    bmesh.ops.translate(bm, vec=f.normal * -0.06, verts=f.verts)
tB, _ = ngon_prism(bm, 32, 5.6, 1.1, 1.5, r1=5.3)
inset_down(bm, tB, 1.0, 0.12)
ngon_prism(bm, 16, 2.0, 1.4, 2.0, r1=1.7, mat=TRIM)
base = new_obj("FusionReactor", bm)
parts = []
for i in range(4):
    a = 2 * math.pi * i / 4 + math.pi / 4
    c, s = math.cos(a), math.sin(a)
    pts = [(7.6 * c, 7.6 * s, 0.8), (8.0 * c, 8.0 * s, 5.5), (5.4 * c, 5.4 * s, 10.0), (2.4 * c, 2.4 * s, 10.6)]
    parts.append(curve_tube(f"pylon{i}", pts, 0.7, taper=[1.3, 1.0, 0.75, 0.5]))
    bmc = bmesh.new(); ngon_prism(bmc, 8, 1.2, 0.5, 1.6, r1=1.0, center=(7.6 * c, 7.6 * s)); parts.append(new_obj(f"foot{i}", bmc))
    # floor conduit from the pylon foot to the centre
    parts.append(curve_tube(f"cond{i}", [(6.6 * c, 6.6 * s, 1.15), (4.2 * c + 0.6 * s, 4.2 * s - 0.6 * c, 1.15), (2.1 * c, 2.1 * s, 1.55)], 0.22))
objs["FusionReactor"] = finish(join(base, parts), 0.04)
bm = bmesh.new()
top_v = bm.verts.new((0, 0, 9.0)); bot_v = bm.verts.new((0, 0, 3.6))
mid = [bm.verts.new((1.5 * math.cos(a), 1.5 * math.sin(a), 6.3)) for a in [i * math.pi / 3 for i in range(6)]]
for i in range(6):
    bm.faces.new((mid[i], mid[(i + 1) % 6], top_v)); bm.faces.new((mid[(i + 1) % 6], mid[i], bot_v))
objs["Reactor_Glow"] = new_obj("Reactor_Glow", bm)

# ------------------------------------------------------------------ quartz clusters
for qi, (name, count, hmax) in enumerate((("QuartzA", 6, 5.0), ("QuartzB", 9, 7.5), ("QuartzC", 13, 10.0))):
    bm = bmesh.new()
    ngon_prism(bm, 9, 2.0 + qi * 0.8, -0.5, 0.4, r1=1.3 + qi * 0.6)
    for k in range(count):
        h = hmax * (0.45 + 0.55 * rnd.random())
        r = 0.32 + 0.11 * h * rnd.uniform(0.6, 1.0)
        before = set(bm.verts)
        ftop, _ = ngon_prism(bm, 6, r, -0.4, h * 0.78)
        ring = list(ftop.verts); bm.faces.remove(ftop)
        tip = bm.verts.new((rnd.uniform(-0.1, 0.1) * r, rnd.uniform(-0.1, 0.1) * r, h))
        ring.sort(key=lambda v: math.atan2(v.co.y, v.co.x))
        for i in range(6):
            bm.faces.new((ring[i], ring[(i + 1) % 6], tip))
        new = [v for v in bm.verts if v not in before]
        lean = Matrix.Rotation(rnd.uniform(0.05, 0.55), 3, "X") @ Matrix.Rotation(rnd.uniform(0, 6.28), 3, "Z")
        bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=lean, verts=new)
        bmesh.ops.translate(bm, vec=Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), 0)) * (0.6 + qi * 0.4), verts=new)
    objs[name] = finish(new_obj(name, bm), 0.03, 1)

# layout along X
x = 0.0
for name, o in objs.items():
    if name in ("MatterCore_Glow", "MatterCore_Ring"):
        o.location.x = objs["MatterCore"].location.x; continue
    if name == "Reactor_Glow":
        o.location.x = objs["FusionReactor"].location.x; continue
    w = 22 if name in ("SpawnPad", "FusionReactor") else 16
    o.location.x = x + w / 2; x += w + 6


# ------------------------------------------------------------------ materials
def hull_material():
    m = bpy.data.materials.new("hull"); m.use_nodes = True
    t = m.node_tree; b = t.nodes["Principled BSDF"]
    bev = t.nodes.new("ShaderNodeBevel"); bev.inputs["Radius"].default_value = 0.05; bev.samples = 16
    geo = t.nodes.new("ShaderNodeNewGeometry"); tc = t.nodes.new("ShaderNodeTexCoord")
    dot = t.nodes.new("ShaderNodeVectorMath"); dot.operation = "DOT_PRODUCT"
    t.links.new(bev.outputs[0], dot.inputs[0]); t.links.new(geo.outputs["Normal"], dot.inputs[1])
    edge = t.nodes.new("ShaderNodeMapRange"); t.links.new(dot.outputs["Value"], edge.inputs[0]); edge.inputs[1].default_value = 0.997; edge.inputs[2].default_value = 0.95
    wn = t.nodes.new("ShaderNodeTexNoise"); wn.inputs["Scale"].default_value = 4.0; wn.inputs["Detail"].default_value = 10
    t.links.new(tc.outputs["Object"], wn.inputs["Vector"])
    wear = t.nodes.new("ShaderNodeMath"); wear.operation = "MULTIPLY"; t.links.new(edge.outputs[0], wear.inputs[0]); t.links.new(wn.outputs["Fac"], wear.inputs[1])
    wm = t.nodes.new("ShaderNodeMapRange"); t.links.new(wear.outputs[0], wm.inputs[0]); wm.inputs[1].default_value = 0.22; wm.inputs[2].default_value = 0.4
    # panel tone variation (big cells), off-white with a cool tint
    cells = t.nodes.new("ShaderNodeTexVoronoi"); cells.inputs["Scale"].default_value = 0.35
    t.links.new(tc.outputs["Object"], cells.inputs["Vector"])
    sepc = t.nodes.new("ShaderNodeSeparateColor"); t.links.new(cells.outputs["Color"], sepc.inputs[0])
    tone = t.nodes.new("ShaderNodeMapRange"); t.links.new(sepc.outputs[0], tone.inputs[0]); tone.inputs[3].default_value = 0.62; tone.inputs[4].default_value = 0.74
    base = t.nodes.new("ShaderNodeCombineColor")
    for k, mul in enumerate((1.0, 1.01, 1.04)):
        mm = t.nodes.new("ShaderNodeMath"); mm.operation = "MULTIPLY"; t.links.new(tone.outputs[0], mm.inputs[0]); mm.inputs[1].default_value = mul
        t.links.new(mm.outputs[0], base.inputs[k])
    # painted markings: hazard chevrons on ring/top faces of the pad, read from object-space radius bands
    mixw = t.nodes.new("ShaderNodeMix"); mixw.data_type = "RGBA"
    t.links.new(wm.outputs[0], mixw.inputs[0]); t.links.new(base.outputs[0], mixw.inputs[6]); mixw.inputs[7].default_value = (0.36, 0.36, 0.37, 1)
    ao = t.nodes.new("ShaderNodeAmbientOcclusion"); ao.inputs["Distance"].default_value = 0.9; ao.samples = 16
    grime = t.nodes.new("ShaderNodeMix"); grime.data_type = "RGBA"; grime.blend_type = "MULTIPLY"; grime.inputs[0].default_value = 0.95
    t.links.new(mixw.outputs[2], grime.inputs[6]); t.links.new(ao.outputs["AO"], grime.inputs[7])
    sep = t.nodes.new("ShaderNodeSeparateXYZ"); t.links.new(geo.outputs["Normal"], sep.inputs[0])
    up = t.nodes.new("ShaderNodeMapRange"); t.links.new(sep.outputs[2], up.inputs[0]); up.inputs[1].default_value = 0.75; up.inputs[2].default_value = 1.0
    dn = t.nodes.new("ShaderNodeTexNoise"); dn.inputs["Scale"].default_value = 2.5; dn.inputs["Detail"].default_value = 8
    t.links.new(tc.outputs["Object"], dn.inputs["Vector"])
    dm = t.nodes.new("ShaderNodeMath"); dm.operation = "MULTIPLY"; t.links.new(up.outputs[0], dm.inputs[0]); t.links.new(dn.outputs["Fac"], dm.inputs[1])
    dmr = t.nodes.new("ShaderNodeMapRange"); t.links.new(dm.outputs[0], dmr.inputs[0]); dmr.inputs[1].default_value = 0.4; dmr.inputs[2].default_value = 0.65; dmr.inputs[4].default_value = 0.5
    dust = t.nodes.new("ShaderNodeMix"); dust.data_type = "RGBA"
    t.links.new(dmr.outputs[0], dust.inputs[0]); t.links.new(grime.outputs[2], dust.inputs[6]); dust.inputs[7].default_value = (0.56, 0.545, 0.52, 1)
    t.links.new(dust.outputs[2], b.inputs["Base Color"])
    rough = t.nodes.new("ShaderNodeMapRange"); t.links.new(wm.outputs[0], rough.inputs[0]); rough.inputs[3].default_value = 0.55; rough.inputs[4].default_value = 0.3
    metal = t.nodes.new("ShaderNodeMapRange"); t.links.new(wm.outputs[0], metal.inputs[0]); metal.inputs[3].default_value = 0.05; metal.inputs[4].default_value = 0.9
    t.links.new(rough.outputs[0], b.inputs["Roughness"]); t.links.new(metal.outputs[0], b.inputs["Metallic"]); t.links.new(bev.outputs[0], b.inputs["Normal"])
    return m, {"color": dust.outputs[2], "rough": rough.outputs[0], "metal": metal.outputs[0]}


def trim_material():
    m = bpy.data.materials.new("trim"); m.use_nodes = True
    t = m.node_tree; b = t.nodes["Principled BSDF"]
    bev = t.nodes.new("ShaderNodeBevel"); bev.inputs["Radius"].default_value = 0.04; bev.samples = 16
    tc = t.nodes.new("ShaderNodeTexCoord")
    br = t.nodes.new("ShaderNodeTexNoise"); br.inputs["Scale"].default_value = 30.0; br.inputs["Detail"].default_value = 4
    mp = t.nodes.new("ShaderNodeMapping"); mp.inputs["Scale"].default_value = (1, 1, 30)   # brushed streaks along Z
    t.links.new(tc.outputs["Object"], mp.inputs[0]); t.links.new(mp.outputs[0], br.inputs["Vector"])
    ao = t.nodes.new("ShaderNodeAmbientOcclusion"); ao.inputs["Distance"].default_value = 0.6
    col = t.nodes.new("ShaderNodeMapRange"); t.links.new(br.outputs["Fac"], col.inputs[0]); col.inputs[3].default_value = 0.10; col.inputs[4].default_value = 0.17
    comb = t.nodes.new("ShaderNodeCombineColor")
    for k in range(3):
        t.links.new(col.outputs[0], comb.inputs[k])
    g = t.nodes.new("ShaderNodeMix"); g.data_type = "RGBA"; g.blend_type = "MULTIPLY"; g.inputs[0].default_value = 0.8
    t.links.new(comb.outputs[0], g.inputs[6]); t.links.new(ao.outputs["AO"], g.inputs[7])
    t.links.new(g.outputs[2], b.inputs["Base Color"])
    rough = t.nodes.new("ShaderNodeMapRange"); t.links.new(br.outputs["Fac"], rough.inputs[0]); rough.inputs[3].default_value = 0.28; rough.inputs[4].default_value = 0.45
    metal = t.nodes.new("ShaderNodeValue"); metal.outputs[0].default_value = 0.85
    t.links.new(rough.outputs[0], b.inputs["Roughness"]); t.links.new(metal.outputs[0], b.inputs["Metallic"]); t.links.new(bev.outputs[0], b.inputs["Normal"])
    return m, {"color": g.outputs[2], "rough": rough.outputs[0], "metal": metal.outputs[0]}


def quartz_material():
    m = bpy.data.materials.new("quartz"); m.use_nodes = True
    t = m.node_tree; b = t.nodes["Principled BSDF"]
    geo = t.nodes.new("ShaderNodeNewGeometry")
    sep = t.nodes.new("ShaderNodeSeparateXYZ"); t.links.new(geo.outputs["Position"], sep.inputs[0])
    h = t.nodes.new("ShaderNodeMapRange"); t.links.new(sep.outputs[2], h.inputs[0]); h.inputs[1].default_value = 0.0; h.inputs[2].default_value = 8.0
    nz = t.nodes.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 2.5; nz.inputs["Detail"].default_value = 6
    add = t.nodes.new("ShaderNodeMath"); add.operation = "ADD"; t.links.new(h.outputs[0], add.inputs[0])
    s_ = t.nodes.new("ShaderNodeMath"); s_.operation = "MULTIPLY"; t.links.new(nz.outputs["Fac"], s_.inputs[0]); s_.inputs[1].default_value = 0.35
    t.links.new(s_.outputs[0], add.inputs[1])
    col = t.nodes.new("ShaderNodeValToRGB"); t.links.new(add.outputs[0], col.inputs[0])
    col.color_ramp.elements[0].position, col.color_ramp.elements[0].color = 0.15, (0.30, 0.38, 0.52, 1)
    col.color_ramp.elements[1].position, col.color_ramp.elements[1].color = 0.9, (0.86, 0.92, 0.99, 1)
    ao = t.nodes.new("ShaderNodeAmbientOcclusion"); ao.inputs["Distance"].default_value = 0.6
    g = t.nodes.new("ShaderNodeMix"); g.data_type = "RGBA"; g.blend_type = "MULTIPLY"; g.inputs[0].default_value = 0.7
    t.links.new(col.outputs["Color"], g.inputs[6]); t.links.new(ao.outputs["AO"], g.inputs[7])
    t.links.new(g.outputs[2], b.inputs["Base Color"])
    rough = t.nodes.new("ShaderNodeMapRange"); t.links.new(nz.outputs["Fac"], rough.inputs[0]); rough.inputs[3].default_value = 0.08; rough.inputs[4].default_value = 0.3
    t.links.new(rough.outputs[0], b.inputs["Roughness"])
    metal = t.nodes.new("ShaderNodeValue"); metal.outputs[0].default_value = 0.0
    return m, {"color": g.outputs[2], "rough": rough.outputs[0], "metal": metal.outputs[0]}


def bake_set(setname, names, mats, size):
    """mats: list of (material, sockets) by slot. Unwraps all objects together, bakes each map for every slot."""
    olist = [objs[n] for n in names]
    for o in olist:
        print("SLOTS", o.name, sum(1 for p in o.data.polygons if p.material_index == 1), "trim faces of", len(o.data.polygons))
        for i, (mt, _) in enumerate(mats):
            if i < len(o.data.materials):
                o.data.materials[i] = mt
            else:
                o.data.materials.append(mt)
    bpy.ops.object.select_all(action="DESELECT")
    for o in olist:
        o.select_set(True)
    bpy.context.view_layer.objects.active = olist[0]
    bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(50), island_margin=0.005)
    bpy.ops.uv.pack_islands(margin=0.005)
    bpy.ops.object.mode_set(mode="OBJECT")
    imgs = {}
    for kind, cs in (("color", "sRGB"), ("rough", "Non-Color"), ("metal", "Non-Color"), ("normal", "Non-Color")):
        img = bpy.data.images.new(f"{setname}_{kind}", size, size); img.colorspace_settings.name = cs
        tex_nodes = []
        for mt, socks in mats:
            t = mt.node_tree; out = t.nodes["Material Output"]; b = t.nodes["Principled BSDF"]
            tn = t.nodes.new("ShaderNodeTexImage"); tn.image = img; t.nodes.active = tn; tex_nodes.append((t, tn))
            if kind == "normal":
                t.links.new(b.outputs[0], out.inputs["Surface"])
            else:
                emi = t.nodes.get("bake_emit") or t.nodes.new("ShaderNodeEmission"); emi.name = "bake_emit"
                t.links.new(socks[kind], emi.inputs["Color"]); t.links.new(emi.outputs[0], out.inputs["Surface"])
        if kind == "normal":
            bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT", use_clear=True, margin=8)
        else:
            bpy.ops.object.bake(type="EMIT", use_clear=True, margin=8)
        img.filepath_raw = os.path.join(tex_dir, f"{img.name}.png"); img.file_format = "PNG"; img.save()
        imgs[kind] = img
        for t, tn in tex_nodes:
            t.nodes.remove(tn)
    gm = bpy.data.materials.new(setname); gm.use_nodes = True
    gt = gm.node_tree; gb = gt.nodes["Principled BSDF"]

    def imgn(kind):
        n = gt.nodes.new("ShaderNodeTexImage"); n.image = imgs[kind]; return n
    gt.links.new(imgn("color").outputs["Color"], gb.inputs["Base Color"])
    gt.links.new(imgn("rough").outputs["Color"], gb.inputs["Roughness"])
    gt.links.new(imgn("metal").outputs["Color"], gb.inputs["Metallic"])
    nm = gt.nodes.new("ShaderNodeNormalMap"); gt.links.new(imgn("normal").outputs["Color"], nm.inputs["Color"]); gt.links.new(nm.outputs[0], gb.inputs["Normal"])
    for o in olist:
        o.data.materials.clear(); o.data.materials.append(gm)
        for p in o.data.polygons:
            p.material_index = 0
    print("BAKED", setname)


hull = hull_material(); trim = trim_material()
bake_set("structures", ["SpawnPad", "MatterCore", "MatterCore_Ring", "FusionReactor"], [hull, trim], ATLAS)
bake_set("quartz", ["QuartzA", "QuartzB", "QuartzC"], [quartz_material()], 512)
gw = bpy.data.materials.new("glow"); gw.use_nodes = True
gw.node_tree.nodes["Principled BSDF"].inputs["Emission Color"].default_value = (0.6, 0.95, 1.0, 1)
gw.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = 3.0
for n in ("MatterCore_Glow", "Reactor_Glow"):
    objs[n].data.materials.clear(); objs[n].data.materials.append(gw)

coll = bpy.data.collections.new("MoonStructures"); sc.collection.children.link(coll)
for o in objs.values():
    for c in o.users_collection:
        c.objects.unlink(o)
    coll.objects.link(o)
    print("TRIS", o.name, sum(len(p.vertices) - 2 for p in o.data.polygons))

# preview (close-up row)
bpy.ops.mesh.primitive_plane_add(size=600, location=(x / 2, 0, -0.02))
floor = bpy.context.object; fm = bpy.data.materials.new("floor"); fm.use_nodes = True
fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.45, 0.44, 0.42, 1); floor.data.materials.append(fm)
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN")); sc.collection.objects.link(sun)
sun.data.energy = 4.0; sun.rotation_euler = (math.radians(55), 0, math.radians(30))
w = bpy.data.worlds.new("w"); sc.world = w; w.color = (0.05, 0.05, 0.06)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam")); sc.collection.objects.link(cam); sc.camera = cam
cam.data.lens = 40; cam.location = (34, -40, 22); cam.rotation_euler = (math.radians(66), 0, 0)
sc.render.resolution_x, sc.render.resolution_y = 1700, 800; sc.cycles.samples = 64
sc.render.filepath = os.path.join(tex_dir, "structures_preview.png"); bpy.ops.render.render(write_still=True)
cam.location = (x - 26, -26, 12); cam.rotation_euler = (math.radians(70), 0, 0)
sc.render.filepath = os.path.join(tex_dir, "quartz_preview.png"); bpy.ops.render.render(write_still=True)
bpy.data.objects.remove(floor); bpy.data.objects.remove(sun); bpy.data.objects.remove(cam)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(blend_dir, "moon_structures.blend"))
print("STRUCTURES_OK")
