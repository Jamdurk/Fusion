# Alien Fusion hub: the GOO MARSH kit (30 Oct 2026). Built from the ChatGPT references
#   design\concepts\hub\D2b-goo-marsh-ortho-sheet-chatgpt.png (sizes, front / side / below views),
#   D3-goo-marsh-materials-chatgpt.png (materials + hex targets in design\map-review\goo-marsh\D3-reply.txt),
#   D-goo-marsh-chatgpt.png (look), D2-goo-marsh-model-sheet-chatgpt.png. Spec: design\map-review\goo-marsh\SPEC.md.
# James: soft wet GLOWING goo + glowing lilac gills, never shiny plastic toy balls.
# Authored straight in BLENDER space (z up, 1 unit = 1 stud, base at the origin, front = -Y). The GLB goes to Roblox as
# (-x, z, y), so Blender -Y = Roblox -Z = the piece's front. No R2B step (unlike hub_moonwood_tex.py).
# Every mesh gets a "kind" (stalk / goo / gill / rock / crystal / tunnel / pool) that hub_goomarsh_tex.py bakes.
#   blender --background --factory-startup --python hub_goomarsh.py -- <assets_dir> [geo|full]
import bpy, bmesh, math, os, random, sys
from mathutils import Vector, Matrix, noise, Quaternion

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ASSETS = args[0] if args else r"D:/Roblox Game Venture/Games/Alien Fusion/assets"
MODE = args[1] if len(args) > 1 else "geo"
for o in list(bpy.data.objects): bpy.data.objects.remove(o, do_unlink=True)
TAU = 2 * math.pi
KIT = {}                                                    # name -> (object, kind, texture size)

def link(ob):
    bpy.context.scene.collection.objects.link(ob); return ob

def finish(name, bm, kind, size=1024, smooth=True):
    if kind not in ("stalk", "gill"):   # (r7: open tubes / the gill cone are wound right by construction; recalc flipped some inward)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    for p in me.polygons: p.use_smooth = smooth
    ob = link(bpy.data.objects.new(name, me)); KIT[name] = (ob, kind, size); return ob

def fl(bm, name):
    return bm.verts.layers.float.get(name) or bm.verts.layers.float.new(name)

# ---------------------------------------------------------------- primitives
def frame(d):
    up = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
    s1 = d.cross(up).normalized(); return s1, s1.cross(d).normalized()

def tube(bm, pts, rads, sides=8, twist=0.0, strands=0, amp=0.0, cap=True, tag=None, tagv=None):
    """a smooth tube along pts (radii rads); strands > 0 = rope strands twisting round it (the pearl stalks of D3 #3)"""
    rings = []; cl = fl(bm, "crest") if strands else None    # crest = the strand ridge (+1) / groove (-1), for the bake
    for i, p in enumerate(pts):
        d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized(); s1, s2 = frame(d)
        ring = []
        for k in range(sides):
            a = TAU * k / sides
            bump = 1 + amp * math.cos(strands * (a + twist * i)) if strands else 1
            v = bm.verts.new(p + (s1 * math.cos(a) + s2 * math.sin(a)) * rads[i] * bump)
            if tag: v[tag] = tagv[i] if isinstance(tagv, list) else tagv
            if cl: v[cl] = math.cos(strands * (a + twist * i))
            ring.append(v)
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(sides):
            bm.faces.new((rings[i + 1][k], rings[i + 1][(k + 1) % sides], rings[i][(k + 1) % sides], rings[i][k]))   # (r7: wound OUTWARD; Roblox culls back faces)
    if cap:
        tip = bm.verts.new(pts[-1] + (pts[-1] - pts[-2]).normalized() * rads[-1] * 0.6)
        if tag: tip[tag] = tagv[-1] if isinstance(tagv, list) else tagv
        for k in range(sides): bm.faces.new((rings[-1][(k + 1) % sides], rings[-1][k], tip))
    return rings

def bez(p0, p1, p2, n):
    return [p0 * (1 - t) ** 2 + p1 * 2 * t * (1 - t) + p2 * t * t for t in (i / (n - 1) for i in range(n))]

def drip(bm, top, L, r0, tag, sides=7, n=8):
    """a hanging goo drip (D3 #1 / #5): a thick root tucked into the rim, a neck, a fat teardrop bulb, a soft tip"""
    pts = [top + Vector((0, 0, 0.9 * r0 - L * i / (n - 1))) for i in range(n)]   # (r7: root tucked deeper, slimmer: read as teeth)
    P = [0.95, 0.85, 0.66, 0.52, 0.6, 0.82, 0.75, 0.35]; T = [0.4, 0.55, 0.75, 0.9, 1, 1, 1, 1]
    idx = [round(i * 7 / (n - 1)) for i in range(n)]
    tube(bm, pts, [r0 * P[j] for j in idx], sides, tag=tag, tagv=[T[j] for j in idx])

