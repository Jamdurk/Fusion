# Alien Fusion: COLOSSUS v3 PILOT (James, 27 Oct: "redesign one, the Colossus, and send me a pic"). Built to match the
# ChatGPT reference design/concepts/colossus-v3-reference-chatgpt.png with the "plates, not one blob" flow:
#   * a glowing MAGMA CORE (the body volumes, slightly shrunk), covered by
#   * ~130 separate chunky rock PLATES (chamfered boxes laid on each body volume's surface, small gaps between them),
#     so the magma shows through the seams = the glowing cracks, crisp plate edges instead of remesh mush;
#   * faceted amber crystal GAUNTLETS + crystal spikes on the back and shoulders, a chest core, slit eyes in a brow.
#   * every piece is rigid to one bone (same 10 bones as the current Colossus, so its giant walk still fits).
#   blender --background --factory-startup --python colossus_v3.py -- <assets_dir>
# Writes blender/aliens/crunch_f4_v3.blend, textures/aliens/crunch_f4_v3_*.png and shots/23-colossus-v3.png.
# Does NOT touch the current Colossus (crunch_f4.*).
import os, sys, math, random
_here = os.path.dirname(os.path.abspath(__file__))
_src = open(os.path.join(_here, "aliens_forms.py"), encoding="utf-8").read()
_src = _src[:_src.index("for race, fn in ((\"squish\", squish)")]
sys.argv = [sys.argv[0], "--", sys.argv[sys.argv.index("--") + 1], "none"]
exec(compile(_src, "aliens_forms.py", "exec"))
V = Vector
rnd = random.Random(7)
reset()
shots = os.path.join(root, "..", "shots")

# body volumes: (centre, radii, bone, plates). Front = -Y. Left = +X.
REGIONS = [
    ((0, 0.1, 5.0), (2.2, 1.5, 1.0), "Hips", 10),
    ((0, 0.0, 6.6), (2.0, 1.4, 1.1), "Chest", 9),
    ((0, -0.1, 8.7), (2.9, 1.9, 1.7), "Chest", 18),
    ((0, -0.5, 11.35), (0.95, 0.9, 0.8), "Head", 7),
]
for sx, s in ((1, "L"), (-1, "R")):
    REGIONS += [
        ((sx * 3.25, 0.0, 9.9), (1.6, 1.5, 1.3), "Chest", 9),        # shoulder
        ((sx * 4.05, 0.1, 8.0), (0.95, 0.95, 1.3), "Arm" + s, 6),     # upper arm
        ((sx * 4.4, -0.15, 5.9), (1.15, 1.15, 1.25), "Hand" + s, 7),  # forearm
        ((sx * 1.5, 0.1, 3.9), (1.1, 1.0, 1.2), "Leg" + s, 7),        # thigh
        ((sx * 1.55, 0.0, 2.05), (1.0, 0.95, 1.05), "Leg" + s, 6),    # shin
        ((sx * 1.6, -0.45, 0.6), (1.25, 1.6, 0.7), "Leg" + s, 5),     # foot
    ]


def tag(o, bone):
    g = o.vertex_groups.new(name=bone)
    g.add(list(range(len(o.data.vertices))), 1.0, "REPLACE")
    return o


def fib_dirs(n):
    out, ga = [], math.pi * (3 - math.sqrt(5))
    for i in range(n):
        z = 1 - 2 * (i + 0.5) / n
        rr = math.sqrt(max(0.0, 1 - z * z))
        out.append(V((math.cos(ga * i) * rr, math.sin(ga * i) * rr, z)))
    return out


def ell_area(a, b, c):
    p = 1.6075
    return 4 * math.pi * (((a * b) ** p + (a * c) ** p + (b * c) ** p) / 3) ** (1 / p)


