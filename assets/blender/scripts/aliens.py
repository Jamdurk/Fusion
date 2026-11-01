# Alien Fusion: SQUISH (goo) + CRUNCH (rock beetle) small forms, modelled, textured and rigged in Blender.
#   blender --background --factory-startup --python aliens.py -- <assets_dir>
# Each alien: a low game mesh (phone: ~1.5-3k tris; up to 48 on screen) skinned to a small armature (one rig per
# family; bigger forms = the same rig scaled in Roblox + attachment pieces later), textures baked from a detailed
# procedural material (+ a high-detail copy for the normal map). Faces Blender's Front view (-Y) = Roblox forward.
# Writes blender/aliens/<name>.blend (collection <Name>: armature + mesh, ready for `blender.mjs export ... .fbx`),
# textures/aliens/<name>_{color,rough,normal}.png and turnaround previews.
import bpy, bmesh, math, os, sys, random
from mathutils import Vector, Matrix, Euler

argv = sys.argv[sys.argv.index("--") + 1:]
root = argv[0]
bdir = os.path.join(root, "blender", "aliens"); tdir = os.path.join(root, "textures", "aliens")
os.makedirs(bdir, exist_ok=True); os.makedirs(tdir, exist_ok=True)
TEX = 512


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = 32
    return sc


def sel(o):
    bpy.ops.object.select_all(action="DESELECT"); o.select_set(True); bpy.context.view_layer.objects.active = o


def apply_mods(o):
    sel(o)
    for m in list(o.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)


def join(objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    return objs[0]


def remesh_smooth(o, voxel, smooth_iters=6):
    sel(o)
    r = o.modifiers.new("rm", "REMESH"); r.mode = "VOXEL"; r.voxel_size = voxel
    s = o.modifiers.new("sm", "SMOOTH"); s.iterations = smooth_iters; s.factor = 0.6
    apply_mods(o)


def decimate_to(o, tris):
    sel(o)
    cur = sum(len(p.vertices) - 2 for p in o.data.polygons)
    if cur > tris:
        d = o.modifiers.new("dec", "DECIMATE"); d.ratio = tris / cur
        apply_mods(o)
    bpy.ops.object.shade_smooth()


def uv_unwrap(o):
    sel(o)
    bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.01)
    bpy.ops.uv.pack_islands(margin=0.01)
    bpy.ops.object.mode_set(mode="OBJECT")


def bake_maps(name, lo, hi, mat, sockets):
    """bake colour + roughness (EMIT from the procedural sockets, via the high mesh) and normal (high -> low)"""
    sc = bpy.context.scene
    imgs = {}
    lo_mat = bpy.data.materials.new(name + "_game"); lo_mat.use_nodes = True
    lt = lo_mat.node_tree; lb = lt.nodes["Principled BSDF"]
    lo.data.materials.clear(); lo.data.materials.append(lo_mat)
    t = mat.node_tree; out = t.nodes["Material Output"]; b = t.nodes["Principled BSDF"]
    emi = t.nodes.new("ShaderNodeEmission")
    for kind, cs in (("color", "sRGB"), ("rough", "Non-Color"), ("normal", "Non-Color")):
        img = bpy.data.images.new(f"{name}_{kind}", TEX, TEX); img.colorspace_settings.name = cs
        tn = lt.nodes.new("ShaderNodeTexImage"); tn.image = img; lt.nodes.active = tn
        bpy.ops.object.select_all(action="DESELECT"); hi.select_set(True); lo.select_set(True); bpy.context.view_layer.objects.active = lo
        if kind == "normal":
            t.links.new(b.outputs[0], out.inputs["Surface"])
            bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT", use_selected_to_active=True, cage_extrusion=0.08, max_ray_distance=0.2, margin=6)
        else:
            t.links.new(sockets[kind], emi.inputs["Color"]); t.links.new(emi.outputs[0], out.inputs["Surface"])
            bpy.ops.object.bake(type="EMIT", use_selected_to_active=True, cage_extrusion=0.08, max_ray_distance=0.2, margin=6)
        img.filepath_raw = os.path.join(tdir, f"{img.name}.png"); img.file_format = "PNG"; img.save()
        imgs[kind] = tn
    lt.links.new(imgs["color"].outputs["Color"], lb.inputs["Base Color"])
    lt.links.new(imgs["rough"].outputs["Color"], lb.inputs["Roughness"])
    nm = lt.nodes.new("ShaderNodeNormalMap"); lt.links.new(imgs["normal"].outputs["Color"], nm.inputs["Color"]); lt.links.new(nm.outputs[0], lb.inputs["Normal"])
    t.links.new(b.outputs[0], out.inputs["Surface"])
    return lo_mat