# ---------------------------------------------------------------- mushrooms (D2b rows 1-2)
def mushroom(bms, base, h, sr, cr, th, lean=(0.0, 0.0), strands=7, roots=0, gills=14, gdepth=1.0, drips=10,
             dlen=(1.5, 4.0), lobes=0.06, seed=0, sides=48, ring_step=1.0, nr=7, lo=False, dsides=7, dn=8, bst=6,
             ssides=None, rimdrop=0.22):
    """stalk (rope-twisted, flared foot + flared top), goo cap (lumpy lobed dome, rolled rim, hanging drips) and a gill
    underside (shallow cone + BROAD radial gill blades, spec audit r1 fix 3: 12-16 readable gills, the fine grooves go
    in the bake). h = cap top, sr = stalk radius, cr = cap radius, th = cap thickness. lo = fewer cap rows (small ones,
    audit fix 1: trumpet 1.2-1.5k, umbrella 0.9-1.2k)."""
    stalk, cap, gill = bms
    rng = random.Random(seed); ph = rng.uniform(0, TAU)
    hu = h - th * 0.62                                      # gill apex (where the stalk meets the cap)
    rim = hu - cr * rimdrop                                 # cap rim height (geo r2: the underside rises steeply inward
    D = h - rim                                             # so the violet gill band shows from the side, like D2b)
    top = base + Vector((lean[0], lean[1], hu + 0.2))
    def sc(a): return 1 + lobes * math.cos(3 * a + ph) + 0.6 * lobes * math.cos(5 * a + 2 * ph)
    # stalk: n rings up a gentle S; foot flare 1.7x, waist 0.9x, top flare 1.45x into the gills
    n = max(5, int(hu / ring_step))
    mid = base.lerp(top, 0.5) + Vector((-lean[0] * 0.6, -lean[1] * 0.6, 0)) + Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), 0)) * sr * 0.3
    pts = bez(base + Vector((0, 0, -0.4)), mid, top, n)
    def prof(t):
        return sr * (1.0 + 0.8 * math.exp(-t * 9) + 1.25 * t ** 2.4 - 0.12 * math.sin(math.pi * t))   # (geo r3: vase flare from mid-height, D2b)
    st = fl(stalk, "stT")
    tube(stalk, pts, [prof(i / (n - 1)) for i in range(n)], ssides or max(10, int(sides * 0.6)), twist=0.12,
         strands=strands, amp=0.13 if not lo else 0.09, cap=False, tag=st, tagv=[i / (n - 1) for i in range(n)])
    for i in range(roots):                                   # buttress roots (the giant's flared base in D2b)
        a = TAU * i / roots + rng.uniform(-0.25, 0.25); d = Vector((math.cos(a), math.sin(a), 0))
        L = sr * rng.uniform(1.9, 2.5)
        rp = bez(base + Vector((0, 0, sr * 1.3)) + d * sr * 0.5, base + Vector((0, 0, sr * 0.35)) + d * sr * 1.5,
                 base + Vector((0, 0, -0.5)) + d * (sr + L), 7 if not lo else 5)
        rs = (0.6, 0.55, 0.48, 0.4, 0.3, 0.2, 0.12) if not lo else (0.6, 0.5, 0.36, 0.22, 0.12)
        tube(stalk, rp, [sr * f for f in rs], 8 if not lo else 6, twist=0.1, strands=3, amp=0.08, tag=st, tagv=0.0)
    # cap: lathe round the stalk top; rows (radius fraction, height) from the pole down over the rim and back under
    c0 = Vector((top.x, top.y, 0))
    if lo:
        rows = [(0.0, h), (0.4, h - 0.1 * D), (0.72, h - 0.36 * D), (0.92, h - 0.7 * D), (1.0, rim + 0.06 * D),
                (0.94, rim - 0.06 * D), (0.88, rim + 0.14 * D), (0.0, hu + 0.6 * th)]   # (geo r4: the cap underside stays ABOVE the gill cone)
        rimrows = (4, 5)
    else:
        rows = [(0.0, h), (0.22, h - 0.03 * D), (0.45, h - 0.12 * D), (0.66, h - 0.27 * D), (0.82, h - 0.46 * D),
                (0.93, h - 0.66 * D), (0.99, h - 0.84 * D), (1.0, rim + 0.04 * D), (0.96, rim - 0.07 * D),
                (0.92, rim - 0.02 * D), (0.88, rim + 0.12 * D), (0.0, hu + 0.6 * th)]
        rimrows = (7, 8)
    ct = fl(cap, "dripT"); rr = []
    for j, (f, z) in enumerate(rows):
        if f == 0:
            v = cap.verts.new(c0 + Vector((0, 0, z))); v[ct] = 0; rr.append([v]); continue
        ring = []
        for k in range(sides):
            a = TAU * k / sides; s = sc(a)
            sag = (s - 1) * th * 1.4 * (1 if f > 0.8 or j == len(rows) - 2 else 0)   # lobes droop a little at the edge
            wob = 1 + 0.025 * noise.noise(Vector((math.cos(a) * 3, math.sin(a) * 3, z * 0.3 + seed)))
            v = cap.verts.new(c0 + Vector((math.cos(a) * f * cr * s * wob, math.sin(a) * f * cr * s * wob, z - sag)))
            v[ct] = 0.15 if j in rimrows else 0.0; ring.append(v)
        rr.append(ring)
    for i in range(len(rr) - 1):
        A, B = rr[i], rr[i + 1]
        for k in range(sides):
            if len(A) == 1: cap.faces.new((A[0], B[k], B[(k + 1) % sides]))
            elif len(B) == 1: cap.faces.new((A[k], B[0], A[(k + 1) % sides]))
            else: cap.faces.new((A[k], B[k], B[(k + 1) % sides], A[(k + 1) % sides]))
    for q in range(drips):
        a = TAU * (q + rng.uniform(-0.3, 0.3)) / drips; s = sc(a)
        p = c0 + Vector((math.cos(a) * 0.97 * cr * s, math.sin(a) * 0.97 * cr * s, rim - 0.04 * D - (s - 1) * th * 1.4))
        drip(cap, p, rng.uniform(*dlen) * (1.3 if s > 1.03 else 1), cr * rng.uniform(0.04, 0.06) * (1.2 if lo else 1), ct,
             dsides, dn)
    # gills: cone from the stalk top out to the rim + broad radial gill blades hanging from it
    gt = fl(gill, "gT"); r0 = prof(1.0) * 1.0; NR = nr; m = max(gills * 2, 16)
    def cone(f):                                             # f 0..1 from stalk to rim -> (radius frac, z)
        return (r0 / cr) + f * (0.91 - r0 / cr), hu + 0.15 - f * (hu - rim - 0.03 * D)
    gr = []
    for i in range(NR):
        f = i / (NR - 1); rf, z = cone(f); ring = []
        for k in range(m):
            a = TAU * k / m; s = 1 + (sc(a) - 1) * f
            v = gill.verts.new(c0 + Vector((math.cos(a) * rf * cr * s, math.sin(a) * rf * cr * s, z - (sc(a) - 1) * th * 1.4 * f)))
            v[gt] = f; ring.append(v)
        gr.append(ring)
    for i in range(NR - 1):
        for k in range(m):
            gill.faces.new((gr[i][k], gr[i][(k + 1) % m], gr[i + 1][(k + 1) % m], gr[i + 1][k]))
    gb = fl(gill, "blade")
    for b in range(gills):                                    # broad wedge gills: a rounded keel hanging below the cone
        a = TAU * (b + 0.15 * rng.uniform(-1, 1)) / gills; w = TAU / gills * 0.34
        sts = []
        for i in range(bst):
            f = 0.03 + 0.94 * i / (bst - 1); rf, z = cone(f); s = 1 + (sc(a) - 1) * f
            d = gdepth * (math.sin(math.pi * min(1, f * 1.1)) ** 0.5) * (0.8 + 0.2 * rng.random()) + 0.05
            zz = z - (sc(a) - 1) * th * 1.4 * f
            P = lambda da, dz: c0 + Vector((math.cos(a + da) * rf * cr * s, math.sin(a + da) * rf * cr * s, zz + dz))
            ring = [gill.verts.new(P(-w, 0.06)), gill.verts.new(P(-w * 0.55, -d * 0.75)), gill.verts.new(P(0, -d)),
                    gill.verts.new(P(w * 0.55, -d * 0.75)), gill.verts.new(P(w, 0.06))]
            for v in ring: v[gt] = f; v[gb] = 1.0
            ring[0][gb] = ring[4][gb] = 0.0
            sts.append(ring)
        for i in range(bst - 1):
            for k in range(4):
                gill.faces.new((sts[i][k], sts[i + 1][k], sts[i + 1][k + 1], sts[i][k + 1]))

