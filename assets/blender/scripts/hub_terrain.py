# (31 Oct: this is the r4 SOURCE moon; it now writes terrain_grid_hub.r4.json. The live r5 RING moon = this grid
# stretched by hub_terrain_ring.py -> terrain_grid_hub.json. Re-run this only to change the r4 source, then re-run the ring.)
# Alien Fusion: the HUB moon heightfield, ~1,660 x 1,400 playable since r4 (30 Oct 2026; James: "the map's gotta be bigger ...
# three biomes ... and then still the bases in between"; ChatGPT map-size audit = option C, one shared moon:
# design\map-review\map-size-audit.md). Replaces the 1,008 x 672 arena terrain (map_terrain.py) for the hub place.
#   blender --background --factory-startup --python hub_terrain.py -- <out_dir>
# Same grid format as map_terrain.py (terrain_grid.json, read by src/tools/build-terrain.luau). Axes: X = Roblox X,
# N = grid z = "north" = Roblox -Z (the forest is north, as today).
# The centre is rebuilt EXACTLY like the old map (same noise, same crater, same breaches), so the built crater landmark,
# scar and props keep their ground. Around it (ChatGPT numbers, crater centre = 0,0):
#   hub 650 x 520 (8 flat plots 85 x 95 at X +-230, N +-55 / +-165) - MOONWOOD north (X +-380, N 275..515, a valley) -
#   GOO MARSH west (X -730..-365, N -200..220, a sunken basin with pools) - CRYSTAL CANYON east (X 365..730, a raised
#   plateau cut by winding channels) - LANDER RUINS south (X +-430, N -515..-300, a flat cratered plain) - rocky
#   highland corners between them - the cliff ring round +-750 x +-525.
import bpy, json, math, os, sys
import numpy as np

_a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
out = _a[0] if _a else os.getcwd()
os.makedirs(out, exist_ok=True)
rng = np.random.default_rng(11)

S, HS = 2.8, 1.0 + 1.8 * 0.45          # the old map's scale: the centre must match it exactly
CRATER_W = 82.0
# (r4, James 30 Oct: biomes were "straight up against the tycoon buildings" -> an open moon PLAIN round the bases,
# biomes pushed out against the cliff walls and bigger; playable ~1,660 x 1,400)
W, D, STEP = 1904.0, 1640.0, 2.0       # world incl. the cliff ring + far terrain (corners on the 4-stud voxel grid)
xs = np.arange(-W / 2, W / 2 + 0.01, STEP)
ns = np.arange(-D / 2, D / 2 + 0.01, STEP)
XW, NW = np.meshgrid(xs, ns)
X, Z = XW / S, NW / S                   # old design units (for the centre formulas)
AX = np.abs(X)


