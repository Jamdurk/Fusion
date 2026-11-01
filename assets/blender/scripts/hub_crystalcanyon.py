# Alien Fusion hub: the CRYSTAL CANYON kit (31 Oct 2026). Built from the ChatGPT references
#   design\concepts\hub\E2b-crystal-canyon-ortho-sheet-chatgpt.png (sizes, front / side / top views),
#   E2-crystal-canyon-hero-sheet-chatgpt.png (look), E3 (materials, hex targets in design\map-review\crystal-canyon\E3-reply.txt),
#   E-crystal-canyon-chatgpt.png (master look). Spec: design\map-review\crystal-canyon\SPEC.md.
# James: jagged amber crystals that look like real translucent quartz, cracked mid-grey basalt (never black: LESSONS 15),
# thin glowing magma seams; sharp angular shapes only; nothing "Robloxy".
# Same conventions as hub_goomarsh.py: Blender space (z up, 1 unit = 1 stud, base at the origin, front = -Y); the GLB goes
# to Roblox as (-x, z, y). Every mesh gets a kind (crystal / basalt / tunnel / seam) that hub_crystalcanyon_tex.py bakes.
#   blender --background --factory-startup --python hub_crystalcanyon.py -- <assets_dir> [geo|full]
import bpy, bmesh, math, os, random, sys
from mathutils import Vector, Matrix, noise

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ASSETS = args[0] if args else r"D:/Roblox Game Venture/Games/Alien Fusion/assets"
MODE = args[1] if len(args) > 1 else "geo"
for o in list(bpy.data.objects): bpy.data.objects.remove(o, do_unlink=True)
TAU = 2 * math.pi
KIT = {}                                                    # name -> (object, kind, texture size)

def link(ob):
    bpy.context.scene.collection.objects.link(ob); return ob

def fl(bm, name):
    return bm.verts.layers.float.get(name) or bm.verts.layers.float.new(name)

def finish(name, bm, kind, size=1024, smooth=True, recalc=True):
    if recalc: bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    for p in me.polygons: p.use_smooth = smooth
    ob = link(bpy.data.objects.new(name, me)); KIT[name] = (ob, kind, size); return ob

def frame(d):
    up = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
    s1 = d.cross(up).normalized(); return s1, s1.cross(d).normalized()

def tris_of(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)

def sharp_edges(ob, deg):
    """smooth shading with hard edges where faces meet at > deg (split normals: the GLB keeps crisp chipped rock edges)"""
    bm = bmesh.new(); bm.from_mesh(ob.data)
    for f in bm.faces: f.smooth = True
    for e in bm.edges:
        e.smooth = not (len(e.link_faces) == 2 and e.calc_face_angle(0.0) > math.radians(deg))
    bm.to_mesh(ob.data); bm.free(); ob.data.update()

# ---------------------------------------------------------------- crystals (E2b: long hexagonal prisms, pyramid tips)
def crystal(bm, base, d, L, r, rng, steps=0, chamfer=False, tip=0.27, broken=False, sink=None):
    """one amber quartz crystal: an irregular hexagonal prism (faces 0.85-1.12 x r), slight taper, optional growth bands
    (steps = radius jumps that catch the light), optional narrow chamfers on the 6 long edges (big crystals), a 6-facet
    pyramid tip leaning a little off-axis (or a broken flat top). Root sunk below `base` along -d. Vertex floats: cT 0 root
    .. 1 tip (colour ramp), cI = crystal id 0..1 (per-crystal tint)."""
    d = d.normalized(); s1, s2 = frame(d)
    ct, ci = fl(bm, "cT"), fl(bm, "cI"); cid = rng.random()
    rot = rng.uniform(0, TAU)
    rk = [rng.uniform(0.86, 1.12) for _ in range(6)]
    angs = []
    for k in range(6):
        a = rot + TAU * k / 6 + rng.uniform(-0.08, 0.08)
        if chamfer: angs += [(a - 0.07, rk[k]), (a + 0.07, rk[k])]
        else: angs.append((a, rk[k]))
    n = len(angs)
    sink = r * 1.4 if sink is None else sink
    shoulder = L * (1 - tip)
    hs = [-sink, 0.0]                                       # ring heights along d
    if steps:
        for j in range(steps):
            h = shoulder * (j + 1) / (steps + 1); hs += [h - 0.12 * r, h + 0.06 * r]
    hs.append(shoulder)
    def rad_at(h, j):
        taper = 1 - 0.1 * max(0.0, h) / L
        band = 1.0
        if steps:   # growth bands: each band a touch slimmer than the one below
            band = 1 - 0.035 * sum(1 for q in range(2, len(hs) - 1, 2) if h >= hs[q + 1] - 1e-6)
        return r * taper * band
    rings = []
    for j, h in enumerate(hs):
        ring = []
        for (a, kk) in angs:
            v = bm.verts.new(base + d * h + (s1 * math.cos(a) + s2 * math.sin(a)) * rad_at(h, j) * kk)
            v[ct] = max(0.0, h) / L; v[ci] = cid; ring.append(v)
        rings.append(ring)
    for j in range(len(rings) - 1):
        A, B = rings[j], rings[j + 1]
        for k in range(n):
            bm.faces.new((A[k], A[(k + 1) % n], B[(k + 1) % n], B[k]))
    bot = bm.verts.new(base - d * (sink + 0.2 * r)); bot[ct] = 0; bot[ci] = cid
    for k in range(n): bm.faces.new((rings[0][(k + 1) % n], rings[0][k], bot))
    top = rings[-1]
    if broken:   # a broken, flat-ish top with a little bevel ring
        mid = [bm.verts.new(base + d * (shoulder + 0.25 * r) + (v.co - (base + d * shoulder)) * 0.7) for v in top]
        for v in mid: v[ct] = 0.9; v[ci] = cid
        for k in range(n): bm.faces.new((top[k], top[(k + 1) % n], mid[(k + 1) % n], mid[k]))
        bm.faces.new(mid)
    else:
        off = (s1 * rng.uniform(-1, 1) + s2 * rng.uniform(-1, 1)) * r * 0.18
        apex = bm.verts.new(base + d * L + off); apex[ct] = 1.0; apex[ci] = cid
        if chamfer:   # a small ring just under the apex keeps the 6 big tip facets + narrow chamfer facets
            mid = []
            for k, v in enumerate(top):
                p = base + d * shoulder
                mid.append(bm.verts.new(p + (v.co - p) * 0.32 + d * (L - shoulder) * 0.72 + off * 0.7))
                mid[-1][ct] = 0.93; mid[-1][ci] = cid
            for k in range(n): bm.faces.new((top[k], top[(k + 1) % n], mid[(k + 1) % n], mid[k]))
            for k in range(n): bm.faces.new((mid[k], mid[(k + 1) % n], apex))
        else:
            for k in range(n): bm.faces.new((top[k], top[(k + 1) % n], apex))

