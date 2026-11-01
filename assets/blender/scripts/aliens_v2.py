# Alien Fusion: forms v2 (James, 27 Oct: "not distinct enough"; ChatGPT concept sheets design/concepts/*-forms-v2-chatgpt.jpg)
#   blender --background --factory-startup --python aliens_v2.py -- <assets_dir> [only e.g. squish3]
# Each form is its own body plan and gait, still its race:
#   SQUISH  F1 DRIP (hops, from aliens_forms.py)  F2 TWIN (upright peanut on a puddle, tendril arms, slinky)
#           F3 BRUTE (goo gorilla, knuckle-walks)  F4 TITAN (slime kaiju dome on a skirt, 4 tentacles, slides)
#   CRUNCH  F1 PEBBLE (beetle, from aliens_forms.py)  F2 PINCER (low crab, crystal claws, sidesteps)
#           F3 RAM (horned bull, shoulder hump, charges)  F4 COLOSSUS (biped golem, crystal fists, magma core)
# Helpers, materials, bake, rig and save come from aliens_forms.py (its code up to its build loop is run here).
# Rigs differ per form now (each form gets its own animations); every rig keeps a Root bone at the feet.
import os, sys, math, random
_here = os.path.dirname(os.path.abspath(__file__))
_src = open(os.path.join(_here, "aliens_forms.py"), encoding="utf-8").read()
_src = _src[:_src.index("for race, fn in ((\"squish\", squish)")]
exec(compile(_src, "aliens_forms.py", "exec"))          # defines reset, ellipsoid, goo_material, bake, rig, save, crystal ...

V = Vector


def chain(points, radii, segs=16):
    """a soft limb / tentacle: overlapping ellipsoids along points (the remesh melts them into one shape)"""
    out = []
    for i in range(len(points) - 1):
        a, b = V(points[i]), V(points[i + 1])
        for k in range(3):
            t = k / 3
            r = radii[i] + (radii[i + 1] - radii[i]) * t
            out.append(ellipsoid(tuple(a.lerp(b, t)), (r, r, r), segs))
    r = radii[-1]; out.append(ellipsoid(tuple(points[-1]), (r, r, r), segs))
    return out


def mirror(pts):
    return [(-x, y, z) for (x, y, z) in pts]


def _rot_to(d):
    return V((0, 0, 1)).rotation_difference(V(d).normalized()).to_euler()


def cone_between(a, b, r1, r2, verts=8):
    """a tapered angular limb from a (radius r1) to b (radius r2)"""
    a, b = V(a), V(b)
    return cone(tuple((a + b) / 2), r1, r2, (b - a).length, _rot_to(b - a), verts)


def crystal_dir(a, d, r, h):
    """a crystal prism standing at a, pointing along d"""
    return crystal(tuple(a), r, h, _rot_to(d))


def main_verts(lo):
    """the body's vertices (material 0 straight after make_low; bake later puts every face on one material)"""
    return {v for p in lo.data.polygons if p.material_index == 0 for v in p.vertices}


def follow_surface(lo, main, smooth):
    """(James's video, 27 Oct: the Titan's teeth drifted off its lip and its side split while it moved) heat weighting
    failed on most of the Titan, so its skin was 100 % one bone or another with hard borders. Blend the borders
    (vertex-group smoothing), then every loose part (eye, teeth, mouth, spots, crystals) copies the weights of the
    nearest body vertex, so it rides exactly with the skin under it"""
    from mathutils.kdtree import KDTree
    sel(lo)
    if smooth:
        bpy.ops.object.mode_set(mode="WEIGHT_PAINT")    # (the smooth operator only runs in weight paint)
        bpy.ops.object.vertex_group_smooth(group_select_mode="ALL", factor=0.5, repeat=smooth)
        bpy.ops.object.mode_set(mode="OBJECT")
        bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
        bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
    vs = lo.data.vertices
    idx = list(main)
    kd = KDTree(len(idx))
    for i, vi in enumerate(idx):
        kd.insert(vs[vi].co, i)
    kd.balance()
    copied = 0
    for v in vs:
        if v.index in main:
            continue
        _, i, _ = kd.find(v.co)
        src = vs[idx[i]]
        for g in list(v.groups):
            lo.vertex_groups[g.group].remove([v.index])
        for g in src.groups:
            lo.vertex_groups[g.group].add([v.index], g.weight, "REPLACE")
        copied += 1
    print("FOLLOW", lo.name, "copied", copied, "smoothed", smooth)


