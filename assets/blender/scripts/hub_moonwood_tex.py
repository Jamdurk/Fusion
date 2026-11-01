# Alien Fusion hub: TEXTURED Moonwood trees (30 Oct 2026; James: the trees look "very Robloxy ... is there more textures
# to go on top?"). Run AFTER hub_moonwood.py in the same Blender session:
#   blender --background --factory-startup --python hub_moonwood.py --python hub_moonwood_tex.py -- <obj_out_dir> <assets_dir>
# Reference: design\concepts\hub\C4-moonwood-materials-chatgpt.png:
#   bark = pearly twisted rope strands, fine vertical grain, lilac-grey grooves, pearly sheen;
#   canopy = overlapping rounded leaf scales, light silver-lilac tips, deep violet bases, darker underside (not navy).
# For each tree type the Bark and Canopy meshes get their own UVs and Cycles-baked colour (with AO), roughness and a
# tangent normal map (bark 512, canopy 1024), then go into collection "MoonwoodTex" in assets\blender\hub\moonwood_tex.blend
# for `blender.mjs export` (GLB -> Studio 3D Importer -> SurfaceAppearance). Pods / crystals / moss stay untextured
# (Neon / plain colours from the OBJ kit).
# The meshes were authored in ROBLOX space (x right, y up, z); GLB goes Blender -> Roblox as (-x, z, y), so every mesh
# is first moved into Blender space with (rx, ry, rz) -> (-rx, rz, ry) (a proper rotation, no mirror).
import bpy, bmesh, math, os, sys
from mathutils import Matrix

args = sys.argv[sys.argv.index("--") + 1:]
assets = args[1]
tex_dir = os.path.join(assets, "textures", "hub"); blend_dir = os.path.join(assets, "blender", "hub")
os.makedirs(tex_dir, exist_ok=True); os.makedirs(blend_dir, exist_ok=True)
sc = bpy.context.scene
sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = 16
R2B = Matrix(((-1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))

exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)) if "__file__" in dir() else r"D:/Roblox Game Venture/Games/Alien Fusion/assets/blender/scripts", "hub_leaftile.py")).read())
LEAF, LEAF_P = make_leaf_tile(tex_dir)

TREES = ["mwTall", "mwWide", "mwLow", "mwElder"]
targets = []
for t in TREES:
    for part, size in (("Bark", 1024), ("Canopy", 1024)):     # (r7: bark 512 -> 1024, it was blurry on the big trunks)
        targets.append((bpy.data.objects[t + part], part, size))
# (r6) the pods ride along untextured (plain colours set in Roblox): pale husk + stem, and the Neon drop
plain = [bpy.data.objects[t + part] for t in TREES for part in ("Pods", "PodGlow")]
for o in bpy.data.objects:                                 # everything else out of the way
    if o.type == "MESH" and o not in [x[0] for x in targets] + plain: bpy.data.objects.remove(o, do_unlink=True)
for o in [x[0] for x in targets] + plain:
    o.data.transform(R2B); o.data.update()
    for p in o.data.polygons: p.use_smooth = True
for o in plain:
    pm = bpy.data.materials.new(o.name + "_mat"); pm.use_nodes = True
    pb = pm.node_tree.nodes["Principled BSDF"]; pb.inputs["Metallic"].default_value = 0.0; pb.inputs["Roughness"].default_value = 0.6
    pb.inputs["Base Color"].default_value = (0.36, 0.22, 1.0, 1) if o.name.endswith("Glow") else (0.78, 0.70, 0.95, 1)
    o.data.materials.clear(); o.data.materials.append(pm)

def node(nt, kind, **kw):
    n = nt.nodes.new(kind)
    for k, v in kw.items(): setattr(n, k, v)
    return n

