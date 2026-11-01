# Crystal Canyon kit: Cycles-baked PBR textures (31 Oct 2026). Run AFTER hub_crystalcanyon.py in the same Blender session:
#   blender -b --factory-startup --python hub_crystalcanyon.py --python hub_crystalcanyon_tex.py -- <assets_dir> full
# References: design\concepts\hub\E3-crystal-canyon-materials-chatgpt.png + its hex / roughness table
# (crystal-canyon\E3-reply.txt). Same machinery as hub_goomarsh_tex.py: per group colour (sRGB), roughness, tangent normal
# and an emissive mask (-> SurfaceAppearance EmissiveMaskContent), baked at 2x and downscaled (LESSONS 14), one texture
# set per GROUP (atlas), 1024 max, metalness 0. Pieces with a "_hi" copy bake their normal from it (rock chips); the seam
# plates (hi["allbake"]) bake EVERY map from the dense high mesh (its crack float is too fine for the game mesh).
# Output: assets\textures\hub\cc<Group>_{color,rough,normal,emit}.png + assets\blender\hub\crystalcanyon_tex.blend
# (collection CrystalCanyonTex) for `blender.mjs export`.
import bpy, bmesh, math, os, sys

args = sys.argv[sys.argv.index("--") + 1:]
ASSETS = args[0]
tex_dir = os.path.join(ASSETS, "textures", "hub"); blend_dir = os.path.join(ASSETS, "blender", "hub")
os.makedirs(tex_dir, exist_ok=True); os.makedirs(blend_dir, exist_ok=True)
sc = bpy.context.scene
sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = 12
ONLY = os.environ.get("CC_ONLY")                             # e.g. "spireCrystal,basalt" to rebake a few groups while tuning