def lock_eye(lo, centre, r, bone, skip=(), core=1.2, fade=2.0):
    """(James, 28 Oct: the SQUISH eyes wobble like jelly and clip out of the head as the body squashes) the eye and
    the skin round it move as ONE solid piece on one bone: every vertex within 1.2 x the eye's radius of its centre
    is 100 % `bone`, fading back to its own skinning by 2 x the radius, so the goo can still squash elsewhere but
    never slides over or away from the eye. Run after follow_surface / rigid_parts; `skip` = the lid's vertices"""
    c = Vector(centre)
    b = lo.vertex_groups[bone].index
    r0, r1 = core * r, fade * r                       # (core = solid, fade = back to its own weights; in eye radii)
    n = 0
    for v in lo.data.vertices:
        if v.index in skip:
            continue
        d = (v.co - c).length
        if d >= r1:
            continue
        w = 1.0 if d <= r0 else 1.0 - (d - r0) / (r1 - r0)
        w = w * w * (3 - 2 * w)                          # (smoothstep: no crease at the band's edges)
        old = {g.group: g.weight for g in v.groups}
        for gi, gw in old.items():
            lo.vertex_groups[gi].add([v.index], gw * (1 - w), "REPLACE")
        lo.vertex_groups[b].add([v.index], old.get(b, 0) * (1 - w) + w, "REPLACE")
        n += 1
    sel(lo)                                              # (adding the bone can make a 5th influence: Roblox allows 4)
    bpy.ops.object.vertex_group_clean(group_select_mode="ALL", limit=0.001)
    bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
    bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
    print("EYELOCK", lo.name, bone, n)


def goo_eye(c, r, slit, iris_col):
    c = V(c)
    sclera = ellipsoid(tuple(c), (r, r * 0.78, r), 24)
    front = c + V((0, -r * 0.7, 0))
    iris = ellipsoid(tuple(front + V((0, -0.02 * r, 0))), (r * 0.6, r * 0.14, r * 0.6), 18)
    pr = (r * 0.11, r * 0.09, r * 0.4) if slit else (r * 0.3, r * 0.09, r * 0.3)
    pupil = ellipsoid(tuple(front + V((0, -0.1 * r, 0))), pr, 14)
    catch = ellipsoid(tuple(front + V((-0.24 * r, -0.17 * r, 0.24 * r))), (r * 0.09, r * 0.04, r * 0.09), 8)
    return sclera, iris, pupil, catch


