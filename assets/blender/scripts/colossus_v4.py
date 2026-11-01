# Alien Fusion: COLOSSUS v4 PILOT, built to ChatGPT's model sheet (design/concepts/colossus-v4-model-sheet-chatgpt.png,
# front / side / back; James, 27 Oct: "use the reference photo when you create the models normally ... build off that").
# The normal method (one fused body), read off the sheet:
#   * ~40 rounded, faceted BOULDERS (jittered icospheres) placed and sized from the sheet's front + side views,
#     fused with a light voxel remesh: the creases where boulders meet stay as grooves;
#   * the stone shader turns those grooves into the glowing MAGMA SEAMS (ambient-occlusion crease mask -> magma colour
#     + the glow mask), the reference's look: boulders fitted edge to edge, thin glowing seams between them;
#   * faceted amber crystal gauntlets, a crystal crown behind the head and across the shoulders, a chest core, slit
#     eyes under a heavy brow; separate pieces rigid (rigid_parts); the same 10 bones as the game's Colossus.
#   blender --background --factory-startup --python colossus_v4.py -- <assets_dir>
# Writes blender/aliens/crunch_f4_v4.blend, textures/aliens/crunch_f4_v4_*.png, shots/25-colossus-v4*.png.
# Does NOT touch the game's Colossus.
import os, sys, math, random
_here = os.path.dirname(os.path.abspath(__file__))
_src = open(os.path.join(_here, "aliens_forms.py"), encoding="utf-8").read()
_src = _src[:_src.index("for race, fn in ((\"squish\", squish)")]
_norender = "norender" in sys.argv                    # (skip the 3 Cycles beauty renders: rig / animation rebuilds)
sys.argv = [sys.argv[0], "--", sys.argv[sys.argv.index("--") + 1], "none"]
exec(compile(_src, "aliens_forms.py", "exec"))
import mathutils
V = Vector
rnd = random.Random(11)
reset()
shots = os.path.join(root, "..", "shots")

# boulders: (centre, radii, bone). Front = -Y, left = +X. Sizes measured off the sheet (feet 0, head top ~12.9,
# crystal tips ~15.6 studs; shoulders 3.0 out, gauntlets 3.95 out at hip height)
B = [
    # torso: a big chest slab around the core, pecs, collar, ribs, back, abdomen
    ((0, -0.55, 9.3), (1.5, 0.95, 1.4), "Chest"),
    ((0, -0.45, 7.7), (1.15, 0.9, 0.8), "Chest"),
    ((0, 0.85, 8.3), (1.35, 0.85, 1.1), "Chest"),
    ((0, -0.15, 6.6), (1.4, 1.0, 0.8), "Chest"),
    ((0, 0.6, 10.7), (1.3, 0.9, 0.75), "Chest"),
]
for sx in (-1, 1):
    B += [
        ((sx * 1.45, -0.35, 9.95), (1.1, 0.95, 0.95), "Chest"),   # pec
        ((sx * 0.95, -0.2, 10.95), (1.0, 0.9, 0.7), "Chest"),     # collar
        ((sx * 1.35, -0.35, 8.0), (1.0, 0.9, 0.9), "Chest"),      # ribs
        ((sx * 1.25, 0.8, 9.55), (1.3, 0.9, 1.35), "Chest"),      # back
        ((sx * 0.95, 0.35, 6.75), (0.85, 0.9, 0.75), "Chest"),    # flank
        ((sx * 1.2, 0.1, 5.25), (0.95, 0.95, 0.8), "Hips"),       # hip
        ((sx * 3.0, 0.1, 10.4), (1.35, 1.3, 1.35), "Chest"),      # shoulder ball
        ((sx * 2.25, 0.25, 11.15), (0.9, 0.9, 0.7), "Chest"),     # trapezius
        ((sx * 3.45, 0.1, 8.4), (0.85, 0.85, 1.1), "Arm" + ("L" if sx > 0 else "R")),
        ((sx * 3.75, 0.0, 6.95), (0.9, 0.9, 0.85), "Hand" + ("L" if sx > 0 else "R")),
        ((sx * 1.25, 0.1, 4.2), (1.05, 1.0, 1.0), "Leg" + ("L" if sx > 0 else "R")),   # thigh
        ((sx * 1.3, -0.1, 3.05), (0.85, 0.85, 0.62), "Leg" + ("L" if sx > 0 else "R")),  # knee
        ((sx * 1.3, 0.0, 2.0), (0.95, 0.95, 0.9), "Leg" + ("L" if sx > 0 else "R")),    # shin
        ((sx * 1.35, -0.3, 0.68), (1.25, 1.45, 0.68), "Leg" + ("L" if sx > 0 else "R")),  # foot
        ((sx * 1.35, -1.25, 0.48), (0.85, 0.6, 0.48), "Leg" + ("L" if sx > 0 else "R")),  # toe
    ]