def bark_material(name):
    """(r7, James 30 Oct: "make sure the bark texture is also decent"; C4 panel 1: pearly rope strands twisting round the
    trunk, pale crests, darker lilac crevices, fine grain running ALONG each strand). Blender space: trunk axis = Z.
    phi = atan2(y, x) - 0.3 z follows a strand (0.3 rad per stud of twist, ~30 deg on a 2-stud trunk); 5 strands =
    sin(5 phi), shaped broad-crest / narrow-crevice; grain = noise sampled on a circle of radius 6 in phi (seamless at
    the atan2 wrap) and slow in z, so it streaks along the strands. Returns (material, colour socket, roughness socket)."""
    m = bpy.data.materials.new(name); m.use_nodes = True; nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    tc = node(nt, "ShaderNodeTexCoord")
    sep = node(nt, "ShaderNodeSeparateXYZ"); nt.links.new(tc.outputs["Object"], sep.inputs[0])
    def math_(op, a, b=None, v=None):
        n = node(nt, "ShaderNodeMath", operation=op)
        nt.links.new(a, n.inputs[0])
        if b is not None: nt.links.new(b, n.inputs[1])
        elif v is not None: n.inputs[1].default_value = v
        return n.outputs[0]
    theta = math_("ARCTAN2", sep.outputs[1], sep.outputs[0])
    phi = math_("SUBTRACT", theta, math_("MULTIPLY", sep.outputs[2], v=0.3))
    wave = math_("SINE", math_("MULTIPLY", phi, v=5.0))
    s01 = math_("ADD", math_("MULTIPLY", wave, v=0.5), v=0.5)                               # 0..1
    crest = math_("POWER", s01, v=0.55)                                                    # broad crests, thin crevices
    gx = math_("MULTIPLY", math_("COSINE", phi), v=6.0); gy = math_("MULTIPLY", math_("SINE", phi), v=6.0)
    gz = math_("MULTIPLY", sep.outputs[2], v=0.12)
    cv = node(nt, "ShaderNodeCombineXYZ"); nt.links.new(gx, cv.inputs[0]); nt.links.new(gy, cv.inputs[1]); nt.links.new(gz, cv.inputs[2])
    gr = node(nt, "ShaderNodeTexNoise"); gr.inputs["Scale"].default_value = 2.2; gr.inputs["Detail"].default_value = 10
    gr.inputs["Roughness"].default_value = 0.62; nt.links.new(cv.outputs[0], gr.inputs["Vector"])
    grain = node(nt, "ShaderNodeMapRange"); grain.inputs[1].default_value = 0.3; grain.inputs[2].default_value = 0.7
    nt.links.new(gr.outputs["Fac"], grain.inputs[0])
    height = node(nt, "ShaderNodeMix", data_type="FLOAT"); height.inputs["Factor"].default_value = 0.22
    nt.links.new(crest, height.inputs["A"]); nt.links.new(grain.outputs[0], height.inputs["B"])
    ramp = node(nt, "ShaderNodeValToRGB"); nt.links.new(crest, ramp.inputs[0])
    # linear; (r8: in Studio the shaded trunks went navy under the map exposure -0.4, so the albedo is pearlier:
    # crest ~ 252,248,252, crevice ~ 170,158,192; the crevices still read, only less deep)
    e = ramp.color_ramp.elements
    e[0].position = 0.0; e[0].color = (0.40, 0.34, 0.52, 1)
    e[1].position = 1.0; e[1].color = (0.97, 0.94, 0.97, 1)
    e.new(0.35).color = (0.72, 0.66, 0.80, 1); e.new(0.7).color = (0.90, 0.85, 0.93, 1)
    gm = node(nt, "ShaderNodeMapRange"); gm.inputs[3].default_value = 0.9; gm.inputs[4].default_value = 1.03
    nt.links.new(grain.outputs[0], gm.inputs[0])
    gc = node(nt, "ShaderNodeCombineColor"); [nt.links.new(gm.outputs[0], gc.inputs[i]) for i in range(3)]
    gmul = node(nt, "ShaderNodeMix", data_type="RGBA", blend_type="MULTIPLY"); gmul.inputs["Factor"].default_value = 1.0
    nt.links.new(ramp.outputs[0], gmul.inputs["A"]); nt.links.new(gc.outputs[0], gmul.inputs["B"])
    warm = node(nt, "ShaderNodeTexNoise"); warm.inputs["Scale"].default_value = 0.35; nt.links.new(tc.outputs["Object"], warm.inputs[0])
    tint = node(nt, "ShaderNodeMix", data_type="RGBA", blend_type="MULTIPLY")
    nt.links.new(gmul.outputs["Result"], tint.inputs["A"]); tint.inputs["B"].default_value = (1.0, 0.94, 0.88, 1)
    wf = math_("MULTIPLY", warm.outputs["Fac"], v=0.25); nt.links.new(wf, tint.inputs["Factor"])
    ao = node(nt, "ShaderNodeAmbientOcclusion"); ao.inputs["Distance"].default_value = 3.0
    aom = node(nt, "ShaderNodeMix", data_type="RGBA", blend_type="MULTIPLY"); aom.inputs["Factor"].default_value = 0.15
    nt.links.new(tint.outputs["Result"], aom.inputs["A"]); nt.links.new(ao.outputs["AO"], aom.inputs["B"])
    bump = node(nt, "ShaderNodeBump"); bump.inputs["Strength"].default_value = 1.0; bump.inputs["Distance"].default_value = 0.5
    nt.links.new(height.outputs["Result"], bump.inputs["Height"]); nt.links.new(bump.outputs[0], bsdf.inputs["Normal"])
    rr = node(nt, "ShaderNodeMapRange"); rr.inputs[3].default_value = 0.65; rr.inputs[4].default_value = 0.5   # audit: 0.5-0.65
    nt.links.new(crest, rr.inputs[0])
    nt.links.new(aom.outputs["Result"], bsdf.inputs["Base Color"]); nt.links.new(rr.outputs[0], bsdf.inputs["Roughness"])
    return m, aom.outputs["Result"], rr.outputs[0]

