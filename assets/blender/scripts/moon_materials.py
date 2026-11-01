# Alien Fusion: the Moon ground materials, made in Blender and baked to SEAMLESS PBR sets for Roblox MaterialVariants.
#   blender --background --factory-startup --python moon_materials.py -- <out_dir> [size]
# Seamless trick: every procedural texture is sampled on a 4D torus (cos/sin of u and v), so the bake tiles perfectly.
# Per material writes <name>_color.png (sRGB), <name>_normal.png (OpenGL tangent, = Roblox), <name>_rough.png,
# plus sheet.png (all four tiled 3x3 under a low grazing sun, the way the Moon lights them).
import bpy, math, os, sys

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
out = argv[0] if argv else os.getcwd()
SIZE = int(argv[1]) if len(argv) > 1 else 1024
os.makedirs(out, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = 16
sc.render.bake.margin = 0


class NT:
    """small node-tree builder"""

    def __init__(self, mat):
        self.t = mat.node_tree
        self.n = self.t.nodes
        self.l = self.t.links

    def node(self, kind, **inputs):
        nd = self.n.new(kind)
        for k, v in inputs.items():
            if k.startswith("_"):
                setattr(nd, k[1:], v)
            else:
                nd.inputs[k].default_value = v
        return nd

    def link(self, a, b):
        self.l.new(a, b)

    def math(self, op, a, b=None, clamp=False):
        m = self.node("ShaderNodeMath", _operation=op, _use_clamp=clamp)
        for i, v in enumerate((a, b)):
            if v is None:
                continue
            if isinstance(v, (int, float)):
                m.inputs[i].default_value = v
            else:
                self.link(v, m.inputs[i])
        return m.outputs[0]


def torus(nt):
    """UV -> (cos u, sin u, cos v) + W = sin v (unit torus): returns (vector, w)"""
    tc = nt.node("ShaderNodeTexCoord")
    sep = nt.node("ShaderNodeSeparateXYZ")
    nt.link(tc.outputs["UV"], sep.inputs[0])
    a = nt.math("MULTIPLY", sep.outputs[0], 2 * math.pi)
    b = nt.math("MULTIPLY", sep.outputs[1], 2 * math.pi)
    comb = nt.node("ShaderNodeCombineXYZ")
    nt.link(nt.math("COSINE", a), comb.inputs[0])
    nt.link(nt.math("SINE", a), comb.inputs[1])
    nt.link(nt.math("COSINE", b), comb.inputs[2])
    return comb.outputs[0], nt.math("SINE", b)


def noise(nt, vec, w, scale, detail=4, rough=0.55, dist=0.0):
    n = nt.node("ShaderNodeTexNoise", _noise_dimensions="4D", Scale=scale, Detail=detail, Roughness=rough, Distortion=dist)
    nt.link(vec, n.inputs["Vector"]); nt.link(w, n.inputs["W"])
    return n.outputs["Fac"]


def voronoi(nt, vec, w, scale, feature="F1", metric="EUCLIDEAN", rand=1.0, out="Distance"):
    v = nt.node("ShaderNodeTexVoronoi", _voronoi_dimensions="4D", _feature=feature, _distance=metric, Scale=scale, Randomness=rand)
    nt.link(vec, v.inputs["Vector"]); nt.link(w, v.inputs["W"])
    return v.outputs[out]


def ramp(nt, fac, stops):
    r = nt.node("ShaderNodeValToRGB")
    nt.link(fac, r.inputs["Fac"])
    els = r.color_ramp.elements
    els[0].position, els[0].color = stops[0][0], stops[0][1]
    els[1].position, els[1].color = stops[-1][0], stops[-1][1]
    for p, c in stops[1:-1]:
        e = els.new(p); e.color = c
    return r.outputs["Color"]


def grey(v, tint=(1.0, 1.0, 1.0)):
    return (v * tint[0], v * tint[1], v * tint[2], 1.0)


import numpy as np

_crater_imgs = {}


def crater_map(name, count, rmin, rmax, seed, power=2.6):
    """a seamless crater height image made in numpy: toroidal distances, power-law sizes (many small, few big),
    bowl + raised rim + soft ejecta, older craters softer. Returns a bpy image (Non-Color float)."""
    if name in _crater_imgs:
        return _crater_imgs[name]
    n = SIZE
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32) / n
    h = np.zeros((n, n), np.float32)
    for _ in range(count):
        cx, cy = rng.random(), rng.random()
        r = rmin + (rmax - rmin) * rng.random() ** power
        age = rng.uniform(0.4, 1.0)
        dx = np.abs(xx - cx); dx = np.minimum(dx, 1 - dx)
        dy = np.abs(yy - cy); dy = np.minimum(dy, 1 - dy)
        d = np.sqrt(dx * dx + dy * dy) / r
        m = d < 2.2
        if not m.any():
            continue
        dd = d[m]
        bowl = np.where(dd < 1, (dd * dd - 1) * 0.9, 0)
        rim = 0.35 * np.exp(-((dd - 1) / 0.18) ** 2)
        ej = 0.08 * np.exp(-np.clip(dd - 1, 0, None) * 3) * (dd > 1)
        h[m] = h[m] * np.where(dd < 1, 0.35, 1.0) + age * (bowl + rim + ej) * (r / rmax) ** 0.35
    img = bpy.data.images.new(name, n, n, alpha=False, float_buffer=True)
    img.colorspace_settings.name = "Non-Color"
    px = np.repeat(h.reshape(-1, 1), 4, axis=1); px[:, 3] = 1.0
    img.pixels.foreach_set(px.astype(np.float32).ravel())
    img.pack()
    _crater_imgs[name] = img
    return img