def lin(h):                                                  # "#RRGGBB" (sRGB) -> linear RGBA
    c = [int(h[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    return tuple((x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4) for x in c) + (1.0,)

# ---------------------------------------------------------------- node helpers
class NT:
    def __init__(self, m): self.nt = m.node_tree; self.m = m
    def n(self, kind, **kw):
        x = self.nt.nodes.new(kind)
        for k, v in kw.items(): setattr(x, k, v)
        return x
    def sock(self, node, name, out=False):
        ss = node.outputs if out else node.inputs
        return next(s for s in ss if s.name == name and s.enabled)
    def link(self, a, b): self.nt.links.new(a, b)
    def math(self, op, a, b=None, v=None, clamp=False):
        x = self.n("ShaderNodeMath", operation=op, use_clamp=clamp)
        self.feed(x.inputs[0], a)
        if b is not None: self.feed(x.inputs[1], b)
        elif v is not None: x.inputs[1].default_value = v
        return x.outputs[0]
    def feed(self, inp, val):
        if isinstance(val, (int, float)): inp.default_value = val
        else: self.link(val, inp)
    def mr(self, val, a, b, c=0.0, d=1.0, clamp=True):          # map range a..b -> c..d
        x = self.n("ShaderNodeMapRange", clamp=clamp); self.feed(x.inputs[0], val)
        x.inputs[1].default_value, x.inputs[2].default_value, x.inputs[3].default_value, x.inputs[4].default_value = a, b, c, d
        return x.outputs[0]
    def ramp(self, val, stops):
        x = self.n("ShaderNodeValToRGB"); self.feed(x.inputs[0], val); e = x.color_ramp.elements
        e[0].position, e[0].color = stops[0]; e[1].position, e[1].color = stops[-1]
        for p, c in stops[1:-1]: e.new(p).color = c
        return x.outputs[0]
    def mix(self, a, b, f, blend="MIX"):
        x = self.n("ShaderNodeMix", data_type="RGBA", blend_type=blend)
        self.feed(self.sock(x, "Factor"), f)
        if isinstance(a, tuple): self.sock(x, "A").default_value = a
        else: self.link(a, self.sock(x, "A"))
        if isinstance(b, tuple): self.sock(x, "B").default_value = b
        else: self.link(b, self.sock(x, "B"))
        return self.sock(x, "Result", True)
    def attr(self, name): return self.n("ShaderNodeAttribute", attribute_name=name).outputs["Fac"]
    def coord(self, scale=1.0, warp=None):
        tc = self.n("ShaderNodeTexCoord").outputs["Object"]
        if scale == 1.0 and warp is None: return tc
        mp = self.n("ShaderNodeVectorMath", operation="SCALE"); self.link(tc, mp.inputs[0])
        self.sock(mp, "Scale").default_value = scale; return mp.outputs[0]
    def noise(self, vec, scale, detail=4.0, rough=0.55, out="Fac"):
        x = self.n("ShaderNodeTexNoise"); self.link(vec, x.inputs["Vector"])
        x.inputs["Scale"].default_value = scale; x.inputs["Detail"].default_value = detail; x.inputs["Roughness"].default_value = rough
        return x.outputs[out]
    def voronoi(self, vec, scale, feature="F1", out="Distance", rand=1.0):
        x = self.n("ShaderNodeTexVoronoi", feature=feature); self.link(vec, x.inputs["Vector"])
        x.inputs["Scale"].default_value = scale; x.inputs["Randomness"].default_value = rand
        return x.outputs[out]
    def ao(self, dist, inside=False):
        x = self.n("ShaderNodeAmbientOcclusion", inside=inside, only_local=True, samples=24); x.inputs["Distance"].default_value = dist   # (tex r2: every kit piece sits at the origin: AO must ignore the others)
        return x.outputs["AO"]
    def geo(self, out): return self.n("ShaderNodeNewGeometry").outputs[out]
    def nz(self):                                                       # world normal z (up-facing = 1)
        sep = self.n("ShaderNodeSeparateXYZ"); self.link(self.geo("Normal"), sep.inputs[0]); return sep.outputs[2]
    def bump(self, h, strength, dist):
        x = self.n("ShaderNodeBump"); x.inputs["Strength"].default_value = strength; x.inputs["Distance"].default_value = dist
        self.link(h, x.inputs["Height"]); return x.outputs[0]
    def n_out(self, node):                                              # a Vector Math node's scalar output (DOT_PRODUCT)
        return next(s for s in node.outputs if s.name == "Value" and s.enabled)

def new_mat(name):
    m = bpy.data.materials.new(name); m.use_nodes = True; return m, NT(m)

# ---------------------------------------------------------------- the procedural materials (E3 hex targets, E3-reply.txt)
# (LESSONS 15 / 24: ChatGPT's basalt #62636C is ~0.12 linear = reads black in game under bright seams: kept 0.15-0.32)
CRY = dict(deep=lin("#A73B1B"), root=lin("#DD7A2B"), base=lin("#F5A029"), glow=lin("#FFCC6A"), hi=lin("#FFF1B9"))
def crystal_material(name, thick=2.0, craq=1.0):
    """amber quartz (E3 #1 / #2): deep red-orange root -> golden body -> pale gold tip along cT, per-crystal tint (cI),
    a fine CRAQUELURE of pale fracture lines on the faces (E3 #1), soft internal veils, bright bevelled facet edges
    (Bevel node vs true normal), frosted roughness; emission = core thickness + fractures + the root zone, NOT whole faces"""
    m, t = new_mat(name)
    co = t.coord(); ctt = t.attr("cT"); ci = t.attr("cI")
    # (Blender audit r1 fix 2: pale yellow) deep root -> #D85A1F lower third (25-35 % of the length) -> body -> core -> tip
    col = t.ramp(ctt, [(0.0, CRY["deep"]), (0.14, lin("#D85A1F")), (0.3, CRY["root"]), (0.5, CRY["base"]), (0.9, CRY["glow"]), (1.0, CRY["hi"])])
    col = t.mix(col, CRY["root"], t.math("MULTIPLY", t.mr(ci, 0.0, 1.0, 0.0, 0.35), t.mr(ctt, 0.2, 0.9, 1.0, 0.3)))   # some crystals redder
    veil = t.mr(t.noise(t.coord(), 0.16, 3.0, 0.55), 0.5, 0.8)                             # (fix 2: larger, fainter veils)
    col = t.mix(col, CRY["glow"], t.math("MULTIPLY", veil, v=0.18))   # (tex r3: r2 read pale yellow; E2 is richer amber)
    deep = t.mr(t.noise(co, 0.8, 3.0, 0.5), 0.55, 0.75)                                    # darker inner patches
    col = t.mix(col, CRY["deep"], t.math("MULTIPLY", deep, v=0.32))
    # (fix 2) a few big irregular internal fracture PLANES: large warped Voronoi edges, faint, lighter
    fp = t.n("ShaderNodeTexVoronoi", feature="DISTANCE_TO_EDGE"); t.link(co, fp.inputs["Vector"]); fp.inputs["Scale"].default_value = 0.35
    plane = t.math("MULTIPLY", t.mr(fp.outputs["Distance"], 0.06, 0.0), t.mr(t.noise(co, 0.3, 2.0), 0.45, 0.62))
    col = t.mix(col, CRY["glow"], t.math("MULTIPLY", plane, v=0.45))
    # craquelure: warped Voronoi edges at two scales -> thin pale lines
    wv = t.n("ShaderNodeVectorMath", operation="ADD"); t.link(co, wv.inputs[0])
    wn = t.n("ShaderNodeTexNoise"); t.link(co, wn.inputs["Vector"]); wn.inputs["Scale"].default_value = 1.2
    wsc = t.n("ShaderNodeVectorMath", operation="SCALE"); t.link(wn.outputs["Color"], wsc.inputs[0]); t.sock(wsc, "Scale").default_value = 0.6
    t.link(wsc.outputs[0], wv.inputs[1])
    c1 = t.n("ShaderNodeTexVoronoi", feature="DISTANCE_TO_EDGE"); t.link(wv.outputs[0], c1.inputs["Vector"]); c1.inputs["Scale"].default_value = 1.6 * craq
    c2 = t.n("ShaderNodeTexVoronoi", feature="DISTANCE_TO_EDGE"); t.link(wv.outputs[0], c2.inputs["Vector"]); c2.inputs["Scale"].default_value = 4.5 * craq
    frac = t.math("MAXIMUM", t.mr(c1.outputs["Distance"], 0.025, 0.0), t.math("MULTIPLY", t.mr(c2.outputs["Distance"], 0.03, 0.0), v=0.6))
    frac = t.math("MULTIPLY", frac, t.mr(t.noise(co, 0.5, 2.0), 0.45, 0.65))                # patchy, not everywhere (fix 2: fewer)
    col = t.mix(col, CRY["hi"], t.math("MULTIPLY", frac, v=0.55))
    # facet edges: the Bevel normal leans away from the flat face normal near every edge
    bev = t.n("ShaderNodeBevel", samples=8); bev.inputs["Radius"].default_value = 0.06 * thick
    dot = t.n("ShaderNodeVectorMath", operation="DOT_PRODUCT"); t.link(bev.outputs[0], dot.inputs[0]); t.link(t.geo("Normal"), dot.inputs[1])
    edge = t.mr(t.math("SUBTRACT", 1.0, t.n_out(dot)), 0.005, 0.08)
    col = t.mix(col, CRY["hi"], t.math("MULTIPLY", edge, v=0.45))
    frost = t.noise(co, 6.0, 5.0, 0.6)
    core = t.mr(t.ao(thick, inside=True), 0.25, 0.75)                                       # thick middle = the glowing core
    emit = t.math("ADD", t.math("ADD", 0.12, t.math("MULTIPLY", core, v=0.45)),
                  t.math("ADD", t.math("MULTIPLY", frac, v=0.35), t.math("MULTIPLY", t.mr(ctt, 0.3, 0.0), v=0.35)), clamp=True)
    rough = t.math("ADD", t.mr(frost, 0.3, 0.7, 0.22, 0.38), t.math("MULTIPLY", frac, v=0.15))
    h = t.math("SUBTRACT", t.math("MULTIPLY", frost, v=0.25), t.math("ADD", t.math("MULTIPLY", frac, v=0.5), t.math("MULTIPLY", plane, v=0.4)))
    return m, t, col, rough, emit, t.bump(h, 0.2, 0.04)

BAS = dict(deep=lin("#4A4D57"), base=lin("#6E6F78"), hi=lin("#9A9CA3"), warm=lin("#8F7867"), scorch=lin("#3E3B40"))
MAG = dict(core=lin("#FFF4B7"), hot=lin("#FFCC5A"), mid=lin("#FF8A2E"), edge=lin("#B8320F"))
def basalt_material(name, seams=1.0, crease=0.6, sc=1.0):
    """cracked mid-grey basalt (E3 #3 / #4): cool/warm mottling 0.15-0.32 linear, fine pits + rust specks, lighter chipped
    edges (Bevel), dark crack lines; a SUBSET of the cracks are magma seams (white-yellow core -> orange -> deep red, a
    scorched band beside them) + faint glow deep in crevices (AO crease, LESSONS 23); emission only in the seams"""
    m, t = new_mat(name)
    co = t.coord(sc)
    mot = t.noise(co, 0.6, 6.0, 0.6)
    col = t.ramp(mot, [(0.25, BAS["deep"]), (0.52, BAS["base"]), (0.8, BAS["hi"])])
    col = t.mix(col, BAS["warm"], t.math("MULTIPLY", t.mr(t.noise(co, 0.25, 2.0), 0.55, 0.7), v=0.35))
    pd = t.voronoi(co, 5.0, out="Distance"); pc = t.voronoi(co, 5.0, out="Color")
    ps = t.n("ShaderNodeSeparateColor"); t.link(pc, ps.inputs[0])
    pit = t.math("MULTIPLY", t.mr(pd, 0.12, 0.04), t.mr(ps.outputs[0], 0.4, 0.45))
    col = t.mix(col, BAS["scorch"], t.math("MULTIPLY", pit, v=0.75))
    rust = t.math("MULTIPLY", t.mr(pd, 0.08, 0.03), t.mr(ps.outputs[1], 0.92, 0.94))
    col = t.mix(col, lin("#9A5A2E"), t.math("MULTIPLY", rust, v=0.8))
    bev = t.n("ShaderNodeBevel", samples=8); bev.inputs["Radius"].default_value = 0.12
    dot = t.n("ShaderNodeVectorMath", operation="DOT_PRODUCT"); t.link(bev.outputs[0], dot.inputs[0]); t.link(t.geo("Normal"), dot.inputs[1])
    chip = t.mr(t.math("SUBTRACT", 1.0, t.n_out(dot)), 0.01, 0.12)
    col = t.mix(col, BAS["hi"], t.math("MULTIPLY", chip, v=0.45))
    # cracks (warped Voronoi edges) + seams = the cracks where a slow noise is high
    wv = t.n("ShaderNodeVectorMath", operation="ADD"); t.link(co, wv.inputs[0])
    wn = t.n("ShaderNodeTexNoise"); t.link(co, wn.inputs["Vector"]); wn.inputs["Scale"].default_value = 0.5
    wsc = t.n("ShaderNodeVectorMath", operation="SCALE"); t.link(wn.outputs["Color"], wsc.inputs[0]); t.sock(wsc, "Scale").default_value = 1.4
    t.link(wsc.outputs[0], wv.inputs[1])
    cr = t.n("ShaderNodeTexVoronoi", feature="DISTANCE_TO_EDGE"); t.link(wv.outputs[0], cr.inputs["Vector"]); cr.inputs["Scale"].default_value = 0.42
    dist = cr.outputs["Distance"]
    crack = t.mr(dist, 0.03, 0.0)
    sel = t.mr(t.noise(co, 0.18, 2.0), 0.56, 0.64)                                          # ~30-35 % of the cracks are seams (tex r2)
    seam = t.math("MULTIPLY", t.math("MULTIPLY", t.mr(dist, 0.045, 0.0), sel), seams)
    hot = t.math("MULTIPLY", t.math("MULTIPLY", t.mr(dist, 0.018, 0.0), sel), seams)
    scorch = t.math("MULTIPLY", t.math("MULTIPLY", t.mr(dist, 0.14, 0.03), sel), seams)
    col = t.mix(col, (0.0, 0.0, 0.0, 1), t.math("MULTIPLY", crack, v=0.55))
    col = t.mix(col, BAS["scorch"], t.math("MULTIPLY", scorch, v=0.5))
    # crevices: deep AO = faint warm glow where blocks / columns meet (+ the column joint grooves)
    ao = t.ao(0.8); crev = t.math("MULTIPLY", t.mr(ao, 0.55, 0.2), crease)
    crev = t.math("MAXIMUM", crev, t.math("MULTIPLY", t.math("MULTIPLY", t.attr("joint"), sel), v=0.7 * crease))
    col = t.mix(col, (0.0, 0.0, 0.0, 1), t.math("MULTIPLY", t.math("SUBTRACT", 1.0, ao), v=0.45), "MULTIPLY")
    glow = t.math("MAXIMUM", seam, t.math("MULTIPLY", crev, v=0.6))
    mg = t.ramp(t.math("MAXIMUM", hot, t.math("MULTIPLY", glow, v=0.55)), [(0.0, MAG["edge"]), (0.45, MAG["mid"]), (0.8, MAG["hot"]), (1.0, MAG["core"])])
    col = t.mix(col, mg, t.mr(glow, 0.05, 0.5))
    emit = t.mr(glow, 0.05, 0.7)
    rough = t.math("SUBTRACT", 0.86, t.math("MULTIPLY", glow, v=0.4))
    h = t.math("SUBTRACT", t.math("MULTIPLY", mot, v=0.4), t.math("ADD", t.math("MULTIPLY", crack, v=0.6), t.math("MULTIPLY", pit, v=0.3)))
    return m, t, col, rough, emit, t.bump(h, 0.5, 0.12)

def tunnel_material(name):
    """the nest tunnel (Blender audit r1 fix 1: read as a target): dark basalt RIBS (rib 1), the orange glow on the walls
    BETWEEN them, rising unevenly with depth (tunT 0 mouth .. 1 back), the back wall (cap) DARK: a passage into glowing
    rock, not a lit disc"""
    m, t = new_mat(name)
    co = t.coord()
    tt = t.attr("tunT"); rib = t.attr("rib"); cap = t.attr("cap")
    blot = t.mr(t.noise(co, 0.9, 3.0, 0.6), 0.35, 0.7)
    depth = t.math("MULTIPLY", t.mr(tt, 0.05, 0.75), t.math("ADD", 0.45, t.math("MULTIPLY", blot, v=0.55)))
    wall = t.math("MULTIPLY", depth, t.math("SUBTRACT", 1.0, t.math("MULTIPLY", rib, v=0.85)))
    wall = t.math("MULTIPLY", wall, t.math("SUBTRACT", 1.0, t.mr(cap, 0.3, 1.0)))
    mg = t.ramp(wall, [(0.0, MAG["edge"]), (0.5, MAG["mid"]), (0.85, MAG["hot"]), (1.0, MAG["core"])])
    col = t.mix(BAS["deep"], mg, t.mr(wall, 0.05, 0.45))
    col = t.mix(col, BAS["scorch"], t.math("MULTIPLY", t.mr(cap, 0.3, 1.0), v=0.8))
    emit = t.mr(wall, 0.08, 0.9)
    return m, t, col, 0.75, emit, t.bump(t.noise(co, 1.5, 3.0), 0.4, 0.15)

def seam_material(name):
    """the magma seam ground plates (E3 #5): basalt slabs (crack 0) + glowing cracks from the high mesh's crack float
    (1 = crack centre): deep red edge -> orange -> white-yellow core, a scorched band; baked selected-to-active"""
    m, t, col, rough, _, nrm = basalt_material(name, seams=0.0, crease=0.0)
    ck = t.attr("crack")
    mg = t.ramp(ck, [(0.0, MAG["edge"]), (0.55, MAG["mid"]), (0.82, MAG["hot"]), (1.0, MAG["core"])])
    col = t.mix(col, BAS["scorch"], t.math("MULTIPLY", t.attr("scorch"), v=0.75))   # (fix 5: a 1-2 stud scorched margin)
    col = t.mix(col, mg, t.mr(ck, 0.18, 0.45))
    emit = t.mr(ck, 0.2, 0.9)
    rough = t.math("SUBTRACT", rough, t.math("MULTIPLY", emit, v=0.4))
    return m, t, col, rough, emit, nrm

# ---------------------------------------------------------------- groups -> one texture set each
K = lambda n: bpy.data.objects[n]
GROUPS = [   # (group name, [(object, material fn, kwargs)], final size)
    ("spireCrystal", [("ccSpireCrystal", crystal_material, dict(thick=3.5, craq=0.6))], 1024),
    ("spireRock", [("ccSpireRock", basalt_material, dict(seams=1.0, crease=0.8))], 1024),
    ("crystals", [("ccClusterLCrystal", crystal_material, dict(thick=1.2, craq=1.2)), ("ccClusterSCrystal", crystal_material, dict(thick=0.6, craq=2.0)),
                  ("ccShardsCrystal", crystal_material, dict(thick=0.3, craq=3.0)), ("ccVeinCrystal", crystal_material, dict(thick=0.8, craq=1.6)),
                  ("ccNestCrystal", crystal_material, dict(thick=1.0, craq=1.4)), ("ccArchCrystal", crystal_material, dict(thick=0.6, craq=2.0))], 1024),
    ("basalt", [("ccClusterLRock", basalt_material, dict(seams=0.8, sc=1.6)), ("ccClusterSRock", basalt_material, dict(seams=0.6, sc=2.5)),
                ("ccShardsGravel", basalt_material, dict(seams=0.0, sc=3.0)), ("ccBoulderA", basalt_material, dict(seams=0.9, sc=2.2)),
                ("ccBoulderB", basalt_material, dict(seams=1.0, sc=1.6)), ("ccBoulderC", basalt_material, dict(seams=1.0, sc=1.2)),
                ("ccVeinRock", basalt_material, dict(seams=1.2, sc=1.8))], 512),   # (spec audit r1 fix 5: secondary sets at 512)
    ("columns", [("ccColumnA", basalt_material, dict(seams=0.45, crease=0.5)), ("ccColumnB", basalt_material, dict(seams=0.45, crease=0.5))], 512),
    ("nest", [("ccNestRock", basalt_material, dict(seams=1.1, crease=0.8))], 1024),
    ("tunnel", [("ccNestTunnel", tunnel_material, {})], 256),
    ("arch", [("ccArch", basalt_material, dict(seams=0.9, crease=0.7))], 1024),
    ("seam", [("ccSeamA", seam_material, {}), ("ccSeamB", seam_material, {})], 1024),
]

def select_only(objs, active):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = active

def unwrap(objs):
    select_only(objs, objs[0])
    bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(55), island_margin=0.006, scale_to_bounds=False)
    bpy.ops.uv.pack_islands(margin=0.006)
    bpy.ops.object.mode_set(mode="OBJECT")

def bake_group(gname, items, size):
    objs = [K(n) for n, _, _ in items]
    unwrap(objs)
    B = size * 2
    imgs = {}
    for kind, cs, fill in (("color", "sRGB", (0, 0, 0, 1)), ("rough", "Non-Color", (0.5, 0.5, 0.5, 1)),
                           ("normal", "Non-Color", (0.5, 0.5, 1.0, 1)), ("emit", "Non-Color", (0, 0, 0, 1))):
        img = bpy.data.images.new(f"cc{gname[0].upper() + gname[1:]}_{kind}", B, B, float_buffer=False)
        img.generated_color = fill; img.colorspace_settings.name = cs; imgs[kind] = img
    for (n, fn, kw) in items:
        o = K(n)
        m, t, col, rough, emit, nrm = fn(n + "_proc", **kw)
        bsdf = next(x for x in m.node_tree.nodes if x.type == "BSDF_PRINCIPLED"); out = next(x for x in m.node_tree.nodes if x.type == "OUTPUT_MATERIAL")
        t.link(nrm, bsdf.inputs["Normal"])
        o.data.materials.clear(); o.data.materials.append(m)
        nodes = {}
        for kind, img in imgs.items():
            tn = m.node_tree.nodes.new("ShaderNodeTexImage"); tn.image = img; nodes[kind] = tn
        emi = m.node_tree.nodes.new("ShaderNodeEmission")
        # a high copy for the normal bake: rocks = the remeshed "_hi" mesh; goo = a smooth subdivided copy (soft lobes)
        hi = bpy.data.objects.get(n + "_hi")
        made = None
        if False:   # (tex r3: the subdivided high copy for goo shrank away from the low mesh = dark normal blotches)
            made = o.copy(); made.data = o.data.copy(); made.name = n + "_sub"; sc.collection.objects.link(made)
            sm = made.modifiers.new("s", "SUBSURF"); sm.levels = sm.render_levels = 1
            hi = made
        if hi is not None and not hi.data.uv_layers: hi.data.uv_layers.new()   # (Cycles wants a UV layer on every selected object)
        if hi is not None:
            hi.hide_render = False; hi.data.materials.clear(); hi.data.materials.append(m)
        for kind in ("normal", "color", "rough", "emit"):
            m.node_tree.nodes.active = nodes[kind]
            s2a = dict(use_selected_to_active=True, cage_extrusion=0.3, max_ray_distance=0.8) if (hi is not None and (kind == "normal" or hi.get("allbake"))) else {}
            select_only([o] + ([hi] if s2a else []), o)
            if kind == "normal":
                t.link(bsdf.outputs[0], out.inputs["Surface"])
                bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT", margin=12, use_clear=False, **s2a)
            else:
                src = {"color": col, "rough": rough, "emit": emit}[kind]
                if isinstance(src, (int, float)):
                    emi.inputs["Color"].default_value = (src, src, src, 1)
                    for l in list(emi.inputs["Color"].links): m.node_tree.links.remove(l)
                else:
                    t.link(src, emi.inputs["Color"])
                t.link(emi.outputs[0], out.inputs["Surface"])
                bpy.ops.object.bake(type="EMIT", margin=12, use_clear=False)
        if made: bpy.data.objects.remove(made, do_unlink=True)
        print("BAKED", gname, n)
    for kind, img in imgs.items():
        img.scale(size, size)
        img.filepath_raw = os.path.join(tex_dir, f"{img.name}.png"); img.file_format = "PNG"; img.save()
    # the export material: the 4 maps (one material per group, shared by its meshes)
    fm = bpy.data.materials.new(f"cc_{gname}"); fm.use_nodes = True; ft = fm.node_tree
    fb = next(x for x in ft.nodes if x.type == "BSDF_PRINCIPLED")
    tn = {}
    for kind, img in imgs.items():
        x = ft.nodes.new("ShaderNodeTexImage"); x.image = img; tn[kind] = x
    ft.links.new(tn["color"].outputs["Color"], fb.inputs["Base Color"])
    ft.links.new(tn["rough"].outputs["Color"], fb.inputs["Roughness"])
    nm = ft.nodes.new("ShaderNodeNormalMap"); ft.links.new(tn["normal"].outputs["Color"], nm.inputs["Color"]); ft.links.new(nm.outputs[0], fb.inputs["Normal"])
    # emission = colour x mask, like Roblox (EmissiveMaskContent is multiplied by the albedo); the GLB does not carry it
    # (the importer would turn it into a white mask): Studio gets the _emit map set by the swap script
    em = ft.nodes.new("ShaderNodeMix"); em.data_type = "RGBA"; em.blend_type = "MULTIPLY"
    next(x for x in em.inputs if x.name == "Factor" and x.enabled).default_value = 1.0
    ft.links.new(tn["color"].outputs["Color"], next(x for x in em.inputs if x.name == "A" and x.enabled))
    ft.links.new(tn["emit"].outputs["Color"], next(x for x in em.inputs if x.name == "B" and x.enabled))
    ft.links.new(next(x for x in em.outputs if x.name == "Result" and x.enabled), fb.inputs["Emission Color"])
    fb.inputs["Emission Strength"].default_value = float(os.environ.get("CC_EMIT", "1.0"))
    fb.inputs["Metallic"].default_value = 0.0
    for o in objs: o.data.materials.clear(); o.data.materials.append(fm)

for g in GROUPS:
    if ONLY and g[0] not in ONLY.split(","): continue
    bake_group(*g)

coll = bpy.data.collections.new("CrystalCanyonTex"); sc.collection.children.link(coll)
for n in [i[0] for g in GROUPS for i in g[1]]:
    o = K(n)
    for c in list(o.users_collection): c.objects.unlink(o)
    coll.objects.link(o)
for o in list(bpy.data.objects):
    if o.name.endswith("_hi"): bpy.data.objects.remove(o, do_unlink=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(blend_dir, "crystalcanyon_tex.blend"))
print("SAVED tex", {o.name: len(o.data.polygons) for o in coll.objects})