def smooth(e0, e1, v):
    t = np.clip((v - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def fbm(x, z, octaves, scale, seed):
    r = np.random.default_rng(seed)
    total = np.zeros_like(x)
    amp, freq = 1.0, 1.0 / scale
    for _ in range(octaves):
        g = r.normal(size=(64, 64))
        u = (x * freq) % 63
        v = (z * freq) % 63
        i0, j0 = np.floor(u).astype(int), np.floor(v).astype(int)
        fu, fv = u - i0, v - j0
        fu, fv = fu * fu * (3 - 2 * fu), fv * fv * (3 - 2 * fv)
        a = g[i0, j0]; b = g[i0 + 1, j0]; c = g[i0, j0 + 1]; d = g[i0 + 1, j0 + 1]
        total += amp * (a * (1 - fu) * (1 - fv) + b * fu * (1 - fv) + c * (1 - fu) * fv + d * fu * fv)
        amp *= 0.5; freq *= 2.0
    return total


XWw = XW + 34.0 * fbm(XW, NW, 3, 110.0, 31)            # warped coords: zone edges wander instead of ruler lines
NWw = NW + 34.0 * fbm(XW, NW, 3, 110.0, 32)


def box(x0, x1, n0, n1, feather, warp=True):
    """1 inside the rectangle, smooth falloff over `feather` studs outside it (edges warped by noise)"""
    xw, nw = (XWw, NWw) if warp else (XW, NW)
    fx = smooth(x0 - feather, x0, xw) * (1 - smooth(x1, x1 + feather, xw))
    fn = smooth(n0 - feather, n0, nw) * (1 - smooth(n1, n1 + feather, nw))
    return fx * fn


def crater(cx, cn, r, depth, rim):
    d = np.sqrt((XW - cx) ** 2 + (NW - cn) ** 2) / r
    bowl = -depth * (1 - np.clip(d, 0, 1) ** 2)
    rimh = rim * np.exp(-((d - 1.0) / 0.22) ** 2)
    ej = 0.35 * rim * np.exp(-np.clip(d - 1.0, 0, None) * 2.2) * (d > 1)
    return np.where(d < 1, bowl, 0) + rimh + ej


# ---------- the centre: identical to map_terrain.py at S = 2.8 (rolling ground + crater + 2 breaches) ----------
H = 0.9 * fbm(AX, Z, 4, 40.0, 1)
d0 = np.sqrt(X ** 2 + Z ** 2)
rimR = CRATER_W / S
centre = np.where(d0 < rimR, -6.0 * (1 - (d0 / rimR) ** 2), 0) + 8.0 * np.exp(-((d0 - rimR) / 7.0) ** 2)
breach = np.exp(-(Z / 10.5) ** 2) * smooth(rimR - 14, rimR - 2, d0) * (1 - smooth(rimR + 6, rimR + 18, d0))
centre -= breach * 10.0
H = (H + centre) * HS
H += 0.6 * fbm(np.abs(XW), NW, 3, 18.0, 8) + 0.25 * fbm(np.abs(XW), NW, 2, 6.0, 9)
base = H.copy()                                           # hub ground (used again after the zones)

# ---------- zones (target height fields, blended in by feathered masks) ----------
F = 45.0                                                  # feather between zones
hub = box(-325, 325, -260, 260, 60, warp=False)        # the hub core keeps exact edges (old ground inside)
plain = box(-470, 470, -440, 440, 60)                   # (r4) the open plain round the bases: old rolling ground
forest = box(-480, 480, 420, 700, F)                    # 960 x 280, against the north wall
marsh = box(-830, -490, -330, 330, F)                   # 340 x 660, against the west wall
canyon = box(490, 830, -330, 330, F)                    # 340 x 660, against the east wall
ruins = box(-480, 480, -700, -420, F)                   # 960 x 280, against the south wall

# MOONWOOD: a valley floor a little below the hub, gentle swells for groves, low banks on its east/west ends
forestH = -1.5 + 2.2 * fbm(XW, NW, 3, 70.0, 21) + 9.0 * smooth(400, 480, np.abs(XW))
# GOO MARSH: a sunken basin (-6) with soft mounds and a few deeper pools (goo later)
marshH = -6.0 + 1.6 * fbm(XW, NW, 3, 45.0, 22)
for (cx, cn, r) in ((-600, 120, 34), (-700, -40, 46), (-770, 200, 28), (-590, -180, 30), (-760, -230, 24), (-640, 260, 26)):
    dd = np.sqrt((XW - cx) ** 2 + (NW - cn) ** 2)
    marshH -= 4.5 * (1 - smooth(r * 0.55, r, dd))
# CRYSTAL CANYON: a raised plateau (+24) cut by two winding channels whose floor meets the hub ground at the entrance
plateau = 24.0 + 4.0 * fbm(XW, NW, 3, 55.0, 23)
c1 = 70 + 55 * np.sin((XW - 490) / 70.0)                 # channel centrelines (N as a function of X)
c2 = -110 + 45 * np.sin((XW - 490) / 55.0 + 1.3)
ch = np.maximum(np.exp(-((NW - c1) / 24.0) ** 2), np.exp(-((NW - c2) / 20.0) ** 2) * smooth(540, 590, XW))
mouth = 1 - smooth(490, 545, XW)                          # wide open where the canyon meets the hub
floor = 1.0 + 1.0 * fbm(XW, NW, 2, 30.0, 24)
canyonH = plateau * (1 - np.maximum(ch, mouth * 0.85)) + floor * np.maximum(ch, mouth * 0.85)
# LANDER RUINS: flat plain with a meteor field (craters placed later)
ruinsH = 0.5 + 1.2 * fbm(XW, NW, 3, 60.0, 25)
# HIGHLAND corners: rocky raised ground between the biomes (+12..+26)
highH = 14.0 + 9.0 * fbm(XW, NW, 3, 60.0, 26)

zone_w = np.maximum.reduce([plain, forest, marsh, canyon, ruins])
H = base * plain + forestH * forest + marshH * marsh + canyonH * canyon + ruinsH * ruins
wsum = plain + forest + marsh + canyon + ruins
H = np.where(wsum > 1e-6, H / np.maximum(wsum, 1e-6), 0) * zone_w + highH * (1 - zone_w)
H = np.where(hub > 0.999, base, H)                         # the hub core stays exactly the old ground

# (r4: the r3 approach ramps are gone: the open plain overlaps the inner edge of every biome)

# meteor field in the ruins + a few soft craters in the forest meadows / hub outskirts (not near plots or crater)
placed = []


def place(n, xr, nr, rr, mask_fn, tries=600):
    global H
    for _ in range(tries):
        if n == 0:
            return
        cx = rng.uniform(*xr); cn = rng.uniform(*nr); r = rr[0] + (rr[1] - rr[0]) * rng.random() ** 2.0
        if any(math.hypot(cx - a, cn - b) < (r + c) * 1.4 for a, b, c in placed):
            continue
        if not mask_fn(cx, cn, r):
            continue
        placed.append((cx, cn, r))
        age = rng.uniform(0.4, 1.0)
        H = H + crater(cx, cn, r, r * 0.26 * age, r * 0.12 * age)
        n -= 1


place(20, (-460, 460), (-690, -430), (10, 42), lambda x, n, r: True)
place(6, (-440, 440), (440, 690), (12, 26), lambda x, n, r: True)
# a few soft craters on the open plain, clear of the hub core (plots + crater)
place(8, (-450, 450), (-420, 420), (8, 18), lambda x, n, r: abs(x) > 300 + r or abs(n) > 270 + r)

# ---------- passes through the highland corners (ChatGPT greybox r1 fix 2: no sealed-off biomes) ----------
# each: a 28-stud walkable road between two zones, height eased from one end to the other; two of them climb onto the
# canyon plateau (upper access), plus a 20-wide ramp from the hub up onto the plateau (23 studs over ~90)
def road(x0, n0, h0, x1, n1, h1, width, feather):
    global H
    dx, dn = x1 - x0, n1 - n0; L2 = dx * dx + dn * dn
    t = np.clip(((XW - x0) * dx + (NW - n0) * dn) / L2, 0, 1)
    dist = np.sqrt((XW - (x0 + t * dx)) ** 2 + (NW - (n0 + t * dn)) ** 2)
    m = 1 - smooth(width / 2, width / 2 + feather, dist)
    target = h0 + (h1 - h0) * (t * t * (3 - 2 * t)) + 0.6 * fbm(XW, NW, 2, 25.0, 41)
    H = H * (1 - m) + target * m


road(-480, 470, -1.5, -640, 330, -6.0, 28, 14)       # Moonwood <-> Goo Marsh (NW)
road(480, 470, -1.5, 640, 330, 24.0, 28, 14)         # Moonwood <-> canyon plateau (NE, upper access)
road(-640, -330, -6.0, -480, -470, 0.5, 28, 14)      # Goo Marsh <-> Lander Ruins (SW)
road(480, -470, 0.5, 640, -330, 24.0, 28, 14)        # Lander Ruins <-> canyon plateau (SE, upper access)
road(500, -280, 1.5, 600, -280, 24.0, 20, 10)        # plain -> canyon plateau ramp

# ---------- the 8 plots: flat pads 85 x 95 at y = 3, 9-stud skirts (r2: rows at N +-65 / +-190, 30-35 studs apart) ----------
PLOT_Y = 3.0
plots = [(sx * 230, n) for sx in (-1, 1) for n in (-190, -65, 65, 190)]
for (px, pn) in plots:
    m = box(px - 42.5, px + 42.5, pn - 47.5, pn + 47.5, 9, warp=False)
    H = H * (1 - m) + PLOT_Y * m

# ---------- the cliff ring + far terrain ----------
sup = ((np.abs(XW) / 850.0) ** 4 + (np.abs(NW) / 720.0) ** 4) ** 0.25 + 0.02 * fbm(XW, NW, 2, 80.0, 4)
edge = smooth(0.985, 1.09, sup)
terr = np.round((54.0 + 12.0 * fbm(XW, NW, 3, 120.0, 5)) / 9.0) * 9.0
cliff = 0.6 * terr + 0.4 * (54.0 + 12.0 * fbm(XW, NW, 3, 120.0, 5))
H = H * (1 - edge) + cliff * edge
far = smooth(1.2, 1.5, sup)
H = H * (1 - far) + (30 + 16 * fbm(XW, NW, 3, 200.0, 6)) * far

# ---------- materials ----------
gy, gx = np.gradient(H, STEP)
slope = np.sqrt(gx ** 2 + gy ** 2)
mat = np.full(H.shape, "Sand", dtype=object)
mat[(d0 < rimR - 3)] = "Ground"
mat[(marsh > 0.5)] = "Ground"
mat[(slope > 0.85) & (edge < 0.5)] = "Rock"
mat[(canyon > 0.5) & (H > 12)] = "Rock"
mat[(np.abs(d0 - rimR) < 6.5) & (breach < 0.35)] = "Rock"
mat[edge > 0.45] = "Basalt"

sub = slice(None, None, 2)
Hs, Ms = H[sub, sub], mat[sub, sub]
grid = {
    "cell": 4.0, "originX": float(xs[0]), "originZ": float(ns[0]),
    "nx": int(Hs.shape[1]), "nz": int(Hs.shape[0]),
    "baseY": -20.0, "scale": S, "heightScale": HS, "crater": CRATER_W,
    "h": [[round(float(v), 2) for v in row] for row in Hs],
    "m": ["".join({"Sand": "s", "Ground": "g", "Rock": "r", "Basalt": "b"}[m] for m in row) for row in Ms],
    "note": "HUB 1500 x 1050: row = N index (south -> north, Roblox Z = -N), col = x; h in studs above Y=0",
    "plots": plots, "plotY": PLOT_Y,
    "zones": {"hub": [-325, 325, -260, 260], "plain": [-470, 470, -440, 440], "forest": [-480, 480, 420, 700],
              "marsh": [-830, -490, -330, 330], "canyon": [490, 830, -330, 330], "ruins": [-480, 480, -700, -420]},
}
with open(os.path.join(out, "terrain_grid_hub.r4.json"), "w") as f:
    json.dump(grid, f, separators=(",", ":"))

# ---------- preview: top-down, coloured by zone so the layout can be audited before Studio ----------
bpy.ops.wm.read_factory_settings(use_empty=True)
step = 4
Hp = H[::step, ::step]; Xp = XW[::step, ::step]; Np = NW[::step, ::step]
nz_, nx_ = Hp.shape
mesh = bpy.data.meshes.new("Hub")
mesh.from_pydata([(float(Xp[j, i]), float(Np[j, i]), float(Hp[j, i])) for j in range(nz_) for i in range(nx_)], [],
                 [(j * nx_ + i, j * nx_ + i + 1, (j + 1) * nx_ + i + 1, (j + 1) * nx_ + i) for j in range(nz_ - 1) for i in range(nx_ - 1)])
obj = bpy.data.objects.new("Hub", mesh); bpy.context.scene.collection.objects.link(obj)
for p in mesh.polygons: p.use_smooth = True
zc = {"hub": (0.62, 0.61, 0.6), "forest": (0.62, 0.52, 0.9), "marsh": (0.25, 0.8, 0.85), "canyon": (0.95, 0.6, 0.2),
      "ruins": (0.75, 0.72, 0.62), "high": (0.38, 0.37, 0.38), "edge": (0.15, 0.15, 0.16)}
masks = {"hub": plain, "forest": forest, "marsh": marsh, "canyon": canyon, "ruins": ruins}
vc = mesh.color_attributes.new("zone", "FLOAT_COLOR", "POINT")
for j in range(nz_):
    for i in range(nx_):
        jj, ii = j * step, i * step
        if edge[jj, ii] > 0.45: c = zc["edge"]
        else:
            k = max(masks, key=lambda q: masks[q][jj, ii])
            c = zc[k] if masks[k][jj, ii] > 0.5 else zc["high"]
            if any(abs(XW[jj, ii] - px) < 42.5 and abs(NW[jj, ii] - pn) < 47.5 for px, pn in plots): c = (0.95, 0.95, 0.95)
        vc.data[j * nx_ + i].color = (*c, 1)
m = bpy.data.materials.new("p"); m.use_nodes = True; nt = m.node_tree; b = nt.nodes["Principled BSDF"]
a = nt.nodes.new("ShaderNodeVertexColor"); a.layer_name = "zone"; nt.links.new(a.outputs["Color"], b.inputs["Base Color"])
b.inputs["Roughness"].default_value = 0.95; mesh.materials.append(m)
sc = bpy.context.scene; sc.render.engine = "BLENDER_EEVEE"; sc.render.resolution_x, sc.render.resolution_y = 1600, 1378
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN")); sun.data.energy = 4.0
sun.rotation_euler = (math.radians(50), 0, math.radians(35)); sc.collection.objects.link(sun)
world = bpy.data.worlds.new("w"); sc.world = world; world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.02, 0.02, 0.03, 1)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam")); sc.collection.objects.link(cam); sc.camera = cam
cam.data.type = "ORTHO"; cam.data.ortho_scale = 1904; cam.location = (0, 0, 400)
sc.render.filepath = os.path.join(out, "hub_preview_top.r4.png"); bpy.ops.render.render(write_still=True)
cam.data.type = "PERSP"; cam.data.lens = 24; cam.location = (0, -1300, 620)
cam.rotation_euler = (math.radians(58), 0, 0)
sc.render.filepath = os.path.join(out, "hub_preview_persp.r4.png"); bpy.ops.render.render(write_still=True)
print("HUB_TERRAIN_OK", grid["nx"], grid["nz"], round(float(H.min()), 2), round(float(H.max()), 2))