def lean_dir(az, tilt):
    """a direction tilted `tilt` deg from +z toward azimuth az (rad)"""
    t = math.radians(tilt); return Vector((math.sin(t) * math.cos(az), math.sin(t) * math.sin(az), math.cos(t)))

def crystal_set(name, specs, size=1024, seed=0):
    """specs: [(base (x,y,z), azimuth deg, tilt deg, length, radius, dict(extra))] -> one flat-shaded crystal mesh"""
    bm = bmesh.new(); rng = random.Random(seed)
    for (b, az, tilt, L, r, kw) in specs:
        crystal(bm, Vector(b), lean_dir(math.radians(az), tilt), L, r, rng, **kw)
    return finish(name, bm, "crystal", size, smooth=False)

def ring_of(rng, n, cx, cy, z, R, L0, L1, r0, r1, tilt0, tilt1, ry=None, out=True, arc=(0, 360), kw=None):
    """n crystals round an ellipse (R, ry), leaning outward"""
    ry = ry or R; out_l = []
    for i in range(n):
        a = math.radians(arc[0] + (arc[1] - arc[0]) * (i + rng.uniform(0.2, 0.8)) / n)
        x, y = cx + math.cos(a) * R, cy + math.sin(a) * ry
        out_l.append(((x, y, z), math.degrees(a) if out else rng.uniform(0, 360), rng.uniform(tilt0, tilt1),
                      rng.uniform(L0, L1), rng.uniform(r0, r1), dict(kw or {})))
    return out_l

# ---------------------------------------------------------------- basalt masses (faceted lumps -> fused -> chipped)
def facet(bm, verts, rng, cuts, depth=(0.06, 0.2), down_ok=False):
    """planar chip cuts (LESSONS 23 / 3): flatten every vertex beyond a random plane onto it = flat angular faces"""
    if not verts: return
    c = sum((v.co for v in verts), Vector()) / len(verts)
    for _ in range(cuts):
        n = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.25 if not down_ok else -1, 1))).normalized()
        proj = [(v.co - c).dot(n) for v in verts]
        mx, mn = max(proj), min(proj)
        cut = mx - (mx - mn) * rng.uniform(*depth)
        for v, p in zip(verts, proj):
            if p > cut: v.co -= n * (p - cut)