def plate(pos, normal, w, h, t, spin):
    """a chiselled rock slab: a chamfered box, its corners jittered so no two are alike, flat-shaded facets, its thin
    axis along the surface normal (v3 first render: smooth chamfered boxes read as pillows)"""
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=pos)
    o = bpy.context.object
    o.scale = (w, h, t)
    q = V((0, 0, 1)).rotation_difference(normal)
    o.rotation_euler = (q @ __import__("mathutils").Quaternion((0, 0, 1), spin)).to_euler()
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    m = o.modifiers.new("bev", "BEVEL"); m.width = min(w, h, t) * 0.16; m.segments = 1; m.limit_method = "NONE"
    apply_mods(o)
    j = min(w, h) * 0.09
    for v in o.data.vertices:
        top = 1.0 if v.co.z > 0 else 0.35                # (the outer face gets the most chiselling)
        v.co += V((rnd.uniform(-j, j), rnd.uniform(-j, j), rnd.uniform(-j, j) * top))
    return o


rock_parts, core_parts, cry_parts, glow_parts = [], [], [], []
for c, r, bone, n in REGIONS:
    c, r = V(c), V(r)
    # slab size: big on the torso, but never more than ~85 % of the volume's smallest radius (on the thin limbs big slabs
    # stuck out like a pile of boxes); the count follows from the area, overlapping a little = thin glowing seams
    # (the count stays near the design's, ~9k tris; a slab never wider than 1.15x the volume's smallest radius, and
    # where that leaves gaps the magma shows: the reference's glowing seams)
    n = max(6, round(n * 1.7))
    side = min(math.sqrt(ell_area(*r) / n) * 1.18, 1.2 * min(r))
    for d in fib_dirs(n):
        p = c + V((d.x * r.x, d.y * r.y, d.z * r.z))
        nrm = V(((p.x - c.x) / r.x ** 2, (p.y - c.y) / r.y ** 2, (p.z - c.z) / r.z ** 2)).normalized()
        w, h = side * rnd.uniform(0.95, 1.15), side * rnd.uniform(0.9, 1.1)
        t = side * rnd.uniform(0.32, 0.42)
        rock_parts.append(tag(plate(p - nrm * t * 0.22, nrm, w, h, t, rnd.uniform(0, math.pi)), bone))
    core = ellipsoid(tuple(c), tuple(r * 0.95), 14)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    core_parts.append(tag(core, bone))
# the heavy brow over the eyes, and the slit eyes under it
for sx in (-1, 1):
    b = plate(V((sx * 0.42, -1.3, 11.78)), V((0, -0.55, 0.85)).normalized(), 0.75, 0.42, 0.32, math.radians(sx * 14))
    rock_parts.append(tag(b, "Head"))
    e = ellipsoid((sx * 0.38, -1.36, 11.45), (0.2, 0.08, 0.075), 10)
    e.rotation_euler = (0, math.radians(-12 * sx), 0)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    glow_parts.append(tag(e, "Head"))
# the chest core
cc = ellipsoid((0, -1.9, 8.95), (0.72, 0.3, 0.8), 16)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
glow_parts.append(tag(cc, "Chest"))


def gem(c, r, rot=(0, 0, 0)):
    """a faceted gem block (a 1-subdivision icosphere, flat-shaded facets)"""
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1.0, location=c, rotation=rot)
    o = bpy.context.object; o.scale = r
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return o


def crystal_at(a, d, r, h):
    q = V((0, 0, 1)).rotation_difference(V(d).normalized())
    return crystal(tuple(a), r, h, q.to_euler())


for sx, s in ((1, "L"), (-1, "R")):
    hb = "Hand" + s
    g = V((sx * 4.7, -0.35, 3.75))
    cry_parts.append(tag(gem(tuple(g), (1.45, 1.5, 1.3), (0.3, 0.2 * sx, 0.5)), hb))
    for d, rr, hh in (((sx * 0.9, -0.7, 0.2), 0.42, 1.6), ((sx * 0.3, -1.0, -0.4), 0.38, 1.4), ((sx * 1.0, 0.1, -0.6), 0.36, 1.3),
                      ((sx * 0.4, -0.5, 0.9), 0.34, 1.2), ((sx * 0.1, 0.9, 0.3), 0.3, 1.1)):
        cry_parts.append(tag(crystal_at(g + V(d) * 0.9, d, rr, hh), hb))
    # shoulder spikes
    for (x, y, z, hh, lean) in ((3.0, 0.5, 11.0, 2.3, 18), (3.9, 0.2, 10.7, 1.7, 30), (2.1, 0.9, 11.1, 2.6, 10)):
        cry_parts.append(tag(crystal_at(V((sx * x, y, z)), (sx * math.sin(math.radians(lean)), 0.35, 1), 0.42, hh), "Chest"))
