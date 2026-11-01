# Goo Marsh kit: Cycles-baked PBR textures (30 Oct 2026). Run AFTER hub_goomarsh.py in the same Blender session:
#   blender -b --factory-startup --python hub_goomarsh.py --python hub_goomarsh_tex.py -- <assets_dir> full
# Reference: design\concepts\hub\D3-goo-marsh-materials-chatgpt.png + its hex / roughness list (goo-marsh\D3-reply.txt).
# James: soft wet GLOWING goo, never shiny plastic. ChatGPT spec audit r1 (goo-marsh\spec-audit-r1.txt):
#   - opaque goo, fake translucency baked from thickness (AO "inside"): thin = bright cyan + glow, thick = deeper teal;
#   - roughness 0.35-0.45 on the deep body, 0.18-0.25 on wet rims; pools = dark teal centre + luminous thick rim;
#   - broad gills with fine grooves only in the maps + deep lilac glow between; crystals = frosted + small glowing core;
#   - fix 6: shared ATLASES (one texture set per group below), 1024 max (policy.json), metalness 0.
# Per group: colour (sRGB), roughness, tangent normal and an emissive mask (-> SurfaceAppearance EmissiveMaskContent),
# baked at 2x and downscaled (LESSONS 14). Output: assets\textures\hub\gm<Group>_{color,rough,normal,emit}.png and
# assets\blender\hub\goomarsh_tex.blend (collection GooMarshTex) for `blender.mjs export`.
import bpy, bmesh, math, os, sys

args = sys.argv[sys.argv.index("--") + 1:]
ASSETS = args[0]
tex_dir = os.path.join(ASSETS, "textures", "hub"); blend_dir = os.path.join(ASSETS, "blender", "hub")
os.makedirs(tex_dir, exist_ok=True); os.makedirs(blend_dir, exist_ok=True)
sc = bpy.context.scene
sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = 12
ONLY = os.environ.get("GM_ONLY")                             # e.g. "giantCap,goo" to rebake a few groups while tuning

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
        x = self.n("ShaderNodeAmbientOcclusion", inside=inside, samples=16); x.inputs["Distance"].default_value = dist
        return x.outputs["AO"]
    def geo(self, out): return self.n("ShaderNodeNewGeometry").outputs[out]
    def nz(self):                                                       # world normal z (up-facing = 1)
        sep = self.n("ShaderNodeSeparateXYZ"); self.link(self.geo("Normal"), sep.inputs[0]); return sep.outputs[2]
    def bump(self, h, strength, dist):
        x = self.n("ShaderNodeBump"); x.inputs["Strength"].default_value = strength; x.inputs["Distance"].default_value = dist
        self.link(h, x.inputs["Height"]); return x.outputs[0]

def new_mat(name):
    m = bpy.data.materials.new(name); m.use_nodes = True; return m, NT(m)