def lump(bm, c, r, sq, rng, cuts=9, subd=3, depth=(0.06, 0.22), block=False):
    """one angular basalt chunk: a squashed icosphere with planar chip cuts; block = a chipped BOX (stacked-block
    basalt of E2b: flat tops + square-ish sides, geo r5: the icosphere arch read as potatoes)"""
    tb = bmesh.new()                                         # built alone, then appended (keeps the facet cuts per chunk)
    if block:
        bmesh.ops.create_cube(tb, size=1.6, matrix=Matrix.Identity(4))
        bmesh.ops.subdivide_edges(tb, edges=tb.edges[:], cuts=3, use_grid_fill=True)
    else:
        bmesh.ops.create_icosphere(tb, subdivisions=subd, radius=1.0, matrix=Matrix.Identity(4))
    vs = tb.verts[:]
    rotm = Matrix.Rotation(rng.uniform(0, TAU), 4, "Z") @ (Matrix.Rotation(rng.uniform(-0.12, 0.12), 4, "X") if block else Matrix.Identity(4))
    for v in vs:
        dd = v.co.copy(); k = 1 + (0.05 if block else 0.1) * noise.noise(dd * 1.3 + Vector((rng.random() * 9, 0, 0)))
        v.co = Vector(c) + rotm @ Vector((dd.x * sq[0], dd.y * sq[1], dd.z * sq[2])) * r * k
    facet(tb, vs, rng, cuts if not block else max(4, cuts // 2), depth)
    me = bpy.data.meshes.new("_lump"); tb.to_mesh(me); tb.free(); bm.from_mesh(me); bpy.data.meshes.remove(me)
    return vs

def rockmass(name, lumps, voxel, disp, target, size, kind="basalt", seed=0, cut_z=-0.6, cutter=None, fine=0.0, blocks=0.0):
    """basalt mass (LESSONS 23): faceted lumps fused by a voxel remesh, an optional boolean cutter (tunnel / arch
    opening: ("cyl_y", x, z, rx, rz, y0, y1)), chipped by a noise displace = the HIGH mesh "<name>_hi" (normal bake);
    a decimated copy = the game mesh"""
    rng = random.Random(seed); bm = bmesh.new()
    for it in lumps:   # (c, r, squash[, block])
        c, r, sq = it[:3]; blk = it[3] if len(it) > 3 else rng.random() < blocks
        lump(bm, c, r, sq, rng, cuts=rng.randint(10, 15), depth=(0.08, 0.28), block=blk)   # (geo r2: sharper blocks, E2b)
    me = bpy.data.meshes.new(name + "_hi"); bm.to_mesh(me); bm.free()
    hi = link(bpy.data.objects.new(name + "_hi", me))
    bpy.ops.object.select_all(action="DESELECT"); bpy.context.view_layer.objects.active = hi; hi.select_set(True)
    rm = hi.modifiers.new("rm", "REMESH"); rm.mode = "VOXEL"; rm.voxel_size = voxel; bpy.ops.object.modifier_apply(modifier="rm")
    if cutter:
        cb = bmesh.new(); _, cx, cz, rx, rz, y0, y1 = cutter
        bmesh.ops.create_cone(cb, cap_ends=True, segments=36, radius1=1.0, radius2=1.0, depth=y1 - y0,
                              matrix=Matrix.Translation((cx, (y0 + y1) / 2, cz)) @ Matrix.Rotation(math.pi / 2, 4, "X")
                              @ Matrix.Diagonal((rx, rz, 1.0, 1.0)))
        cm = bpy.data.meshes.new(name + "Cut"); cb.to_mesh(cm); cb.free()
        co_ = link(bpy.data.objects.new(name + "Cut", cm))
        bo = hi.modifiers.new("cut", "BOOLEAN"); bo.operation = "DIFFERENCE"; bo.solver = "EXACT"; bo.object = co_
        bpy.context.view_layer.objects.active = hi; bpy.ops.object.modifier_apply(modifier="cut")
        bpy.data.objects.remove(co_, do_unlink=True)
    bm = bmesh.new(); bm.from_mesh(hi.data)
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, 0, cut_z), plane_no=(0, 0, 1), clear_inner=True)
    bm.to_mesh(hi.data); bm.free()
    # (geo r3: the displaced mesh read as soft river stones. The GAME mesh keeps the flat chip faces of the faceted lumps;
    # the noise + plate chips go only into the high copy = the normal map)
    lo = hi.copy(); lo.data = hi.data.copy(); lo.name = name; lo.data.name = name; link(lo)
    bpy.ops.object.select_all(action="DESELECT"); bpy.context.view_layer.objects.active = hi; hi.select_set(True)
    tex = bpy.data.textures.new(name + "_n", "CLOUDS"); tex.noise_scale = 0.7; tex.noise_depth = 3
    ds = hi.modifiers.new("ds", "DISPLACE"); ds.texture = tex; ds.strength = disp; ds.mid_level = 0.5
    bpy.ops.object.modifier_apply(modifier="ds")
    if fine:
        tf = bpy.data.textures.new(name + "_f", "VORONOI"); tf.noise_scale = 0.35; tf.distance_metric = "DISTANCE"
        tf.weight_1, tf.weight_2 = -1.0, 1.0                 # (F2 - F1: chipped plate edges)
        d2 = hi.modifiers.new("d2", "DISPLACE"); d2.texture = tf; d2.strength = fine; d2.mid_level = 0.0
        bpy.ops.object.modifier_apply(modifier="d2")
    bpy.ops.object.select_all(action="DESELECT"); bpy.context.view_layer.objects.active = lo; lo.select_set(True)
    d = lo.modifiers.new("dec", "DECIMATE"); d.ratio = min(1.0, target / max(1, tris_of(lo)))
    bpy.ops.object.modifier_apply(modifier="dec")
    sharp_edges(lo, 36)
    for p in hi.data.polygons: p.use_smooth = True
    hi.hide_render = True
    KIT[name] = (lo, kind, size); return lo

