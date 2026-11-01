# Alien Fusion: the HUB moon r5 "ring" heightfield (31 Oct 2026; James: "Move bases too" = CONQUEST LANES ring,
# design\CONQUEST-LANES-HANDOFF.md, stage spec design\conquest-lanes\STRETCH-SPEC.md, ChatGPT stage-1 audit r1).
#   blender --background --factory-startup --python hub_terrain_ring.py -- <r4 grid json> <out_dir>
# The r4 moon (hub_terrain.py -> terrain_grid_hub.r4.json, everything built on it) is STRETCHED, not regenerated:
# every r5 point samples the r4 grid at (x - sx, n - sn), a smooth displacement field that is
#   0 in the hub centre (crater, scar, wreck: identical), 52 studs out east / west across the marsh + canyon latitudes,
#   100 studs out north / south across the forest + ruins longitudes, both in the highland corners.
# So each biome WITH its blend band, passes and cliff wall is the same ground moved by a whole number of voxels; the
# stretch itself happens only on the open plain (|x| 330..450 at marsh / canyon latitudes, |n| 280..400 at forest / ruins
# longitudes) and in the rocky corners. Then the r5 ring goes on top: the old two-row plot pads are replaced by plain
# ground, 8 plots 85 x 95 at r 380 (was 320) (22.5 + 45k deg, facing the crater), 8 graded lanes, 16 levelled fort pads.
# Axes: X = Roblox X, N = grid z = "north" = Roblox -Z.
import bpy, json, math, os, sys
import numpy as np

_a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
src = json.load(open(_a[0]))
out = _a[1] if len(_a) > 1 else os.getcwd()
os.makedirs(out, exist_ok=True)

SHIFT_N, SHIFT_X = 100.0, 52.0                          # whole voxels (25 / 13)
W, D, STEP = 2016.0, 1872.0, 4.0                         # the r5 grid straight at the 4-stud cell (corners on the voxel grid)
xs = np.arange(-W / 2, W / 2 + 0.01, STEP)
ns = np.arange(-D / 2, D / 2 + 0.01, STEP)
XW, NW = np.meshgrid(xs, ns)