def armature(name, bones):
    """bones: list of (name, head, tail, parent)"""
    arm = bpy.data.armatures.new(name + "Rig"); ao = bpy.data.objects.new(name + "Rig", arm)
    bpy.context.scene.collection.objects.link(ao)
    sel(ao); bpy.ops.object.mode_set(mode="EDIT")
    for bn, h, t, p in bones:
        eb = arm.edit_bones.new(bn); eb.head = h; eb.tail = t
        if p:
            eb.parent = arm.edit_bones[p]
    bpy.ops.object.mode_set(mode="OBJECT")
    return ao


def skin(mesh, arm):
    bpy.ops.object.select_all(action="DESELECT"); mesh.select_set(True); arm.select_set(True); bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    # Roblox: <= 4 influences, normalised, and nothing on the root
    sel(mesh)
    vg_root = mesh.vertex_groups.get("Root")
    if vg_root:
        mesh.vertex_groups.remove(vg_root)
    bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
    bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)


def preview(name, objs, height):
    sc = bpy.context.scene
    bpy.ops.mesh.primitive_plane_add(size=60, location=(0, 0, 0))
    floor = bpy.context.object; fm = bpy.data.materials.new("floor"); fm.use_nodes = True
    fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.42, 0.41, 0.4, 1); floor.data.materials.append(fm)
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN")); sc.collection.objects.link(sun)
    sun.data.energy = 4.0; sun.rotation_euler = (math.radians(50), 0, math.radians(-30))
    w = bpy.data.worlds.new("w"); sc.world = w; w.color = (0.08, 0.08, 0.1)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam")); sc.collection.objects.link(cam); sc.camera = cam
    cam.data.lens = 50
    sc.render.resolution_x, sc.render.resolution_y = 1400, 700; sc.cycles.samples = 64
    d = height * 3.2
    for tag, yaw in (("front", 0.0), ("side", math.radians(-60))):
        dir_ = Vector((math.sin(yaw), -math.cos(yaw), 0.45)).normalized()
        cam.location = dir_ * d + Vector((0, 0, height * 0.45))
        cam.rotation_euler = (Vector((0, 0, height * 0.45)) - cam.location).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(tdir, f"{name}_{tag}.png"); bpy.ops.render.render(write_still=True)
    for o in (floor, sun, cam):
        bpy.data.objects.remove(o)


def finish(name, mesh, arm, extra_hide):
    coll = bpy.data.collections.new(name); bpy.context.scene.collection.children.link(coll)
    for o in (arm, mesh):
        for c in o.users_collection:
            c.objects.unlink(o)
        coll.objects.link(o)
    for o in extra_hide:
        o.hide_render = True; o.hide_set(True)
    print("TRIS", name, sum(len(p.vertices) - 2 for p in mesh.data.polygons), "bones", len(arm.data.bones))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(bdir, f"{name.lower()}.blend"))