def mushroom_piece(name, specs, size=1024):
    bms = (bmesh.new(), bmesh.new(), bmesh.new())
    for sp in specs: mushroom(bms, **sp)
    finish(name + "Stalk", bms[0], "stalk", size); finish(name + "Cap", bms[1], "goo", size)
    finish(name + "Gills", bms[2], "gill", size)

# GIANT landmark (D2b row 1): 36 tall, cap 40 wide, 7 buttress roots, 14 broad gills, 18 drips
mushroom_piece("gmGiant", [dict(base=Vector((0, 0, 0)), h=36.0, sr=4.2, cr=19.5, th=11.0, lean=(1.2, 0.4), roots=7,
                                gills=14, gdepth=2.4, drips=16, dlen=(2.0, 7.0), lobes=0.07, seed=1, sides=72, nr=7, bst=8, dsides=9)])
# TRUMPET cluster (D2b row 2 left): 3 stalks 15 / 10.5 / 8 tall, small domed caps
SM = dict(lo=True, dsides=5, dn=6, bst=4, nr=2, ssides=8, strands=4)
mushroom_piece("gmTrumpet", [
    dict(base=Vector((0.6, 0.4, 0)), h=15.0, sr=0.8, cr=3.6, th=3.0, lean=(0.6, 0.2), gills=8, gdepth=0.5, drips=3, dlen=(0.8, 2.0), seed=2, sides=14, ring_step=1.6, **SM),
    dict(base=Vector((-3.0, 0.8, 0)), h=10.5, sr=0.65, cr=2.9, th=2.4, lean=(-1.6, 0.3), gills=8, gdepth=0.45, drips=2, dlen=(0.7, 1.7), seed=3, sides=12, ring_step=1.6, **SM),
    dict(base=Vector((3.3, -0.6, 0)), h=8.0, sr=0.6, cr=2.6, th=2.2, lean=(1.5, -0.4), gills=8, gdepth=0.4, drips=2, dlen=(0.6, 1.5), seed=4, sides=12, ring_step=1.6, **SM)])