# ---------------------------------------------------------------- the procedural materials (D3 hex targets)
GOO = dict(base=lin("#31D9FF"), deep=lin("#0A6B8F"), glow=lin("#9EF7FF"), hi=lin("#E6FCFF"))
def goo_material(name, thick=3.0, spot=0.14, spots=True):
    """translucent-looking jelly: thickness (AO inside) -> glow / base / deep teal, swirling depth, soft glow spots
    sunk under the top surface, fine suspended bubbles, rim sheen; drips (vertex float dripT) read thin"""
    m, t = new_mat(name)
    co = t.coord()
    # (tex r2: the first bake read every cap as "thin" (a 40-wide cap is only ~2.5 studs thick) = pale glow everywhere,
    # a whitewash. Now: BASE cyan body, deeper teal swirls + crevices, glow only where it is really thin / dripping)
    th = t.mr(t.ao(thick, inside=True), 0.05, 0.45)                    # 0 thin .. 1 thick
    drip = t.attr("dripT")
    thin = t.math("MAXIMUM", t.math("MULTIPLY", t.math("POWER", t.math("SUBTRACT", 1.0, th), v=3.0), v=0.3), t.math("MULTIPLY", drip, v=0.85))   # (tex r3: r2 still too pale)
    swirl = t.mr(t.noise(co, 0.16, 3.0, 0.5), 0.35, 0.68)               # slow internal depth swirls
    deepmix = tuple(GOO["base"][i] * 0.45 + GOO["deep"][i] * 0.55 for i in range(3)) + (1,)
    col = t.mix(GOO["base"], GOO["deep"], t.math("MULTIPLY", th, t.math("ADD", 0.3, t.math("MULTIPLY", swirl, v=0.35))))   # (Blender audit r1 fix 1: dark teal depth)
    crev = t.math("SUBTRACT", 1.0, t.ao(1.5))
    col = t.mix(col, GOO["deep"], t.math("MULTIPLY", crev, v=0.6))
    col = t.mix(col, GOO["glow"], t.math("MULTIPLY", thin, v=0.65))
    th = t.math("SUBTRACT", 1.0, thin)
    # glow spots (D3 #1): large soft cells, ~60 % of cells lit, only on up-facing surfaces, soft edges = "sunk in"
    up = t.mr(t.nz(), 0.0, 0.6)
    vd = t.voronoi(co, spot * 1.7, out="Distance"); vc = t.voronoi(co, spot * 1.7, out="Color")   # (r4: smaller spots)
    cell = t.n("ShaderNodeSeparateColor"); t.link(vc, cell.inputs[0])
    lit = t.mr(cell.outputs[0], 0.58, 0.66)                              # (r4: ~40 % of cells, less even)
    sp = t.math("MULTIPLY", t.math("MULTIPLY", t.mr(vd, 0.42, 0.12), lit), up) if spots else 0.0
    col = t.mix(col, GOO["glow"], t.math("MULTIPLY", sp, v=0.6)) if spots else col
    core = t.math("MULTIPLY", sp, t.mr(vd, 0.2, 0.05)) if spots else 0.0
    col = t.mix(col, GOO["hi"], t.math("MULTIPLY", core, v=0.3)) if spots else col
    # suspended bubbles: tiny bright dots in some fine cells
    bd = t.voronoi(co, 1.6, out="Distance"); bc = t.voronoi(co, 1.6, out="Color")
    bsep = t.n("ShaderNodeSeparateColor"); t.link(bc, bsep.inputs[0])
    bub = t.math("MULTIPLY", t.math("MULTIPLY", t.mr(bd, 0.09, 0.04), t.mr(bsep.outputs[1], 0.55, 0.6)), t.mr(th, 0.3, 0.8))   # (r4: clusters in the dark body)
    col = t.mix(col, GOO["hi"], t.math("MULTIPLY", bub, v=0.55))
    # convex rims catch a soft wet sheen (baked, not a hard hot-spot)
    pt = t.math("MAXIMUM", t.mr(t.geo("Pointiness"), 0.52, 0.6), t.mr(drip, 0.1, 0.16))   # (r4: sheen on the rolled rim, not the dome)
    col = t.mix(col, GOO["glow"], t.math("MULTIPLY", pt, v=0.3))
    # roughness: 0.18-0.25 thin / rims, 0.38-0.42 deep body
    rough = t.math("SUBTRACT", t.mr(th, 0.0, 1.0, 0.3, 0.42), t.math("MULTIPLY", pt, v=0.12))   # (r4: body 0.35-0.42, rim 0.2-0.27)
    emit = t.math("ADD", t.math("ADD", 0.08, t.math("MULTIPLY", thin, v=0.5)),
                  t.math("MULTIPLY", sp, v=0.6) if spots else 0.0, clamp=True)
    h = t.math("ADD", t.math("MULTIPLY", t.noise(co, 0.6, 2.0, 0.5), v=0.6), t.math("MULTIPLY", bub, v=0.3))
    return m, t, col, rough, emit, t.bump(h, 0.25, 0.3)