def crater_image(nt, img):
    tc = nt.node("ShaderNodeTexCoord")
    tx = nt.node("ShaderNodeTexImage"); tx.image = img; tx.interpolation = "Cubic"
    nt.link(tc.outputs["UV"], tx.inputs[0])
    return tx.outputs["Color"]


def crater_field(nt, vec, w, scale, size, chance=0.55):
    """bowls with soft rims from Voronoi F1, one per cell where the cell's random value passes `chance`, each its own
    size (size .. 2.2*size): returns a height contribution (bowl -1 .. rim +)"""
    v = nt.node("ShaderNodeTexVoronoi", _voronoi_dimensions="4D", _feature="F1", Scale=scale, Randomness=0.9)
    nt.link(vec, v.inputs["Vector"]); nt.link(w, v.inputs["W"])
    sep = nt.node("ShaderNodeSeparateColor"); nt.link(v.outputs["Color"], sep.inputs[0])
    rad = nt.math("ADD", size, nt.math("MULTIPLY", sep.outputs[0], size * 1.2))
    alive = nt.math("GREATER_THAN", sep.outputs[1], chance)
    r = nt.math("ADD", nt.math("DIVIDE", v.outputs["Distance"], rad), nt.math("MULTIPLY", nt.math("SUBTRACT", 1.0, alive), 5.0))
    bowl = nt.math("SUBTRACT", nt.math("POWER", nt.math("MINIMUM", r, 1.0), 2.0), 1.0)   # -1 .. 0 inside
    rim = nt.math("MULTIPLY", nt.math("EXPONENT", nt.math("MULTIPLY", nt.math("POWER", nt.math("SUBTRACT", r, 1.0), 2.0), -40.0)), 0.35)
    return nt.math("ADD", bowl, rim)


# ---- each material: (height socket, colour socket, roughness socket, bump strength)
def regolith(nt, vec, w):
    big = noise(nt, vec, w, 3.0, 6, 0.55)
    fine = noise(nt, vec, w, 38.0, 8, 0.7)
    peb = nt.math("GREATER_THAN", voronoi(nt, vec, w, 55.0, rand=1.0), 0.0)
    pebbles = nt.math("MULTIPLY", nt.math("SUBTRACT", 1.0, nt.math("MULTIPLY", voronoi(nt, vec, w, 55.0), 6.0, True)), 0.6)
    cr1 = crater_image(nt, crater_map("cr_regolith", 85, 0.006, 0.05, 11))
    cr2 = crater_image(nt, crater_map("cr_regolith_fine", 260, 0.002, 0.012, 21))
    h = nt.math("ADD", nt.math("ADD", nt.math("MULTIPLY", big, 0.6), nt.math("MULTIPLY", fine, 0.35)),
                nt.math("ADD", nt.math("MULTIPLY", cr1, 1.4), nt.math("MULTIPLY", cr2, 0.5)))
    h = nt.math("ADD", h, nt.math("MULTIPLY", pebbles, 0.25, ))
    col = ramp(nt, nt.math("ADD", nt.math("MULTIPLY", big, 0.7), nt.math("MULTIPLY", fine, 0.3)),
               [(0.30, grey(0.36, (1, 0.99, 0.97))), (0.55, grey(0.52, (1, 0.995, 0.98))), (0.75, grey(0.62))])
    rough = nt.math("ADD", 0.86, nt.math("MULTIPLY", fine, 0.1))
    return h, col, rough, 0.55


