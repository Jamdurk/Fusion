# Alien Fusion: Moon rocks (boulders + spires), sculpted high-detail in Blender and baked down to light game meshes.
#   blender --background --factory-startup --python props_rocks.py -- <assets_dir> [atlas_size]
# For each rock: a dense displaced sculpt (craters / fractures / grain) -> a decimated low mesh (phone budget) ->
# all lows of a set share ONE UV atlas -> Cycles bakes colour (with cavity + top dust), roughness and a tangent normal
# map from the sculpt onto the atlas. Writes moon_rocks.blend (collection "MoonRocks", lows only, image-textured,
# ready for `blender.mjs export`) + textures + a preview render. Rocks sit on Z = 0, spaced along X.
import bpy, bmesh, math, os, sys, random
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
root = argv[0]
ATLAS = int(argv[1]) if len(argv) > 1 else 1024
blend_dir = os.path.join(root, "blender", "props"); tex_dir = os.path.join(root, "textures", "props")
os.makedirs(blend_dir, exist_ok=True); os.makedirs(tex_dir, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = 24
random.seed(5)

# name, kind, size (x, y, z studs), low tris, seed
ROCKS = [
    ("Boulder1", "boulder", (4.5, 3.8, 3.0), 1200, 1),
    ("Boulder2", "boulder", (7.0, 5.5, 4.2), 1600, 2),
    ("Boulder3", "boulder", (9.5, 8.0, 5.5), 2000, 3),
    ("Boulder4", "boulder", (13.0, 10.0, 7.0), 2600, 4),
    ("Spire1", "spire", (7.0, 6.0, 15.0), 2400, 5),
    ("Spire2", "spire", (9.0, 8.0, 22.0), 3000, 6),
    ("Spire3", "spire", (12.0, 10.0, 30.0), 3800, 7),
]


def tex(kind, name, **kw):
    t = bpy.data.textures.new(name, kind)
    for k, v in kw.items():
        setattr(t, k, v)
    return t


def displace(obj, texture, strength, size_coords="LOCAL", mid=0.5):
    m = obj.modifiers.new("D" + texture.name, "DISPLACE")
    m.texture = texture; m.strength = strength; m.mid_level = mid; m.texture_coords = size_coords
    return m


def make_high(name, kind, size, seed):
    """fractured rock: an icosphere sliced by random planes (angular faces, sharp-ish edges), voxel-remeshed to an even
    dense mesh, then small chips, pits and grain. Spires are tapered + leaning columns sliced the same way."""
    bpy.ops.object.select_all(action="DESELECT")
    rnd = random.Random(seed * 101)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=3, radius=1.0)
    if kind == "spire":
        for v in bm.verts:
            t = (v.co.z + 1) / 2
            taper = 1.0 - 0.75 * t ** 1.3
            v.co.x *= taper; v.co.y *= taper
            v.co.x += 0.22 * t * t
    cuts = 14 if kind == "boulder" else 30
    for i in range(cuts):
        if kind == "spire":   # mostly side cuts: a jagged, faceted column instead of a cone
            n = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.25, 0.55))).normalized()
            d = rnd.uniform(0.32, 0.62)
        else:
            n = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.6, 1.0))).normalized()
            d = rnd.uniform(0.55, 0.86)
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=n * d, plane_no=n, clear_outer=True)
        edges = [e for e in bm.edges if e.is_boundary]
        if edges:
            bmesh.ops.holes_fill(bm, edges=edges, sides=0)
    # a flat-ish underside
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=Vector((0, 0, -0.55)), plane_no=Vector((0, 0, -1)), clear_outer=True)
    edges = [e for e in bm.edges if e.is_boundary]
    if edges:
        bmesh.ops.holes_fill(bm, edges=edges, sides=0)
    me = bpy.data.meshes.new(name + "_high"); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name + "_high", me); sc.collection.objects.link(o)
    bpy.context.view_layer.objects.active = o; o.select_set(True)
    o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(scale=True)
    rm = o.modifiers.new("remesh", "REMESH"); rm.mode = "VOXEL"; rm.voxel_size = max(size) / (140.0 if kind == "boulder" else 220.0); rm.adaptivity = 0
    bpy.ops.object.modifier_apply(modifier="remesh")
    s = max(size)
    t1 = tex("CLOUDS", f"{name}_chips", noise_scale=s * 0.09, noise_depth=4, noise_basis="VORONOI_F2")
    displace(o, t1, s * 0.03)
    t2 = tex("VORONOI", f"{name}_pits", noise_scale=s * 0.06, distance_metric="DISTANCE_SQUARED")
    t2.color_mode = "INTENSITY"
    displace(o, t2, s * 0.012, mid=0.1)
    t3 = tex("CLOUDS", f"{name}_grain", noise_scale=0.15, noise_depth=2)
    displace(o, t3, 0.04)
    for mm in list(o.modifiers):
        bpy.ops.object.modifier_apply(modifier=mm.name)
    # sit on the ground: bottom flattened a little and pushed to Z = 0 (slightly sunk)
    zmin = min(v.co.z for v in o.data.vertices)
    for v in o.data.vertices:
        v.co.z -= zmin + size[2] * 0.08
        if v.co.z < 0:
            v.co.z *= 0.35
    bpy.ops.object.shade_smooth()
    return o