GILL = dict(base=lin("#B884FF"), deep=lin("#6B27D9"), glow=lin("#F7A8FF"), hi=lin("#FFE7FF"))
def gill_material(name, fine=140):
    """broad lilac gill blades (blade = 1 on the keel), fine radial grooves, a violet depth toward the stalk (gT 0),
    glowing pink-violet light deep between the blades (D3 #2)"""
    m, t = new_mat(name)
    co = t.coord(); sep = t.n("ShaderNodeSeparateXYZ"); t.link(co, sep.inputs[0])
    ang = t.math("ARCTAN2", sep.outputs[1], sep.outputs[0])
    wob = t.math("MULTIPLY", t.noise(co, 0.8, 2.0), v=0.25)
    groove = t.math("ADD", t.math("MULTIPLY", t.math("SINE", t.math("ADD", t.math("MULTIPLY", ang, v=fine), wob)), v=0.5), v=0.5)
    gt = t.attr("gT"); blade = t.attr("blade")
    col = t.ramp(gt, [(0.0, GILL["deep"]), (0.45, GILL["base"]), (1.0, tuple(min(1, c * 1.15) for c in GILL["base"][:3]) + (1,))])
    col = t.mix(col, GILL["deep"], t.math("MULTIPLY", t.math("SUBTRACT", 1.0, groove), v=0.35))
    ao = t.ao(1.2)
    gap = t.math("MULTIPLY", t.math("SUBTRACT", 1.0, blade), t.mr(gt, 0.0, 0.9, 1.0, 0.35))        # between the blades
    streak = t.mr(t.noise(t.coord(), 0.35, 3.0), 0.5, 0.68)                                   # pink-hot streaks
    glow = t.math("MAXIMUM", gap, t.math("MULTIPLY", t.math("MULTIPLY", streak, blade), t.mr(gt, 0.1, 0.8, 0.8, 0.2)))
    col = t.mix(t.mix(col, (0.0, 0.0, 0.0, 1), t.math("MULTIPLY", t.math("SUBTRACT", 1.0, ao), v=0.45), "MULTIPLY"),
                GILL["glow"], t.math("MULTIPLY", glow, v=0.45))
    emit = t.math("ADD", 0.06, t.math("MULTIPLY", glow, v=0.6), clamp=True)
    rough = t.mr(groove, 0, 1, 0.5, 0.42)
    return m, t, col, rough, emit, t.bump(groove, 0.35, 0.08)

STALK = dict(base=lin("#E7E2F7"), deep=lin("#C5B4E6"), groove=lin("#9A7EC6"), hi=lin("#F9F7FF"))
def stalk_material(name):
    """pale pearl fibrous twisted stalk (D3 #3): strand crests (vertex float crest from the modelled twist) pearly,
    lilac-grey grooves, fine fibres along the stalk, a few small dark pores; matte with a faint sheen"""
    m, t = new_mat(name)
    co = t.coord(); sep = t.n("ShaderNodeSeparateXYZ"); t.link(co, sep.inputs[0])
    crest = t.mr(t.attr("crest"), -1.0, 1.0)
    fv = t.n("ShaderNodeCombineXYZ")
    t.link(t.math("MULTIPLY", sep.outputs[0], v=3.0), fv.inputs[0]); t.link(t.math("MULTIPLY", sep.outputs[1], v=3.0), fv.inputs[1])
    t.link(t.math("MULTIPLY", sep.outputs[2], v=0.25), fv.inputs[2])
    fib = t.mr(t.noise(fv.outputs[0], 2.5, 8.0, 0.65), 0.3, 0.7)
    h = t.math("ADD", t.math("MULTIPLY", crest, v=0.7), t.math("MULTIPLY", fib, v=0.3))
    col = t.ramp(h, [(0.0, STALK["deep"]), (0.15, STALK["base"]), (0.6, STALK["base"]), (1.0, STALK["hi"])])   # (r4: predominantly pearl, lavender only in the grooves)
    pd = t.voronoi(co, 1.1, out="Distance"); pc = t.voronoi(co, 1.1, out="Color")
    ps = t.n("ShaderNodeSeparateColor"); t.link(pc, ps.inputs[0])
    pore = t.math("MULTIPLY", t.mr(pd, 0.07, 0.035), t.mr(ps.outputs[2], 0.8, 0.82))
    col = t.mix(col, lin("#3A2E5A"), t.math("MULTIPLY", pore, v=0.85))
    col = t.mix(col, (0.0, 0.0, 0.0, 1), t.math("MULTIPLY", t.math("SUBTRACT", 1.0, t.ao(1.5)), v=0.2), "MULTIPLY")
    rough = t.mr(crest, 0, 1, 0.66, 0.55)
    return m, t, col, rough, 0.22, t.bump(t.math("SUBTRACT", h, t.math("MULTIPLY", pore, v=0.6)), 0.6, 0.15)   # (Studio r1: a small glow lift keeps the pearl in shade)