def pile(rng, cx, cy, R, n, r0, r1, zf=0.55, ry=None, h0=0.0):
    """n angular chunks heaped round (cx, cy) inside an ellipse R x ry, the big ones in the middle"""
    ry = ry or R; out = []
    for i in range(n):
        a = rng.uniform(0, TAU); f = math.sqrt(rng.random()); rr = rng.uniform(r0, r1) * (1.25 - 0.5 * f)
        x, y = cx + math.cos(a) * R * f, cy + math.sin(a) * ry * f
        out.append(((x, y, h0 + rr * zf * (1.2 - 0.6 * f)), rr, (rng.uniform(0.9, 1.25), rng.uniform(0.85, 1.15), rng.uniform(0.6, 0.95))))
    return out

# ---------------------------------------------------------------- 1. LANDMARK spire (E2b row 1): 50 tall, base 30 wide
rng = random.Random(101)
base_l = [((0, 0, 5.0), 11.0, (1.2, 1.0, 1.05)),   # (geo r3: a taller block mountain, E2b)
           ((-8, 3, 3.2), 7.0, (1, 1, 1.0)), ((8, -2, 3.0), 7.0, (1, 1, 0.95)),
          ((2, 8, 2.6), 6.0, (1, 1, 1.0)), ((-4, -8, 2.2), 5.5, (1, 1, 0.95)), ((0, 0, 10.5), 6.0, (1, 1, 1.1)), ((-5, 2, 8.5), 4.5, (1, 1, 1)), ((5, -3, 8.0), 4.5, (1, 1, 1))]
base_l += pile(rng, 0, 0, 13.5, 16, 1.8, 3.8, h0=0.0)
base_l += [((0, 0, 14.0), 5.5, (1.1, 1, 1.1)), ((-3.5, 3, 12.5), 4.6, (1, 1, 1)), ((3.5, -2.5, 12.0), 4.6, (1, 1, 1)), ((1, 4, 11), 4, (1, 1, 1))]   # (geo r4: rock core up to ~18, E2b)
rockmass("ccSpireRock", base_l, 0.3, 0.18, 4600, 1024, seed=102, fine=0.3, blocks=0.6)   # (geo r2: base 30 wide x ~14 tall, angular)
SPIRE = [((0.6, 1.2, 9.0), 120, 5, 44.0, 4.3, dict(steps=3, chamfer=True)),      # main: top ~52
         ((-5.2, 2.6, 7.0), 160, 17, 33.0, 3.4, dict(steps=2, chamfer=True)),
         ((5.0, -0.5, 6.5), 345, 21, 29.0, 3.2, dict(steps=2, chamfer=True)),
         ((-1.0, -5.5, 5.0), 255, 26, 22.0, 2.6, dict(steps=1, chamfer=True)),
         ((3.5, 5.5, 4.0), 60, 30, 16.0, 2.3, dict(steps=1, chamfer=True)),      # (spec audit r1 fix 4: 4 crystals dominate,
         ((-7.5, -3.0, 3.0), 205, 38, 12.0, 1.9, dict(chamfer=True)),             #  the rest shorter + sunk between them)
         ((8.0, 4.0, 2.5), 25, 42, 10.0, 1.6, dict(chamfer=True))]
SPIRE += ring_of(rng, 10, 0, 0, 3.5, 12.5, 3.0, 7.0, 0.6, 1.2, 35, 62, ry=11.5)
SPIRE += ring_of(rng, 6, 0, 0, 9.0, 7.5, 4.0, 8.0, 0.8, 1.4, 25, 50)
crystal_set("ccSpireCrystal", SPIRE, 1024, seed=103)

# ---------------------------------------------------------------- 2-4. clusters + shards (E2b row 2)
rng = random.Random(201)
rockmass("ccClusterLRock", pile(rng, 0, 0, 6.0, 11, 1.0, 2.2) + [((0, 0, 1.2), 3.0, (1.2, 1.0, 0.75))], 0.18, 0.22, 900, 1024, seed=202, blocks=0.4)
crystal_set("ccClusterLCrystal", [((0.2, 0.3, 2.0), 90, 6, 12.5, 1.45, dict(steps=1, chamfer=True)),
                                  ((-1.8, 0.8, 1.6), 170, 22, 8.5, 1.1, {}), ((1.9, -0.4, 1.5), 350, 26, 8.0, 1.05, {}),
                                  ((0.4, -1.9, 1.3), 260, 30, 6.5, 0.9, {}), ((0.9, 2.0, 1.3), 70, 30, 6.0, 0.85, {})]
            + ring_of(rng, 8, 0, 0, 0.6, 4.6, 1.8, 4.2, 0.4, 0.75, 35, 65), 1024, seed=203)
rng = random.Random(211)
rockmass("ccClusterSRock", pile(rng, 0, 0, 2.6, 7, 0.5, 1.1) + [((0, 0, 0.5), 1.4, (1.2, 1.0, 0.7))], 0.12, 0.12, 450, 512, seed=212)
crystal_set("ccClusterSCrystal", [((0, 0.1, 0.9), 90, 5, 5.2, 0.62, {}), ((-0.8, 0.3, 0.7), 170, 24, 3.6, 0.48, {}),
                                  ((0.8, -0.2, 0.7), 350, 26, 3.4, 0.46, {}), ((0.1, -0.8, 0.6), 270, 32, 2.6, 0.4, {})]
            + ring_of(rng, 5, 0, 0, 0.3, 2.0, 0.8, 1.8, 0.22, 0.35, 40, 65), 512, seed=213)