def rock_material(name):
    """procedural rock for the HIGH mesh: grey grain, darker cavities (AO), light regolith dust on upward faces"""
    m = bpy.data.materials.new(name); m.use_nodes = True
    t = m.node_tree; b = t.nodes["Principled BSDF"]
    geo = t.nodes.new("ShaderNodeNewGeometry")
    ao = t.nodes.new("ShaderNodeAmbientOcclusion"); ao.inputs["Distance"].default_value = 1.2; ao.samples = 16
    nz = t.nodes.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 1.6; nz.inputs["Detail"].default_value = 10
    fine = t.nodes.new("ShaderNodeTexNoise"); fine.inputs["Scale"].default_value = 14; fine.inputs["Detail"].default_value = 8
    rr = t.nodes.new("ShaderNodeValToRGB"); t.links.new(nz.outputs["Fac"], rr.inputs[0])
    rr.color_ramp.elements[0].position, rr.color_ramp.elements[0].color = 0.35, (0.20, 0.195, 0.19, 1)
    rr.color_ramp.elements[1].position, rr.color_ramp.elements[1].color = 0.70, (0.40, 0.39, 0.375, 1)
    # dust: up-facing normals
    sep = t.nodes.new("ShaderNodeSeparateXYZ"); t.links.new(geo.outputs["Normal"], sep.inputs[0])
    up = t.nodes.new("ShaderNodeMapRange"); t.links.new(sep.outputs[2], up.inputs[0]); up.inputs[1].default_value = 0.45; up.inputs[2].default_value = 0.85
    dustn = t.nodes.new("ShaderNodeMath"); dustn.operation = "MULTIPLY"; t.links.new(up.outputs[0], dustn.inputs[0]); t.links.new(fine.outputs["Fac"], dustn.inputs[1])
    dmr = t.nodes.new("ShaderNodeMapRange"); t.links.new(dustn.outputs[0], dmr.inputs[0]); dmr.inputs[1].default_value = 0.2; dmr.inputs[2].default_value = 0.5
    mixd = t.nodes.new("ShaderNodeMix"); mixd.data_type = "RGBA"
    t.links.new(dmr.outputs[0], mixd.inputs[0]); t.links.new(rr.outputs["Color"], mixd.inputs[6]); mixd.inputs[7].default_value = (0.55, 0.54, 0.52, 1)
    # cavities darker
    mixa = t.nodes.new("ShaderNodeMix"); mixa.data_type = "RGBA"; mixa.blend_type = "MULTIPLY"; mixa.inputs[0].default_value = 0.85
    t.links.new(mixd.outputs[2], mixa.inputs[6]); t.links.new(ao.outputs["AO"], mixa.inputs[7])
    t.links.new(mixa.outputs[2], b.inputs["Base Color"])
    rough = t.nodes.new("ShaderNodeMapRange"); t.links.new(fine.outputs["Fac"], rough.inputs[0]); rough.inputs[3].default_value = 0.78; rough.inputs[4].default_value = 0.95
    t.links.new(rough.outputs[0], b.inputs["Roughness"])
    m["color_socket"] = mixa.name; m["rough_socket"] = rough.name
    return m


coll = bpy.data.collections.new("MoonRocks"); sc.collection.children.link(coll)
highs, lows = [], []
x = 0.0
hmat = rock_material("rock_high")
for name, kind, size, tris, seed in ROCKS:
    hi = make_high(name, kind, size, seed)
    hi.location.x = x + size[0] / 2
    hi.data.materials.append(hmat)
    # low: copy + decimate to the budget
    lo = hi.copy(); lo.data = hi.data.copy(); lo.name = name
    sc.collection.objects.link(lo)
    dec = lo.modifiers.new("dec", "DECIMATE"); dec.ratio = tris / max(1, len(hi.data.polygons))
    bpy.context.view_layer.objects.active = lo; bpy.ops.object.modifier_apply(modifier="dec")
    bpy.ops.object.shade_smooth()
    lo.data.materials.clear()
    highs.append(hi); lows.append(lo)
    x += size[0] + 4
    print("ROCK", name, len(hi.data.polygons), "->", len(lo.data.polygons))