def canopy_material(name):
    """(r4) the modelled leaf tile (hub_leaftile.py), box-projected from Object coords (one tile = LEAF_P studs; on the
    sides the leaf tips point down), x a light-top / darker-underside factor, x mild AO; bump from the leaf height tile"""
    m = bpy.data.materials.new(name); m.use_nodes = True; nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    tc = node(nt, "ShaderNodeTexCoord")
    # (r5: leaves ~2x bigger, like C4 panel 2: a 4-stud tile is drawn over 7.5 studs)
    mp = node(nt, "ShaderNodeMapping"); s = 1.0 / (LEAF_P * 1.875); mp.inputs["Scale"].default_value = (s, s, s)
    nt.links.new(tc.outputs["Object"], mp.inputs[0])
    ci = node(nt, "ShaderNodeTexImage", projection="BOX", projection_blend=0.25); ci.image = LEAF["color"]
    hi = node(nt, "ShaderNodeTexImage", projection="BOX", projection_blend=0.25); hi.image = LEAF["height"]
    nt.links.new(mp.outputs[0], ci.inputs[0]); nt.links.new(mp.outputs[0], hi.inputs[0])
    geo = node(nt, "ShaderNodeNewGeometry"); sep = node(nt, "ShaderNodeSeparateXYZ"); nt.links.new(geo.outputs["Normal"], sep.inputs[0])
    hz = node(nt, "ShaderNodeMapRange"); hz.inputs[1].default_value = -1; hz.inputs[2].default_value = 1
    hz.inputs[3].default_value = 0.84; hz.inputs[4].default_value = 1.06
    nt.links.new(sep.outputs[2], hz.inputs[0])
    hcol = node(nt, "ShaderNodeCombineColor"); [nt.links.new(hz.outputs[0], hcol.inputs[i]) for i in range(3)]
    hmul = node(nt, "ShaderNodeMix", data_type="RGBA", blend_type="MULTIPLY"); hmul.inputs["Factor"].default_value = 1.0
    nt.links.new(ci.outputs["Color"], hmul.inputs["A"]); nt.links.new(hcol.outputs[0], hmul.inputs["B"])
    ao = node(nt, "ShaderNodeAmbientOcclusion"); ao.inputs["Distance"].default_value = 2.0
    aom = node(nt, "ShaderNodeMix", data_type="RGBA", blend_type="MULTIPLY"); aom.inputs["Factor"].default_value = 0.22
    nt.links.new(hmul.outputs["Result"], aom.inputs["A"]); nt.links.new(ao.outputs["AO"], aom.inputs["B"])
    bump = node(nt, "ShaderNodeBump"); bump.inputs["Strength"].default_value = 1.0; bump.inputs["Distance"].default_value = 0.25
    nt.links.new(hi.outputs["Color"], bump.inputs["Height"]); nt.links.new(bump.outputs[0], bsdf.inputs["Normal"])
    # (r6, ChatGPT texture audit r1: matte foliage, roughness 0.75-0.85, metalness 0)
    rr = node(nt, "ShaderNodeMapRange"); rr.inputs[3].default_value = 0.85; rr.inputs[4].default_value = 0.75
    nt.links.new(hi.outputs["Color"], rr.inputs[0])
    # (r6) the fringe blades (vertex float leafT > 0) get their own gradient: violet base -> lilac -> pale tip
    at = node(nt, "ShaderNodeAttribute", attribute_name="leafT")
    mask = node(nt, "ShaderNodeMapRange"); mask.inputs[1].default_value = 0.0; mask.inputs[2].default_value = 0.01
    nt.links.new(at.outputs["Fac"], mask.inputs[0])
    br = node(nt, "ShaderNodeValToRGB"); nt.links.new(at.outputs["Fac"], br.inputs[0]); be = br.color_ramp.elements
    be[0].position = 0.0; be[0].color = (0.171, 0.098, 0.347, 1)       # deep underside violet 115,88,159
    be[1].position = 1.0; be[1].color = (0.807, 0.716, 0.913, 1)       # pale tip 232,220,245
    be.new(0.45).color = (0.546, 0.429, 0.753, 1)                       # lilac 195,175,225
    fm = node(nt, "ShaderNodeMix", data_type="RGBA"); nt.links.new(mask.outputs[0], fm.inputs["Factor"])
    nt.links.new(aom.outputs["Result"], fm.inputs["A"]); nt.links.new(br.outputs[0], fm.inputs["B"])
    nt.links.new(fm.outputs["Result"], bsdf.inputs["Base Color"]); nt.links.new(rr.outputs[0], bsdf.inputs["Roughness"])
    return m, fm.outputs["Result"], rr.outputs[0]