rng = random.Random(221)
sh = []
for i in range(9):
    x, y = rng.uniform(-3.6, 3.6), rng.uniform(-2.4, 2.4)
    sh.append(((x, y, 0.1), rng.uniform(0, 360), rng.uniform(25, 72), rng.uniform(0.7, 2.3), rng.uniform(0.15, 0.32),
               dict(broken=rng.random() < 0.3)))
crystal_set("ccShardsCrystal", sh, 512, seed=222)
bm = bmesh.new()
for i in range(14):
    lump(bm, (rng.uniform(-3.8, 3.8), rng.uniform(-2.6, 2.6), 0.0), rng.uniform(0.25, 0.7), (1.1, 0.9, 0.6), rng, cuts=5, subd=1)
for v in bm.verts: v.co.z = max(v.co.z, -0.3)
finish("ccShardsGravel", bm, "basalt", 512, smooth=False)

# ---------------------------------------------------------------- 5. basalt column outcrops (E2b row 2 right)
def columns(name, footprint, hmax, hmin, seed, size=1024, rmin=1.5, rmax=2.4):
    """a cluster of hexagonal basalt columns: packed on a hex grid with small gaps (dark joints), heights falling off
    from the tall middle, tilted tops, horizontal joint grooves every 4-7 studs, a few short broken stumps at the foot"""
    rng = random.Random(seed); bm = bmesh.new(); jt = fl(bm, "joint"); hl = fl(bm, "hgt")
    w, dpt = footprint; R = (rmin + rmax) / 2; cells = []
    for iy in range(-6, 7):
        for ix in range(-8, 9):
            x = ix * R + (iy % 2) * R * 0.5; y = iy * R * 0.866   # (geo r3: tight hex packing; r2 spacing left 2-stud gaps)
            if (x / (w / 2)) ** 2 + (y / (dpt / 2)) ** 2 <= 1.0: cells.append((x, y))
    # (Blender audit r1 fix 3: read as masonry) natural columnar basalt: 5-7 sided irregular profiles, each turned 5-12 deg,
    # neighbours +-20 % in height, ~30 % leaning 4-8 deg, >= 20 % chipped / broken tops, joints at random heights
    for (x, y) in cells:
        f = math.sqrt((x / (w / 2)) ** 2 + (y / (dpt / 2)) ** 2)
        h = hmin + (hmax - hmin) * (1 - f * 0.8) ** 1.1 * rng.uniform(0.85, 1.12)
        if f > 0.45 and rng.random() < 0.1: h *= rng.uniform(0.35, 0.55)   # broken stumps (outer ring only: the tall middle stays)
        h = max(1.5, h); r = R / 1.732 * rng.uniform(0.9, 1.0)
        ns = rng.choice((5, 6, 6, 7))
        rot = math.pi / 6 + math.radians(rng.choice((-1, 1)) * rng.uniform(5, 12))
        angs = [rot + TAU * (k + rng.uniform(-0.18, 0.18)) / ns for k in range(ns)]
        rk = [rng.uniform(0.86, 1.08) for _ in range(ns)]
        tilt = Vector((rng.uniform(-0.25, 0.25), rng.uniform(-0.25, 0.25), 0))   # tilted top (dz per stud)
        lt = math.tan(math.radians(rng.uniform(4, 8))) if rng.random() < 0.3 else 0.015
        la = rng.uniform(0, TAU); lean = Vector((math.cos(la) * lt, math.sin(la) * lt, 0))
        chip = rng.random() < 0.3                                          # a broken corner off the top
        ck = rng.randrange(ns)
        hs = [-0.8]; z = rng.uniform(2.5, 7.5)
        while z < h - 2.0:
            hs += [z - 0.18, z, z + 0.18]; z += rng.uniform(3.0, 8.0)
        hs.append(h)
        rings = []
        for j, zz in enumerate(hs):
            inset = rng.uniform(0.82, 0.9) if (len(hs) > 2 and 0 < j < len(hs) - 1 and (j - 1) % 3 == 1) else 1.0   # joint groove
            ring = []
            top = (j == len(hs) - 1)
            for k in range(ns):
                a = angs[k]; px, py = math.cos(a) * r * rk[k] * inset, math.sin(a) * r * rk[k] * inset
                dz = tilt.x * px + tilt.y * py if top else 0
                if top and chip and k in (ck, (ck + 1) % ns): dz -= rng.uniform(1.0, 2.2)
                v = bm.verts.new((x + px + lean.x * zz, y + py + lean.y * zz, zz + dz))
                v[jt] = 1.0 if inset < 1 else 0.0; v[hl] = zz / hmax; ring.append(v)
            rings.append(ring)
        for j in range(len(rings) - 1):
            for k in range(ns): bm.faces.new((rings[j][k], rings[j][(k + 1) % ns], rings[j + 1][(k + 1) % ns], rings[j + 1][k]))
        bm.faces.new(rings[-1]); bm.faces.new(list(reversed(rings[0])))
    return finish(name, bm, "basalt", size, smooth=False)