def crater_dust(nt, vec, w):
    big = noise(nt, vec, w, 2.0, 5, 0.5)
    fine = noise(nt, vec, w, 30.0, 6, 0.6)
    ripple = nt.math("SINE", nt.math("MULTIPLY", noise(nt, vec, w, 1.2, 2, 0.4, 2.0), 40.0))
    cr = crater_image(nt, crater_map("cr_dust", 70, 0.008, 0.05, 12))
    h = nt.math("ADD", nt.math("ADD", nt.math("MULTIPLY", big, 0.4), nt.math("MULTIPLY", fine, 0.25)),
                nt.math("ADD", nt.math("MULTIPLY", ripple, 0.04), nt.math("MULTIPLY", cr, 0.4)))
    col = ramp(nt, nt.math("ADD", nt.math("MULTIPLY", big, 0.8), nt.math("MULTIPLY", fine, 0.2)),
               [(0.3, grey(0.30, (0.97, 0.98, 1.03))), (0.7, grey(0.42, (0.98, 0.99, 1.02)))])
    return h, col, nt.math("ADD", 0.9, nt.math("MULTIPLY", fine, 0.06)), 0.35


def highland_rock(nt, vec, w):
    cells = voronoi(nt, vec, w, 0.9, "DISTANCE_TO_EDGE")
    cracks = nt.math("MULTIPLY", nt.math("SUBTRACT", 1.0, nt.math("MULTIPLY", cells, 9.0, True)), -1.0)
    strata = nt.math("SINE", nt.math("MULTIPLY", noise(nt, vec, w, 1.5, 3, 0.5, 1.5), 22.0))
    grain = noise(nt, vec, w, 24.0, 8, 0.65)
    facet = voronoi(nt, vec, w, 0.9, "F1", out="Distance")
    h = nt.math("ADD", nt.math("ADD", nt.math("MULTIPLY", cracks, 0.5), nt.math("MULTIPLY", strata, 0.12)),
                nt.math("ADD", nt.math("MULTIPLY", grain, 0.3), nt.math("MULTIPLY", facet, -0.35)))
    col = ramp(nt, nt.math("ADD", nt.math("MULTIPLY", grain, 0.6), nt.math("MULTIPLY", nt.math("ADD", strata, 1.0), 0.2)),
               [(0.25, grey(0.30, (1, 0.98, 0.95))), (0.6, grey(0.46, (1, 0.98, 0.95))), (0.85, grey(0.56))])
    return h, col, nt.math("ADD", 0.78, nt.math("MULTIPLY", grain, 0.15)), 0.9


def basalt(nt, vec, w):
    big = noise(nt, vec, w, 3.5, 6, 0.6)
    pits = nt.math("MULTIPLY", nt.math("LESS_THAN", voronoi(nt, vec, w, 40.0), 0.12), -1.0)
    cells = voronoi(nt, vec, w, 1.6, "DISTANCE_TO_EDGE")
    cracks = nt.math("MULTIPLY", nt.math("SUBTRACT", 1.0, nt.math("MULTIPLY", cells, 18.0, True)), -1.0)
    grain = noise(nt, vec, w, 30.0, 8, 0.7)
    h = nt.math("ADD", nt.math("ADD", nt.math("MULTIPLY", big, 0.5), nt.math("MULTIPLY", grain, 0.25)),
                nt.math("ADD", nt.math("MULTIPLY", pits, 0.25), nt.math("MULTIPLY", cracks, 0.35)))
    col = ramp(nt, nt.math("ADD", nt.math("MULTIPLY", big, 0.6), nt.math("MULTIPLY", grain, 0.4)),
               [(0.3, grey(0.10, (1, 1, 1.04))), (0.7, grey(0.19, (1, 1, 1.03)))])
    return h, col, nt.math("ADD", 0.82, nt.math("MULTIPLY", grain, 0.12)), 0.8


MATS = {"regolith": regolith, "craterdust": crater_dust, "highland": highland_rock, "basalt": basalt}

bpy.ops.mesh.primitive_plane_add(size=2)
plane = bpy.context.object