# =====================================================================================================================
# SQUISH: a glossy cyan jelly teardrop, one big eye, four nubby feet. 2.5 tall, 2 wide.
# =====================================================================================================================
sc = reset()
bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=24, radius=1.0)
body = bpy.context.object; body.name = "SquishBody"
for v in body.data.vertices:                       # teardrop: wide low belly, tip leaning back
    z = v.co.z
    t = (z + 1) / 2
    k = 1.0 - 0.55 * t ** 2.2
    v.co.x *= k; v.co.y *= k
    v.co.y += 0.25 * t ** 3                         # tip leans back (+Y = away from the front)
    v.co.z = z * 1.15 + 0.05 * math.sin(v.co.x * 5)
body.scale = (1.0, 0.95, 1.0); bpy.ops.object.transform_apply(scale=True)
body.location.z = 1.2
parts = [body]
for i, (fx, fy) in enumerate(((-0.5, -0.45), (0.5, -0.45), (-0.5, 0.45), (0.5, 0.45))):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=0.32, location=(fx, fy, 0.22))
    f = bpy.context.object; f.scale = (1.0, 1.15, 0.7); parts.append(f)
# eye socket bulge + eye (eye stays its own object: white sclera, iris painted in the texture)
bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=0.55, location=(0, -0.7, 1.55))
eye = bpy.context.object; eye.name = "SquishEye"; eye.scale = (1.0, 0.75, 1.0)
parts.append(eye)
hi = join(parts); hi.name = "Squish_high"
sel(hi); bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
remesh_smooth(hi, 0.03, 4)
# high detail: soft wobble + tiny bubbles inside the jelly surface
tx = bpy.data.textures.new("sq_wob", "CLOUDS"); tx.noise_scale = 0.35
m = hi.modifiers.new("d", "DISPLACE"); m.texture = tx; m.strength = 0.03
apply_mods(hi); bpy.ops.object.shade_smooth()
lo = hi.copy(); lo.data = hi.data.copy(); lo.name = "Squish"; sc.collection.objects.link(lo)
decimate_to(lo, 2200)
uv_unwrap(lo)

