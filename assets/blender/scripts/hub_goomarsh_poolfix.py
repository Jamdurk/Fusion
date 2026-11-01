# Goo Marsh pools, Studio audit r2 blocker (31 Oct): the pools read as uniformly lit cyan plates. Rework the baked maps
# (no rebake, same UVs): the emit map already holds the rim (0.1 centre .. ~0.7 rim), so it drives a rim factor:
#   emit_v2  = clamp((emit - 0.13) * 1.35)            -> interior glow cut ~70-100 %, rim kept
#   color_v2 = color * (0.5 + 0.5 * rim) + deep teal  -> darker, deeper centre, bright cyan only toward the rim
#   blender -b --factory-startup --python hub_goomarsh_poolfix.py -- <tex_dir> poolA poolB flats
import bpy, sys, os
import numpy as np
args = sys.argv[sys.argv.index("--") + 1:]
tex, groups = args[0], args[1:]
DEEP = np.array([0.0030, 0.1470, 0.2705])            # #0A6B8F linear
for g in groups:
    base = "gm" + g[0].upper() + g[1:]
    ci = bpy.data.images.load(os.path.join(tex, base + "_color.png")); ei = bpy.data.images.load(os.path.join(tex, base + "_emit.png"))
    ci.colorspace_settings.name = "sRGB"; ei.colorspace_settings.name = "Non-Color"
    w, h = ci.size
    c = np.array(ci.pixels[:]).reshape(h, w, 4); e = np.array(ei.pixels[:]).reshape(h, w, 4)
    rim = np.clip((e[..., 0] - 0.13) / 0.5, 0, 1)
    # cloudy depth: a cheap blurred noise so the centre isn't one flat colour
    rng = np.random.default_rng(7); n = rng.random((h // 32 + 2, w // 32 + 2))
    n = np.kron(n, np.ones((32, 32)))[:h, :w]
    for _ in range(3): n = (n + np.roll(n, 9, 0) + np.roll(n, 9, 1) + np.roll(n, -9, 0) + np.roll(n, -9, 1)) / 5
    cloud = 0.85 + 0.3 * (n - n.mean()) / (n.std() + 1e-6) * 0.25
    k = (0.5 + 0.5 * rim)[..., None] * cloud[..., None]
    lin = np.where(c[..., :3] <= 0.04045, c[..., :3] / 12.92, ((c[..., :3] + 0.055) / 1.055) ** 2.4)   # pixels arrive in sRGB values
    mixd = lin * k + DEEP * (1 - k) * 0.6
    srgb = np.where(mixd <= 0.0031308, mixd * 12.92, 1.055 * np.power(np.clip(mixd, 0, None), 1 / 2.4) - 0.055)
    c[..., :3] = np.clip(srgb, 0, 1)
    e[..., :3] = np.clip((e[..., :3] - 0.13) * 1.35, 0, 1)
    for img, arr, suffix in ((ci, c, "_color_v2.png"), (ei, e, "_emit_v2.png")):
        out = bpy.data.images.new(base + suffix, w, h); out.pixels = arr.ravel().tolist()
        out.filepath_raw = os.path.join(tex, base + suffix); out.file_format = "PNG"; out.save()
        print("WROTE", base + suffix)
