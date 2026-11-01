# Alien Fusion, map 1: the Moon arena heightfield (Blender 5.2, run headless).
#   blender --background --factory-startup --python map_terrain.py -- <out_dir>
# Builds the ground shape from the design (design/02-MAP.md), mirror-symmetric about x = 0 so both players get the
# same map. Writes:
#   terrain_grid.json   heights + material per 4-stud cell, for Roblox Terrain (x = Blender x, z = -Blender y)
#   moon_ground.blend   the sculpt as a mesh (2-stud grid) for previews and for baking the hero rocks against
#   preview_top.png / preview_persp.png
import bpy, bmesh, json, math, os, sys
import numpy as np

_a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
out = _a[0] if _a else os.getcwd()
S = float(_a[1]) if len(_a) > 1 else 1.0          # map scale: every distance x S (design is written at S = 1)
HS = 1.0 + (S - 1.0) * 0.45                        # heights grow slower than distances
CRATER_W = float(_a[2]) if len(_a) > 2 else 42.0 * S   # world crater radius (forms/rules v1: 80-85 at the 2.8 map)
os.makedirs(out, exist_ok=True)
rng = np.random.default_rng(7)

# world: 520 x 400 studs centred on 0; playable 360 x 240
W, D, STEP = 520.0 * S, 400.0 * S, 2.0
xs = np.arange(-W / 2, W / 2 + 0.01, STEP)
zs = np.arange(-D / 2, D / 2 + 0.01, STEP)
XW, ZW = np.meshgrid(xs, zs)        # world studs
X, Z = XW / S, ZW / S               # design units: every feature formula below is written at S = 1
AX = np.abs(X)                      # mirror symmetry about x = 0