B += [((0, 0, 5.4), (1.6, 1.1, 0.75), "Hips"),
      ((0, -0.35, 12.1), (1.05, 0.95, 0.85), "Head"),
      ((0, -1.1, 12.42), (0.9, 0.38, 0.3), "Head")]                # the heavy brow


def boulder(c, r):
    """a rounded, faceted boulder: an icosphere (2 subdivisions), each vertex nudged so no two are alike"""
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.0, location=(0, 0, 0))
    o = bpy.context.object
    for v in o.data.vertices:
        v.co *= rnd.uniform(0.93, 1.06)
    o.scale = r
    o.rotation_euler = (rnd.uniform(-0.25, 0.25), rnd.uniform(-0.25, 0.25), rnd.uniform(0, math.pi))
    o.location = c
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return o


body = join([boulder(c, r) for c, r, _ in B]); body.name = "rock"
remesh(body, 0.065, 1)                                 # (fuses them; the light smoothing keeps the creases)
displace(body, "CLOUDS", 0.6, 0.035)
bpy.ops.object.shade_smooth()

# chest core (set into the chest slab), slit eyes under the brow
glow = []
cc = ellipsoid((0, -1.38, 9.75), (0.75, 0.32, 0.8), 20); bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
glow.append(cc)
for sx in (-1, 1):
    e = ellipsoid((sx * 0.4, -1.18, 12.08), (0.24, 0.1, 0.09), 12); e.rotation_euler = (0, math.radians(-12 * sx), 0)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    glow.append(e)
sink_eyes(body, glow[1:], 0.55)
glow = join(glow)


def gem(c, r, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1.0, location=c, rotation=rot)
    o = bpy.context.object; o.scale = r
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return o


def crystal_at(a, d, r, h):
    q = V((0, 0, 1)).rotation_difference(V(d).normalized())
    return crystal(tuple(a), r, h, q.to_euler())


cry = []
for sx in (-1, 1):
    g = V((sx * 3.95, -0.1, 5.0))
    cry.append(gem(tuple(g), (1.85, 1.6, 1.95), (0.25, 0.15 * sx, 0.6)))              # the gauntlet block
    for d, rr, hh in (((sx * 0.6, -0.9, -0.55), 0.55, 1.7), ((sx * -0.2, -1.0, -0.7), 0.5, 1.5), ((sx * 1.0, -0.2, -0.6), 0.48, 1.4),
                      ((sx * 0.9, -0.6, 0.35), 0.45, 1.3), ((sx * 0.2, -1.05, 0.25), 0.4, 1.1)):
        cry.append(crystal_at(g + V(d) * 1.0, d, rr, hh))
    for (x, y, z, hh, lean) in ((2.0, 0.55, 11.4, 2.5, 12), (2.9, 0.35, 11.4, 2.0, 24), (3.7, 0.2, 11.1, 1.5, 34), (1.1, 0.75, 11.6, 2.8, 6)):
        cry.append(crystal_at(V((sx * x, y, z)), (sx * math.sin(math.radians(lean)), 0.3, 1), 0.5, hh))