def goo_build(form, H, budget, tex, goo, eye, slit, iris_col, mouth, fangs, spots, bones):
    g = join(goo); g.name = "goo"
    remesh(g, H / 120.0, 4)
    displace(g, "CLOUDS", 0.35 * H / 2.5, 0.008 * H)
    bpy.ops.object.shade_smooth()
    sclera, iris, pupil, catch = goo_eye(eye[0], eye[1], slit, iris_col)
    spot_objs = []
    if spots:
        hits = surface_points(g, [((c[0] * 3, c[1] * 3 + 0.01, c[2]), (0, 0, c[2])) for c, r in spots], 0.0)
        for (loc, nrm), (c, r) in zip(hits, spots):
            s = ellipsoid(tuple(loc - nrm * r * 0.45), (r, r, r * 0.55), 10)
            s.rotation_euler = nrm.to_track_quat("Z", "Y").to_euler()
            spot_objs.append(s)
    gm = goo_material(0.0, H, SQ_PALETTES[form])
    em = flat_material("sclera", (0.95, 0.97, 1.0, 1), 0.08)
    im = flat_material("iris", iris_col, 0.06)
    pm = flat_material("pupil", (0.01, 0.01, 0.02, 1), 0.04)
    cm_ = flat_material("catch", (1, 1, 1, 1), 0.05)
    parts = [(gm[0], gm[1], g), (em[0], em[1], sclera), (im[0], im[1], iris), (pm[0], pm[1], pupil), (cm_[0], cm_[1], catch)]
    mats = [gm, em, im, pm, cm_]
    if mouth:
        mm = flat_material("mouth", (0.12, 0.02, 0.2, 1), 0.3)
        parts.append((mm[0], mm[1], mouth)); mats.append(mm)
    if fangs:
        fm = flat_material("fang", (0.93, 0.95, 0.97, 1), 0.25)
        parts.append((fm[0], fm[1], join(fangs))); mats.append(fm)
    if spot_objs:
        sm = glow_material((0.75, 1.0, 0.92, 1), (0.35, 0.95, 1.0, 1))
        parts.append((sm[0], sm[1], join(spot_objs))); mats.append(sm)
    # the eyelid for the blink (James, 27 Oct), on its own Lid bone, parented to the bone the eye rides on
    lm = flat_material("lid", SQ_PALETTES[form]["mid"], 0.15)
    lid_slot = len(parts)
    parts.append((lm[0], lm[1], make_lid(eye[0], eye[1]))); mats.append(lm)
    ec, er = V(eye[0]), eye[1]
    bones = bones + [("Lid", tuple(ec), tuple(ec + V((0, -er, 0))), {2: "Upper", 3: "Chest", 4: "Top"}[form])]
    hi = build_high(parts); hi.name = f"Squish{form}_high"
    lo = make_low(hi, f"SquishF{form}", budget)
    main = main_verts(lo)
    lv = lid_verts(lo, lid_slot)
    bake(f"squish_f{form}", lo, hi, mats, tex)
    arm, unw = rig(f"SquishF{form}", lo, bones)
    strip_lid(lo, lv)                                   # (only the lid follows the Lid bone)
    follow_surface(lo, main, 8)                         # (goo: soft blended skin)
    rigid_parts(lo, main)                               # (eye, teeth, spots move solid: no ripple)
    assign_lid(lo, lv)
    save(f"squish_f{form}", f"SquishF{form}", lo, arm, hi, H, unw)


