# Crystal Canyon particle textures (31 Oct 2026), drawn to match ChatGPT's effects sheet E5
# (design\concepts\hub\E5-crystal-canyon-effects-chatgpt.png). White on transparent (the ParticleEmitter colour tints them):
#   ccFxStar   a 4-point star glint with a soft core (crystal sparkle, E5 #3)
#   ccFxEmber  a small hot ember: bright core, short soft tail upward (E5 #2)
#   ccFxDust   a big soft irregular puff, very low alpha (warm floor dust, E5 #6)
#   ccFxMote   a soft round mote (nest motes, spire haze, E5 #4 / #5) - same as gmFxDot but softer
#   blender -b --factory-startup --python hub_crystalcanyon_fx.py -- <assets_dir>
import bpy, math, os, sys
from mathutils import noise, Vector

out = os.path.join(sys.argv[sys.argv.index("--") + 1], "textures", "hub", "fx"); os.makedirs(out, exist_ok=True)
N = 128

def save(name, fn):
    img = bpy.data.images.new(name, N, N, alpha=True)
    px = []
    for j in range(N):
        for i in range(N):
            x = (i + 0.5) / N * 2 - 1; y = (j + 0.5) / N * 2 - 1
            a = max(0.0, min(1.0, fn(x, y)))
            px += [1.0, 1.0, 1.0, a]
    img.pixels = px; img.filepath_raw = os.path.join(out, name + ".png"); img.file_format = "PNG"; img.save()
    print("FX", name)

def star(x, y):
    r = math.hypot(x, y)
    rays = math.exp(-(abs(x) / 0.035) ** 2) * math.exp(-(abs(y) / 0.85) ** 2) + math.exp(-(abs(y) / 0.035) ** 2) * math.exp(-(abs(x) / 0.85) ** 2)
    diag = (math.exp(-(abs(x - y) / 0.04) ** 2) + math.exp(-(abs(x + y) / 0.04) ** 2)) * math.exp(-(r / 0.35) ** 2) * 0.45
    return rays + diag + math.exp(-(r / 0.12) ** 2) + math.exp(-(r / 0.4) ** 2) * 0.25
save("ccFxStar", star)
def ember(x, y):
    # image rows run bottom-up (y up): core at (0, -0.35), a soft tail fading upward
    core = math.exp(-((x / 0.16) ** 2 + ((y + 0.35) / 0.16) ** 2))
    tail = math.exp(-(x / (0.1 + 0.05 * (y + 0.35))) ** 2) * max(0.0, 1 - (y + 0.35) / 1.2) * (1 if y > -0.35 else 0) * 0.55
    halo = math.exp(-((x / 0.4) ** 2 + ((y + 0.3) / 0.5) ** 2)) * 0.25
    return core + tail + halo
save("ccFxEmber", ember)
def dust(x, y):
    r = math.hypot(x, y); n = noise.noise(Vector((x * 2.2, y * 2.2, 3.1))) * 0.25 + noise.noise(Vector((x * 5, y * 5, 7.7))) * 0.1
    return max(0.0, 1 - (r / (0.8 + n)) ** 2) ** 1.6 * 0.55
save("ccFxDust", dust)
save("ccFxMote", lambda x, y: math.exp(-(math.hypot(x, y) / 0.18) ** 2) * 0.85 + math.exp(-(math.hypot(x, y) / 0.5) ** 2) * 0.3)