# the back / crown spikes
for (x, y, z, hh) in ((0, 1.1, 11.3, 3.4), (-0.9, 1.2, 10.9, 2.7), (0.9, 1.2, 10.9, 2.7), (0, 0.4, 12.0, 1.9), (-0.45, 0.2, 12.05, 1.4), (0.45, 0.2, 12.05, 1.4)):
    cry_parts.append(tag(crystal_at(V((x, y, z)), (x * 0.25, 0.45, 1), 0.48, hh), "Chest" if z < 11.5 else "Head"))


# ---- materials
def stone_material():
    """grey basalt plates: two-scale noise, darker crevices, lighter worn edges, fine grit in the normal"""
    m, t = material("stone"); b = t.nodes["Principled BSDF"]
    tc = t.nodes.new("ShaderNodeTexCoord"); geo = t.nodes.new("ShaderNodeNewGeometry")
    n1 = t.nodes.new("ShaderNodeTexNoise"); n1.inputs["Scale"].default_value = 0.9; n1.inputs["Detail"].default_value = 6
    t.links.new(tc.outputs["Object"], n1.inputs["Vector"])
    ramp = t.nodes.new("ShaderNodeValToRGB"); t.links.new(n1.outputs["Fac"], ramp.inputs[0])
    ramp.color_ramp.elements[0].color = (0.09, 0.087, 0.085, 1); ramp.color_ramp.elements[1].color = (0.2, 0.195, 0.19, 1)
    ao = t.nodes.new("ShaderNodeAmbientOcclusion"); ao.inputs["Distance"].default_value = 0.6
    mul = t.nodes.new("ShaderNodeMix"); mul.data_type = "RGBA"; mul.blend_type = "MULTIPLY"; mul.inputs[0].default_value = 0.85
    t.links.new(ramp.outputs["Color"], mul.inputs[6]); t.links.new(ao.outputs["AO"], mul.inputs[7])
    pe = t.nodes.new("ShaderNodeMapRange"); t.links.new(geo.outputs["Pointiness"], pe.inputs[0]); pe.inputs[1].default_value = 0.53; pe.inputs[2].default_value = 0.62
    ed = t.nodes.new("ShaderNodeMix"); ed.data_type = "RGBA"; t.links.new(pe.outputs[0], ed.inputs[0])
    t.links.new(mul.outputs[2], ed.inputs[6]); ed.inputs[7].default_value = (0.34, 0.33, 0.31, 1)
    # tiny dark pits
    vp = t.nodes.new("ShaderNodeTexVoronoi"); vp.inputs["Scale"].default_value = 9; t.links.new(tc.outputs["Object"], vp.inputs["Vector"])
    pl = t.nodes.new("ShaderNodeMath"); pl.operation = "LESS_THAN"; t.links.new(vp.outputs["Distance"], pl.inputs[0]); pl.inputs[1].default_value = 0.07
    pm = t.nodes.new("ShaderNodeMix"); pm.data_type = "RGBA"; t.links.new(pl.outputs[0], pm.inputs[0])
    t.links.new(ed.outputs[2], pm.inputs[6]); pm.inputs[7].default_value = (0.12, 0.115, 0.11, 1)
    t.links.new(pm.outputs[2], b.inputs["Base Color"])
    rr = t.nodes.new("ShaderNodeMapRange"); t.links.new(pe.outputs[0], rr.inputs[0]); rr.inputs[3].default_value = 0.88; rr.inputs[4].default_value = 0.62
    t.links.new(rr.outputs[0], b.inputs["Roughness"])
    grit = t.nodes.new("ShaderNodeTexNoise"); grit.inputs["Scale"].default_value = 14; grit.inputs["Detail"].default_value = 8
    t.links.new(tc.outputs["Object"], grit.inputs["Vector"])
    bump = t.nodes.new("ShaderNodeBump"); bump.inputs["Strength"].default_value = 0.35; bump.inputs["Distance"].default_value = 0.05
    t.links.new(grit.outputs["Fac"], bump.inputs["Height"]); t.links.new(bump.outputs[0], b.inputs["Normal"])
    z = t.nodes.new("ShaderNodeValue"); z.outputs[0].default_value = 0.0
    return m, {"color": pm.outputs[2], "rough": rr.outputs[0], "emit": z.outputs[0]}