cry.append(crystal_at(V((0, 0.75, 11.9)), (0, 0.25, 1), 0.62, 3.6))                    # the tall centre spike
cry = join(cry)


# ---- materials
def seam_stone():
    """grey basalt; the creases between boulders glow as magma (AO crease mask); worn lighter edges; fine grit"""
    m, t = material("seamstone"); b = t.nodes["Principled BSDF"]
    tc = t.nodes.new("ShaderNodeTexCoord"); geo = t.nodes.new("ShaderNodeNewGeometry")
    n1 = t.nodes.new("ShaderNodeTexNoise"); n1.inputs["Scale"].default_value = 1.1; n1.inputs["Detail"].default_value = 6
    t.links.new(tc.outputs["Object"], n1.inputs["Vector"])
    ramp = t.nodes.new("ShaderNodeValToRGB"); t.links.new(n1.outputs["Fac"], ramp.inputs[0])
    ramp.color_ramp.elements[0].color = (0.16, 0.155, 0.15, 1); ramp.color_ramp.elements[1].color = (0.33, 0.32, 0.305, 1)
    pe = t.nodes.new("ShaderNodeMapRange"); t.links.new(geo.outputs["Pointiness"], pe.inputs[0]); pe.inputs[1].default_value = 0.52; pe.inputs[2].default_value = 0.58
    ed = t.nodes.new("ShaderNodeMix"); ed.data_type = "RGBA"; t.links.new(pe.outputs[0], ed.inputs[0])
    t.links.new(ramp.outputs["Color"], ed.inputs[6]); ed.inputs[7].default_value = (0.36, 0.35, 0.33, 1)
    ao = t.nodes.new("ShaderNodeAmbientOcclusion"); ao.inputs["Distance"].default_value = 0.3; ao.samples = 24
    seam = t.nodes.new("ShaderNodeMapRange"); t.links.new(ao.outputs["AO"], seam.inputs[0])
    seam.inputs[1].default_value = 0.55; seam.inputs[2].default_value = 0.78; seam.inputs[3].default_value = 1.0; seam.inputs[4].default_value = 0.0
    # + the reference's network of seams ACROSS the boulders: big irregular cells (~1.8 studs), thin glowing edges
    cv = t.nodes.new("ShaderNodeTexVoronoi"); cv.feature = "DISTANCE_TO_EDGE"; cv.inputs["Scale"].default_value = 0.55
    t.links.new(tc.outputs["Object"], cv.inputs["Vector"])
    ck = t.nodes.new("ShaderNodeMapRange"); t.links.new(cv.outputs["Distance"], ck.inputs[0])
    ck.inputs[1].default_value = 0.012; ck.inputs[2].default_value = 0.04; ck.inputs[3].default_value = 1.0; ck.inputs[4].default_value = 0.0
    both = t.nodes.new("ShaderNodeMath"); both.operation = "MAXIMUM"
    t.links.new(seam.outputs[0], both.inputs[0]); t.links.new(ck.outputs[0], both.inputs[1])
    seam = both
    hot = t.nodes.new("ShaderNodeValToRGB"); t.links.new(seam.outputs[0], hot.inputs[0])
    hot.color_ramp.elements[0].color = (0.95, 0.22, 0.01, 1); hot.color_ramp.elements[1].color = (1.0, 0.55, 0.06, 1)
    mix = t.nodes.new("ShaderNodeMix"); mix.data_type = "RGBA"; t.links.new(seam.outputs[0], mix.inputs[0])
    t.links.new(ed.outputs[2], mix.inputs[6]); t.links.new(hot.outputs["Color"], mix.inputs[7])
    t.links.new(mix.outputs[2], b.inputs["Base Color"])
    rr = t.nodes.new("ShaderNodeMapRange"); t.links.new(pe.outputs[0], rr.inputs[0]); rr.inputs[3].default_value = 0.86; rr.inputs[4].default_value = 0.6
    t.links.new(rr.outputs[0], b.inputs["Roughness"])
    grit = t.nodes.new("ShaderNodeTexNoise"); grit.inputs["Scale"].default_value = 16; grit.inputs["Detail"].default_value = 8
    t.links.new(tc.outputs["Object"], grit.inputs["Vector"])
    bump = t.nodes.new("ShaderNodeBump"); bump.inputs["Strength"].default_value = 0.3; bump.inputs["Distance"].default_value = 0.04
    t.links.new(grit.outputs["Fac"], bump.inputs["Height"]); t.links.new(bump.outputs[0], b.inputs["Normal"])
    return m, {"color": mix.outputs[2], "rough": rr.outputs[0], "emit": seam.outputs[0]}


