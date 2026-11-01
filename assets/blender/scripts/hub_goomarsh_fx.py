# Goo Marsh particle textures (30 Oct 2026), drawn to match ChatGPT's effects sheet D5
# (design\concepts\hub\D5-goo-marsh-effects-chatgpt.png). White on transparent (the ParticleEmitter colour tints them):
#   gmFxDot    soft glowing spore / mote (D5 #3, #6)        gmFxRing  thin soft ripple ring (drip + bubble pops, D5 #1, #2)
#   gmFxDrop   a goo drop: teardrop, bright rim, clear-ish middle (D5 #1)
#   gmFxBubble a bubble: thin bright rim + a highlight dot (D5 #2, #5)
#   blender -b --factory-startup --python hub_goomarsh_fx.py -- <assets_dir>
import bpy, math, os, sys

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

def ring(r, w):
    return lambda x, y: math.exp(-((math.hypot(x, y) - r) / w) ** 2)

save("gmFxDot", lambda x, y: math.exp(-(math.hypot(x, y) / 0.22) ** 2) * 0.9 + math.exp(-(math.hypot(x, y) / 0.55) ** 2) * 0.35)
save("gmFxRing", lambda x, y: ring(0.78, 0.07)(x, y) * 0.95 + ring(0.6, 0.12)(x, y) * 0.25)
def drop(x, y):
    # teardrop, point up (image rows run bottom-up, y up): round bottom centred (0, -0.3) r 0.45, a curved taper to y 0.85
    if y <= -0.3: q = math.hypot(x, y + 0.3) / 0.45
    else:
        r = 0.45 * max(0.0, 1 - (y + 0.3) / 1.15) ** 0.75
        q = abs(x) / r if r > 1e-3 else 9.0
    body = 1.0 if q < 1 else math.exp(-((q - 1) / 0.12) ** 2)
    rim = math.exp(-((q - 0.9) / 0.1) ** 2)
    return body * 0.4 + rim * 0.5 + math.exp(-((x + 0.15) ** 2 + (y + 0.4) ** 2) / 0.006) * 0.8
save("gmFxDrop", drop)
save("gmFxBubble", lambda x, y: ring(0.8, 0.06)(x, y) * 0.9 + (0.12 if math.hypot(x, y) < 0.8 else 0)
     + math.exp(-((x + 0.32) ** 2 + (y - 0.32) ** 2) / 0.008) * 0.9)