mat = bpy.data.materials.new("squish_src"); mat.use_nodes = True
t = mat.node_tree; b = t.nodes["Principled BSDF"]
geo = t.nodes.new("ShaderNodeNewGeometry"); tc = t.nodes.new("ShaderNodeTexCoord")
sep = t.nodes.new("ShaderNodeSeparateXYZ"); t.links.new(geo.outputs["Position"], sep.inputs[0])
sepn = t.nodes.new("ShaderNodeSeparateXYZ"); t.links.new(geo.outputs["Normal"], sepn.inputs[0])
# body gradient: deep teal belly -> electric cyan top, violet in the cavities, mint speckles
hgrad = t.nodes.new("ShaderNodeMapRange"); t.links.new(sep.outputs[2], hgrad.inputs[0]); hgrad.inputs[1].default_value = 0.1; hgrad.inputs[2].default_value = 2.6
ramp = t.nodes.new("ShaderNodeValToRGB"); t.links.new(hgrad.outputs[0], ramp.inputs[0])
ramp.color_ramp.elements[0].color = (0.0, 0.22, 0.32, 1); ramp.color_ramp.elements[1].color = (0.15, 0.85, 1.0, 1)
e = ramp.color_ramp.elements.new(0.55); e.color = (0.02, 0.62, 0.86, 1)
ao = t.nodes.new("ShaderNodeAmbientOcclusion"); ao.inputs["Distance"].default_value = 0.35
cav = t.nodes.new("ShaderNodeMapRange"); t.links.new(ao.outputs["AO"], cav.inputs[0]); cav.inputs[1].default_value = 0.4; cav.inputs[2].default_value = 0.95
mixv = t.nodes.new("ShaderNodeMix"); mixv.data_type = "RGBA"
t.links.new(cav.outputs[0], mixv.inputs[0]); mixv.inputs[6].default_value = (0.32, 0.12, 0.62, 1); t.links.new(ramp.outputs["Color"], mixv.inputs[7])
spk = t.nodes.new("ShaderNodeTexVoronoi"); spk.inputs["Scale"].default_value = 14.0; t.links.new(tc.outputs["Object"], spk.inputs["Vector"])
spm = t.nodes.new("ShaderNodeMath"); spm.operation = "LESS_THAN"; t.links.new(spk.outputs["Distance"], spm.inputs[0]); spm.inputs[1].default_value = 0.09
mixs = t.nodes.new("ShaderNodeMix"); mixs.data_type = "RGBA"
t.links.new(spm.outputs[0], mixs.inputs[0]); t.links.new(mixv.outputs[2], mixs.inputs[6]); mixs.inputs[7].default_value = (0.6, 1.0, 0.85, 1)
# the eye: sphere centred at (0, -0.7, 1.55): white sclera, violet iris ring, black pupil, a catchlight
ev = t.nodes.new("ShaderNodeVectorMath"); ev.operation = "SUBTRACT"; t.links.new(geo.outputs["Position"], ev.inputs[0]); ev.inputs[1].default_value = (0, -0.7, 1.55)
evl = t.nodes.new("ShaderNodeVectorMath"); evl.operation = "LENGTH"; t.links.new(ev.outputs[0], evl.inputs[0])
in_eye = t.nodes.new("ShaderNodeMath"); in_eye.operation = "LESS_THAN"; t.links.new(evl.outputs["Value"], in_eye.inputs[0]); in_eye.inputs[1].default_value = 0.6
evs = t.nodes.new("ShaderNodeSeparateXYZ"); t.links.new(ev.outputs[0], evs.inputs[0])
# distance from the eye's forward axis (looking -Y): sqrt(x^2 + z^2)
r2 = t.nodes.new("ShaderNodeVectorMath"); r2.operation = "MULTIPLY"; t.links.new(ev.outputs[0], r2.inputs[0]); r2.inputs[1].default_value = (1, 0, 1)
rl = t.nodes.new("ShaderNodeVectorMath"); rl.operation = "LENGTH"; t.links.new(r2.outputs[0], rl.inputs[0])
front = t.nodes.new("ShaderNodeMath"); front.operation = "LESS_THAN"; t.links.new(evs.outputs[1], front.inputs[0]); front.inputs[1].default_value = -0.2
irisr = t.nodes.new("ShaderNodeMath"); irisr.operation = "LESS_THAN"; t.links.new(rl.outputs["Value"], irisr.inputs[0]); irisr.inputs[1].default_value = 0.30
pupr = t.nodes.new("ShaderNodeMath"); pupr.operation = "LESS_THAN"; t.links.new(rl.outputs["Value"], pupr.inputs[0]); pupr.inputs[1].default_value = 0.15
iris = t.nodes.new("ShaderNodeMath"); iris.operation = "MULTIPLY"; t.links.new(irisr.outputs[0], iris.inputs[0]); t.links.new(front.outputs[0], iris.inputs[1])
pup = t.nodes.new("ShaderNodeMath"); pup.operation = "MULTIPLY"; t.links.new(pupr.outputs[0], pup.inputs[0]); t.links.new(front.outputs[0], pup.inputs[1])
eyec = t.nodes.new("ShaderNodeMix"); eyec.data_type = "RGBA"; t.links.new(iris.outputs[0], eyec.inputs[0])
eyec.inputs[6].default_value = (0.95, 0.97, 1.0, 1); eyec.inputs[7].default_value = (0.42, 0.14, 0.78, 1)
eyep = t.nodes.new("ShaderNodeMix"); eyep.data_type = "RGBA"; t.links.new(pup.outputs[0], eyep.inputs[0])
t.links.new(eyec.outputs[2], eyep.inputs[6]); eyep.inputs[7].default_value = (0.01, 0.01, 0.02, 1)
# catchlight: a small bright dot up-left of the pupil
cl = t.nodes.new("ShaderNodeVectorMath"); cl.operation = "DISTANCE"; t.links.new(ev.outputs[0], cl.inputs[0]); cl.inputs[1].default_value = (-0.09, -0.42, 0.1)
clm = t.nodes.new("ShaderNodeMath"); clm.operation = "LESS_THAN"; t.links.new(cl.outputs["Value"], clm.inputs[0]); clm.inputs[1].default_value = 0.06
eyef = t.nodes.new("ShaderNodeMix"); eyef.data_type = "RGBA"; t.links.new(clm.outputs[0], eyef.inputs[0])
t.links.new(eyep.outputs[2], eyef.inputs[6]); eyef.inputs[7].default_value = (1, 1, 1, 1)
final = t.nodes.new("ShaderNodeMix"); final.data_type = "RGBA"; t.links.new(in_eye.outputs[0], final.inputs[0])
t.links.new(mixs.outputs[2], final.inputs[6]); t.links.new(eyef.outputs[2], final.inputs[7])
t.links.new(final.outputs[2], b.inputs["Base Color"])
rough = t.nodes.new("ShaderNodeMix"); rough.data_type = "FLOAT"; t.links.new(in_eye.outputs[0], rough.inputs[0])
rough.inputs[2].default_value = 0.16; rough.inputs[3].default_value = 0.06
t.links.new(rough.outputs[0], b.inputs["Roughness"])
b.inputs["Coat Weight"].default_value = 0.6
hi.data.materials.append(mat)
bake_maps("squish", lo, hi, mat, {"color": final.outputs[2], "rough": rough.outputs[0]})

