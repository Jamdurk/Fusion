# Alien Fusion: the Colossus v4 PILOT's attack props (James, 27 Oct: 3 attack animations to test the method).
#   * CrystalSpike: a cluster of amber crystals, the same crystal and shader as his gauntlets, that bursts out of the
#     ground round GROUND SHATTER's impact (spawned ~8x, scaled, rotated; the base sits ~0.4 below the ground);
#   * Boulder: his own seamed stone, a ~4.4-stud boulder he rips from the ground and throws (BOULDER HURL); its seams
#     glow like his.
#   blender --background --factory-startup --python colossus_fx.py -- <assets_dir>
# Writes blender/aliens/colossus_fx.blend (collections CrystalSpike, Boulder) + textures/aliens/fx_*_*.png.
import os, sys, math, random
_here = os.path.dirname(os.path.abspath(__file__))
_src = open(os.path.join(_here, "aliens_forms.py"), encoding="utf-8").read()
_src = _src[:_src.index("for race, fn in ((\"squish\", squish)")]
sys.argv = [sys.argv[0], "--", sys.argv[sys.argv.index("--") + 1], "none"]
exec(compile(_src, "aliens_forms.py", "exec"))
V = Vector
rnd = random.Random(23)
reset()


def seam_stone():
    """(the v4 Colossus's stone, as in colossus_v4.py) grey basalt, glowing magma in the creases and a crack network"""
    m, t = material("seamstone"); b = t.nodes["Principled BSDF"]
    tc = t.nodes.new("ShaderNodeTexCoord"); geo = t.nodes.new("ShaderNodeNewGeometry")
    n1 = t.nodes.new("ShaderNodeTexNoise"); n1.inputs["Scale"].default_value = 1.1; n1.inputs["Detail"].default_value = 6
    t.links.new(tc.outputs["Object"], n1.inputs["Vector"])
    ramp = t.nodes.new("ShaderNodeValToRGB"); t.links.new(n1.outputs["Fac"], ramp.inputs[0])
    ramp.color_ramp.elements[0].color = (0.16, 0.155, 0.15, 1); ramp.color_ramp.elements[1].color = (0.33, 0.32, 0.305, 1)
    pe = t.nodes.new("ShaderNodeMapRange"); t.links.new(geo.outputs["Pointiness"], pe.inputs[0]); pe.inputs[1].default_value = 0.52; pe.inputs[2].default_value = 0.58
    ed = t.nodes.new("ShaderNodeMix"); ed.data_type = "RGBA"; t.links.new(pe.outputs[0], ed.inputs[0])
    t.links.new(ramp.outputs["Color"], ed.inputs[6]); ed.inputs[7].default_value = (0.36, 0.35, 0.33, 1)
    ao = t.nodes.new("ShaderNodeAmbientOcclusion"); ao.inputs["Distance"].default_value = 0.3; ao.samples = 24
    seam = t.nodes.new("ShaderNodeMapRange"); t.links.new(ao.outputs["AO"], seam.inputs[0])
    seam.inputs[1].default_value = 0.55; seam.inputs[2].default_value = 0.78; seam.inputs[3].default_value = 1.0; seam.inputs[4].default_value = 0.0
    cv = t.nodes.new("ShaderNodeTexVoronoi"); cv.feature = "DISTANCE_TO_EDGE"; cv.inputs["Scale"].default_value = 0.9
    t.links.new(tc.outputs["Object"], cv.inputs["Vector"])
    ck = t.nodes.new("ShaderNodeMapRange"); t.links.new(cv.outputs["Distance"], ck.inputs[0])
    ck.inputs[1].default_value = 0.012; ck.inputs[2].default_value = 0.04; ck.inputs[3].default_value = 1.0; ck.inputs[4].default_value = 0.0
    both = t.nodes.new("ShaderNodeMath"); both.operation = "MAXIMUM"
    t.links.new(seam.outputs[0], both.inputs[0]); t.links.new(ck.outputs[0], both.inputs[1])
    hot = t.nodes.new("ShaderNodeValToRGB"); t.links.new(both.outputs[0], hot.inputs[0])
    hot.color_ramp.elements[0].color = (0.95, 0.22, 0.01, 1); hot.color_ramp.elements[1].color = (1.0, 0.55, 0.06, 1)
    mix = t.nodes.new("ShaderNodeMix"); mix.data_type = "RGBA"; t.links.new(both.outputs[0], mix.inputs[0])
    t.links.new(ed.outputs[2], mix.inputs[6]); t.links.new(hot.outputs["Color"], mix.inputs[7])
    t.links.new(mix.outputs[2], b.inputs["Base Color"])
    rr = t.nodes.new("ShaderNodeMapRange"); t.links.new(pe.outputs[0], rr.inputs[0]); rr.inputs[3].default_value = 0.86; rr.inputs[4].default_value = 0.6
    t.links.new(rr.outputs[0], b.inputs["Roughness"])
    return m, {"color": mix.outputs[2], "rough": rr.outputs[0], "emit": both.outputs[0]}