# UMBRELLA (D2b row 2 right): 9 tall, 14 wide flat dome on a short thick flaring stalk
mushroom_piece("gmUmbrella", [dict(base=Vector((0, 0, 0)), h=9.0, sr=1.5, cr=7.0, th=3.4, lean=(0.3, 0.0), roots=3,
                                   gills=12, gdepth=0.9, drips=6, dlen=(1.0, 2.6), lobes=0.05, seed=5, sides=26,
                                   ring_step=1.2, **dict(SM, ssides=10, nr=3))])
# SPROUT (scatter, the small mushrooms of D): 5 tall
mushroom_piece("gmSprout", [dict(base=Vector((0, 0, 0)), h=5.0, sr=0.42, cr=1.8, th=1.3, lean=(0.4, 0.1), gills=6,
                                 gdepth=0.3, drips=2, dlen=(0.4, 1.0), seed=6, sides=10, ring_step=1.2,
                                 **dict(SM, ssides=6))], 512)

# ---------------------------------------------------------------- metaball goo (blobs, nest shell, vein seep)
def meta_mesh(name, elems, res, kind, size, target_tris, cut=-0.15, fit=None, cutter=None):
    """elements [(type, (x,y,z), radius, (sx,sy,sz), negative, rot quaternion or None)] -> a merged soft goo mesh,
    cut flat just under the ground, decimated to target_tris; fit = (dx, dy, dz) rescales to exact bounds"""
    mb = bpy.data.metaballs.new(name + "MB"); mb.resolution = res; mb.render_resolution = res; mb.threshold = 0.6
    ob = link(bpy.data.objects.new(name + "MB", mb))
    for (t, co, r, s, neg, rot) in elems:
        e = mb.elements.new(); e.type = t; e.co = co; e.radius = r * 1.75; e.use_negative = neg   # (r = the real surface radius: Blender puts it at 0.57 x)
        if t in ("ELLIPSOID", "CAPSULE", "CUBE"): e.size_x, e.size_y, e.size_z = s
        if rot: e.rotation = rot
    bpy.ops.object.select_all(action="DESELECT"); bpy.context.view_layer.objects.active = ob; ob.select_set(True)
    bpy.ops.object.convert(target="MESH"); me_ob = bpy.context.view_layer.objects.active
    if cutter:   # (geo r6) a clean tunnel: boolean-subtract a cylinder along Y: cutter = (x, z, radius, y0, y1)
        cb = bmesh.new(); cx, cz, cr_, y0, y1 = cutter
        bmesh.ops.create_cone(cb, cap_ends=True, segments=28, radius1=cr_, radius2=cr_, depth=y1 - y0,
                              matrix=Matrix.Translation((cx, (y0 + y1) / 2, cz)) @ Matrix.Rotation(math.pi / 2, 4, "X"))
        cm = bpy.data.meshes.new(name + "Cut"); cb.to_mesh(cm); cb.free()
        co_ = link(bpy.data.objects.new(name + "Cut", cm))
        bo = me_ob.modifiers.new("cut", "BOOLEAN"); bo.operation = "DIFFERENCE"; bo.solver = "EXACT"; bo.object = co_
        bpy.context.view_layer.objects.active = me_ob; bpy.ops.object.modifier_apply(modifier="cut")
        bpy.data.objects.remove(co_, do_unlink=True)
    bm = bmesh.new(); bm.from_mesh(me_ob.data)
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, 0, cut), plane_no=(0, 0, 1), clear_inner=True)
    if fit:
        xs = [v.co.x for v in bm.verts]; ys = [v.co.y for v in bm.verts]; zs = [v.co.z for v in bm.verts]
        k = Vector((fit[0] / (max(xs) - min(xs)), fit[1] / (max(ys) - min(ys)), fit[2] / (max(zs) - cut)))
        print("FIT", name, "raw", round(min(xs), 1), round(max(xs), 1), round(min(ys), 1), round(max(ys), 1), round(max(zs), 1), "k", [round(c, 2) for c in k])
        for v in bm.verts: v.co = Vector((v.co.x * k.x, v.co.y * k.y, cut + (v.co.z - cut) * k.z))
    bm.to_mesh(me_ob.data); bm.free(); me_ob.data.update()
    nt = sum(len(p.vertices) - 2 for p in me_ob.data.polygons)
    if nt > target_tris:
        d = me_ob.modifiers.new("dec", "DECIMATE"); d.ratio = target_tris / nt
        bpy.ops.object.modifier_apply(modifier="dec")
    me_ob.name = name; me_ob.data.name = name
    for p in me_ob.data.polygons: p.use_smooth = True
    KIT[name] = (me_ob, kind, size); return me_ob