def smooth(e0, e1, v):
    t = np.clip((v - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


# ---------- the displacement field (destination coordinates -> how far the r4 ground moved out) ----------
AXa, ANa = np.abs(XW), np.abs(NW)
# where the E/W stretch happens depends on latitude: on the plain at marsh / canyon latitudes (|n| < 300), out past the
# forest / ruins (|x| 560+) at their latitudes (|n| > 420)
a_n = 330.0 + 230.0 * smooth(300, 420, ANa)
sx = SHIFT_X * np.sign(XW) * smooth(a_n, a_n + 120.0, AXa)
# where the N/S stretch happens depends on longitude: on the plain inside the marsh / canyon (|x| < 450), out past the
# marsh / canyon's north + south ends (|n| 400+) at their longitudes (|x| > 520)
c_x = 280.0 + 120.0 * smooth(450, 520, AXa)
sn = SHIFT_N * np.sign(NW) * smooth(c_x, c_x + 120.0, ANa)
SX, SN = XW - sx, NW - sn                                 # where each r5 point samples the r4 ground

# ---------- sample the r4 grid (bilinear heights, nearest material) ----------
h4 = np.array(src["h"], dtype=np.float64)                 # rows = N index (south -> north), cols = x
m4 = np.array([list(r) for r in src["m"]])
c4, ox4, oz4 = src["cell"], src["originX"], src["originZ"]
fi = np.clip((SX - ox4) / c4, 0, src["nx"] - 1.000001)
fj = np.clip((SN - oz4) / c4, 0, src["nz"] - 1.000001)
i0, j0 = np.floor(fi).astype(int), np.floor(fj).astype(int)
ti, tj = fi - i0, fj - j0
H = (h4[j0, i0] * (1 - ti) * (1 - tj) + h4[j0, i0 + 1] * ti * (1 - tj) + h4[j0 + 1, i0] * (1 - ti) * tj + h4[j0 + 1, i0 + 1] * ti * tj)
MAT = m4[np.clip(np.rint(fj).astype(int), 0, src["nz"] - 1), np.clip(np.rint(fi).astype(int), 0, src["nx"] - 1)]

# ---------- the old two-row plot pads -> rolling plain again (r4 base ground, same formula as hub_terrain.r4.py) ----------
def fbm(x, z, octaves, scale, seed):
    r = np.random.default_rng(seed)
    total = np.zeros_like(x)
    amp, freq = 1.0, 1.0 / scale
    for _ in range(octaves):
        g = r.normal(size=(64, 64))
        u = (x * freq) % 63
        v = (z * freq) % 63
        a0, b0 = np.floor(u).astype(int), np.floor(v).astype(int)
        fu, fv = u - a0, v - b0
        fu, fv = fu * fu * (3 - 2 * fu), fv * fv * (3 - 2 * fv)
        a = g[a0, b0]; b = g[a0 + 1, b0]; c = g[a0, b0 + 1]; d = g[a0 + 1, b0 + 1]
        total += amp * (a * (1 - fu) * (1 - fv) + b * fu * (1 - fv) + c * (1 - fu) * fv + d * fu * fv)
        amp *= 0.5; freq *= 2.0
    return total


S_, HS_ = 2.8, 1.0 + 1.8 * 0.45
X_, Z_ = XW / S_, NW / S_
base = 0.9 * fbm(np.abs(X_), Z_, 4, 40.0, 1) * HS_ + 0.6 * fbm(np.abs(XW), NW, 3, 18.0, 8) + 0.25 * fbm(np.abs(XW), NW, 2, 6.0, 9)
oldpads = np.zeros_like(H)
for sxp in (-1, 1):
    for pn in (-190, -65, 65, 190):
        px = sxp * 230
        fx = smooth(px - 42.5 - 12, px - 42.5, XW) * (1 - smooth(px + 42.5, px + 42.5 + 12, XW))
        fn = smooth(pn - 47.5 - 12, pn - 47.5, NW) * (1 - smooth(pn + 47.5, pn + 47.5 + 12, NW))
        oldpads = np.maximum(oldpads, fx * fn)
H = H * (1 - oldpads) + base * oldpads
MAT[oldpads > 0.5] = "s"

# ---------- the 4 corner passes, re-cut between their MOVED ends (the corner stretch bends the r4 roads; same road() as
# hub_terrain.r4.py: 28-stud walkable road, height eased end to end, 14-stud feather) ----------
def road(x0, n0, h0, x1, n1, h1, width, feather):
    global H
    dx, dn = x1 - x0, n1 - n0; L2 = dx * dx + dn * dn
    t = np.clip(((XW - x0) * dx + (NW - n0) * dn) / L2, 0, 1)
    dist = np.sqrt((XW - (x0 + t * dx)) ** 2 + (NW - (n0 + t * dn)) ** 2)
    m = 1 - smooth(width / 2, width / 2 + feather, dist)
    target = h0 + (h1 - h0) * (t * t * (3 - 2 * t)) + 0.6 * fbm(XW, NW, 2, 25.0, 41)
    H = H * (1 - m) + target * m
    MAT[(m > 0.5) & (MAT == "r")] = "s"


road(-480, 470 + SHIFT_N, -1.5, -640 - SHIFT_X, 330, -6.0, 28, 14)       # Moonwood <-> Goo Marsh (NW)
road(480, 470 + SHIFT_N, -1.5, 640 + SHIFT_X, 330, 24.0, 28, 14)         # Moonwood <-> canyon plateau (NE, upper access)
road(-640 - SHIFT_X, -330, -6.0, -480, -470 - SHIFT_N, 0.5, 28, 14)      # Goo Marsh <-> Lander Ruins (SW)
road(480, -470 - SHIFT_N, 0.5, 640 + SHIFT_X, -330, 24.0, 28, 14)        # Lander Ruins <-> canyon plateau (SE, upper access)

# ---------- the 8 plots (RING) + lanes + fort pads ----------
PLOT_Y, PLOT_R = 3.0, 380.0                 # (31 Oct pm, James: bases further back, a bigger gap to Fort 1; was 320)
PLOT_U, PLOT_V = 42.5, 47.5                # half sizes: 85 along the radius, 95 across it
plots = [(round(PLOT_R * math.cos(math.radians(22.5 + 45 * k)), 2), round(PLOT_R * math.sin(math.radians(22.5 + 45 * k)), 2))
         for k in range(8)]
RR = np.sqrt(XW ** 2 + NW ** 2); AA = np.arctan2(NW, XW)


def rotrect(r, a, hu, hv, feather):
    """1 inside a rectangle centred r studs out on angle a (u = along the radius, v = across), soft edge"""
    px, pn = r * math.cos(a), r * math.sin(a)
    u = (XW - px) * math.cos(a) + (NW - pn) * math.sin(a)
    v = -(XW - px) * math.sin(a) + (NW - pn) * math.cos(a)
    return (1 - smooth(hu, hu + feather, np.abs(u))) * (1 - smooth(hv, hv + feather, np.abs(v)))


def blur(a, rad, passes=3):
    """box blur x3 ~ gaussian (rad in cells), edges clamped"""
    for _ in range(passes):
        for ax in (0, 1):
            pad = [(0, 0), (0, 0)]; pad[ax] = (rad + 1, rad)
            c = np.cumsum(np.pad(a, pad, mode="edge"), axis=ax)
            if ax == 0:
                a = (c[2 * rad + 1:, :] - c[:-2 * rad - 1, :]) / (2 * rad + 1)
            else:
                a = (c[:, 2 * rad + 1:] - c[:, :-2 * rad - 1]) / (2 * rad + 1)
    return a


# lanes: 20 wide + 10-stud soft shoulders, from each plot's inner edge (r 277.5) to the crater edge (r 125); graded =
# blended toward a blur of the ground (rolling stays, bumps go: <= ~2 studs in a 20-stud section)
LANE_W, LANE_R0, LANE_R1, SHOULDER = 20.0, 125.0, PLOT_R - PLOT_U, 10.0
FORT1_R, FORT2_R = 240.0, 170.0
FORT1_HU, FORT1_HV = 19.0, 22.0            # Fort 1 pad 38 along x 44 across (footprint 34 x 40 + margin)
FORT2_HU, FORT2_HV = 24.0, 26.0            # Fort 2 pad 48 along x 52 across (footprint 44 x 48 + margin)
Hb = blur(H, 4)                             # 4-stud cells: rad 4 x 3 passes ~ sigma 16 studs (r 380 lanes are longer)
lanemask = np.zeros_like(H)
padmask = np.zeros_like(H)
for (px, pn) in plots:
    a = math.atan2(pn, px)
    da = np.angle(np.exp(1j * (AA - a)))
    across = np.abs(RR * np.sin(da))
    m = (1 - smooth(LANE_W / 2, LANE_W / 2 + SHOULDER, across)) * smooth(LANE_R0 - 4, LANE_R0 + 4, RR) * (1 - smooth(LANE_R1, LANE_R1 + 6, RR)) * (np.cos(da) > 0)
    lanemask = np.maximum(lanemask, m)
H = H * (1 - lanemask) + Hb * lanemask
for (px, pn) in plots:
    a = math.atan2(pn, px)
    for (r, hu, hv) in ((FORT1_R, FORT1_HU, FORT1_HV), (FORT2_R, FORT2_HU, FORT2_HV)):
        i = int(round((r * math.cos(a) - xs[0]) / STEP)); j = int(round((r * math.sin(a) - ns[0]) / STEP))
        level = float(H[j, i])
        m = rotrect(r, a, hu, hv, 8)
        padmask = np.maximum(padmask, m)
        H = H * (1 - m) + level * m
plotmask = np.zeros_like(H)
for (px, pn) in plots:
    m = rotrect(PLOT_R, math.atan2(pn, px), PLOT_U, PLOT_V, 9)
    plotmask = np.maximum(plotmask, m)
    H = H * (1 - m) + PLOT_Y * m
MAT[plotmask > 0.5] = "s"
lanemask = np.maximum(lanemask * (1 - plotmask), padmask)
MAT[(lanemask > 0.5) & (MAT != "b")] = "g"                # lanes + pads read as darker packed paths

grid = {
    "cell": STEP, "originX": float(xs[0]), "originZ": float(ns[0]),
    "nx": int(H.shape[1]), "nz": int(H.shape[0]),
    "baseY": src["baseY"], "scale": src["scale"], "heightScale": src["heightScale"], "crater": src["crater"],
    "h": [[round(float(v), 2) for v in row] for row in H],
    "m": ["".join(row) for row in MAT],
    "note": "HUB r5 RING = the r4 grid stretched (hub_terrain_ring.py): row = N index (south -> north, Roblox Z = -N), col = x",
    "plots": plots, "plotY": PLOT_Y, "plotSize": [2 * PLOT_U, 2 * PLOT_V], "plotR": PLOT_R, "laneW": LANE_W,
    "fort1R": FORT1_R, "fort2R": FORT2_R,
    "shift": {"forestN": SHIFT_N, "ruinsN": -SHIFT_N, "marshX": -SHIFT_X, "canyonX": SHIFT_X},
    "zones": {"plain": [-522, 522, -540, 540], "forest": [-480, 480, 520, 800], "marsh": [-882, -542, -330, 330],
              "canyon": [542, 882, -330, 330], "ruins": [-480, 480, -800, -520]},
}
with open(os.path.join(out, "terrain_grid_hub.json"), "w") as f:
    json.dump(grid, f, separators=(",", ":"))

# ---------- preview: top-down by material, plots white, lanes red ----------
bpy.ops.wm.read_factory_settings(use_empty=True)
step = 2
Hp = H[::step, ::step]; Xp = XW[::step, ::step]; Np = NW[::step, ::step]
nz_, nx_ = Hp.shape
mesh = bpy.data.meshes.new("Hub")
mesh.from_pydata([(float(Xp[j, i]), float(Np[j, i]), float(Hp[j, i])) for j in range(nz_) for i in range(nx_)], [],
                 [(j * nx_ + i, j * nx_ + i + 1, (j + 1) * nx_ + i + 1, (j + 1) * nx_ + i) for j in range(nz_ - 1) for i in range(nx_ - 1)])
obj = bpy.data.objects.new("Hub", mesh); bpy.context.scene.collection.objects.link(obj)
for p in mesh.polygons: p.use_smooth = True
mc = {"s": (0.62, 0.61, 0.6), "g": (0.42, 0.40, 0.40), "r": (0.38, 0.37, 0.38), "b": (0.15, 0.15, 0.16)}
vc = mesh.color_attributes.new("zone", "FLOAT_COLOR", "POINT")
for j in range(nz_):
    for i in range(nx_):
        jj, ii = j * step, i * step
        c = mc.get(MAT[jj, ii], (0.6, 0.6, 0.6))
        if plotmask[jj, ii] > 0.5: c = (0.95, 0.95, 0.95)
        elif lanemask[jj, ii] > 0.5: c = (0.85, 0.3, 0.3)
        vc.data[j * nx_ + i].color = (*c, 1)
mt = bpy.data.materials.new("p"); mt.use_nodes = True; nt = mt.node_tree
b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
a = nt.nodes.new("ShaderNodeVertexColor"); a.layer_name = "zone"; nt.links.new(a.outputs["Color"], b.inputs["Base Color"])
b.inputs["Roughness"].default_value = 0.95; mesh.materials.append(mt)
sc = bpy.context.scene; sc.render.resolution_x, sc.render.resolution_y = 1600, int(1600 * D / W)
try:
    sc.render.engine = "BLENDER_EEVEE"
except TypeError:
    sc.render.engine = "BLENDER_EEVEE_NEXT"
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN")); sun.data.energy = 4.0
sun.rotation_euler = (math.radians(50), 0, math.radians(35)); sc.collection.objects.link(sun)
world = bpy.data.worlds.new("w"); sc.world = world; world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.02, 0.02, 0.03, 1)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam")); sc.collection.objects.link(cam); sc.camera = cam
cam.data.type = "ORTHO"; cam.data.ortho_scale = W; cam.location = (0, 0, 400)
sc.render.filepath = os.path.join(out, "hub_preview_top.png"); bpy.ops.render.render(write_still=True)
print("HUB_RING_OK", grid["nx"], grid["nz"], round(float(H.min()), 2), round(float(H.max()), 2))