sm = seam_stone()
cm = crystal_material(2.0, 16.0, (0.9, 0.26, 0.02, 1), (1.0, 0.62, 0.1, 1))
gm = glow_material((1.0, 0.95, 0.5, 1), (1.0, 0.55, 0.05, 1))
sel(cry); bpy.ops.object.shade_flat()
hi = build_high([(sm[0], sm[1], body), (cm[0], cm[1], cry), (gm[0], gm[1], glow)]); hi.name = "Colossus4_high"
lo = make_low(hi, "CrunchF4", 9000)
bv = body_verts(lo)
bake("crunch_f4_v4", lo, hi, [sm, cm, gm], 1024)
# 15 bones (James, 27 Oct: "an animation overhaul that matches it"; ChatGPT rig LOCK, design/06-COLOSSUS-V4-ANIMATION-SPEC.md):
# knees (Shin, ~23 % up) and ankles (Foot, ~6 %) for planted-foot IK, and the spine split at Belly
BONES = [("Root", (0, 0, 0), (0, 0, 0.8), None),
         ("Hips", (0, 0.1, 4.8), (0, 0.1, 6.0), "Root"),
         ("Belly", (0, 0.1, 6.0), (0, 0.05, 7.6), "Hips"),
         ("Chest", (0, 0.05, 7.6), (0, 0.0, 11.0), "Belly"),
         ("Head", (0, -0.2, 11.2), (0, -0.5, 12.9), "Chest"),
         ("ArmL", (3.0, 0.1, 10.0), (3.6, 0.05, 7.6), "Chest"), ("HandL", (3.6, 0.05, 7.6), (3.95, -0.1, 3.0), "ArmL"),
         ("ArmR", (-3.0, 0.1, 10.0), (-3.6, 0.05, 7.6), "Chest"), ("HandR", (-3.6, 0.05, 7.6), (-3.95, -0.1, 3.0), "ArmR"),
         ("LegL", (1.25, 0.1, 4.9), (1.3, -0.15, 3.0), "Hips"), ("LegR", (-1.25, 0.1, 4.9), (-1.3, -0.15, 3.0), "Hips"),
         ("ShinL", (1.3, -0.15, 3.0), (1.33, 0.0, 0.85), "LegL"), ("ShinR", (-1.3, -0.15, 3.0), (-1.33, 0.0, 0.85), "LegR"),
         ("FootL", (1.33, 0.0, 0.85), (1.35, -1.35, 0.45), "ShinL"), ("FootR", (-1.33, 0.0, 0.85), (-1.35, -1.35, 0.45), "ShinR")]
arm, unw = rig("CrunchF4", lo, BONES)
rigid_parts(lo, bv)