B, E, C = "BALL", "ELLIPSOID", "CAPSULE"
def film(x, y, rx, ry):                                       # a thin spreading goo film on the ground (D3 #5)
    return (E, (x, y, -0.35), 1.0, (rx, ry, 0.55), False, None)
# BLOB A (D2b row 3: 8 x 4.5 slumped jelly mound, a knob on top, smaller lumps sagging round it, a film round the foot)
rngb = random.Random(31)
elA = [(E, (0, 0, 1.4), 1.0, (2.6, 2.2, 2.0), False, None), (E, (1.9, 0.5, 0.9), 1.0, (1.7, 1.5, 1.3), False, None),
       (E, (-2.1, -0.3, 0.8), 1.0, (1.6, 1.4, 1.2), False, None), (E, (0.4, -1.7, 0.7), 1.0, (1.4, 1.2, 1.0), False, None),
       (E, (-0.6, 1.6, 0.8), 1.0, (1.5, 1.2, 1.1), False, None), (B, (0.3, 0.1, 3.4), 1.25, (1, 1, 1), False, None),
       (B, (0.35, 0.1, 4.2), 0.75, (1, 1, 1), False, None), film(0, 0, 4.2, 3.6), film(2.6, -1.2, 2.0, 1.6)]
meta_mesh("gmBlobA", elA, 0.16, "goo", 512, 1000, fit=(8.6, 7.4, 4.5))
elB = [(E, (0, 0, 0.9), 1.0, (2.2, 1.7, 1.3), False, None), (E, (1.7, 0.6, 0.6), 1.0, (1.3, 1.1, 0.9), False, None),
       (E, (-1.6, -0.5, 0.5), 1.0, (1.2, 1.0, 0.8), False, None), (B, (-0.3, 0.2, 1.9), 0.8, (1, 1, 1), False, None),
       film(0, 0, 3.4, 2.8)]
meta_mesh("gmBlobB", elB, 0.14, "goo", 512, 700, fit=(6.6, 5.2, 2.6))

# NEST (D2b row 4): soft jelly dome 32 x 24 x 15, an arched tunnel at the front (-Y), knobbly horns, base blobs, film
el = [(E, (0, 1.0, 3.5), 1.0, (13.5, 10.5, 9.5), False, None), (E, (0, -6.5, 2.5), 1.0, (9.0, 5.0, 6.5), False, None)]
rngn = random.Random(41)
for i in range(9):                                            # horns: upright capsules with a bulb on top
    a = TAU * i / 9 + rngn.uniform(-0.2, 0.2); rr = rngn.uniform(5.5, 9.0)
    x, y = math.cos(a) * rr * 1.1, math.sin(a) * rr * 0.9 + 1.0
    zt = 9.5 + 3.5 * (1 - (rr / 10) ** 2) + rngn.uniform(-1.0, 1.5)
    slump = i % 3 == 1                                         # (Blender audit r1 fix 3: asymmetric, some slumped into the base)
    if slump: zt -= 3.5
    tilt = Quaternion((0, 1, 0), math.pi / 2 + rngn.uniform(-0.45, 0.45)) @ Quaternion((1, 0, 0), rngn.uniform(-0.3, 0.3))
    el.append((C, (x, y, zt), rngn.uniform(0.8, 1.2), (rngn.uniform(0.6, 1.6), 1, 1), False, tilt))
    el.append((B, (x + rngn.uniform(-0.6, 0.6), y, zt + rngn.uniform(0.8, 1.8)), rngn.uniform(0.9, 1.5), (1, 1, 1), False, None))
for i in range(16):                                           # blobs round the foot
    a = TAU * i / 16 + rngn.uniform(-0.15, 0.15)
    if math.sin(a) < -0.85: continue                          # keep the tunnel mouth (-Y) clear
    x, y = math.cos(a) * 15.0, math.sin(a) * 11.5 + 1.0
    el.append((E, (x, y, 0.9), 1.0, (rngn.uniform(1.6, 2.6),) * 2 + (rngn.uniform(1.4, 2.0),), False, None))
el.append(film(0, 0, 17.5, 14.0))
for k in range(14):                                           # a thick, irregular goo lip round the tunnel mouth
    a = TAU * k / 14
    if math.sin(a) < -0.5: continue                            # (not under the floor)
    el.append((B, (math.cos(a) * 6.0, -12.0 + rngn.uniform(-0.5, 0.5), 5.0 + math.sin(a) * 6.0), rngn.uniform(1.3, 1.8), (1, 1, 1), False, None))