def smooth(e0, e1, v):
    t = np.clip((v - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def fbm(x, z, octaves, scale, seed):
    # value-noise fBm (numpy, deterministic): smooth rolling ground
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


H = 0.9 * fbm(AX, Z, 4, 40.0, 1)                     # gentle rolling ground (mirrored)


def crater(cx, cz, r, depth, rim, ax=AX):
    # bowl + raised rim + soft ejecta falloff
    d = np.sqrt((ax - cx) ** 2 + (Z - cz) ** 2) / r
    bowl = -depth * (1 - np.clip(d, 0, 1) ** 2)
    rimh = rim * np.exp(-((d - 1.0) / 0.22) ** 2)
    ej = 0.35 * rim * np.exp(-np.clip(d - 1.0, 0, None) * 2.2) * (d > 1)
    return np.where(d < 1, bowl, 0) + rimh + ej


# --- centre crater (x = 0, so build it on the true x, it straddles the mirror) with two breaches toward the bases
d0 = np.sqrt(X ** 2 + Z ** 2)
rimR = CRATER_W / S
centre = np.where(d0 < rimR, -6.0 * (1 - (d0 / rimR) ** 2), 0) + 8.0 * np.exp(-((d0 - rimR) / 7.0) ** 2)
breach = np.exp(-(Z / 10.5) ** 2) * smooth(rimR - 14, rimR - 2, d0) * (1 - smooth(rimR + 6, rimR + 18, d0))
centre -= breach * 10.0                                  # cut the rim where z ~ 0 on both sides (the base-facing breaches)
H += centre
H *= np.where(d0 < rimR - 4, 0.35, 1.0) ** 0.0          # (keep noise inside the crater)

# --- base plateaus at x = +-150: flat +6 pad radius 26, ramp down toward the centre
dp = np.sqrt((AX - 150) ** 2 + Z ** 2)
plateau = 1 - smooth(26, 40, dp)
H = H * (1 - plateau) + 6.0 * plateau

# --- north flank (z > 0): Crystal Canyon: two ridges with a winding channel between them
wind = 62 + 9 * np.sin(AX / 26.0)                       # channel centreline z
ridgeBand = smooth(34, 46, Z) * (1 - smooth(110, 122, Z))
channel = np.exp(-((Z - wind) / 8.5) ** 2)              # ~17 wide floor
ridges = 14.0 * ridgeBand * (1 - channel) * smooth(48, 70, AX) * (1 - smooth(132, 140, AX))
ridges += 2.5 * ridgeBand * fbm(AX, Z, 2, 22.0, 3) * (1 - channel)
H += ridges

# crater placement with spacing (no "bubble wrap"): rejection-sample centres, sizes skewed small, rims vary with age
placed = []


def place(n, xr, zr, rr, mask, tries=400):
    global H
    for _ in range(tries):
        if n == 0:
            return
        cx = rng.uniform(*xr); cz = rng.uniform(*zr); r = rr[0] + (rr[1] - rr[0]) * rng.random() ** 2.2
        if any(math.hypot(cx - a, cz - b) < (r + c) * 1.35 for a, b, c in placed):
            continue
        placed.append((cx, cz, r))
        age = rng.uniform(0.35, 1.0)                    # old craters are soft and shallow
        H = H + mask * crater(cx, cz, r, r * 0.26 * age, r * 0.12 * age)
        n -= 1


# --- south flank (z < 0): Boulder Plain: flat, a few craters (boulders are meshes later)
place(int(9 * S ** 1.4), (40, 172), (-110, -48), (6 / S ** 0.5, 15), smooth(-30, -50, Z))
# scattered craters elsewhere (outside bases, the centre crater and the canyon)
place(int(14 * S ** 1.4), (12, 175), (-115, 110), (4 / S ** 0.5, 10), (1 - plateau) * smooth(rimR + 10, rimR + 22, d0) * (1 - ridgeBand))

# --- the ring wall: a rounded crater wall around the playable area, rolling far terrain beyond
sup = ((AX / 182.0) ** 4 + (np.abs(Z) / 122.0) ** 4) ** 0.25 + 0.035 * fbm(AX, Z, 2, 30.0, 4)
edge = smooth(0.97, 1.12, sup)
terr = np.round((30.0 + 7.0 * fbm(AX, Z, 3, 45.0, 5)) / 6.0) * 6.0          # broad terraces
cliff = 0.6 * terr + 0.4 * (30.0 + 7.0 * fbm(AX, Z, 3, 45.0, 5))
H = H * (1 - edge) + cliff * edge
far = smooth(1.35, 1.7, sup)
H = H * (1 - far) + (16 + 9 * fbm(AX, Z, 3, 80.0, 6)) * far

H *= HS
# world-scale detail so a bigger map isn't just a blown-up smooth one
H += 0.6 * fbm(np.abs(XW), ZW, 3, 18.0, 8) * (1 - edge) + 0.25 * fbm(np.abs(XW), ZW, 2, 6.0, 9)

# --- materials per cell (Roblox base material each MaterialVariant overrides)
#   Sand = regolith (main, bright) · Ground = crater dust (cooler) · Basalt = outer cliffs · Rock = steep slopes / ridges
gy, gx = np.gradient(H, STEP)   # (slopes in world studs)
slope = np.sqrt(gx ** 2 + gy ** 2)
mat = np.full(H.shape, "Sand", dtype=object)
mat[(d0 < rimR - 3) | ((Z < -40) & (H < -0.6))] = "Ground"
mat[(slope > 0.85) & (edge < 0.5)] = "Rock"
rim = (np.abs(d0 - rimR) < 6.5) & (breach < 0.35)
mat[rim] = "Rock"                                  # the crater rim: its own material, a ring you can see from a base
mat[edge > 0.45] = "Basalt"

# --- write the Roblox grid at 4 studs (every 2nd sample)
sub = slice(None, None, 2)
Hs, Ms = H[sub, sub], mat[sub, sub]
grid = {
    "cell": 4.0, "originX": float(xs[0]), "originZ": float(zs[0]),
    "nx": int(Hs.shape[1]), "nz": int(Hs.shape[0]),
    "baseY": -20.0, "scale": S, "heightScale": HS, "crater": CRATER_W,
    "h": [[round(float(v), 2) for v in row] for row in Hs],
    "m": ["".join({"Sand": "s", "Ground": "g", "Rock": "r", "Basalt": "b"}[m] for m in row) for row in Ms],
    "note": "row = z index (south -> north, Roblox z = -(Blender y)), col = x; h in studs above Y=0",
}
with open(os.path.join(out, "terrain_grid.json"), "w") as f:
    json.dump(grid, f, separators=(",", ":"))

# --- the Blender mesh (x, Blender y = -z, height on z)
bpy.ops.wm.read_factory_settings(use_empty=True)
mesh = bpy.data.meshes.new("MoonGround")
nz_, nx_ = H.shape
verts = [(float(XW[j, i]), float(-ZW[j, i]), float(H[j, i])) for j in range(nz_) for i in range(nx_)]
faces = [(j * nx_ + i, j * nx_ + i + 1, (j + 1) * nx_ + i + 1, (j + 1) * nx_ + i) for j in range(nz_ - 1) for i in range(nx_ - 1)]
mesh.from_pydata(verts, [], faces)
mesh.update()
obj = bpy.data.objects.new("MoonGround", mesh)
bpy.context.scene.collection.objects.link(obj)
for p in mesh.polygons:
    p.use_smooth = True

# preview material: colour by material class
cols = {"Sand": (0.62, 0.61, 0.6, 1), "Ground": (0.42, 0.43, 0.46, 1), "Rock": (0.5, 0.48, 0.46, 1), "Basalt": (0.17, 0.17, 0.18, 1)}
vc = mesh.color_attributes.new("cls", "FLOAT_COLOR", "POINT")
flat = mat.reshape(-1)
for k, c in enumerate(vc.data):
    c.color = cols[flat[k]]
m = bpy.data.materials.new("preview"); m.use_nodes = True
nt = m.node_tree; bsdf = nt.nodes["Principled BSDF"]
attr = nt.nodes.new("ShaderNodeVertexColor"); attr.layer_name = "cls"
nt.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"]); bsdf.inputs["Roughness"].default_value = 0.95
mesh.materials.append(m)

# markers: bases + reactor
for name, loc in (("BaseA", (-150 * S, 0, 6 * HS)), ("BaseB", (150 * S, 0, 6 * HS)), ("Reactor", (0, 0, -6 * HS))):
    bpy.ops.mesh.primitive_cylinder_add(radius=6 if name != "Reactor" else 4, depth=4, location=loc)
    bpy.context.object.name = name

sc = bpy.context.scene
sc.render.engine = "BLENDER_EEVEE"
sc.render.resolution_x, sc.render.resolution_y = 1400, 1000
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 4.0; sun.rotation_euler = (math.radians(55), 0, math.radians(35))
sc.collection.objects.link(sun)
world = bpy.data.worlds.new("w"); sc.world = world; world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.02, 0.02, 0.03, 1)

cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam")); sc.collection.objects.link(cam); sc.camera = cam
cam.data.type = "ORTHO"; cam.data.ortho_scale = 540 * S; cam.location = (0, 0, 300); cam.rotation_euler = (0, 0, 0)
sc.render.filepath = os.path.join(out, "preview_top.png"); bpy.ops.render.render(write_still=True)
cam.data.type = "PERSP"; cam.data.lens = 28; cam.location = (-250 * S, 190 * S, 120 * S)
cam.rotation_euler = (math.radians(62), 0, math.radians(-128))
sc.render.filepath = os.path.join(out, "preview_persp.png"); bpy.ops.render.render(write_still=True)

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "moon_ground.blend"))
print("TERRAIN_OK", grid["nx"], grid["nz"], round(float(H.min()), 2), round(float(H.max()), 2))