def magma_material():
    m, t = material("magma"); b = t.nodes["Principled BSDF"]
    tc = t.nodes.new("ShaderNodeTexCoord")
    n = t.nodes.new("ShaderNodeTexNoise"); n.inputs["Scale"].default_value = 2.5; t.links.new(tc.outputs["Object"], n.inputs["Vector"])
    ramp = t.nodes.new("ShaderNodeValToRGB"); t.links.new(n.outputs["Fac"], ramp.inputs[0])
    ramp.color_ramp.elements[0].color = (1.0, 0.32, 0.02, 1); ramp.color_ramp.elements[1].color = (1.0, 0.78, 0.22, 1)
    t.links.new(ramp.outputs["Color"], b.inputs["Base Color"])
    t.links.new(ramp.outputs["Color"], b.inputs["Emission Color"]); b.inputs["Emission Strength"].default_value = 3.0
    r = t.nodes.new("ShaderNodeValue"); r.outputs[0].default_value = 0.4; t.links.new(r.outputs[0], b.inputs["Roughness"])
    g = t.nodes.new("ShaderNodeValue"); g.outputs[0].default_value = 1.0
    return m, {"color": ramp.outputs["Color"], "rough": r.outputs[0], "emit": g.outputs[0]}


sm, mm = stone_material(), magma_material()
cm = crystal_material(2.0, 16.0, (0.9, 0.26, 0.02, 1), (1.0, 0.62, 0.1, 1))
gm = glow_material((1.0, 0.95, 0.5, 1), (1.0, 0.55, 0.05, 1))
rock, core, cry, glow = join(rock_parts), join(core_parts), join(cry_parts), join(glow_parts)
for o in (cry, rock):
    sel(o); bpy.ops.object.shade_flat()
for o in (core, glow):
    sel(o); bpy.ops.object.shade_smooth()
hi = build_high([(sm[0], sm[1], rock), (mm[0], mm[1], core), (cm[0], cm[1], cry), (gm[0], gm[1], glow)])
hi.name = "Colossus3_high"
lo = hi.copy(); lo.data = hi.data.copy(); lo.name = "CrunchF4"; bpy.context.scene.collection.objects.link(lo)
sel(lo)
bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.0)
bpy.ops.uv.average_islands_scale()
try:
    bpy.ops.uv.pack_islands(shape_method="CONCAVE", rotate=True, margin=0.002)
except TypeError:
    bpy.ops.uv.pack_islands(rotate=True, margin=0.002)
bpy.ops.object.mode_set(mode="OBJECT")
print("UVCOVER", round(uv_coverage(lo), 3), "TRIS", tris(lo))
bake("crunch_f4_v3", lo, hi, [sm, mm, cm, gm], 1024)