# two atlases: boulders, spires
sets = {"boulders": [l for l, r in zip(lows, ROCKS) if r[1] == "boulder"], "spires": [l for l, r in zip(lows, ROCKS) if r[1] == "spire"]}
for setname, objs in sets.items():
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.004)
    bpy.ops.uv.pack_islands(margin=0.004)
    bpy.ops.object.mode_set(mode="OBJECT")
    imgs = {}
    for kind, cs in (("color", "sRGB"), ("rough", "Non-Color"), ("normal", "Non-Color")):
        img = bpy.data.images.new(f"rocks_{setname}_{kind}", ATLAS, ATLAS); img.colorspace_settings.name = cs
        imgs[kind] = img
    lm = bpy.data.materials.new(f"Moon{setname.capitalize()}"); lm.use_nodes = True
    lt = lm.node_tree; lb = lt.nodes["Principled BSDF"]
    nodes = {}
    for kind in imgs:
        n = lt.nodes.new("ShaderNodeTexImage"); n.image = imgs[kind]; nodes[kind] = n
    lt.links.new(nodes["color"].outputs["Color"], lb.inputs["Base Color"])
    lt.links.new(nodes["rough"].outputs["Color"], lb.inputs["Roughness"])
    nm = lt.nodes.new("ShaderNodeNormalMap"); lt.links.new(nodes["normal"].outputs["Color"], nm.inputs["Color"]); lt.links.new(nm.outputs[0], lb.inputs["Normal"])
    for o in objs:
        o.data.materials.append(lm)
    # bake each low from its high into the shared atlas
    for kind in ("color", "rough", "normal"):
        lt.nodes.active = nodes[kind]
        first = True
        for o in objs:
            hi = bpy.data.objects[o.name + "_high"]
            bpy.ops.object.select_all(action="DESELECT")
            hi.select_set(True); o.select_set(True); bpy.context.view_layer.objects.active = o
            ht = hmat.node_tree; hb = ht.nodes["Principled BSDF"]; out = ht.nodes["Material Output"]
            if kind == "normal":
                ht.links.new(hb.outputs[0], out.inputs["Surface"])
                bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT", use_selected_to_active=True, cage_extrusion=0.6, max_ray_distance=1.2, use_clear=first, margin=8)
            else:
                emi = ht.nodes.get("bake_emit") or ht.nodes.new("ShaderNodeEmission"); emi.name = "bake_emit"
                src = ht.nodes[hmat["color_socket"]].outputs[2] if kind == "color" else ht.nodes[hmat["rough_socket"]].outputs[0]
                ht.links.new(src, emi.inputs["Color"]); ht.links.new(emi.outputs[0], out.inputs["Surface"])
                bpy.ops.object.bake(type="EMIT", use_selected_to_active=True, cage_extrusion=0.6, max_ray_distance=1.2, use_clear=first, margin=8)
            first = False
        img = imgs[kind]; img.filepath_raw = os.path.join(tex_dir, f"{img.name}.png"); img.file_format = "PNG"; img.save()
    print("BAKED", setname)

# keep only the lows in the export collection; highs stay in the file (hidden) as the editable source
for o in lows:
    for c in o.users_collection:
        c.objects.unlink(o)
    coll.objects.link(o)
hc = bpy.data.collections.new("HighSculpts"); sc.collection.children.link(hc)
for o in highs:
    for c in o.users_collection:
        c.objects.unlink(o)
    hc.objects.link(o); o.hide_render = True; o.hide_set(True)
for o in lows:
    bpy.context.view_layer.objects.active = o; o.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

# preview: lows under a low sun, on a grey floor
bpy.ops.mesh.primitive_plane_add(size=400, location=(x / 2, 0, -0.05))
floor = bpy.context.object; fm = bpy.data.materials.new("floor"); fm.use_nodes = True
fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.45, 0.44, 0.42, 1); floor.data.materials.append(fm)
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN")); sc.collection.objects.link(sun)
sun.data.energy = 4.5; sun.rotation_euler = (math.radians(60), 0, math.radians(35))
w = bpy.data.worlds.new("w"); sc.world = w
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam")); sc.collection.objects.link(cam); sc.camera = cam
cam.data.lens = 35; cam.location = (x / 2, -70, 26); cam.rotation_euler = (math.radians(74), 0, 0)
sc.render.resolution_x, sc.render.resolution_y = 1600, 700; sc.cycles.samples = 48
sc.render.filepath = os.path.join(tex_dir, "rocks_preview.png"); bpy.ops.render.render(write_still=True)
bpy.data.objects.remove(floor); bpy.data.objects.remove(sun); bpy.data.objects.remove(cam)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(blend_dir, "moon_rocks.blend"))
print("ROCKS_OK")
