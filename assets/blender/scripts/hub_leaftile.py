# Alien Fusion hub: a REAL overlapping-leaf texture tile for the Moonwood canopies (30 Oct 2026; reference
# design\concepts\hub\C4-moonwood-materials-chatgpt.png panels 2-3). Node shaders only gave tiles or dots, so this models
# a 4 x 4 stud patch of shingled leaves (staggered rows, each leaf tilted so its tip lies over the base of the leaf
# below, like roof tiles), renders it straight down (orthographic) into a tileable COLOUR image and a HEIGHT image.
# exec'd by hub_moonwood_tex.py: make_leaf_tile(tex_dir) -> ({"color": img, "height": img}, period_studs)
import bpy, bmesh, math, os, random

def make_leaf_tile(tex_dir, px=1024):
    tile = bpy.data.scenes.new("LeafTile")
    tile.render.engine = "CYCLES"; tile.cycles.samples = 8; tile.cycles.device = "CPU"
    tile.render.resolution_x = tile.render.resolution_y = px
    tile.view_settings.view_transform = "Standard"
    w = bpy.data.worlds.new("tileW"); tile.world = w; w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    P, SX, SY = 4.0, 1.0, 4.0 / 6                     # period; column + row spacing (6 rows so the stagger tiles)
    # one leaf: a flat teardrop, wide near the base (+Y), pointed tip at -Y, slightly cupped
    me = bpy.data.meshes.new("leaf"); bm = bmesh.new()
    prof = [(0.0, 0.42), (0.30, 0.36), (0.46, 0.12), (0.44, -0.20), (0.30, -0.52), (0.12, -0.80), (0.0, -0.92)]
    rows = []
    for (hw, y) in prof:
        if hw == 0: rows.append([bm.verts.new((0, y, 0))]); continue
        cup = 0.10 * (hw / 0.46) ** 2
        rows.append([bm.verts.new((-hw, y, cup)), bm.verts.new((0, y, 0)), bm.verts.new((hw, y, cup))])
    for i in range(len(rows) - 1):
        A, B = rows[i], rows[i + 1]
        if len(A) == 1: bm.faces.new((A[0], B[0], B[1])); bm.faces.new((A[0], B[1], B[2]))
        elif len(B) == 1: bm.faces.new((A[0], A[1], B[0])); bm.faces.new((A[1], A[2], B[0]))
        else: bm.faces.new((A[0], B[0], B[1], A[1])); bm.faces.new((A[1], B[1], B[2], A[2]))
    bm.to_mesh(me); bm.free()

    def mat(height):
        m = bpy.data.materials.new("leafH" if height else "leafC"); m.use_nodes = True; nt = m.node_tree
        for n in list(nt.nodes):
            if n.type != "OUTPUT_MATERIAL": nt.nodes.remove(n)
        out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
        em = nt.nodes.new("ShaderNodeEmission"); nt.links.new(em.outputs[0], out.inputs["Surface"])
        if height:                                          # world Z 0..0.55 -> 0..1
            geo = nt.nodes.new("ShaderNodeNewGeometry"); s2 = nt.nodes.new("ShaderNodeSeparateXYZ"); nt.links.new(geo.outputs["Position"], s2.inputs[0])
            mr = nt.nodes.new("ShaderNodeMapRange"); mr.inputs[1].default_value = 0.0; mr.inputs[2].default_value = 0.55
            nt.links.new(s2.outputs[2], mr.inputs[0]); nt.links.new(mr.outputs[0], em.inputs["Color"])
            return m
        tc = nt.nodes.new("ShaderNodeTexCoord"); sp = nt.nodes.new("ShaderNodeSeparateXYZ"); nt.links.new(tc.outputs["Object"], sp.inputs[0])
        t = nt.nodes.new("ShaderNodeMapRange"); t.inputs[1].default_value = 0.42; t.inputs[2].default_value = -0.92
        nt.links.new(sp.outputs[1], t.inputs[0])
        ramp = nt.nodes.new("ShaderNodeValToRGB"); nt.links.new(t.outputs[0], ramp.inputs[0])
        e = ramp.color_ramp.elements
        # (r4, ChatGPT texture audit r1 albedo targets, sRGB -> linear: shadowed base 115,88,159; base 150,122,193;
        #  mid 195,175,225; tip 232,220,245 - silver-lilac on top, violet only in the overlaps)
        e[0].position = 0.0; e[0].color = (0.171, 0.098, 0.347, 1)      # base in the overlap shadow
        e[1].position = 1.0; e[1].color = (0.807, 0.716, 0.913, 1)      # silver-lilac tip
        e.new(0.38).color = (0.305, 0.195, 0.533, 1); e.new(0.72).color = (0.546, 0.429, 0.753, 1)
        ab = nt.nodes.new("ShaderNodeMath"); ab.operation = "ABSOLUTE"; nt.links.new(sp.outputs[0], ab.inputs[0])
        rib = nt.nodes.new("ShaderNodeMapRange"); rib.inputs[1].default_value = 0.0; rib.inputs[2].default_value = 0.05
        rib.inputs[3].default_value = 0.78; rib.inputs[4].default_value = 1.0; nt.links.new(ab.outputs[0], rib.inputs[0])
        oi = nt.nodes.new("ShaderNodeObjectInfo")
        jr = nt.nodes.new("ShaderNodeMapRange"); jr.inputs[3].default_value = 0.84; jr.inputs[4].default_value = 1.10
        nt.links.new(oi.outputs["Random"], jr.inputs[0])
        mul = nt.nodes.new("ShaderNodeMath"); mul.operation = "MULTIPLY"
        nt.links.new(rib.outputs[0], mul.inputs[0]); nt.links.new(jr.outputs[0], mul.inputs[1])
        cc = nt.nodes.new("ShaderNodeCombineColor")
        for i in range(3): nt.links.new(mul.outputs[0], cc.inputs[i])
        m1 = nt.nodes.new("ShaderNodeMix"); m1.data_type = "RGBA"; m1.blend_type = "MULTIPLY"; m1.inputs["Factor"].default_value = 1.0
        nt.links.new(ramp.outputs[0], m1.inputs["A"]); nt.links.new(cc.outputs[0], m1.inputs["B"])
        nt.links.new(m1.outputs["Result"], em.inputs["Color"])
        return m
    mc, mh = mat(False), mat(True)
    me.materials.append(mc)
    nrow, ncol = int(round(P / SY)), int(round(P / SX))
    for r in range(-2, nrow + 2):
        for c in range(-1, ncol + 2):
            rr, cc = r % nrow, c % ncol
            g = random.Random(rr * 97 + cc * 13)              # identical jitter on wrapped copies: seamless tile
            x = c * SX + (0.5 * SX if rr % 2 else 0) + g.uniform(-0.08, 0.08) - P / 2
            y = P / 2 - r * SY + g.uniform(-0.05, 0.05)
            o = bpy.data.objects.new("lf", me); tile.collection.objects.link(o)
            # rows further down sit higher, so each row's tips lie over the bases of the row below (wraps: use rr)
            o.location = (x, y, 0.05 + 0.05 * rr + 0.02 * g.uniform(-1, 1))
            s = g.uniform(1.05, 1.25); o.scale = (s, s * 1.1, s)
            o.rotation_euler = (math.radians(-22 + g.uniform(-4, 4)), 0, math.radians(g.uniform(-9, 9)))
    cam = bpy.data.objects.new("tcam", bpy.data.cameras.new("tcam")); tile.collection.objects.link(cam); tile.camera = cam
    cam.data.type = "ORTHO"; cam.data.ortho_scale = P; cam.location = (0, 0, 10)
    paths = {}
    for kind, m in (("color", mc), ("height", mh)):
        me.materials[0] = m
        bg.inputs[0].default_value = (0.171, 0.098, 0.347, 1) if kind == "color" else (0, 0, 0, 1)
        tile.render.filepath = os.path.join(tex_dir, f"moonwood_leaftile_{kind}.png")
        prev = bpy.context.window.scene if bpy.context.window else None
        bpy.ops.render.render(write_still=True, scene=tile.name)
        paths[kind] = tile.render.filepath
    imgs = {k: bpy.data.images.load(p) for k, p in paths.items()}
    imgs["height"].colorspace_settings.name = "Non-Color"
    print("LEAFTILE", paths)
    return imgs, P