def pin_pieces(lo, main):
    """(James, 27 Oct, watching the pilot: "diamonds sort of spinning through" the gauntlets) rigid_parts copies each
    piece's weights from the body vertex nearest it, and around the wrist those mix Arm + Hand differently piece to
    piece, so the gauntlet block and its crystals turned against each other. Pin whole groups to ONE bone: every
    gauntlet piece (|x| > 2.6, below z 7.2) to its Hand, every crown / shoulder crystal (z > 10.8) to the Chest"""
    vs = lo.data.vertices
    parent = {v.index: v.index for v in vs if v.index not in main}
    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]; i = parent[i]
        return i
    for e in lo.data.edges:
        a, b = e.vertices
        if a in parent and b in parent:
            ra, rb = find(a), find(b)
            if ra != rb:
                parent[ra] = rb
    islands = {}
    for i in parent:
        islands.setdefault(find(i), []).append(i)
    names = [g.name for g in lo.vertex_groups]
    pinned = {}
    for verts in islands.values():
        c = sum((vs[i].co for i in verts), Vector()) / len(verts)
        bone = None
        if abs(c.x) > 2.6 and c.z < 7.2:
            bone = "HandL" if c.x > 0 else "HandR"
        elif c.z > 10.8 and c.y > -0.5:             # (not the slit eyes: they sit at the front, y -1.2, on the Head)
            bone = "Chest"
        if not bone:
            continue
        for n in names:
            lo.vertex_groups[n].remove(verts)
        lo.vertex_groups[bone].add(verts, 1.0, "REPLACE")
        pinned[bone] = pinned.get(bone, 0) + 1
    print("PINNED", pinned)


pin_pieces(lo, bv)
coll = bpy.data.collections.new("CrunchF4"); bpy.context.scene.collection.children.link(coll)
for o in (arm, lo):
    for c in o.users_collection:
        c.objects.unlink(o)
    coll.objects.link(o)
hi.hide_render = True; hi.hide_set(True)

# ---- renders: a 3/4 beauty shot like the reference + front / side views to hold against the sheet
sc = bpy.context.scene
sc.render.engine = "CYCLES"; sc.cycles.samples = 128
gmat = lo.data.materials[0]; gt = gmat.node_tree; gb = gt.nodes["Principled BSDF"]
imgs = {n.image.name: n for n in gt.nodes if n.type == "TEX_IMAGE" and n.image}
emit_n = next((n for k, n in imgs.items() if k.endswith("_emit")), None)
col_n = next((n for k, n in imgs.items() if k.endswith("_color")), None)
if emit_n and col_n:
    gt.links.new(col_n.outputs["Color"], gb.inputs["Emission Color"])
    em = gt.nodes.new("ShaderNodeMath"); em.operation = "MULTIPLY"; em.inputs[1].default_value = 1.6
    gt.links.new(emit_n.outputs["Color"], em.inputs[0]); gt.links.new(em.outputs[0], gb.inputs["Emission Strength"])
try:
    sc.view_settings.view_transform = "Standard"
except TypeError:
    pass
sc.view_settings.exposure = -0.5
w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.5, 0.5, 0.52, 1); w.node_tree.nodes["Background"].inputs[1].default_value = 0.45
bpy.ops.mesh.primitive_plane_add(size=80, location=(0, 0, 0))
floor = bpy.context.object; fm = bpy.data.materials.new("floor"); fm.use_nodes = True
fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.62, 0.62, 0.64, 1); floor.data.materials.append(fm)
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN")); sc.collection.objects.link(sun)
sun.data.energy = 3.0; sun.data.angle = math.radians(8); sun.rotation_euler = (math.radians(48), math.radians(-12), math.radians(-38))
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam")); sc.collection.objects.link(cam); sc.camera = cam
os.makedirs(shots, exist_ok=True)
target = V((0, 0, 7.4))
for tag, yaw, lens, res in () if _norender else (("", -28, 60, (1100, 1400)), ("-front", 0, 70, (900, 1200)), ("-side", -90, 70, (900, 1200))):
    cam.data.lens = lens
    sc.render.resolution_x, sc.render.resolution_y = res
    a = math.radians(yaw)
    d = V((math.sin(a), -math.cos(a), 0.14)).normalized()
    cam.location = target + d * 38
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.join(shots, f"25-colossus-v4{tag}.png")
    bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(bdir, "crunch_f4_v4.blend"))
print("COLOSSUS_V4_OK tris", tris(lo), "unweighted", unw, "bones", len(arm.data.bones))
for b in arm.data.bones:                               # (the IK needs the real thigh / shin lengths)
    print("BONE", b.name, "head", tuple(round(x, 3) for x in b.head_local), "len", round(b.length, 3))