def rock_material(name):
    """mid-grey moon rock (LESSONS 15: never near-black): mottled 0.14-0.32 linear, pits, thin cracks, AO"""
    m, t = new_mat(name)
    co = t.coord()
    mot = t.noise(co, 0.9, 6.0, 0.6)
    col = t.ramp(mot, [(0.25, (0.13, 0.125, 0.13, 1)), (0.55, (0.22, 0.21, 0.215, 1)), (0.8, (0.32, 0.31, 0.31, 1))])
    # (Studio r1: the plain Voronoi edges read as a tortoise shell: warp them, smaller cells, thinner + fainter)
    wv = t.n("ShaderNodeVectorMath", operation="ADD"); t.link(co, wv.inputs[0])
    wn = t.n("ShaderNodeTexNoise"); t.link(co, wn.inputs["Vector"]); wn.inputs["Scale"].default_value = 0.6
    wsc = t.n("ShaderNodeVectorMath", operation="SCALE"); t.link(wn.outputs["Color"], wsc.inputs[0]); t.sock(wsc, "Scale").default_value = 1.6
    t.link(wsc.outputs[0], wv.inputs[1])
    cr = t.n("ShaderNodeTexVoronoi", feature="DISTANCE_TO_EDGE"); t.link(wv.outputs[0], cr.inputs["Vector"]); cr.inputs["Scale"].default_value = 1.4
    crack = t.math("MULTIPLY", t.mr(cr.outputs["Distance"], 0.022, 0.0), t.mr(t.noise(co, 0.5, 2.0), 0.4, 0.6))
    pit = t.mr(t.voronoi(co, 2.2), 0.12, 0.0)
    col = t.mix(col, (0.06, 0.06, 0.065, 1), t.math("MAXIMUM", t.math("MULTIPLY", crack, v=0.8), t.math("MULTIPLY", pit, v=0.5)))
    col = t.mix(col, (0.0, 0.0, 0.0, 1), t.math("MULTIPLY", t.math("SUBTRACT", 1.0, t.ao(1.2)), v=0.5), "MULTIPLY")
    h = t.math("SUBTRACT", mot, t.math("ADD", t.math("MULTIPLY", crack, v=0.5), t.math("MULTIPLY", pit, v=0.3)))
    return m, t, col, 0.86, 0.0, t.bump(h, 0.5, 0.2)

CRY = dict(base=lin("#4DEBFF"), deep=lin("#0B7CAA"), glow=lin("#A9F8FF"), hi=lin("#E7FDFF"))
def crystal_material(name):
    """frosted pale cyan shards (D3 #6): deeper at the root, pale at the tips, frosty noise, facet edges catch light,
    a glowing core (emit) that is NOT the whole shard"""
    m, t = new_mat(name)
    co = t.coord(); sep = t.n("ShaderNodeSeparateXYZ"); t.link(co, sep.inputs[0])
    hgt = t.mr(sep.outputs[2], 1.0, 7.5)
    frost = t.noise(co, 3.0, 5.0, 0.6)
    col = t.ramp(t.math("ADD", hgt, t.math("MULTIPLY", frost, v=0.25)), [(0.0, CRY["deep"]), (0.45, CRY["base"]), (1.0, CRY["glow"])])
    edge = t.mr(t.geo("Pointiness"), 0.52, 0.6)
    col = t.mix(col, CRY["hi"], t.math("MULTIPLY", edge, v=0.6))
    core = t.mr(t.noise(co, 0.8, 2.0), 0.45, 0.6)
    emit = t.math("ADD", 0.15, t.math("MULTIPLY", t.math("MAXIMUM", core, t.mr(hgt, 0.0, 0.35, 1.0, 0.0)), v=0.65), clamp=True)   # (r4: glow at the base)
    return m, t, col, t.mr(frost, 0.3, 0.7, 0.22, 0.38), emit, t.bump(frost, 0.15, 0.05)

def tunnel_material(name):
    """the nest tunnel lining: lilac / violet rib rings getting brighter toward the glowing core (tunT 0 mouth .. 1)"""
    m, t = new_mat(name)
    co = t.coord(); sep = t.n("ShaderNodeSeparateXYZ"); t.link(co, sep.inputs[0])
    tt = t.attr("tunT")
    rib = t.math("ADD", t.math("MULTIPLY", t.math("SINE", t.math("MULTIPLY", sep.outputs[1], v=4.2)), v=0.5), v=0.5)
    col = t.ramp(tt, [(0.0, GILL["deep"]), (0.6, GILL["base"]), (1.0, GILL["glow"])])
    col = t.mix(col, GILL["deep"], t.math("MULTIPLY", rib, v=0.45))
    emit = t.math("ADD", t.mr(tt, 0.0, 1.0, 0.3, 1.0), t.math("MULTIPLY", t.math("SUBTRACT", 1.0, rib), v=0.2), clamp=True)
    return m, t, col, 0.4, emit, t.bump(rib, 0.4, 0.1)