arm = armature("Squish", [
    ("Root", (0, 0, 0), (0, 0, 0.3), None),
    ("Body", (0, 0, 0.35), (0, 0, 1.2), "Root"),
    ("Top", (0, 0.05, 1.2), (0, 0.2, 2.4), "Body"),
    ("FootFL", (-0.5, -0.45, 0.3), (-0.5, -0.45, 0.05), "Root"),
    ("FootFR", (0.5, -0.45, 0.3), (0.5, -0.45, 0.05), "Root"),
    ("FootBL", (-0.5, 0.45, 0.3), (-0.5, 0.45, 0.05), "Root"),
    ("FootBR", (0.5, 0.45, 0.3), (0.5, 0.45, 0.05), "Root"),
])
skin(lo, arm)
preview("squish", [lo], 2.6)
finish("Squish", lo, arm, [hi])

# =====================================================================================================================
# CRUNCH: a wide crystal-shelled beetle. Charcoal rock body with glowing yellow cracks, amber crystal plates on the
# back, a stubby horn, four chunky legs. 2 tall, 3 wide.
# =====================================================================================================================
sc = reset()
rnd = random.Random(3)
bpy.ops.mesh.primitive_uv_sphere_add(segments=40, ring_count=20, radius=1.0)
cb = bpy.context.object; cb.scale = (1.35, 1.5, 0.55); cb.location = (0, 0.1, 0.85)
bpy.ops.object.transform_apply(location=True, scale=True)
parts = [cb]
bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=0.55, location=(0, -1.35, 0.75))
head = bpy.context.object; head.scale = (1.05, 0.85, 0.75); parts.append(head)
bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=0.26, radius2=0.03, depth=0.95, location=(0, -1.9, 1.12))
horn = bpy.context.object; horn.rotation_euler = (math.radians(-60), 0, 0); parts.append(horn)
for sx in (-1, 1):                                   # mandibles
    bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.1, radius2=0.01, depth=0.5, location=(0.28 * sx, -1.8, 0.55))
    md = bpy.context.object; md.rotation_euler = (math.radians(-80), 0, math.radians(25 * sx)); parts.append(md)