def bake_object(o, part, size):
    bpy.ops.object.select_all(action="DESELECT"); o.select_set(True); bpy.context.view_layer.objects.active = o
    bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.004)
    bpy.ops.uv.pack_islands(margin=0.004)
    bpy.ops.object.mode_set(mode="OBJECT")
    proc, col_sock, rough_sock = (bark_material if part == "Bark" else canopy_material)(o.name + "_proc")
    o.data.materials.clear(); o.data.materials.append(proc)
    nt = proc.node_tree; bsdf = nt.nodes["Principled BSDF"]; out = nt.nodes["Material Output"]
    imgs = {}
    for kind, cs in (("color", "sRGB"), ("rough", "Non-Color"), ("normal", "Non-Color")):
        img = bpy.data.images.new(f"{o.name}_{kind}", size, size); img.colorspace_settings.name = cs; imgs[kind] = img
        tn = nt.nodes.new("ShaderNodeTexImage"); tn.image = img; tn.name = "bake_" + kind
    emi = nt.nodes.new("ShaderNodeEmission")
    # (r8, ChatGPT texture audit r2 fix 2: the canopy lobes shaded in harsh triangular facets) canopies bake FROM a
    # Catmull-Clark subdivided copy (level 2) onto the low mesh, so the normal map carries smooth lobes; tris unchanged
    hi = None; sel = {}
    if part == "Canopy":
        # (the thin fringe blades would shrink to nothing under subdivision: they bake from an unsubdivided copy)
        def part_copy(suffix, keep_blades):
            c = o.copy(); c.data = o.data.copy(); c.name = o.name + suffix; bpy.context.scene.collection.objects.link(c)
            bm = bmesh.new(); bm.from_mesh(c.data); lt = bm.verts.layers.float.get("leafT")
            bmesh.ops.delete(bm, geom=[v for v in bm.verts if (v[lt] > 0) != keep_blades], context="VERTS")
            bm.to_mesh(c.data); bm.free(); return c
        hi = [part_copy("_hi", False), part_copy("_blades", True)]
        sm = hi[0].modifiers.new("sub", "SUBSURF"); sm.levels = sm.render_levels = 2
        bpy.ops.object.select_all(action="DESELECT"); [c.select_set(True) for c in hi]; o.select_set(True); bpy.context.view_layer.objects.active = o
        sel = dict(use_selected_to_active=True, cage_extrusion=0.6, max_ray_distance=1.5)
    for kind in ("normal", "color", "rough"):
        nt.nodes.active = nt.nodes["bake_" + kind]
        if kind == "normal":
            nt.links.new(bsdf.outputs[0], out.inputs["Surface"])
            bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT", margin=8, use_clear=True, **sel)
        else:
            nt.links.new(col_sock if kind == "color" else rough_sock, emi.inputs["Color"])
            nt.links.new(emi.outputs[0], out.inputs["Surface"])
            bpy.ops.object.bake(type="EMIT", margin=8, use_clear=True, **sel)
        img = imgs[kind]; img.filepath_raw = os.path.join(tex_dir, f"{img.name}.png"); img.file_format = "PNG"; img.save()
    for c in (hi or []): bpy.data.objects.remove(c, do_unlink=True)
    # the final, export material: just the three images (what the GLB carries)
    fm = bpy.data.materials.new(o.name + "_mat"); fm.use_nodes = True; ft = fm.node_tree; fb = ft.nodes["Principled BSDF"]
    t = {}
    for kind in imgs:
        n = ft.nodes.new("ShaderNodeTexImage"); n.image = imgs[kind]; t[kind] = n
    ft.links.new(t["color"].outputs["Color"], fb.inputs["Base Color"])
    ft.links.new(t["rough"].outputs["Color"], fb.inputs["Roughness"])
    nm = ft.nodes.new("ShaderNodeNormalMap"); ft.links.new(t["normal"].outputs["Color"], nm.inputs["Color"]); ft.links.new(nm.outputs[0], fb.inputs["Normal"])
    fb.inputs["Metallic"].default_value = 0.0
    o.data.materials.clear(); o.data.materials.append(fm)
    print("BAKED", o.name, size)

for o, part, size in targets: bake_object(o, part, size)

coll = bpy.data.collections.new("MoonwoodTex"); sc.collection.children.link(coll)
for o in [x[0] for x in targets] + plain:
    for c in list(o.users_collection): c.objects.unlink(o)
    coll.objects.link(o)
path = os.path.join(blend_dir, "moonwood_tex.blend")
bpy.ops.wm.save_as_mainfile(filepath=path)
print("SAVED", path, "tris", {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in [x[0] for x in targets] + plain})