POOL = dict(base=lin("#29D6FF"), deep=lin("#0C6A8D"), glow=lin("#8EF4FF"), hi=lin("#DFFAFF"))
def pool_material(name, rs=1.0):
    """goo pools / films / streams (D3 #4): dark teal centre -> cyan -> a thick luminous rim (rimT), slow ripples,
    faint caustic lines glowing from below, tiny bubbles; wet (0.18 rim .. 0.28 centre)"""
    m, t = new_mat(name)
    co = t.coord()
    rim = t.attr("rimT")
    dn = t.noise(co, 0.05 * rs, 2.0)
    centre = t.math("MULTIPLY", t.math("SUBTRACT", 1.0, rim), t.mr(dn, 0.35, 0.65, 0.75, 1.0))
    col = t.ramp(t.math("SUBTRACT", 1.0, centre), [(0.0, tuple(POOL["deep"][i] * 0.8 + POOL["base"][i] * 0.2 for i in range(3)) + (1,)),
                                                   (0.55, tuple(POOL["deep"][i] * 0.35 + POOL["base"][i] * 0.65 for i in range(3)) + (1,)),
                                                   (0.88, POOL["base"]), (1.0, POOL["glow"])])   # (r4: darker teal centre, narrow glowing rim)
    # (tex r3: straight Voronoi edges read as cracked ice tiles: warp them with noise, thinner + fainter)
    wv = t.n("ShaderNodeVectorMath", operation="ADD"); t.link(co, wv.inputs[0])
    wn = t.n("ShaderNodeTexNoise"); t.link(co, wn.inputs["Vector"]); wn.inputs["Scale"].default_value = 0.12 * rs
    wsc = t.n("ShaderNodeVectorMath", operation="SCALE"); t.link(wn.outputs["Color"], wsc.inputs[0]); t.sock(wsc, "Scale").default_value = 9.0
    t.link(wsc.outputs[0], wv.inputs[1])
    ca = t.n("ShaderNodeTexVoronoi", feature="DISTANCE_TO_EDGE"); t.link(wv.outputs[0], ca.inputs["Vector"]); ca.inputs["Scale"].default_value = 0.16 * rs
    caus = t.math("MULTIPLY", t.mr(ca.outputs["Distance"], 0.035, 0.0), t.math("SUBTRACT", 1.0, rim))
    col = t.mix(col, POOL["glow"], t.math("MULTIPLY", caus, v=0.04))   # (Blender audit r1 fix 2: cracks almost gone)
    broad = t.n("ShaderNodeTexWave", wave_type="RINGS"); t.link(wv.outputs[0], broad.inputs["Vector"]); broad.inputs["Scale"].default_value = 0.035 * rs
    broad.inputs["Distortion"].default_value = 3.0
    col = t.mix(col, POOL["glow"], t.math("MULTIPLY", t.mr(broad.outputs["Fac"], 0.6, 1.0), v=0.12))   # 2-4 broad soft ripples
    bd = t.voronoi(co, 1.4, out="Distance"); bc = t.voronoi(co, 1.4, out="Color")
    bs = t.n("ShaderNodeSeparateColor"); t.link(bc, bs.inputs[0])
    bub = t.math("MULTIPLY", t.mr(bd, 0.1, 0.05), t.mr(bs.outputs[1], 0.85, 0.88))
    col = t.mix(col, POOL["hi"], t.math("MULTIPLY", bub, v=0.6))
    rip = t.n("ShaderNodeTexWave", wave_type="RINGS"); t.link(co, rip.inputs["Vector"]); rip.inputs["Scale"].default_value = 0.09 * rs
    rip.inputs["Distortion"].default_value = 6.0; rip.inputs["Detail"].default_value = 2.0
    h = t.math("ADD", t.math("MULTIPLY", rip.outputs["Fac"], v=0.6), t.math("MULTIPLY", t.noise(co, 0.4 * rs, 3.0), v=0.4))
    emit = t.math("MULTIPLY", t.math("ADD", 0.1, t.math("MULTIPLY", t.mr(rim, 0.6, 1.0), v=0.6), clamp=True), v=1.0 if rs <= 1.0 else 0.6)   # (r4: films dimmer)
    return m, t, col, t.mr(rim, 0.0, 1.0, 0.28, 0.18), emit, t.bump(h, 0.3, 0.15)