columns("ccColumnA", (15, 11), 25.0, 9.0, 301, rmin=2.7, rmax=3.6)   # (geo r2: fewer, thicker columns, E2b)
columns("ccColumnB", (17, 13), 16.0, 6.0, 302, rmin=2.7, rmax=3.6)

# ---------------------------------------------------------------- 6. boulders (E2b row 3: 4 / 7 / 11 wide)
rng = random.Random(401)
rockmass("ccBoulderA", [((0, 0, 1.2), 2.0, (1.0, 0.85, 0.75))], 0.12, 0.12, 320, 512, seed=402)
rockmass("ccBoulderB", [((0, 0, 2.2), 3.2, (1.05, 0.9, 0.85)), ((1.6, 0.6, 1.0), 1.8, (1, 1, 0.8))], 0.16, 0.2, 480, 512, seed=403)
rockmass("ccBoulderC", [((0, 0, 3.6), 5.0, (1.05, 0.85, 0.82)), ((-2.6, 1.0, 1.6), 2.8, (1, 1, 0.8)),
                        ((2.8, -1.2, 1.4), 2.4, (1, 0.9, 0.8))], 0.2, 0.3, 700, 512, seed=404)

# ---------------------------------------------------------------- 7. amber DNA vein (E2b row 3: 9 wide, 6 tall)
rng = random.Random(501)
# (Blender audit r1 fix 4 + E6 #3: must read as MINEABLE, not decor) a chipped-out cavity: back wall + two cheeks of
# blocky rock open to the front (-Y), ONE big chunky core crystal (1.4x the r1 core) rooted low in the cavity, a few
# small side crystals, 4 broken pieces lying round the foot
vl = [((0, 2.0, 2.2), 3.0, (1.35, 0.75, 0.95), True), ((-3.0, 0.4, 1.6), 2.2, (0.9, 1.1, 0.95), True),
      ((3.0, 0.6, 1.5), 2.1, (0.9, 1.1, 0.95), True), ((-2.0, -1.9, 0.5), 1.1, (1, 1, 0.8)), ((2.1, -1.8, 0.5), 1.0, (1, 1, 0.8)),
      ((0, 0.6, 0.3), 2.2, (1.2, 1.0, 0.35))]
vl += pile(rng, 0, 1.2, 4.6, 7, 0.6, 1.2, ry=2.6)
rockmass("ccVeinRock", vl, 0.15, 0.25, 900, 512, seed=502)
vc = [((0.2, -0.3, 0.6), 270, 16, 8.8, 1.95, dict(chamfer=True, steps=2, sink=1.4)),   # the core: ~9 long, ~4 wide
      ((-1.5, 0.3, 1.2), 210, 34, 4.2, 0.75, {}), ((1.7, 0.4, 1.1), 330, 36, 3.8, 0.7, {}), ((0.3, 1.3, 2.4), 95, 14, 3.4, 0.6, {})]
for k, (x, y, az) in enumerate(((-2.6, -2.6, 200), (2.4, -2.9, 330), (-0.6, -3.4, 250), (1.2, -3.8, 300))):   # broken pieces
    vc.append(((x, y, 0.15), az, rng.uniform(70, 84), rng.uniform(1.1, 1.8), rng.uniform(0.3, 0.45), dict(broken=True, sink=0.1)))
crystal_set("ccVeinCrystal", vc, 512, seed=503)

# ---------------------------------------------------------------- 8. crystal NEST (E2b row 3: 32 wide, 14 tall, mouth 9)
rng = random.Random(601)
nl = [((0, 1.5, 3.0), 9.0, (1.75, 1.25, 0.8)), ((-9.5, 2, 2.6), 6.2, (1.1, 1.2, 0.85)), ((9.5, 2, 2.6), 6.2, (1.1, 1.2, 0.85)),
      ((0, -4.5, 3.0), 6.5, (1.25, 0.8, 0.95)), ((-6, -5.0, 2.4), 4.4, (1, 1, 1)), ((6, -5.0, 2.4), 4.4, (1, 1, 1))]   # (geo r2: 32 wide)
nl += pile(rng, 0, 1, 16.5, 22, 1.3, 3.0, ry=12.0)
for k in range(9):   # (E6 #2) a rim of stacked blocks round the tunnel mouth (the boolean cuts the hole after)
    a = math.pi * k / 8
    nl.append(((math.cos(a) * 7.4, -6.9, 4.6 + math.sin(a) * 6.8), 1.8, (1.0, 0.9, 1.0), True))