legs = []
for i, (lx, ly) in enumerate(((-1.05, -0.65), (1.05, -0.65), (-1.05, 0.75), (1.05, 0.75))):
    sx = 1 if lx > 0 else -1
    bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.2, depth=0.75, location=(lx + 0.25 * sx, ly, 0.6))
    up = bpy.context.object; up.rotation_euler = (0, math.radians(55 * sx), 0); parts.append(up)
    bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.18, depth=0.6, location=(lx + 0.5 * sx, ly, 0.25))
    dn = bpy.context.object; parts.append(dn)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=6, radius=0.22, location=(lx + 0.5 * sx, ly, 0.06))
    ft = bpy.context.object; ft.scale = (1.1, 1.2, 0.6); parts.append(ft)
    legs.append((lx, ly, sx))
body = join(parts); body.name = "CrunchBody"
sel(body); bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
remesh_smooth(body, 0.035, 3)
# rocky surface: slicing chips + grain
for nm_, sc_, st_ in (("cr_chunk", 0.45, 0.11), ("cr_grain", 0.12, 0.025)):
    tx = bpy.data.textures.new(nm_, "CLOUDS"); tx.noise_scale = sc_; tx.noise_basis = "VORONOI_F2"
    m = body.modifiers.new(nm_, "DISPLACE"); m.texture = tx; m.strength = st_
apply_mods(body)
# crystal plates: faceted amber prisms on the back
crystals = []
row = [(-0.55, -0.55), (0.55, -0.55), (-0.62, 0.1), (0.62, 0.1), (-0.5, 0.75), (0.5, 0.75), (0.0, -0.15), (0.0, 0.55)]
for k, (x, y) in enumerate(row):
    centre = abs(x) < 0.1
    h = rnd.uniform(0.75, 1.0) * (1.25 if centre else 0.85)
    rr = rnd.uniform(0.26, 0.34) * (1.15 if centre else 1.0)
    bm = bmesh.new()
    base = [bm.verts.new((rr * math.cos(i * math.pi / 3), rr * math.sin(i * math.pi / 3), -0.15)) for i in range(6)]
    mid = [bm.verts.new((rr * 0.92 * math.cos(i * math.pi / 3), rr * 0.92 * math.sin(i * math.pi / 3), h * 0.68)) for i in range(6)]
    tip = bm.verts.new((0, 0, h))
    bm.faces.new(base[::-1])
    for i in range(6):
        j = (i + 1) % 6
        bm.faces.new((base[i], base[j], mid[j], mid[i]))
        bm.faces.new((mid[i], mid[j], tip))
    me = bpy.data.meshes.new(f"cry{k}"); bm.to_mesh(me); bm.free()
    co = bpy.data.objects.new(f"cry{k}", me); sc.collection.objects.link(co)
    zsurf = 0.85 + 0.55 * math.sqrt(max(0.0, 1 - (x / 1.35) ** 2 - ((y - 0.1) / 1.5) ** 2)) - 0.1
    lean = 0.0 if centre else (0.42 if x > 0 else -0.42)
    co.location = (x, y, zsurf); co.rotation_euler = (rnd.uniform(-0.15, 0.15), lean, rnd.uniform(0, 1.0))
    crystals.append(co)
# two glowing eyes on the head front
for sx in (-1, 1):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=0.15, location=(0.27 * sx, -1.72, 0.92))
    crystals.append(bpy.context.object)
cry = join(crystals); cry.name = "CrunchCrystals"
sel(cry); bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
# high = body + crystals; the crystal faces get their own material slot
hi = join([body, cry]); hi.name = "Crunch_high"
bpy.ops.object.shade_smooth()
lo = hi.copy(); lo.data = hi.data.copy(); lo.name = "Crunch"; sc.collection.objects.link(lo)
decimate_to(lo, 2600)
uv_unwrap(lo)