# ---------------------------------------------------------------- groups -> one texture set each (audit fix 6)
K = lambda n: bpy.data.objects[n]
GROUPS = [   # (group name, [(object, material fn, kwargs)], final size, normal from a high copy?)
    ("giantCap", [("gmGiantCap", goo_material, dict(thick=4.5, spot=0.1))], 1024),
    ("giantGills", [("gmGiantGills", gill_material, dict(fine=150))], 1024),
    ("giantStalk", [("gmGiantStalk", stalk_material, {})], 1024),
    ("mush", [("gmTrumpetCap", goo_material, dict(thick=1.4, spot=0.4)), ("gmUmbrellaCap", goo_material, dict(thick=2.0, spot=0.3)),
              ("gmSproutCap", goo_material, dict(thick=0.9, spot=0.6)), ("gmTrumpetGills", gill_material, dict(fine=60)),
              ("gmUmbrellaGills", gill_material, dict(fine=90)), ("gmSproutGills", gill_material, dict(fine=40)),
              ("gmTrumpetStalk", stalk_material, {}), ("gmUmbrellaStalk", stalk_material, {}), ("gmSproutStalk", stalk_material, {})], 1024),
    ("goo", [("gmBlobA", goo_material, dict(thick=2.2, spot=0.35)), ("gmBlobB", goo_material, dict(thick=1.6, spot=0.4)),
             ("gmVeinGoo", goo_material, dict(thick=1.2, spot=0.5, spots=False)), ("gmDrape", goo_material, dict(thick=1.6, spot=0.35))], 1024),
    ("nest", [("gmNestShell", goo_material, dict(thick=4.0, spot=0.16))], 1024),
    ("tunnel", [("gmNestTunnel", tunnel_material, {})], 256),
    ("poolA", [("gmPoolA", pool_material, {})], 1024),
    ("poolB", [("gmPoolB", pool_material, {})], 1024),
    ("flats", [("gmFilmA", pool_material, dict(rs=1.6)), ("gmFilmB", pool_material, dict(rs=1.6)),
               ("gmStreamA", pool_material, dict(rs=1.6)), ("gmStreamB", pool_material, dict(rs=1.6))], 1024),
    ("rocks", [("gmRockA", rock_material, {}), ("gmRockB", rock_material, {}), ("gmRockC", rock_material, {}),
               ("gmVeinRock", rock_material, {}), ("gmVeinCrystal", crystal_material, {})], 1024),
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
        img = bpy.data.images.new(f"gm{gname[0].upper() + gname[1:]}_{kind}", B, B, float_buffer=False)
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
        if hi is not None:
            hi.hide_render = False; hi.data.materials.clear(); hi.data.materials.append(m)
        for kind in ("normal", "color", "rough", "emit"):
            m.node_tree.nodes.active = nodes[kind]
            s2a = dict(use_selected_to_active=True, cage_extrusion=0.3, max_ray_distance=0.8) if (hi is not None and kind == "normal") else {}
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
    fm = bpy.data.materials.new(f"gm_{gname}"); fm.use_nodes = True; ft = fm.node_tree
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
    fb.inputs["Emission Strength"].default_value = float(os.environ.get("GM_EMIT", "1.0"))
    fb.inputs["Metallic"].default_value = 0.0
    for o in objs: o.data.materials.clear(); o.data.materials.append(fm)

for g in GROUPS:
    if ONLY and g[0] not in ONLY.split(","): continue
    bake_group(*g)

coll = bpy.data.collections.new("GooMarshTex"); sc.collection.children.link(coll)
for n in [i[0] for g in GROUPS for i in g[1]]:
    o = K(n)
    for c in list(o.users_collection): c.objects.unlink(o)
    coll.objects.link(o)
for o in list(bpy.data.objects):
    if o.name.endswith("_hi"): bpy.data.objects.remove(o, do_unlink=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(blend_dir, "goomarsh_tex.blend"))
print("SAVED tex", {o.name: len(o.data.polygons) for o in coll.objects})