def bake(mat, kind, img):
    nt = mat.node_tree
    tex = nt.nodes.new("ShaderNodeTexImage"); tex.image = img
    nt.nodes.active = tex
    bpy.context.view_layer.objects.active = plane; plane.select_set(True)
    if kind == "NORMAL":
        bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT", use_clear=True)
    else:
        bpy.ops.object.bake(type="EMIT", use_clear=True)
    nt.nodes.remove(tex)


baked = {}
for name, fn in MATS.items():
    mat = bpy.data.materials.new(name); mat.use_nodes = True
    nt = NT(mat)
    for nd in list(nt.n):
        if nd.type != "OUTPUT_MATERIAL":
            nt.n.remove(nd)
    outn = [nd for nd in nt.n if nd.type == "OUTPUT_MATERIAL"][0]
    vec, w = torus(nt)
    h, col, rough, strength = fn(nt, vec, w)
    bump = nt.node("ShaderNodeBump", Strength=strength, Distance=0.06)
    nt.link(h, bump.inputs["Height"])
    bsdf = nt.node("ShaderNodeBsdfPrincipled")
    nt.link(col, bsdf.inputs["Base Color"]); nt.link(rough, bsdf.inputs["Roughness"]); nt.link(bump.outputs["Normal"], bsdf.inputs["Normal"])
    emi = nt.node("ShaderNodeEmission")
    plane.data.materials.clear(); plane.data.materials.append(mat)
    imgs = {}
    for kind, socket, cs in (("color", col, "sRGB"), ("rough", rough, "Non-Color"), ("normal", None, "Non-Color")):
        img = bpy.data.images.new(f"{name}_{kind}", SIZE, SIZE, alpha=False, float_buffer=False)
        img.colorspace_settings.name = cs
        if kind == "normal":
            nt.link(bsdf.outputs[0], outn.inputs["Surface"])
            bake(mat, "NORMAL", img)
        else:
            nt.link(socket, emi.inputs["Color"]); nt.link(emi.outputs[0], outn.inputs["Surface"])
            bake(mat, "EMIT", img)
        img.filepath_raw = os.path.join(out, f"{name}_{kind}.png"); img.file_format = "PNG"; img.save()
        imgs[kind] = img
    baked[name] = imgs
    print("BAKED", name)

# ---- the sheet: each set on a 3x3-tiled plane, low sun (does it tile, does it read as the Moon?)
for o in list(bpy.data.objects):
    bpy.data.objects.remove(o)
for k, (name, imgs) in enumerate(baked.items()):
    bpy.ops.mesh.primitive_plane_add(size=2, location=((k % 2) * 2.1 - 1.05, (k // 2) * -2.1 + 1.05, 0))
    p = bpy.context.object
    m = bpy.data.materials.new(name + "_view"); m.use_nodes = True
    t = m.node_tree; b = t.nodes["Principled BSDF"]
    mp = t.nodes.new("ShaderNodeMapping"); mp.inputs["Scale"].default_value = (3, 3, 1)
    tc = t.nodes.new("ShaderNodeTexCoord"); t.links.new(tc.outputs["UV"], mp.inputs[0])
    for kind, sock in (("color", "Base Color"), ("rough", "Roughness")):
        tx = t.nodes.new("ShaderNodeTexImage"); tx.image = imgs[kind]; t.links.new(mp.outputs[0], tx.inputs[0])
        t.links.new(tx.outputs["Color"], b.inputs[sock])
    tx = t.nodes.new("ShaderNodeTexImage"); tx.image = imgs["normal"]; t.links.new(mp.outputs[0], tx.inputs[0])
    nm = t.nodes.new("ShaderNodeNormalMap"); t.links.new(tx.outputs["Color"], nm.inputs["Color"]); t.links.new(nm.outputs[0], b.inputs["Normal"])
    p.data.materials.append(m)
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN")); sc.collection.objects.link(sun)
sun.data.energy = 5; sun.rotation_euler = (math.radians(72), 0, math.radians(40))
world = bpy.data.worlds.new("w"); sc.world = world
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam")); sc.collection.objects.link(cam); sc.camera = cam
cam.data.type = "ORTHO"; cam.data.ortho_scale = 4.4; cam.location = (0, 0, 5)
sc.render.resolution_x = sc.render.resolution_y = 1200
sc.cycles.samples = 32
sc.render.filepath = os.path.join(out, "sheet.png"); bpy.ops.render.render(write_still=True)
print("MATERIALS_OK")