mat = bpy.data.materials.new("crunch_src"); mat.use_nodes = True
t = mat.node_tree; b = t.nodes["Principled BSDF"]
geo = t.nodes.new("ShaderNodeNewGeometry"); tc = t.nodes.new("ShaderNodeTexCoord")
# which surface is crystal: positions above the shell surface ellipsoid (crystals stick out of it)
pv = t.nodes.new("ShaderNodeVectorMath"); pv.operation = "SUBTRACT"; t.links.new(geo.outputs["Position"], pv.inputs[0]); pv.inputs[1].default_value = (0, 0.1, 0.85)
pd = t.nodes.new("ShaderNodeVectorMath"); pd.operation = "DIVIDE"; t.links.new(pv.outputs[0], pd.inputs[0]); pd.inputs[1].default_value = (1.35, 1.5, 0.55)
pl = t.nodes.new("ShaderNodeVectorMath"); pl.operation = "LENGTH"; t.links.new(pd.outputs[0], pl.inputs[0])
sepp = t.nodes.new("ShaderNodeSeparateXYZ"); t.links.new(geo.outputs["Position"], sepp.inputs[0])
above = t.nodes.new("ShaderNodeMath"); above.operation = "GREATER_THAN"; t.links.new(pl.outputs["Value"], above.inputs[0]); above.inputs[1].default_value = 1.12
high_ = t.nodes.new("ShaderNodeMath"); high_.operation = "GREATER_THAN"; t.links.new(sepp.outputs[2], high_.inputs[0]); high_.inputs[1].default_value = 1.18
is_cry = t.nodes.new("ShaderNodeMath"); is_cry.operation = "MULTIPLY"; t.links.new(above.outputs[0], is_cry.inputs[0]); t.links.new(high_.outputs[0], is_cry.inputs[1])
# rock: charcoal with yellow glowing cracks (voronoi edges), darker in cavities
vor = t.nodes.new("ShaderNodeTexVoronoi"); vor.feature = "DISTANCE_TO_EDGE"; vor.inputs["Scale"].default_value = 1.7
t.links.new(tc.outputs["Object"], vor.inputs["Vector"])
crack = t.nodes.new("ShaderNodeMath"); crack.operation = "LESS_THAN"; t.links.new(vor.outputs["Distance"], crack.inputs[0]); crack.inputs[1].default_value = 0.024
nz = t.nodes.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 6; nz.inputs["Detail"].default_value = 8; t.links.new(tc.outputs["Object"], nz.inputs["Vector"])
rock = t.nodes.new("ShaderNodeValToRGB"); t.links.new(nz.outputs["Fac"], rock.inputs[0])
rock.color_ramp.elements[0].color = (0.10, 0.095, 0.10, 1); rock.color_ramp.elements[1].color = (0.27, 0.26, 0.25, 1)   # lighter (ChatGPT alien audit: charcoal blended into dark rocks)
ao = t.nodes.new("ShaderNodeAmbientOcclusion"); ao.inputs["Distance"].default_value = 0.3
rk = t.nodes.new("ShaderNodeMix"); rk.data_type = "RGBA"; rk.blend_type = "MULTIPLY"; rk.inputs[0].default_value = 0.8
t.links.new(rock.outputs["Color"], rk.inputs[6]); t.links.new(ao.outputs["AO"], rk.inputs[7])
rkc = t.nodes.new("ShaderNodeMix"); rkc.data_type = "RGBA"; t.links.new(crack.outputs[0], rkc.inputs[0])
t.links.new(rk.outputs[2], rkc.inputs[6]); rkc.inputs[7].default_value = (1.0, 0.62, 0.05, 1)
# crystal: amber gradient by height with a pale tip
cg = t.nodes.new("ShaderNodeMapRange"); t.links.new(sepp.outputs[2], cg.inputs[0]); cg.inputs[1].default_value = 1.3; cg.inputs[2].default_value = 2.3
cr = t.nodes.new("ShaderNodeValToRGB"); t.links.new(cg.outputs[0], cr.inputs[0])
cr.color_ramp.elements[0].color = (0.85, 0.28, 0.0, 1); cr.color_ramp.elements[1].color = (1.0, 0.72, 0.2, 1)
final0 = t.nodes.new("ShaderNodeMix"); final0.data_type = "RGBA"; t.links.new(is_cry.outputs[0], final0.inputs[0])
t.links.new(rkc.outputs[2], final0.inputs[6]); t.links.new(cr.outputs["Color"], final0.inputs[7])
eyed = t.nodes.new("ShaderNodeVectorMath"); eyed.operation = "MULTIPLY"; t.links.new(geo.outputs["Position"], eyed.inputs[0]); eyed.inputs[1].default_value = (1, 1, 1)
ex = t.nodes.new("ShaderNodeSeparateXYZ"); t.links.new(geo.outputs["Position"], ex.inputs[0])
eax = t.nodes.new("ShaderNodeMath"); eax.operation = "ABSOLUTE"; t.links.new(ex.outputs[0], eax.inputs[0])
ev = t.nodes.new("ShaderNodeCombineXYZ"); t.links.new(eax.outputs[0], ev.inputs[0]); t.links.new(ex.outputs[1], ev.inputs[1]); t.links.new(ex.outputs[2], ev.inputs[2])
edist = t.nodes.new("ShaderNodeVectorMath"); edist.operation = "DISTANCE"; t.links.new(ev.outputs[0], edist.inputs[0]); edist.inputs[1].default_value = (0.27, -1.72, 0.92)
iseye = t.nodes.new("ShaderNodeMath"); iseye.operation = "LESS_THAN"; t.links.new(edist.outputs["Value"], iseye.inputs[0]); iseye.inputs[1].default_value = 0.19
pupd = t.nodes.new("ShaderNodeMath"); pupd.operation = "LESS_THAN"; t.links.new(edist.outputs["Value"], pupd.inputs[0]); pupd.inputs[1].default_value = 0.0
final1 = t.nodes.new("ShaderNodeMix"); final1.data_type = "RGBA"; t.links.new(iseye.outputs[0], final1.inputs[0])
t.links.new(final0.outputs[2], final1.inputs[6]); final1.inputs[7].default_value = (1.0, 0.85, 0.15, 1)
final = final1
t.links.new(final.outputs[2], b.inputs["Base Color"])
gloss = t.nodes.new("ShaderNodeMath"); gloss.operation = "MAXIMUM"; t.links.new(is_cry.outputs[0], gloss.inputs[0]); t.links.new(iseye.outputs[0], gloss.inputs[1])
rough = t.nodes.new("ShaderNodeMix"); rough.data_type = "FLOAT"; t.links.new(gloss.outputs[0], rough.inputs[0])
rough.inputs[2].default_value = 0.88; rough.inputs[3].default_value = 0.1
t.links.new(rough.outputs[0], b.inputs["Roughness"])
hi.data.materials.clear(); hi.data.materials.append(mat)
bake_maps("crunch", lo, hi, mat, {"color": final.outputs[2], "rough": rough.outputs[0]})

bones = [("Root", (0, 0, 0), (0, 0, 0.3), None),
         ("Body", (0, 0.6, 0.85), (0, -0.6, 0.85), "Root"),
         ("Head", (0, -0.9, 0.8), (0, -1.6, 0.85), "Body"),
         ("Shell", (0, 0.2, 1.2), (0, 0.2, 1.9), "Body")]
for i, (lx, ly, sx) in enumerate(legs):
    nm = ("LegFL", "LegFR", "LegBL", "LegBR")[i]
    bones.append((nm, (lx, ly, 0.75), (lx + 0.5 * sx, ly, 0.1), "Body"))
arm = armature("Crunch", bones)
skin(lo, arm)
preview("crunch", [lo], 2.2)
finish("Crunch", lo, arm, [hi])
print("ALIENS_OK")