# ---- the rig: the current Colossus's 10 bones; every piece already carries its bone's vertex group (rigid)
BONES = [("Root", (0, 0, 0), (0, 0, 0.8), None),
         ("Hips", (0, 0.2, 4.6), (0, 0.2, 6.0), "Root"),
         ("Chest", (0, 0.2, 6.0), (0, 0.0, 10.3), "Hips"),
         ("Head", (0, -0.3, 10.6), (0, -0.6, 12.4), "Chest"),
         ("ArmL", (3.7, 0.0, 9.6), (4.3, 0.0, 6.9), "Chest"), ("HandL", (4.3, 0.0, 6.9), (4.7, -0.35, 2.6), "ArmL"),
         ("ArmR", (-3.7, 0.0, 9.6), (-4.3, 0.0, 6.9), "Chest"), ("HandR", (-4.3, 0.0, 6.9), (-4.7, -0.35, 2.6), "ArmR"),
         ("LegL", (1.5, 0.2, 5.0), (1.6, -0.2, 0.1), "Hips"), ("LegR", (-1.5, 0.2, 5.0), (-1.6, -0.2, 0.1), "Hips")]
arm = bpy.data.armatures.new("CrunchF4Rig"); ao = bpy.data.objects.new("CrunchF4Rig", arm)
bpy.context.scene.collection.objects.link(ao)
sel(ao); bpy.ops.object.mode_set(mode="EDIT")
for bn, h, tl, p in BONES:
    eb = arm.edit_bones.new(bn); eb.head = h; eb.tail = tl
    if p:
        eb.parent = arm.edit_bones[p]
bpy.ops.object.mode_set(mode="OBJECT")
lo.parent = ao
mod = lo.modifiers.new("Armature", "ARMATURE"); mod.object = ao
unw = sum(1 for v in lo.data.vertices if not v.groups)
print("UNWEIGHTED", unw)
coll = bpy.data.collections.new("CrunchF4"); bpy.context.scene.collection.children.link(coll)
for o in (ao, lo):
    for c in o.users_collection:
        c.objects.unlink(o)
    coll.objects.link(o)
hi.hide_render = True; hi.hide_set(True)

# ---- the beauty render, set up like the reference (3/4 front, plain light backdrop, soft key light)
sc = bpy.context.scene
sc.render.engine = "CYCLES"; sc.cycles.samples = 128
# (the glow, as in game: the baked emit mask lights the baked colour; first render was overexposed and had no glow)
gmat = lo.data.materials[0]; gt = gmat.node_tree; gb = gt.nodes["Principled BSDF"]
imgs = {n.image.name: n for n in gt.nodes if n.type == "TEX_IMAGE" and n.image}
emit_n = next((n for k, n in imgs.items() if k.endswith("_emit")), None)
col_n = next((n for k, n in imgs.items() if k.endswith("_color")), None)
if emit_n and col_n:
    gt.links.new(col_n.outputs["Color"], gb.inputs["Emission Color"])
    em = gt.nodes.new("ShaderNodeMath"); em.operation = "MULTIPLY"; em.inputs[1].default_value = 4.0
    gt.links.new(emit_n.outputs["Color"], em.inputs[0]); gt.links.new(em.outputs[0], gb.inputs["Emission Strength"])
try:
    sc.view_settings.view_transform = "Standard"
except TypeError:
    pass
sc.view_settings.exposure = -0.6
w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.5, 0.5, 0.52, 1); w.node_tree.nodes["Background"].inputs[1].default_value = 0.45
bpy.ops.mesh.primitive_plane_add(size=80, location=(0, 0, 0))
floor = bpy.context.object; fm = bpy.data.materials.new("floor"); fm.use_nodes = True
fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.62, 0.62, 0.64, 1); floor.data.materials.append(fm)
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN")); sc.collection.objects.link(sun)
sun.data.energy = 3.2; sun.data.angle = math.radians(8); sun.rotation_euler = (math.radians(48), math.radians(-12), math.radians(-38))
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam")); sc.collection.objects.link(cam); sc.camera = cam
cam.data.lens = 60
sc.render.resolution_x, sc.render.resolution_y = 1100, 1400
yaw = math.radians(-28)
d = V((math.sin(yaw), -math.cos(yaw), 0.16)).normalized()
target = V((0, 0, 6.6))
cam.location = target + d * 36
cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
os.makedirs(shots, exist_ok=True)
sc.render.filepath = os.path.join(shots, "23-colossus-v3.png")
bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(bdir, "crunch_f4_v3.blend"))
print("COLOSSUS_V3_OK tris", tris(lo))