# (Blender audit r1 fix 1: the mouth read as a target) 11 wide, a little wider at the bottom
rockmass("ccNestRock", nl, 0.3, 0.18, 3000, 1024, seed=602, cutter=("cyl_y", 0.0, 4.4, 5.6, 5.0, -16.0, 3.4), fine=0.25, blocks=0.4)
# the lining: 7 irregular angular rock RIBS (polygon rings, every other one inset = a ridge), the mouth wider at the
# bottom, ~9 studs of depth; vertex floats tunT (0 mouth .. 1 back), rib (1 on a ridge), cap (1 = the dark back wall)
rngt = random.Random(611)
bm = bmesh.new(); tt = fl(bm, "tunT"); rb = fl(bm, "rib"); cp = fl(bm, "cap")
NR, NS = 15, 11
prof = [(rngt.uniform(0.86, 1.1)) for _ in range(NS)]
rings = []
for i in range(NR):
    t = i / (NR - 1); y = -6.2 + 9.2 * t; z0 = 4.4 - 0.4 * t
    ridge = (i % 2 == 1)
    sc = 5.3 * (1 - 0.45 * t) * (0.88 if ridge else 1.0)
    ring = []
    for k in range(NS):
        a = TAU * (k + 0.15 * math.sin(i * 1.7 + k)) / NS
        bottom = max(0.0, -math.sin(a))
        rr = sc * prof[k] * rngt.uniform(0.93, 1.07) * (1 + 0.16 * bottom)
        v = bm.verts.new((math.cos(a) * rr, y + rngt.uniform(-0.15, 0.15), z0 + math.sin(a) * rr * 0.95))
        v[tt] = t; v[rb] = 1.0 if ridge else 0.0; v[cp] = 0.0; ring.append(v)
    rings.append(ring)
for i in range(NR - 1):
    for k in range(NS): bm.faces.new((rings[i][k], rings[i + 1][k], rings[i + 1][(k + 1) % NS], rings[i][(k + 1) % NS]))
core = bm.verts.new((0, 3.6, 3.9)); core[tt] = 1.0; core[cp] = 1.0
for k in range(NS): bm.faces.new((rings[-1][k], core, rings[-1][(k + 1) % NS]))
me = bpy.data.meshes.new("ccNestTunnel"); bm.to_mesh(me); bm.free()
for p in me.polygons: p.use_smooth = False
KIT["ccNestTunnel"] = (link(bpy.data.objects.new("ccNestTunnel", me)), "tunnel", 256)
# crown: crystals all along the top ridge + a fan framing the mouth (E2 / E2b), leaning outward
crown = []   # (geo r2: an even ring read as a sunburst: CLUMPS of 3-4 along the ridge, each leaning one way, like E2b)
for (cx, cy, az, n) in ((-10, 3, 200, 4), (-5, 7, 120, 3), (1, 8, 80, 4), (7, 6, 40, 3), (11, 2, -10, 4), (-2, 2, 100, 3)):
    zc = 7.5 - 0.02 * (cx * cx)
    for j in range(n):
        crown.append(((cx + rng.uniform(-1.6, 1.6), cy + rng.uniform(-1.4, 1.4), zc), az + rng.uniform(-35, 35),
                      rng.uniform(12, 38), rng.uniform(3.5, 8.5) * (1.0 if j else 1.2), rng.uniform(0.6, 1.25), {}))
for a in [math.radians(v) for v in (10, 40, 70, 95, 120, 150, 172)]:   # mouth frame: out from the mouth centre, a bit forward
    dv = Vector((math.cos(a) * 0.6, -0.3, max(math.sin(a), 0.55))).normalized()   # (geo r2: more upright, no rays)
    crown.append(((math.cos(a) * 8.0, -7.4, 4.4 + math.sin(a) * 7.2), math.degrees(math.atan2(dv.y, dv.x)),
                  math.degrees(math.acos(dv.z)), rng.uniform(4.0, 7.5), rng.uniform(0.7, 1.15), {}))
crown += ring_of(rng, 10, 0, 1, 0.4, 15.2, 1.5, 3.5, 0.35, 0.6, 40, 70, ry=11.5, arc=(-60, 240))
crystal_set("ccNestCrystal", crown, 1024, seed=603)