# (geo r6: the tunnel is a boolean cut below; negative metaballs either sealed it (r4) or ate the dome (r5))
meta_mesh("gmNestShell", el, 0.35, "goo", 1024, 3400, cutter=(0.0, 5.0, 4.8, -22.0, -1.0))   # (geo r5: no fit, so the mouth lip + lining stay aligned; ~36 x 30 x 14.6)
# tunnel lining: rings of lilac ridges narrowing into the nest, normals facing in, a glowing core at the end
bm = bmesh.new(); tt = fl(bm, "tunT")
pts = [Vector((0, -11.5 + 10.0 * i / 11, 5.0 - 0.12 * i)) for i in range(12)]
rad = [4.65 * (1 - 0.62 * i / 11) * (1 + 0.07 * math.cos(i * math.pi)) for i in range(12)]
tube(bm, pts, rad, 20, cap=True, tag=tt, tagv=[i / 11 for i in range(12)])
bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
me = bpy.data.meshes.new("gmNestTunnel"); bm.to_mesh(me); bm.free()
for p in me.polygons: p.use_smooth = True
KIT["gmNestTunnel"] = (link(bpy.data.objects.new("gmNestTunnel", me)), "tunnel", 512)

# ---------------------------------------------------------------- pools + streams (D2b pool top view, D3 #4)
def lip_profile():
    """(across 0..1 of the pool radius / stream half-width, height) for a flat goo sheet with a thick rounded rim"""
    return [(0.0, 0.30), (0.25, 0.31), (0.5, 0.33), (0.7, 0.36), (0.82, 0.42), (0.89, 0.62), (0.93, 0.8),
            (0.965, 0.78), (0.99, 0.55), (1.01, 0.18), (1.04, -0.4), (1.04, -2.5)]

def pool(name, seed, R=23.0, aspect=1.0, hs=1.0, N=96, wob2=0.0, kind="pool", size=1024, prof=None):
    """a kidney goo pool (or, flatter + wobblier, a thin goo FILM patch: spec audit r1 fix 2); aspect stretches it in x,
    hs scales the heights, wob2 adds a fine wavy outline"""
    rng = random.Random(seed); ph = [rng.uniform(0, TAU) for _ in range(5)]
    def Ra(a): return R * (1 + 0.13 * math.cos(2 * a + ph[0]) + 0.09 * math.cos(3 * a + ph[1]) + 0.05 * math.cos(5 * a + ph[2])
                           + wob2 * math.cos(9 * a + ph[3]) + 0.6 * wob2 * math.cos(13 * a + ph[4]))
    bm = bmesh.new(); rt = fl(bm, "rimT"); prof = [(f, z * hs if z > -1 else z) for (f, z) in (prof or lip_profile())]
    centre = bm.verts.new((0, 0, prof[0][1])); centre[rt] = 0
    rings = []
    for (f, z) in prof[1:]:
        ring = []
        for k in range(N):
            a = TAU * k / N; r = Ra(a) * f
            wob = 0.04 * noise.noise(Vector((math.cos(a) * 2, math.sin(a) * 2, seed))) if f < 0.85 else 0
            v = bm.verts.new((math.cos(a) * r * aspect, math.sin(a) * r, z + wob)); v[rt] = min(1, max(0, (f - 0.8) / 0.2)); ring.append(v)
        rings.append(ring)
    for k in range(N): bm.faces.new((centre, rings[0][k], rings[0][(k + 1) % N]))
    for i in range(len(rings) - 1):
        for k in range(N): bm.faces.new((rings[i][k], rings[i + 1][k], rings[i + 1][(k + 1) % N], rings[i][(k + 1) % N]))
    finish(name, bm, kind, size)

pool("gmPoolA", 51); pool("gmPoolB", 52, R=22.0)
# thin goo FILM patches (30 x 16 and 24 x 14): a low sheet with a soft lip, wavy edge; placed in groups between pools
FILM = [(0.0, 0.16), (0.45, 0.17), (0.75, 0.2), (0.88, 0.3), (0.95, 0.34), (1.0, 0.18), (1.05, -0.3), (1.05, -1.5)]
pool("gmFilmA", 81, R=8.0, aspect=1.9, N=56, wob2=0.05, kind="pool", size=512, prof=FILM)
pool("gmFilmB", 82, R=7.0, aspect=1.7, N=48, wob2=0.06, kind="pool", size=512, prof=FILM)