def crystal_at(a, d, r, h):
    q = V((0, 0, 1)).rotation_difference(V(d).normalized())
    return crystal(tuple(a), r, h, q.to_euler())


def into(name, objs):
    coll = bpy.data.collections.new(name); bpy.context.scene.collection.children.link(coll)
    for o in objs:
        for c in o.users_collection:
            c.objects.unlink(o)
        coll.objects.link(o)


# ---- CrystalSpike: a tall hero spike and two leaning ones, from z -0.4 (buried) up to ~3.3
cm = crystal_material(-0.4, 3.4, (0.9, 0.26, 0.02, 1), (1.0, 0.62, 0.1, 1))
cry = [crystal_at(V((0, 0, -0.4)), (0.08, 0.05, 1), 0.55, 3.7),
       crystal_at(V((0.45, 0.2, -0.4)), (0.55, 0.25, 1), 0.36, 2.4),
       crystal_at(V((-0.4, -0.25, -0.4)), (-0.5, -0.35, 1), 0.3, 1.9)]
cry = join(cry); sel(cry); bpy.ops.object.shade_flat()
hi = build_high([(cm[0], cm[1], cry)]); hi.name = "Spike_high"
lo = make_low(hi, "CrystalSpike", 400)
bake("fx_crystal_spike", lo, hi, [cm], 256)
hi.hide_render = True; hi.hide_set(True)
into("CrystalSpike", [lo])
print("SPIKE tris", tris(lo))

# ---- Boulder: five fused rounded stones, ~4.4 across, centred on its origin, offset well away from the spike
parts = []
for c, r in (((0, 0, 0), (2.0, 1.8, 1.7)), ((1.1, 0.4, 0.6), (1.2, 1.1, 1.1)), ((-1.0, -0.5, 0.5), (1.1, 1.2, 1.0)),
             ((0.3, -1.0, -0.6), (1.1, 1.0, 1.0)), ((-0.5, 0.9, -0.5), (1.0, 1.0, 0.9))):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.0, location=(0, 0, 0))
    o = bpy.context.object
    for v in o.data.vertices:
        v.co *= rnd.uniform(0.92, 1.07)
    o.scale = r; o.rotation_euler = (rnd.uniform(0, 3), rnd.uniform(0, 3), rnd.uniform(0, 3)); o.location = c
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    parts.append(o)
body = join(parts); body.name = "rock"
remesh(body, 0.06, 1)
displace(body, "CLOUDS", 0.6, 0.04)
bpy.ops.object.shade_smooth()
sm = seam_stone()
hi2 = build_high([(sm[0], sm[1], body)]); hi2.name = "Boulder_high"
lo2 = make_low(hi2, "Boulder", 1800)
bake("fx_boulder", lo2, hi2, [sm], 512)
hi2.hide_render = True; hi2.hide_set(True)
into("Boulder", [lo2])
print("BOULDER tris", tris(lo2))
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(bdir, "colossus_fx.blend"))
print("COLOSSUS_FX_OK")