def squish_v2(form):
    reset()
    iris_col, slit, mouth, fangs, spots = (0.42, 0.14, 0.78, 1), False, None, [], []
    if form == 2:                                       # TWIN: two drips stacked on a puddle, eye at the waist
        H, budget, tex = 4.3, 3000, 1024
        goo = [ellipsoid((0, 0, 0.28), (1.35, 1.25, 0.32), 32),
               ellipsoid((0, 0, 1.25), (1.0, 0.95, 1.0), 32),
               teardrop((0, 0.05, 2.75), 0.85, 2.7, 0.35),
               brow((0.1, -0.86, 2.62), (0.62, 0.26, 0.2), 14, -16)]
        for sx in (-1, 1):                              # tendril arms, out and down
            goo += chain([(sx * 0.8, -0.1, 1.55), (sx * 1.25, -0.25, 1.4), (sx * 1.55, -0.4, 1.15), (sx * 1.62, -0.55, 0.92)], [0.24, 0.2, 0.16, 0.19])
        eye = ((0, -0.86, 1.95), 0.62)
        spots = [((-0.55, 0.25, 2.9), 0.2), ((0.55, 0.25, 2.9), 0.2)]   # the two drips it was made from
        bones = [("Root", (0, 0, 0), (0, 0, 0.3), None),
                 ("Lower", (0, 0, 0.35), (0, 0, 1.75), "Root"),
                 ("Upper", (0, 0, 1.75), (0, 0.12, 4.0), "Lower"),
                 ("ArmL", (-0.8, -0.1, 1.55), (-1.62, -0.55, 0.92), "Lower"),
                 ("ArmR", (0.8, -0.1, 1.55), (1.62, -0.55, 0.92), "Lower")]
    elif form == 3:                                     # BRUTE: a goo gorilla, big arms knuckle-walking
        H, budget, tex = 6.6, 4500, 1024
        slit = True
        # (the torso and head are the mass: the first build's arms out-weighed a small body and read as an arch)
        # (ChatGPT r2: a broad chest pushed forward between the arms carries the eye; gorilla arms = thick upper arm,
        # narrow elbow, huge rounded knuckles, angled out)
        goo = [ellipsoid((0, -0.15, 3.75), (2.6, 2.15, 2.25), 40, (math.radians(-16), 0, 0)),
               ellipsoid((0, -1.25, 5.35), (1.25, 1.0, 0.9), 32),
               brow((0.15, -2.45, 5.55), (1.2, 0.45, 0.34), 10, -22)]
        for sx in (-1, 1):
            goo += chain([(sx * 2.35, -0.4, 4.7), (sx * 3.05, -0.85, 3.4), (sx * 3.3, -1.3, 2.05), (sx * 3.35, -1.55, 1.05)], [1.2, 0.95, 0.68, 0.85])
            goo.append(ellipsoid((sx * 3.4, -1.7, 0.66), (1.55, 1.45, 0.75), 24))                # the knuckle fist
            goo += chain([(sx * 1.05, 0.9, 2.1), (sx * 1.1, 0.85, 1.0)], [0.75, 0.7])
            goo.append(ellipsoid((sx * 1.1, 0.65, 0.35), (0.8, 1.0, 0.38), 20))                  # the foot
        goo += [spine((0, 1.25, 4.95), 0.62, 2.2, 52), spine((-0.95, 1.35, 4.35), 0.5, 1.8, 60, -18), spine((0.95, 1.35, 4.35), 0.5, 1.8, 60, 18)]
        eye = ((0, -2.3, 4.6), 1.0)
        mouth = ellipsoid((0.15, -2.45, 3.35), (0.75, 0.32, 0.22), 16); mouth.rotation_euler = (0, math.radians(10), 0)
        fangs = [fang((0.65, -2.68, 3.37), 0.15, 0.45), fang((-0.25, -2.68, 3.3), 0.15, 0.45)]
        spots = [((sx * 2.0, -0.2, 4.4), 0.42) for sx in (-1, 1)] + [((sx * 1.2, 1.5, 3.4), 0.42) for sx in (-1, 1)]
        bones = [("Root", (0, 0, 0), (0, 0, 0.4), None),
                 ("Hips", (0, 0.7, 1.7), (0, 0.45, 3.0), "Root"),
                 ("Chest", (0, 0.45, 3.0), (0, -0.3, 4.6), "Hips"),
                 ("Head", (0, -0.7, 4.6), (0, -1.8, 5.9), "Chest"),
                 ("ArmL", (-2.35, -0.4, 4.7), (-3.3, -1.3, 2.05), "Chest"), ("HandL", (-3.3, -1.3, 2.05), (-3.4, -1.7, 0.1), "ArmL"),
                 ("ArmR", (2.35, -0.4, 4.7), (3.3, -1.3, 2.05), "Chest"), ("HandR", (3.3, -1.3, 2.05), (3.4, -1.7, 0.1), "ArmR"),
                 ("LegL", (-1.05, 0.9, 2.1), (-1.1, 0.7, 0.1), "Hips"), ("LegR", (1.05, 0.9, 2.1), (1.1, 0.7, 0.1), "Hips")]
    else:                                               # TITAN: kaiju dome on a skirt, maw, 4 tentacles, crown
        H, budget, tex = 13.0, 7500, 1024
        iris_col, slit = (0.55, 0.06, 0.95, 1), True
        goo = [ellipsoid((0, 0.3, 6.2), (4.9, 4.3, 4.7), 48),
               ellipsoid((0, 0, 1.15), (6.0, 5.4, 1.25), 48),
               brow((-1.35, -4.0, 9.45), (2.1, 1.0, 0.75), 22, -18), brow((1.35, -4.0, 9.45), (2.1, 1.0, 0.75), -22, -18)]
        tent = {}
        for name, sx, sy in (("FL", -1, -1), ("FR", 1, -1), ("BL", -1, 1), ("BR", 1, 1)):
            pts = [(sx * 3.4, sy * 2.6, 1.7), (sx * 5.0, sy * 3.6, 1.25), (sx * 6.5, sy * 4.1, 1.05), (sx * 7.6, sy * 3.9, 1.35), (sx * 7.95, sy * 3.25, 2.05)]
            goo += chain(pts, [1.35, 1.1, 0.9, 0.7, 0.55])
            tent[name] = pts
        for (x, y, ang, out, r1, ln) in ((-3.0, 0.6, 40, -38, 1.2, 3.2), (-1.7, -0.3, 30, -22, 1.4, 4.0), (-0.55, -0.6, 22, -8, 1.45, 4.4),
                                         (0.55, -0.6, 22, 8, 1.45, 4.4), (1.7, -0.3, 30, 22, 1.4, 4.0), (3.0, 0.6, 40, 38, 1.2, 3.2)):
            goo.append(spine((x, y, 10.3 - abs(x) * 0.35), r1, ln, ang, out))
        eye = ((0, -3.95, 8.3), 1.95)
        mouth = ellipsoid((0, -3.95, 4.9), (2.7, 1.0, 1.1), 20)
        # (tucked INTO the mouth, hanging from the upper lip: in front of it they read as stuck on. James's video)
        fangs = [fang((x, -4.7, 5.4), 0.38, 1.05) for x in (-1.6, -0.55, 0.55, 1.6)] + [fang((x, -4.65, 4.25), 0.32, 0.85, up=True) for x in (-1.05, 1.05)]
        rnd = random.Random(44)
        for cx, cy, cz in ((-4.2, -0.8, 5.0), (4.2, -0.8, 5.0), (-3.4, 1.8, 8.2), (3.4, 1.8, 8.2)):
            for k in range(4):
                spots.append(((cx + rnd.uniform(-0.6, 0.6), cy + rnd.uniform(-0.7, 0.7), cz + rnd.uniform(-0.8, 0.8)), rnd.uniform(0.4, 0.55)))
        bones = [("Root", (0, 0, 0), (0, 0, 0.6), None),
                 ("Body", (0, 0.3, 1.8), (0, 0.3, 6.5), "Root"),
                 ("Top", (0, 0.3, 6.5), (0, 0.3, 11.5), "Body")]
        for name, pts in tent.items():
            bones.append(("Tent" + name + "1", pts[0], pts[2], "Body"))
            bones.append(("Tent" + name + "2", pts[2], pts[4], "Tent" + name + "1"))
    goo_build(form, H, budget, tex, goo, eye, slit, iris_col, mouth, fangs, spots, bones)