def stream(name, ctrl, w0, seed):
    """a goo ribbon (D: rivers linking the pools): lipped cross-section, rounded ends, width wobbling along it"""
    rng = random.Random(seed); n = 22
    pts = bez(Vector(ctrl[0]), Vector(ctrl[1]), Vector(ctrl[2]), n)
    prof = lip_profile(); bm = bmesh.new(); rt = fl(bm, "rimT"); rows = []
    for i, p in enumerate(pts):
        d = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized(); side = Vector((-d.y, d.x, 0))
        t = i / (n - 1); w = w0 * (1 + 0.18 * math.sin(t * 9 + seed)) * math.sqrt(max(0.0, math.sin(math.pi * t))) + 0.05
        row = []
        for sgn in (-1, 1):
            for (f, z) in (prof[::-1] if sgn < 0 else prof):
                if sgn < 0 and f == 0: continue
                v = bm.verts.new(p + side * (sgn * f * w) + Vector((0, 0, z if w > 0.6 else min(z, 0.3))))
                v[rt] = min(1, max(0, (f - 0.8) / 0.2)); row.append(v)
        rows.append(row)
    m = len(rows[0])
    for i in range(n - 1):
        for k in range(m - 1): bm.faces.new((rows[i][k], rows[i][k + 1], rows[i + 1][k + 1], rows[i + 1][k]))
    finish(name, bm, "pool", 512)

stream("gmStreamA", [(-12, 0, 0), (0, 7, 0), (12, -1, 0)], 3.2, 61)
stream("gmStreamB", [(-12, -3, 0), (2, -6, 0), (12, 4, 0)], 2.6, 62)

# cliff DRAPE (audit r1 D: goo dripping down the cliff walls in D): goo runs sliding down a 55 deg slope (local +Y =
# into the wall, so the piece faces -Y like the rest), 12 wide, 16 tall, pooling in a film at the foot
el = []; rngd = random.Random(91)
for i in range(5):
    x = -5 + 2.5 * i + rngd.uniform(-0.6, 0.6); top = rngd.uniform(10, 16)
    for j in range(13):                                       # (geo r4: 13 overlapping balls per run, a continuous ribbon)
        z = top * (1 - j / 12); y = z * 0.7 + 0.6
        el.append(("BALL", (x + 0.3 * math.sin(j * 0.5 + i), y, z), 1.0 + 0.6 * (j / 12) + rngd.uniform(-0.1, 0.1), (1, 1, 1), False, None))
el += [("ELLIPSOID", (0, 0.4, 0.2), 1.0, (7.0, 2.6, 0.9), False, None)]
meta_mesh("gmDrape", el, 0.25, "goo", 512, 1300)

# ---------------------------------------------------------------- rocks + DNA crystal vein (D2b row 3, D3 #6)
def boulder(name, lumps, voxel, disp, target, size, kind="rock"):
    """fused boulder (LESSONS 23): lumpy icospheres -> voxel remesh -> noise displace = the HIGH mesh ("<name>_hi",
    kept for the normal bake); a decimated copy = the game mesh"""
    bm = bmesh.new()
    for (c, r, sq, seed) in lumps:
        vs = bmesh.ops.create_icosphere(bm, subdivisions=3, radius=1.0, matrix=Matrix.Identity(4))["verts"]
        for v in vs:
            d = v.co.copy(); k = 1 + 0.18 * noise.noise(d * 1.4 + Vector((seed, 2 * seed, -seed)))
            v.co = Vector(c) + Vector((d.x * sq[0], d.y * sq[1], d.z * sq[2])) * r * k
    me = bpy.data.meshes.new(name + "_hi"); bm.to_mesh(me); bm.free()
    hi = link(bpy.data.objects.new(name + "_hi", me))
    bpy.ops.object.select_all(action="DESELECT"); bpy.context.view_layer.objects.active = hi; hi.select_set(True)
    rm = hi.modifiers.new("rm", "REMESH"); rm.mode = "VOXEL"; rm.voxel_size = voxel; bpy.ops.object.modifier_apply(modifier="rm")
    tex = bpy.data.textures.new(name + "_n", "CLOUDS"); tex.noise_scale = 0.9; tex.noise_depth = 3
    ds = hi.modifiers.new("ds", "DISPLACE"); ds.texture = tex; ds.strength = disp; ds.mid_level = 0.5
    bpy.ops.object.modifier_apply(modifier="ds")
    bm = bmesh.new(); bm.from_mesh(hi.data)
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, 0, -0.6), plane_no=(0, 0, 1), clear_inner=True)
    bm.to_mesh(hi.data); bm.free()
    lo = hi.copy(); lo.data = hi.data.copy(); lo.name = name; lo.data.name = name; link(lo)
    bpy.context.view_layer.objects.active = lo; lo.select_set(True)
    d = lo.modifiers.new("dec", "DECIMATE"); d.ratio = target / max(1, sum(len(p.vertices) - 2 for p in lo.data.polygons))
    bpy.ops.object.modifier_apply(modifier="dec")
    for p in lo.data.polygons: p.use_smooth = True
    for p in hi.data.polygons: p.use_smooth = True
    hi.hide_render = True
    KIT[name] = (lo, kind, size); return lo