# ---------------------------------------------------------------- 9. magma seam ground plates (E2b row 4 left)
def seam_plate(name, L, W, seed, cell=2.2, res=0.25):
    """polygon basalt slabs separated by glowing cracks (E2b / E3 #5): a dense heightfield (the _hi bake source, vertex
    float crack 1 = crack centre) + a decimated game mesh; soft feathered outline sunk into the ground"""
    rng = random.Random(seed)
    pts = [(rng.uniform(-L / 2 - 2, L / 2 + 2), rng.uniform(-W / 2 - 2, W / 2 + 2)) for _ in range(int(L * W / cell ** 2 * 1.2))]
    # a main hot crack along the length: the cells either side are split by a wavy line
    def crack_at(x, y):
        ds = sorted((x - px) ** 2 + (y - py) ** 2 for (px, py) in pts)
        e = math.sqrt(ds[1]) - math.sqrt(ds[0])                  # F2 - F1 ~ distance to a cell edge x2
        main = abs(y - 0.9 * math.sin(x * 0.45 + seed) - 0.4 * math.sin(x * 1.3)) * 2.0
        return min(e, main)
    nx, ny = int(L / res) + 1, int(W / res) + 1
    bm = bmesh.new(); ck = fl(bm, "crack"); sco = fl(bm, "scorch"); vs = []
    for j in range(ny):
        row = []
        for i in range(nx):
            x, y = -L / 2 + i * res, -W / 2 + j * res
            e = crack_at(x, y)
            # (Blender audit r1 fix 5) outline: chipped + irregular (two noise scales), the edge sinks under the ground;
            # the hot cracks are narrow and DISCONTINUOUS (a slow noise fades whole runs), a 1-2 stud scorched margin
            q = ((abs(x) / (L / 2)) ** 3 + (abs(y) / (W / 2)) ** 3) ** (1 / 3) + 0.2 * noise.noise(Vector((x * 0.22, y * 0.22, seed))) \
                + 0.08 * noise.noise(Vector((x * 0.9, y * 0.9, seed + 7)))
            edge = max(0.0, min(1.0, (q - 0.72) / 0.2))
            slab = 0.55 + 0.12 * noise.noise(Vector((x * 0.5, y * 0.5, seed + 3)))
            h = slab * min(1.0, e / 0.5) ** 0.5 - 0.15 * (1 - min(1.0, e / 0.5))
            h = h * (1 - edge) - 0.45 * edge
            run = max(0.0, min(1.0, (noise.noise(Vector((x * 0.28, y * 0.28, seed + 11))) + 0.15) / 0.3))
            v = bm.verts.new((x, y, h)); v[ck] = max(0.0, 1 - e / 0.32) * (1 - edge) * run
            v[sco] = max(0.0, 1 - e / 1.6) * (1 - 0.6 * edge) * (0.4 + 0.6 * run); row.append(v)
        vs.append(row)
    for j in range(ny - 1):
        for i in range(nx - 1):
            bm.faces.new((vs[j][i], vs[j][i + 1], vs[j + 1][i + 1], vs[j + 1][i]))
    me = bpy.data.meshes.new(name + "_hi"); bm.to_mesh(me); bm.free()
    hi = link(bpy.data.objects.new(name + "_hi", me))
    lo = hi.copy(); lo.data = hi.data.copy(); lo.name = name; lo.data.name = name; link(lo)
    bpy.ops.object.select_all(action="DESELECT"); bpy.context.view_layer.objects.active = lo; lo.select_set(True)
    d = lo.modifiers.new("dec", "DECIMATE"); d.ratio = 1600 / max(1, tris_of(lo)); bpy.ops.object.modifier_apply(modifier="dec")
    for p in lo.data.polygons: p.use_smooth = True
    for p in hi.data.polygons: p.use_smooth = True
    hi.hide_render = True   # (tex r3: the selected-to-active bake from this lost the glow; the game mesh bakes its own crack float)
    KIT[name] = (lo, "seam", 1024); return lo

seam_plate("ccSeamA", 20.0, 6.0, 701)
seam_plate("ccSeamB", 14.0, 5.0, 702)

# ---------------------------------------------------------------- 10. basalt ARCH (E2b row 4: 40 long, 14 tall, opening 24)
rng = random.Random(801)
al = []
for i in range(15):                                          # the deck: a chain of chunks along x, top ~14
    x = -19 + 38 * i / 14
    al.append(((x, rng.uniform(-0.9, 0.9), 11.0 + rng.uniform(-1.2, 1.0)), rng.uniform(2.6, 3.9), (rng.uniform(1.0, 1.4), 1.55, rng.uniform(0.75, 1.05))))   # (Blender audit r1 fix 5: varied blocks)
for sx in (-1, 1):                                           # the piers, flaring at the foot
    for j in range(6):
        z = 1.0 + j * 1.9
        al.append(((sx * (16.0 - 0.25 * j) + rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), z), rng.uniform(3.2, 4.0) - 0.15 * j,
                   (1.05, 1.5 - 0.05 * j, 0.85)))
    al += [((sx * 19.5, rng.uniform(-2.5, 2.5), 1.0), 2.4, (1, 1, 0.8)), ((sx * 13.5, rng.uniform(-3, 3), 0.8), 2.0, (1, 1, 0.8))]
rockmass("ccArch", al, 0.3, 0.18, 2600, 1024, seed=802, cutter=("cyl_y", 0.0, 0.0, 12.0, 9.2, -9.0, 9.0), fine=0.18, blocks=0.9)
crystal_set("ccArchCrystal", ring_of(rng, 7, 0, 0, 13.0, 16.0, 1.5, 3.8, 0.35, 0.7, 20, 50, ry=3.2, arc=(-170, 170)), 512, seed=803)

# ---------------------------------------------------------------- report + save
coll = bpy.data.collections.new("CrystalCanyonKit"); bpy.context.scene.collection.children.link(coll)
for name, (ob, kind, size) in KIT.items():
    for c in list(ob.users_collection): c.objects.unlink(ob)
    coll.objects.link(ob); ob["kind"] = kind
    me = ob.data; me.calc_loop_triangles()
    xs = [v.co.x for v in me.vertices]; ys = [v.co.y for v in me.vertices]; zs = [v.co.z for v in me.vertices]
    print("PIECE %-18s %-7s %4d  size %.1f x %.1f x %.1f  z %.1f..%.1f  tris %d" % (name, kind, size, max(xs) - min(xs),
          max(ys) - min(ys), max(zs) - min(zs), min(zs), max(zs), len(me.loop_triangles)))
print("TOTAL TRIS", sum(len(o.data.loop_triangles) for o, _, _ in KIT.values()))
bd = os.path.join(ASSETS, "blender", "hub"); os.makedirs(bd, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(bd, "crystalcanyon_geo.blend"))
print("SAVED geo")