# ----------------------------------------------------------------------------------------------- CRUNCH v2
def place_crystals(body, specs, rnd):
    """specs: ((x, y), r, h, (tilt_x_deg, tilt_y_deg), scale or None): cast down onto the body, stood on the surface"""
    hits = surface_points(body, [((x, y, 60), (x, y, -10)) for (x, y), r, h, tilt, s in specs], 0.0)
    out = []
    for (loc, nrm), ((x, y), r, h, tilt, s) in zip(hits, specs):
        co = crystal(tuple(loc - V((0, 0, r * 0.25))), r, h, (math.radians(tilt[0]), math.radians(tilt[1]), rnd.uniform(0, 1.0)))
        if s:
            co.scale = s
        out.append(co)
    return out


def rock_build(form, H, W, budget, tex, rock, facets, centre, crystals_fn, eyes, core, bones, ncore):
    rnd = random.Random(form * 31)
    # only the core masses (body / head) get the angular facet cuts: cut after joining, the planes chopped the limbs,
    # legs and horns clean off (v2 first build)
    body = join(rock[:ncore])
    if facets:
        slice_planes(body, facets, rnd, 0.86, 0.98, zmin=0.1, centre=centre)
    body = join([body] + rock[ncore:]); body.name = "rock"
    remesh(body, W / 120.0, 2)
    displace(body, "CLOUDS", 0.45 * W / 3.0, 0.03 * W, "VORONOI_F2")
    displace(body, "CLOUDS", 0.12 * W / 3.0, 0.007 * W)
    bpy.ops.object.shade_smooth()
    cry = join(crystals_fn(body, rnd))
    # (the Ram and the Colossus: eyes sunk 75 % into the head with a thin charcoal socket; the Pincer keeps its
    # eye-stalk beads. James, 27 Oct)
    sockets = None
    if form >= 3:
        sink_eyes(body, eyes, 0.75)
        sockets = join([eye_socket(e) for e in eyes])
    eye = join(eyes)
    rm = rock_material(W, 1.0 + 0.04 * form, {2: 0.026, 3: 0.03, 4: 0.04}[form], {2: (1.0, 0.58, 0.04, 1), 3: (1.0, 0.5, 0.03, 1), 4: (1.0, 0.38, 0.02, 1)}[form])
    cm = crystal_material(H * 0.1, H * 1.1, (0.6, 0.1, 0.0, 1), (1.0, 0.6, 0.12, 1)) if form >= 3 else crystal_material(0.0, H * 1.1)
    gm = glow_material((1.0, 0.92, 0.35, 1), (1.0, 0.6, 0.05, 1)) if form == 2 else glow_material((1.0, 0.55, 0.08, 1), (0.95, 0.12, 0.0, 1))
    parts = [(rm[0], rm[1], body), (cm[0], cm[1], cry), (gm[0], gm[1], eye)]
    mats = [rm, cm, gm]
    if sockets:
        sk = flat_material("socket", (0.035, 0.03, 0.03, 1), 0.7)
        parts.append((sk[0], sk[1], sockets)); mats.append(sk)
    if core:
        km = glow_material((1.0, 0.85, 0.3, 1), (1.0, 0.35, 0.0, 1))
        parts.append((km[0], km[1], core)); mats.append(km)
    hi = build_high(parts); hi.name = f"Crunch{form}_high"
    lo = make_low(hi, f"CrunchF{form}", budget)
    main = main_verts(lo)
    bake(f"crunch_f{form}", lo, hi, mats, tex)
    arm, unw = rig(f"CrunchF{form}", lo, bones)
    follow_surface(lo, main, 3)                         # (rock: only a light blend, it should stay stiff)
    rigid_parts(lo, main)                               # (eyes, crystals, claws move solid)
    save(f"crunch_f{form}", f"CrunchF{form}", lo, arm, hi, H, unw)