boulder("gmRockA", [((0, 0, 0.6), 1.6, (1.0, 0.85, 0.7), 1), ((1.1, 0.4, 0.4), 1.0, (1, 0.9, 0.8), 2)], 0.12, 0.25, 450, 512)
boulder("gmRockB", [((0, 0, 1.0), 2.4, (1.0, 0.8, 0.75), 3), ((-1.8, 0.6, 0.6), 1.5, (1, 0.9, 0.8), 4),
                    ((1.6, -0.8, 0.5), 1.3, (1, 1, 0.8), 5)], 0.16, 0.35, 550, 512)
boulder("gmRockC", [((0, 0, 1.4), 3.0, (1.0, 0.75, 0.62), 6), ((2.6, 0.5, 0.8), 1.9, (1, 0.9, 0.8), 7),
                    ((-2.4, -0.7, 0.7), 1.8, (1, 0.9, 0.75), 8), ((0.5, 1.9, 0.5), 1.5, (1, 1, 0.7), 9)], 0.2, 0.45, 650, 512)
# vein: a jagged rock mound (8 wide, ~4.5 tall), crystal shards out of its top-front, goo seeping round the foot
boulder("gmVeinRock", [((0, 0.6, 1.4), 2.8, (1.2, 0.85, 0.85), 11), ((-2.2, 0.0, 1.0), 1.8, (1, 0.9, 1.0), 12),
                       ((2.1, 0.9, 0.9), 1.7, (1, 0.9, 1.1), 13), ((0.6, -1.4, 0.5), 1.4, (1, 0.8, 0.7), 14)], 0.14, 0.4, 900, 512)
bm = bmesh.new(); rngc = random.Random(71)
for i, (bx, by, bz, h, r, tx, ty) in enumerate([(0.4, -0.4, 3.0, 6.6, 0.85, 8, -14), (-0.9, -0.6, 2.6, 4.2, 0.6, -22, -8),
                                                 (1.6, -0.2, 2.4, 3.6, 0.55, 26, -6), (-0.1, -1.4, 1.2, 2.6, 0.45, -6, -30),
                                                 (1.0, -1.2, 1.3, 2.2, 0.4, 20, -28), (-1.8, -1.1, 1.1, 1.8, 0.35, -34, -20)]):
    R_ = Matrix.Rotation(math.radians(tx), 4, "Y") @ Matrix.Rotation(math.radians(ty), 4, "X")
    base = Vector((bx, by, bz)); ring_b, ring_t = [], []
    for k in range(6):                                        # hexagonal prism + pyramid tip, flat-shaded facets
        a = TAU * k / 6 + rngc.uniform(-0.1, 0.1); rk = r * rngc.uniform(0.85, 1.1)
        ring_b.append(bm.verts.new(base + R_ @ Vector((math.cos(a) * rk, math.sin(a) * rk, -0.8))))
        ring_t.append(bm.verts.new(base + R_ @ Vector((math.cos(a) * rk * 0.92, math.sin(a) * rk * 0.92, h * 0.72))))
    tip = bm.verts.new(base + R_ @ Vector((rngc.uniform(-0.1, 0.1) * r, 0, h)))
    for k in range(6):
        k2 = (k + 1) % 6
        bm.faces.new((ring_b[k], ring_b[k2], ring_t[k2], ring_t[k])); bm.faces.new((ring_t[k], ring_t[k2], tip))
finish("gmVeinCrystal", bm, "crystal", 512, smooth=False)
elV = [film(0, -0.6, 4.6, 3.4), (E, (-0.5, -2.0, 0.5), 1.0, (1.6, 1.0, 0.9), False, None),
       (E, (1.4, -1.9, 0.4), 1.0, (1.2, 0.9, 0.7), False, None), (B, (0.4, -1.6, 1.4), 0.9, (1, 1, 1), False, None),
       (E, (-2.6, -0.4, 0.4), 1.0, (1.1, 1.3, 0.8), False, None)]
meta_mesh("gmVeinGoo", elV, 0.14, "goo", 512, 700)

# ---------------------------------------------------------------- report + save
coll = bpy.data.collections.new("GooMarshKit"); bpy.context.scene.collection.children.link(coll)
for name, (ob, kind, size) in KIT.items():
    for c in list(ob.users_collection): c.objects.unlink(ob)
    coll.objects.link(ob)
    me = ob.data; me.calc_loop_triangles()
    xs = [v.co.x for v in me.vertices]; ys = [v.co.y for v in me.vertices]; zs = [v.co.z for v in me.vertices]
    print("PIECE %-15s %-7s %4d  size %.1f x %.1f x %.1f  z %.1f..%.1f  tris %d" % (name, kind, size, max(xs) - min(xs),
          max(ys) - min(ys), max(zs) - min(zs), min(zs), max(zs), len(me.loop_triangles)))
print("TOTAL TRIS", sum(len(o.data.loop_triangles) for o, _, _ in KIT.values()))
bd = os.path.join(ASSETS, "blender", "hub"); os.makedirs(bd, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(bd, "goomarsh_geo.blend"))
print("SAVED geo")