def eye_pair(c, r, sx_off, slant=0.0, narrow=False):
    out = []
    for sx in (-1, 1):
        e = ellipsoid((c[0] + sx * sx_off, c[1], c[2]), (r * 1.25, r * 0.6, r * 0.55) if narrow else (r, r, r), 16)
        if slant:
            e.rotation_euler = (0, math.radians(-slant * sx), 0)
        out.append(e)
    return out


def crunch_v2(form):
    reset()
    core = None
    if form == 2:                                       # PINCER: a low wide crab, two crystal claws, six legs
        H, W, budget, tex = 3.2, 4.5, 3500, 1024           # (W 4.5: a smaller voxel + displacement keeps the thin legs)
        rock = [ellipsoid((0, 0.25, 1.35), (2.0, 1.6, 0.8), 40), ellipsoid((0, -1.35, 1.25), (0.95, 0.65, 0.55), 24)]
        for sx in (-1, 1):
            for ly in (-0.55, 0.35, 1.2):               # three short angular legs a side: thick at the hip, tapering down
                rock += [cone_between((sx * 1.5, ly, 1.15), (sx * 2.45, ly + 0.1, 1.5), 0.42, 0.3),
                         cone_between((sx * 2.45, ly + 0.1, 1.5), (sx * 2.95, ly + 0.15, 0.05), 0.3, 0.1)]
            rock += chain([(sx * 1.15, -1.15, 1.1), (sx * 1.85, -2.2, 1.05)], [0.38, 0.42], 14)   # the claw arm
            rock.append(ellipsoid((sx * 2.0, -2.55, 1.0), (0.62, 0.72, 0.5), 20))               # the claw palm

        def crys(body, rnd):
            out = place_crystals(body, [((x, y), 0.3, h, (rnd.uniform(-10, 10), rnd.uniform(-10, 10)), None)
                                        for (x, y, h) in ((-0.7, 0.2, 1.0), (0.7, 0.2, 1.0), (0, 0.6, 1.3), (-0.4, 1.0, 0.8), (0.4, 1.0, 0.8), (0, -0.2, 0.9))], rnd)
            for sx in (-1, 1):                          # C-shaped pincers: a big curved finger over a small one, a gap between
                palm = V((sx * 2.0, -2.75, 1.05))
                big = [palm + V((sx * 0.1, -0.15, 0.3)), palm + V((sx * 0.25, -0.85, 0.7)), palm + V((sx * 0.25, -1.65, 0.55)), palm + V((sx * 0.1, -2.15, 0.05))]
                for i, r in ((0, 0.42), (1, 0.36), (2, 0.28)):
                    out.append(crystal_dir(big[i], big[i + 1] - big[i], r, (big[i + 1] - big[i]).length * 1.25))
                small = [palm + V((0, -0.2, -0.3)), palm + V((0, -0.95, -0.4)), palm + V((sx * 0.05, -1.45, -0.1))]
                for i, r in ((0, 0.3), (1, 0.22)):
                    out.append(crystal_dir(small[i], small[i + 1] - small[i], r, (small[i + 1] - small[i]).length * 1.25))
            return out
        eyes = eye_pair((0, -1.95, 1.5), 0.17, 0.32)
        bones = [("Root", (0, 0, 0), (0, 0, 0.3), None),
                 ("Body", (0, 1.0, 1.3), (0, -1.0, 1.3), "Root"),
                 ("ArmL", (-1.15, -1.15, 1.1), (-2.0, -2.6, 1.05), "Body"), ("ClawL", (-2.0, -2.6, 1.05), (-2.15, -4.6, 1.1), "ArmL"),
                 ("ArmR", (1.15, -1.15, 1.1), (2.0, -2.6, 1.05), "Body"), ("ClawR", (2.0, -2.6, 1.05), (2.15, -4.6, 1.1), "ArmR"),
                 ]
        # (James's video: one bone per side moved all three legs together = a strafe. Now one bone per leg, front 1 to
        # back 3, for an alternating insect step)
        for side, sx in (("L", -1), ("R", 1)):
            for k, ly in enumerate((-0.55, 0.35, 1.2), 1):
                bones.append((f"Leg{side}{k}", (sx * 1.5, ly, 1.15), (sx * 2.95, ly + 0.15, 0.05), "Body"))
        centre = (0, 0.25, 1.35); facets = 8
    elif form == 3:                                     # RAM: a horned bull, a towering shoulder hump, four thick legs
        H, W, budget, tex = 6.8, 8.0, 5500, 1024
        rock = [ellipsoid((0, 0.7, 3.0), (1.9, 2.7, 1.55), 40), ellipsoid((0, -0.8, 4.3), (2.15, 1.8, 1.55), 32, (math.radians(-12), 0, 0)),
                ellipsoid((0, -2.95, 2.7), (1.15, 1.05, 1.0), 28), ellipsoid((0, -3.8, 2.25), (0.78, 0.65, 0.62), 20)]
        for sx in (-1, 1):
            for ly, rr in ((-1.2, 0.62), (2.3, 0.55)):
                rock += chain([(sx * 1.3, ly, 2.6), (sx * 1.35, ly - 0.1, 1.2), (sx * 1.35, ly - 0.2, 0.35)], [rr * 1.25, rr, rr * 1.15], 14)
            # the curled horn (ChatGPT r2): rooted on the skull's outer side above the eye, thick at the root, sweeping
            # OUT to ~2x the head's width, then down and round, the tip curling up and in: reads from the front
            pts = [(sx * 0.95, -2.85, 3.45), (sx * 1.75, -2.6, 3.85), (sx * 2.6, -2.55, 3.7), (sx * 3.1, -2.85, 3.1),
                   (sx * 3.05, -3.3, 2.45), (sx * 2.65, -3.55, 2.3), (sx * 2.35, -3.5, 2.75)]
            rock += chain(pts, [0.6, 0.56, 0.5, 0.44, 0.37, 0.3, 0.24], 14)

        def crys(body, rnd):
            specs = [((0, y), 0.42, h, (-8, 0), None) for (y, h) in ((-1.6, 2.6), (-0.7, 3.2), (0.2, 2.6), (1.1, 1.9), (1.9, 1.3))]
            specs += [((sx * 1.0, y), 0.32, h, (0, sx * 22), None) for sx in (-1, 1) for (y, h) in ((-1.1, 1.7), (-0.2, 1.4))]
            return place_crystals(body, specs, rnd)
        eyes = eye_pair((0, -3.85, 2.95), 0.2, 0.42, slant=14, narrow=True)
        bones = [("Root", (0, 0, 0), (0, 0, 0.4), None),
                 ("Body", (0, 2.2, 3.0), (0, -0.6, 3.2), "Root"),
                 ("Head", (0, -1.9, 3.0), (0, -4.3, 2.3), "Body"),
                 ("Shell", (0, -0.8, 4.4), (0, -0.8, 6.2), "Body")]
        for bn, sx, ly in (("LegFL", -1, -1.2), ("LegFR", 1, -1.2), ("LegBL", -1, 2.3), ("LegBR", 1, 2.3)):
            bones.append((bn, (sx * 1.3, ly, 2.6), (sx * 1.35, ly - 0.2, 0.1), "Body"))
        centre = (0, 0.3, 3.2); facets = 14
    else:                                               # COLOSSUS: an upright golem, crystal fists, a magma core
        H, W, budget, tex = 14.5, 14.0, 9000, 1024
        rock = [ellipsoid((0, 0.2, 5.3), (2.2, 1.5, 1.2), 32), ellipsoid((0, 0.0, 8.3), (3.4, 2.3, 2.7), 40),
                ellipsoid((0, -0.55, 11.35), (1.25, 1.1, 1.0), 24)]
        for sx in (-1, 1):
            rock += [ellipsoid((sx * 3.7, 0.0, 9.6), (1.6, 1.5, 1.4), 24)]                                  # shoulder
            rock += chain([(sx * 4.0, 0.0, 9.0), (sx * 4.35, -0.15, 7.0), (sx * 4.5, -0.35, 5.0)], [1.05, 1.0, 1.2], 16)
            rock.append(ellipsoid((sx * 4.55, -0.4, 4.6), (1.15, 1.15, 0.7), 20))                           # wrist (the gauntlet is crystal)
            rock += chain([(sx * 1.4, 0.3, 5.0), (sx * 1.5, 0.25, 3.0), (sx * 1.5, 0.15, 1.2)], [1.15, 1.05, 1.05], 16)
            rock.append(ellipsoid((sx * 1.5, -0.35, 0.45), (1.3, 1.65, 0.5), 20))                           # foot

        def crys(body, rnd):
            specs = [((x, y), 0.75, h, (14, x * 8), None) for (x, y, h) in ((-2.4, 1.0, 3.6), (2.4, 1.0, 3.6), (-1.3, 1.4, 4.6), (1.3, 1.4, 4.6), (0, 1.6, 3.9))]
            specs += [((sx * 3.8, 0.3), 0.7, 2.8, (0, sx * 30), None) for sx in (-1, 1)]                     # shoulder spikes
            out = place_crystals(body, specs, rnd)
            for sx in (-1, 1):                          # crystal GAUNTLETS (ChatGPT r2): a huge faceted block ~1.5x the head's
                c = V((sx * 4.6, -0.5, 3.2))            # width, plus 3 big amber projections forward and out: a wrecking fist
                g = crystal((c.x, c.y, c.z + 1.6), 1.75, 3.0, (math.pi, 0, 0)); g.scale = (1.0, 1.0, 1.0)
                out.append(g)
                for d, r, h in (((0, -1, 0.15), 0.6, 2.2), ((sx * 1, -0.5, 0.2), 0.55, 2.0), ((sx * 0.6, -0.8, 0.7), 0.5, 1.8)):
                    out.append(crystal_dir(c + V(d) * 0.6, d, r, h))
            return out
        eyes = eye_pair((0, -1.6, 11.45), 0.22, 0.45, slant=16, narrow=True)
        core = ellipsoid((0, -2.15, 8.4), (0.95, 0.5, 0.95), 20)
        bones = [("Root", (0, 0, 0), (0, 0, 0.8), None),
                 ("Hips", (0, 0.2, 4.6), (0, 0.2, 6.0), "Root"),
                 ("Chest", (0, 0.2, 6.0), (0, 0.0, 10.3), "Hips"),
                 ("Head", (0, -0.3, 10.4), (0, -0.6, 12.4), "Chest"),
                 ("ArmL", (-3.7, 0.0, 9.6), (-4.5, -0.35, 5.0), "Chest"), ("HandL", (-4.5, -0.35, 5.0), (-4.6, -0.5, 1.4), "ArmL"),
                 ("ArmR", (3.7, 0.0, 9.6), (4.5, -0.35, 5.0), "Chest"), ("HandR", (4.5, -0.35, 5.0), (4.6, -0.5, 1.4), "ArmR"),
                 ("LegL", (-1.4, 0.3, 5.0), (-1.5, 0.1, 0.1), "Hips"), ("LegR", (1.4, 0.3, 5.0), (1.5, 0.1, 0.1), "Hips")]
        centre = (0, 0.0, 8.3); facets = 18
    rock_build(form, H, W, budget, tex, rock, facets, centre, crys, eyes, core, bones, {2: 2, 3: 4, 4: 3}[form])


for race, fn in (("squish", squish_v2), ("crunch", crunch_v2)):
    for f in (2, 3, 4):
        key = f"{race}{f}"
        if ONLY and ONLY != key and ONLY != race:
            continue
        fn(f)
print("FORMS_V2_OK")
