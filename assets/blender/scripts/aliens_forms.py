# Alien Fusion: all 8 alien forms (SQUISH F1-F4, CRUNCH F1-F4) per design/03-FORMS-AND-RULES.md §5.
#   blender --background --factory-startup --python aliens_forms.py -- <assets_dir> [only e.g. squish2]
# Every form of a race uses the SAME bone names (SQUISH 7, CRUNCH 8) placed for its own proportions, so animations
# can be shared where the shapes allow. Geometry is built from simple parts, voxel-remeshed into one smooth/rocky
# body (one material), plus separate eye / spot / crystal parts with their own materials; a high-detail version is
# baked (colour / roughness / normal, multi-material) onto a decimated low. Faces Blender Front (-Y) = Roblox forward.
# Writes blender/aliens/<race>_f<n>.blend (collection <Race>F<n>), textures/aliens/<race>_f<n>_*.png, previews.
import bpy, bmesh, math, os, sys, random
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

argv = sys.argv[sys.argv.index("--") + 1:]
root = argv[0]
ONLY = argv[1] if len(argv) > 1 else None
bdir = os.path.join(root, "blender", "aliens"); tdir = os.path.join(root, "textures", "aliens")
os.makedirs(bdir, exist_ok=True); os.makedirs(tdir, exist_ok=True)


# ----------------------------------------------------------------------------------------------- helpers
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = 24
    return sc


def sel(o):
    bpy.ops.object.select_all(action="DESELECT"); o.select_set(True); bpy.context.view_layer.objects.active = o


def apply_mods(o):
    sel(o)
    for m in list(o.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)


def join(objs):
    objs = [o for o in objs if o]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    o = objs[0]
    sel(o); bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return o


def ellipsoid(c, r, segs=32, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=max(8, segs // 2), radius=1.0, location=c, rotation=rot)
    o = bpy.context.object; o.scale = r
    return o


def teardrop(c, rad, height, lean=0.25, squash=1.0):
    """the SQUISH droplet: wide low belly, a tip leaning back (+Y)"""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=40, ring_count=20, radius=1.0)
    o = bpy.context.object
    for v in o.data.vertices:
        t = (v.co.z + 1) / 2
        k = 1.0 - 0.55 * t ** 2.2
        v.co.x *= k; v.co.y *= k
        v.co.y += lean * t ** 3
    o.scale = (rad, rad * 0.95 * squash, height / 2); o.location = c
    return o


def cone(c, r1, r2, depth, rot, verts=14):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=depth, location=c, rotation=rot)
    return bpy.context.object


def remesh(o, voxel, smooth=4):
    sel(o)
    r = o.modifiers.new("rm", "REMESH"); r.mode = "VOXEL"; r.voxel_size = voxel
    if smooth:
        s = o.modifiers.new("sm", "SMOOTH"); s.iterations = smooth; s.factor = 0.6
    apply_mods(o)


def displace(o, kind, scale, strength, basis=None):
    t = bpy.data.textures.new(o.name + kind, kind); t.noise_scale = scale
    if basis:
        t.noise_basis = basis
    m = o.modifiers.new("d", "DISPLACE"); m.texture = t; m.strength = strength
    apply_mods(o)


def surface_points(body, dirs_from, offset=0.0):
    """ray-cast from outside toward an inner point: [(outer_start, inner_target)] -> surface hits"""
    bm = bmesh.new(); bm.from_mesh(body.data); bm.transform(body.matrix_world)
    tree = BVHTree.FromBMesh(bm); bm.free()
    hits = []
    for start, target in dirs_from:
        d = (Vector(target) - Vector(start)).normalized()
        loc, nrm, _, _ = tree.ray_cast(Vector(start), d)
        if loc is not None:
            hits.append((loc + nrm * offset, nrm))
    return hits


def slice_planes(o, n, rnd, dmin, dmax, zmin=-0.4, centre=(0, 0, 0)):
    """angular facets: cut by random planes around `centre` (rocks / CRUNCH bodies)"""
    me = o.data
    bm = bmesh.new(); bm.from_mesh(me)
    bmesh.ops.translate(bm, vec=-Vector(centre), verts=bm.verts)
    for _ in range(n):
        nv = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(zmin, 1.0))).normalized()
        # plane at a fraction of the extent along nv
        ext = max(abs(v.co.dot(nv)) for v in bm.verts)
        bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=nv * ext * rnd.uniform(dmin, dmax), plane_no=nv, clear_outer=True)
        edges = [e for e in bm.edges if e.is_boundary]
        if edges:
            bmesh.ops.holes_fill(bm, edges=edges, sides=0)
    bmesh.ops.translate(bm, vec=Vector(centre), verts=bm.verts)
    bm.to_mesh(me); bm.free()


def material(name):
    m = bpy.data.materials.new(name); m.use_nodes = True
    return m, m.node_tree


def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


# ----------------------------------------------------------------------------------------------- materials
def goo_material(zmin, zmax, palette):
    """SQUISH jelly: belly -> top gradient, violet in cavities, mint speckles"""
    m, t = material("goo"); b = t.nodes["Principled BSDF"]
    geo = t.nodes.new("ShaderNodeNewGeometry"); tc = t.nodes.new("ShaderNodeTexCoord")
    sep = t.nodes.new("ShaderNodeSeparateXYZ"); t.links.new(geo.outputs["Position"], sep.inputs[0])
    h = t.nodes.new("ShaderNodeMapRange"); t.links.new(sep.outputs[2], h.inputs[0]); h.inputs[1].default_value = zmin; h.inputs[2].default_value = zmax
    nz = t.nodes.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 3.0 / max(1.0, (zmax - zmin) / 2.5); t.links.new(tc.outputs["Object"], nz.inputs["Vector"])
    hm = t.nodes.new("ShaderNodeMath"); hm.operation = "ADD"; t.links.new(h.outputs[0], hm.inputs[0])
    nm = t.nodes.new("ShaderNodeMath"); nm.operation = "MULTIPLY"; t.links.new(nz.outputs["Fac"], nm.inputs[0]); nm.inputs[1].default_value = palette.get("mottle", 0.12)
    t.links.new(nm.outputs[0], hm.inputs[1])
    ramp = t.nodes.new("ShaderNodeValToRGB"); t.links.new(hm.outputs[0], ramp.inputs[0])
    els = ramp.color_ramp.elements
    els[0].position, els[0].color = 0.0, palette["belly"]
    els[1].position, els[1].color = 1.0, palette["top"]
    e = els.new(0.55); e.color = palette["mid"]
    ao = t.nodes.new("ShaderNodeAmbientOcclusion"); ao.inputs["Distance"].default_value = 0.35 * (zmax - zmin) / 2.5
    cav = t.nodes.new("ShaderNodeMapRange"); t.links.new(ao.outputs["AO"], cav.inputs[0]); cav.inputs[1].default_value = 0.4; cav.inputs[2].default_value = 0.95
    mixv = t.nodes.new("ShaderNodeMix"); mixv.data_type = "RGBA"
    t.links.new(cav.outputs[0], mixv.inputs[0]); mixv.inputs[6].default_value = palette["cavity"]; t.links.new(ramp.outputs["Color"], mixv.inputs[7])
    spk = t.nodes.new("ShaderNodeTexVoronoi"); spk.inputs["Scale"].default_value = 14.0 * 2.5 / (zmax - zmin); t.links.new(tc.outputs["Object"], spk.inputs["Vector"])
    spm = t.nodes.new("ShaderNodeMath"); spm.operation = "LESS_THAN"; t.links.new(spk.outputs["Distance"], spm.inputs[0]); spm.inputs[1].default_value = 0.08
    mixs = t.nodes.new("ShaderNodeMix"); mixs.data_type = "RGBA"
    t.links.new(spm.outputs[0], mixs.inputs[0]); t.links.new(mixv.outputs[2], mixs.inputs[6]); mixs.inputs[7].default_value = (0.6, 1.0, 0.85, 1)
    out_col = mixs.outputs[2]
    k = 2.5 / (zmax - zmin)                             # (detail scales stay the same size on every form)
    # (HD pass, ChatGPT texture audit: detail at three scales; medium = small bubbles, lighter, with a dark rim)
    bub = t.nodes.new("ShaderNodeTexVoronoi"); bub.inputs["Scale"].default_value = 6.0 * k; t.links.new(tc.outputs["Object"], bub.inputs["Vector"])
    bm_ = t.nodes.new("ShaderNodeMath"); bm_.operation = "LESS_THAN"; t.links.new(bub.outputs["Distance"], bm_.inputs[0]); bm_.inputs[1].default_value = 0.12
    bmix = t.nodes.new("ShaderNodeMix"); bmix.data_type = "RGBA"; bmix.blend_type = "SCREEN"
    bf = t.nodes.new("ShaderNodeMath"); bf.operation = "MULTIPLY"; t.links.new(bm_.outputs[0], bf.inputs[0]); bf.inputs[1].default_value = 0.35
    t.links.new(bf.outputs[0], bmix.inputs[0]); t.links.new(out_col, bmix.inputs[6]); bmix.inputs[7].default_value = (0.75, 0.95, 1.0, 1)
    out_col = bmix.outputs[2]
    emit = None
    if palette.get("veins"):                            # bright cyan bioluminescent veins over the dark indigo
        vv = t.nodes.new("ShaderNodeTexVoronoi"); vv.feature = "DISTANCE_TO_EDGE"; vv.inputs["Scale"].default_value = 1.3
        vsc = t.nodes.new("ShaderNodeVectorMath"); vsc.operation = "SCALE"; t.links.new(tc.outputs["Object"], vsc.inputs[0]); vsc.inputs["Scale"].default_value = k
        t.links.new(vsc.outputs[0], vv.inputs["Vector"])
        # (crisp: a thin bright core + a soft coloured halo around it; the core is also the glow mask)
        vm = t.nodes.new("ShaderNodeMath"); vm.operation = "LESS_THAN"; t.links.new(vv.outputs["Distance"], vm.inputs[0]); vm.inputs[1].default_value = 0.016
        vh = t.nodes.new("ShaderNodeMapRange"); t.links.new(vv.outputs["Distance"], vh.inputs[0]); vh.inputs[1].default_value = 0.06; vh.inputs[2].default_value = 0.016
        hmix = t.nodes.new("ShaderNodeMix"); hmix.data_type = "RGBA"
        hf = t.nodes.new("ShaderNodeMath"); hf.operation = "MULTIPLY"; t.links.new(vh.outputs[0], hf.inputs[0]); hf.inputs[1].default_value = 0.45
        t.links.new(hf.outputs[0], hmix.inputs[0]); t.links.new(out_col, hmix.inputs[6]); hmix.inputs[7].default_value = (0.1, 0.65, 1.0, 1)
        vl = t.nodes.new("ShaderNodeMath"); vl.operation = "MULTIPLY"; t.links.new(vm.outputs[0], vl.inputs[0]); t.links.new(cav.outputs[0], vl.inputs[1])
        vmix = t.nodes.new("ShaderNodeMix"); vmix.data_type = "RGBA"; t.links.new(vl.outputs[0], vmix.inputs[0])
        t.links.new(hmix.outputs[2], vmix.inputs[6]); vmix.inputs[7].default_value = (0.4, 1.0, 1.0, 1)
        out_col = vmix.outputs[2]
        emit = vl.outputs[0]
    t.links.new(out_col, b.inputs["Base Color"])
    # roughness: wet glossy body 0.14, the recesses matte-r up to 0.38 (ChatGPT ranges)
    rr = t.nodes.new("ShaderNodeMapRange"); t.links.new(cav.outputs[0], rr.inputs[0]); rr.inputs[1].default_value = 0.0; rr.inputs[2].default_value = 1.0
    rr.inputs[3].default_value = 0.38; rr.inputs[4].default_value = 0.14
    t.links.new(rr.outputs[0], b.inputs["Roughness"]); b.inputs["Coat Weight"].default_value = 0.6
    # fine scale: a soft micro ripple in the normal map (subtle: noise everywhere reads as rough plastic)
    fn = t.nodes.new("ShaderNodeTexNoise"); fn.inputs["Scale"].default_value = 18.0 * k; fn.inputs["Detail"].default_value = 4
    t.links.new(tc.outputs["Object"], fn.inputs["Vector"])
    bump = t.nodes.new("ShaderNodeBump"); bump.inputs["Strength"].default_value = 0.12; bump.inputs["Distance"].default_value = 0.02
    t.links.new(fn.outputs["Fac"], bump.inputs["Height"]); t.links.new(bump.outputs[0], b.inputs["Normal"])
    socks = {"color": out_col, "rough": rr.outputs[0]}
    if emit is not None:
        socks["emit"] = emit
    return m, socks


def eye_material(sclera, iris, pupil_r=0.5, iris_r=0.78, slit=False):
    """eyes look along -Y: iris/pupil by how directly the surface faces forward (works for any eye position)"""
    m, t = material("eye"); b = t.nodes["Principled BSDF"]
    geo = t.nodes.new("ShaderNodeNewGeometry")
    dot = t.nodes.new("ShaderNodeVectorMath"); dot.operation = "DOT_PRODUCT"
    t.links.new(geo.outputs["Normal"], dot.inputs[0]); dot.inputs[1].default_value = (0, -1, 0)
    fi = t.nodes.new("ShaderNodeMath"); fi.operation = "GREATER_THAN"; t.links.new(dot.outputs["Value"], fi.inputs[0]); fi.inputs[1].default_value = iris_r
    fp = t.nodes.new("ShaderNodeMath"); fp.operation = "GREATER_THAN"; t.links.new(dot.outputs["Value"], fp.inputs[0]); fp.inputs[1].default_value = 1 - (1 - iris_r) * pupil_r
    c1 = t.nodes.new("ShaderNodeMix"); c1.data_type = "RGBA"; t.links.new(fi.outputs[0], c1.inputs[0]); c1.inputs[6].default_value = sclera; c1.inputs[7].default_value = iris
    c2 = t.nodes.new("ShaderNodeMix"); c2.data_type = "RGBA"; t.links.new(fp.outputs[0], c2.inputs[0]); t.links.new(c1.outputs[2], c2.inputs[6]); c2.inputs[7].default_value = (0.01, 0.01, 0.02, 1)
    # catchlight: the surface facing up-left-forward
    dl = t.nodes.new("ShaderNodeVectorMath"); dl.operation = "DOT_PRODUCT"
    t.links.new(geo.outputs["Normal"], dl.inputs[0]); dl.inputs[1].default_value = tuple(Vector((-0.35, -0.85, 0.4)).normalized())
    cl = t.nodes.new("ShaderNodeMath"); cl.operation = "GREATER_THAN"; t.links.new(dl.outputs["Value"], cl.inputs[0]); cl.inputs[1].default_value = 0.985
    c3 = t.nodes.new("ShaderNodeMix"); c3.data_type = "RGBA"; t.links.new(cl.outputs[0], c3.inputs[0]); t.links.new(c2.outputs[2], c3.inputs[6]); c3.inputs[7].default_value = (1, 1, 1, 1)
    t.links.new(c3.outputs[2], b.inputs["Base Color"])
    r = t.nodes.new("ShaderNodeValue"); r.outputs[0].default_value = 0.05; t.links.new(r.outputs[0], b.inputs["Roughness"])
    return m, {"color": c3.outputs[2], "rough": r.outputs[0]}


def flat_material(name, color, rough):
    m, t = material(name); b = t.nodes["Principled BSDF"]
    c = t.nodes.new("ShaderNodeRGB"); c.outputs[0].default_value = color
    r = t.nodes.new("ShaderNodeValue"); r.outputs[0].default_value = rough
    t.links.new(c.outputs[0], b.inputs["Base Color"]); t.links.new(r.outputs[0], b.inputs["Roughness"])
    return m, {"color": c.outputs[0], "rough": r.outputs[0]}


def glow_material(core, rim):
    """fusion-memory spots / glowing eyes: bright core fading to a rim (reads as a light under the skin)"""
    m, t = material("glow"); b = t.nodes["Principled BSDF"]
    lw = t.nodes.new("ShaderNodeLayerWeight"); lw.inputs["Blend"].default_value = 0.4
    c = t.nodes.new("ShaderNodeMix"); c.data_type = "RGBA"; t.links.new(lw.outputs["Facing"], c.inputs[0])
    c.inputs[6].default_value = core; c.inputs[7].default_value = rim
    # Facing in a bake is view-dependent; use the normal against the outward direction from the part centre instead
    geo = t.nodes.new("ShaderNodeNewGeometry"); tc = t.nodes.new("ShaderNodeTexCoord")
    nz = t.nodes.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 8; t.links.new(tc.outputs["Object"], nz.inputs["Vector"])
    mx = t.nodes.new("ShaderNodeMix"); mx.data_type = "RGBA"; t.links.new(nz.outputs["Fac"], mx.inputs[0]); mx.inputs[6].default_value = core; mx.inputs[7].default_value = rim
    t.links.new(mx.outputs[2], b.inputs["Base Color"])
    r = t.nodes.new("ShaderNodeValue"); r.outputs[0].default_value = 0.1; t.links.new(r.outputs[0], b.inputs["Roughness"])
    g = t.nodes.new("ShaderNodeValue"); g.outputs[0].default_value = 0.9   # (glows: spots, CRUNCH eyes, the core)
    return m, {"color": mx.outputs[2], "rough": r.outputs[0], "emit": g.outputs[0]}


def rock_material(size, lighter=1.0, crack_w=0.024, crack_col=(1.0, 0.62, 0.05, 1)):
    """CRUNCH rock: grey-charcoal with thin amber glowing cracks, darker in cavities"""
    m, t = material("rock"); b = t.nodes["Principled BSDF"]
    tc = t.nodes.new("ShaderNodeTexCoord")
    sc_ = t.nodes.new("ShaderNodeVectorMath"); sc_.operation = "SCALE"; t.links.new(tc.outputs["Object"], sc_.inputs[0]); sc_.inputs["Scale"].default_value = 3.0 / size
    vor = t.nodes.new("ShaderNodeTexVoronoi"); vor.feature = "DISTANCE_TO_EDGE"; vor.inputs["Scale"].default_value = 1.7
    t.links.new(sc_.outputs[0], vor.inputs["Vector"])
    crack = t.nodes.new("ShaderNodeMath"); crack.operation = "LESS_THAN"; t.links.new(vor.outputs["Distance"], crack.inputs[0]); crack.inputs[1].default_value = crack_w
    nz = t.nodes.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 6; nz.inputs["Detail"].default_value = 8; t.links.new(sc_.outputs[0], nz.inputs["Vector"])
    rock = t.nodes.new("ShaderNodeValToRGB"); t.links.new(nz.outputs["Fac"], rock.inputs[0])
    # (HD pass: a lighter stone; with the brighter glowing cracks the old 0.10-0.27 read near-black in game)
    rock.color_ramp.elements[0].color = (0.17 * lighter, 0.16 * lighter, 0.165 * lighter, 1)
    rock.color_ramp.elements[1].color = (0.40 * lighter, 0.385 * lighter, 0.37 * lighter, 1)
    ao = t.nodes.new("ShaderNodeAmbientOcclusion"); ao.inputs["Distance"].default_value = 0.15 * size
    rk = t.nodes.new("ShaderNodeMix"); rk.data_type = "RGBA"; rk.blend_type = "MULTIPLY"; rk.inputs[0].default_value = 0.8
    t.links.new(rock.outputs["Color"], rk.inputs[6]); t.links.new(ao.outputs["AO"], rk.inputs[7])
    # (HD pass, ChatGPT texture audit) chipped edges: the convex rims a lighter, worn grey (Cycles pointiness)
    geo = t.nodes.new("ShaderNodeNewGeometry")
    pe = t.nodes.new("ShaderNodeMapRange"); t.links.new(geo.outputs["Pointiness"], pe.inputs[0]); pe.inputs[1].default_value = 0.52; pe.inputs[2].default_value = 0.6
    pm_ = t.nodes.new("ShaderNodeMath"); pm_.operation = "MULTIPLY"; t.links.new(pe.outputs[0], pm_.inputs[0]); pm_.inputs[1].default_value = 0.55
    em_ = t.nodes.new("ShaderNodeMix"); em_.data_type = "RGBA"; t.links.new(pm_.outputs[0], em_.inputs[0])
    t.links.new(rk.outputs[2], em_.inputs[6]); em_.inputs[7].default_value = (0.52 * lighter, 0.5 * lighter, 0.47 * lighter, 1)
    # thin dark hairline cracks between the big magma ones
    hv = t.nodes.new("ShaderNodeTexVoronoi"); hv.feature = "DISTANCE_TO_EDGE"; hv.inputs["Scale"].default_value = 5.5
    t.links.new(sc_.outputs[0], hv.inputs["Vector"])
    hl = t.nodes.new("ShaderNodeMath"); hl.operation = "LESS_THAN"; t.links.new(hv.outputs["Distance"], hl.inputs[0]); hl.inputs[1].default_value = 0.012
    hmx = t.nodes.new("ShaderNodeMix"); hmx.data_type = "RGBA"; hf = t.nodes.new("ShaderNodeMath"); hf.operation = "MULTIPLY"
    t.links.new(hl.outputs[0], hf.inputs[0]); hf.inputs[1].default_value = 0.8; t.links.new(hf.outputs[0], hmx.inputs[0])
    t.links.new(em_.outputs[2], hmx.inputs[6]); hmx.inputs[7].default_value = (0.04, 0.035, 0.035, 1)
    # the magma crack: a bright hot core inside a darker orange edge (sharper than one flat colour)
    hot = t.nodes.new("ShaderNodeMath"); hot.operation = "LESS_THAN"; t.links.new(vor.outputs["Distance"], hot.inputs[0]); hot.inputs[1].default_value = crack_w * 0.45
    rkc = t.nodes.new("ShaderNodeMix"); rkc.data_type = "RGBA"; t.links.new(crack.outputs[0], rkc.inputs[0])
    t.links.new(hmx.outputs[2], rkc.inputs[6]); rkc.inputs[7].default_value = tuple(c * 0.7 for c in crack_col[:3]) + (1,)
    rkh = t.nodes.new("ShaderNodeMix"); rkh.data_type = "RGBA"; t.links.new(hot.outputs[0], rkh.inputs[0])
    t.links.new(rkc.outputs[2], rkh.inputs[6]); rkh.inputs[7].default_value = (1.0, min(1.0, crack_col[1] + 0.3), 0.25, 1)
    t.links.new(rkh.outputs[2], b.inputs["Base Color"])
    # roughness: matte stone 0.86, worn edges 0.6, the cracks 0.5
    rr = t.nodes.new("ShaderNodeMapRange"); t.links.new(pm_.outputs[0], rr.inputs[0]); rr.inputs[3].default_value = 0.86; rr.inputs[4].default_value = 0.6
    rc = t.nodes.new("ShaderNodeMix"); t.links.new(crack.outputs[0], rc.inputs[0]); t.links.new(rr.outputs[0], rc.inputs[2]); rc.inputs[3].default_value = 0.5
    t.links.new(rc.outputs[0], b.inputs["Roughness"])
    # normal: the cracks cut IN, the hairlines a little, plus fine grit (all three scales show in the normal map)
    hgt = t.nodes.new("ShaderNodeMath"); hgt.operation = "ADD"; t.links.new(crack.outputs[0], hgt.inputs[0]); t.links.new(hf.outputs[0], hgt.inputs[1])
    grit = t.nodes.new("ShaderNodeTexNoise"); grit.inputs["Scale"].default_value = 40; grit.inputs["Detail"].default_value = 6; t.links.new(sc_.outputs[0], grit.inputs["Vector"])
    gm2 = t.nodes.new("ShaderNodeMath"); gm2.operation = "MULTIPLY"; t.links.new(grit.outputs["Fac"], gm2.inputs[0]); gm2.inputs[1].default_value = 0.25
    hg2 = t.nodes.new("ShaderNodeMath"); hg2.operation = "SUBTRACT"; t.links.new(gm2.outputs[0], hg2.inputs[0]); t.links.new(hgt.outputs[0], hg2.inputs[1])
    bump = t.nodes.new("ShaderNodeBump"); bump.inputs["Strength"].default_value = 0.45; bump.inputs["Distance"].default_value = 0.02 * size / 3.0
    t.links.new(hg2.outputs[0], bump.inputs["Height"]); t.links.new(bump.outputs[0], b.inputs["Normal"])
    # the glow mask: the magma cracks (hot core brightest)
    gl = t.nodes.new("ShaderNodeMath"); gl.operation = "MULTIPLY_ADD"; t.links.new(crack.outputs[0], gl.inputs[0]); gl.inputs[1].default_value = 0.55; t.links.new(hot.outputs[0], gl.inputs[2])
    return m, {"color": rkh.outputs[2], "rough": rc.outputs[0], "emit": gl.outputs[0]}


def crystal_material(zmin, zmax, deep=(0.85, 0.28, 0.0, 1), tip=(1.0, 0.72, 0.2, 1)):
    m, t = material("crystal"); b = t.nodes["Principled BSDF"]
    geo = t.nodes.new("ShaderNodeNewGeometry")
    sep = t.nodes.new("ShaderNodeSeparateXYZ"); t.links.new(geo.outputs["Position"], sep.inputs[0])
    g = t.nodes.new("ShaderNodeMapRange"); t.links.new(sep.outputs[2], g.inputs[0]); g.inputs[1].default_value = zmin; g.inputs[2].default_value = zmax
    cr = t.nodes.new("ShaderNodeValToRGB"); t.links.new(g.outputs[0], cr.inputs[0])
    cr.color_ramp.elements[0].color = deep; cr.color_ramp.elements[1].color = tip
    ao = t.nodes.new("ShaderNodeAmbientOcclusion"); ao.inputs["Distance"].default_value = 0.4
    mul = t.nodes.new("ShaderNodeMix"); mul.data_type = "RGBA"; mul.blend_type = "MULTIPLY"; mul.inputs[0].default_value = 0.5
    t.links.new(cr.outputs["Color"], mul.inputs[6]); t.links.new(ao.outputs["AO"], mul.inputs[7])
    # (HD pass: jewel-like facets, ChatGPT: "the claws should be almost jewel-like against the dull stone": each flat
    # face lit or shaded by which way it faces, and a bright line on the facet edges)
    fd = t.nodes.new("ShaderNodeVectorMath"); fd.operation = "DOT_PRODUCT"
    t.links.new(geo.outputs["True Normal"], fd.inputs[0]); fd.inputs[1].default_value = tuple(Vector((-0.45, -0.55, 0.7)).normalized())
    fr = t.nodes.new("ShaderNodeMapRange"); t.links.new(fd.outputs["Value"], fr.inputs[0]); fr.inputs[1].default_value = -0.6; fr.inputs[2].default_value = 0.9
    fr.inputs[3].default_value = 0.7; fr.inputs[4].default_value = 1.12
    fl = t.nodes.new("ShaderNodeMix"); fl.data_type = "RGBA"; fl.blend_type = "MULTIPLY"; fl.inputs[0].default_value = 1.0
    t.links.new(mul.outputs[2], fl.inputs[6])
    fc = t.nodes.new("ShaderNodeCombineColor"); t.links.new(fr.outputs[0], fc.inputs[0]); t.links.new(fr.outputs[0], fc.inputs[1]); t.links.new(fr.outputs[0], fc.inputs[2])
    t.links.new(fc.outputs[0], fl.inputs[7])
    # (the crystals are small, sharp prisms: pointiness is high all over them, so only the very sharpest edges get a
    # thin, half-strength highlight; the first bake washed them out to cream)
    pe = t.nodes.new("ShaderNodeMapRange"); t.links.new(geo.outputs["Pointiness"], pe.inputs[0]); pe.inputs[1].default_value = 0.72; pe.inputs[2].default_value = 0.85
    pe2 = t.nodes.new("ShaderNodeMath"); pe2.operation = "MULTIPLY"; t.links.new(pe.outputs[0], pe2.inputs[0]); pe2.inputs[1].default_value = 0.45
    ed = t.nodes.new("ShaderNodeMix"); ed.data_type = "RGBA"; t.links.new(pe2.outputs[0], ed.inputs[0])
    t.links.new(fl.outputs[2], ed.inputs[6]); ed.inputs[7].default_value = (1.0, 0.85, 0.45, 1)
    t.links.new(ed.outputs[2], b.inputs["Base Color"])
    r = t.nodes.new("ShaderNodeValue"); r.outputs[0].default_value = 0.14; t.links.new(r.outputs[0], b.inputs["Roughness"])
    g = t.nodes.new("ShaderNodeValue"); g.outputs[0].default_value = 0.22   # (a faint inner glow)
    return m, {"color": ed.outputs[2], "rough": r.outputs[0], "emit": g.outputs[0]}


# ----------------------------------------------------------------------------------------------- eyes + lids (27 Oct)
def sink_eyes(body, eyes, depth=0.7):
    """CRUNCH (James, 27 Oct: the eyes were beads floating in front of the face): ray-cast from in front of each eye
    straight back onto the head and sit it there, sunk `depth` of its own depth into the rock, so a glowing lens shows"""
    for e in eyes:
        x, z = e.location.x, e.location.z
        hits = surface_points(body, [((x, -80.0, z), (x, 80.0, z))], 0.0)
        if hits:
            e.location.y = hits[0][0].y + e.scale.y * depth


def make_lid(c, r, open_deg=-175.0):
    """SQUISH eyelid: the front half of a shell ~1.1x the eye, modelled OPEN (swung back behind the eye, inside the head, about its centre by
    open_deg, into the head); its Lid bone swings it down over the eye to blink"""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=12, radius=1.0)
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, 0, 0), plane_no=(0, 1, 0), clear_outer=True)
    me = bpy.data.meshes.new("lid"); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new("lid", me); bpy.context.scene.collection.objects.link(o)
    o.location = c; o.scale = (r * 1.12, r * 0.92, r * 1.12); o.rotation_euler = (math.radians(open_deg), 0, 0)
    return o


def rigid_parts(lo, main):
    """(James, 27 Oct: the eyes rippled like liquid and clipped while walking) every loose piece that isn't the body (an
    eye ball, iris, pupil, glint, tooth, spot, crystal, socket) becomes RIGID: all its vertices get one identical weight
    set, copied from the body vertex nearest the piece's centre, so it moves as a solid object with the skin under it
    instead of stretching across several bones. Run after rig() (and after follow_surface on the v2 forms)"""
    from mathutils.kdtree import KDTree
    vs = lo.data.vertices
    loose = [v.index for v in vs if v.index not in main]
    parent = {i: i for i in loose}                     # the pieces = connected islands of the loose vertices
    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]; i = parent[i]
        return i
    for e in lo.data.edges:
        a, b = e.vertices
        if a in parent and b in parent:
            ra, rb = find(a), find(b)
            if ra != rb:
                parent[ra] = rb
    islands = {}
    for i in loose:
        islands.setdefault(find(i), []).append(i)
    idx = list(main)
    kd = KDTree(len(idx))
    for k, vi in enumerate(idx):
        kd.insert(vs[vi].co, k)
    kd.balance()
    for verts in islands.values():
        c = sum((vs[i].co for i in verts), Vector()) / len(verts)
        _, k, _ = kd.find(c)
        src = [(g.group, g.weight) for g in vs[idx[k]].groups]
        for i in verts:
            for g in list(vs[i].groups):
                lo.vertex_groups[g.group].remove([i])
            for gi, w in src:
                lo.vertex_groups[gi].add([i], w, "REPLACE")
    print("RIGID", lo.name, len(islands), "pieces")


def body_verts(lo):
    """the body's vertices (material 0), read before bake() merges every face onto one material"""
    return {v for p in lo.data.polygons if p.material_index == 0 for v in p.vertices}


def lid_verts(lo, slot):
    """the lid's vertices, read before bake() merges every face onto one material"""
    return {v for p in lo.data.polygons if p.material_index == slot for v in p.vertices}


def strip_lid(lo, verts, bone="Lid"):
    """heat weighting gives the face near the eye some Lid weight: only the lid itself may follow the Lid bone (else the
    face would fold with every blink). Run straight after rig(), before follow_surface()"""
    others = [v.index for v in lo.data.vertices if v.index not in verts]
    lo.vertex_groups[bone].remove(others)
    sel(lo)
    bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)


def assign_lid(lo, verts, bone="Lid"):
    for g in lo.vertex_groups:
        g.remove(list(verts))
    lo.vertex_groups[bone].add(list(verts), 1.0, "REPLACE")
    print("LID", lo.name, len(verts))


def eye_socket(e, grow=1.3, push=0.12):
    """a thin charcoal socket ring around a sunk CRUNCH eye (ChatGPT: thin, not an oversized black ring)"""
    s = ellipsoid(tuple(e.location), (e.scale.x * grow, e.scale.y, e.scale.z * grow), 16)
    s.rotation_euler = e.rotation_euler
    s.location.y += e.scale.y * push
    return s


# ----------------------------------------------------------------------------------------------- bake + rig + save
def build_high(parts_by_mat):
    """parts_by_mat: [(material, sockets, object)] -> one joined high mesh with one slot per material"""
    objs = []
    for i, (m, socks, o) in enumerate(parts_by_mat):
        o.data.materials.clear()
        for mm, _, _ in parts_by_mat:
            o.data.materials.append(mm)
        for p in o.data.polygons:
            p.material_index = i
        objs.append(o)
    return join(objs)


def bake(name, lo, hi, mats, size):
    # (HD pass, ChatGPT texture audit: bake at 2x, then scale down = crisp, anti-aliased detail; 16 px seam padding at
    # 2x. A 4th map, "emit", is the glow mask for SurfaceAppearance.EmissiveMaskContent: veins, magma, eyes, cores)
    out_size, size = size, size * 2
    kinds = [("color", "sRGB"), ("rough", "Non-Color"), ("normal", "Non-Color")]
    has_emit = any("emit" in socks for _, socks in mats)
    if has_emit:
        kinds.append(("emit", "Non-Color"))
    imgs, nodes = {}, []
    for kind, cs in kinds:
        img = bpy.data.images.new(f"{name}_{kind}", size, size); img.colorspace_settings.name = cs
        imgs[kind] = img
    game = bpy.data.materials.new(name + "_game"); game.use_nodes = True
    gt = game.node_tree; gb = gt.nodes["Principled BSDF"]
    lo.data.materials.clear(); lo.data.materials.append(game)
    for p in lo.data.polygons:
        p.material_index = 0
    tex = {}
    for kind, img in imgs.items():
        n = gt.nodes.new("ShaderNodeTexImage"); n.image = img; tex[kind] = n
    for kind, _ in kinds:
        gt.nodes.active = tex[kind]
        for m, socks in mats:
            t = m.node_tree; out = t.nodes["Material Output"]; b = t.nodes["Principled BSDF"]
            if kind == "normal":
                t.links.new(b.outputs[0], out.inputs["Surface"])
            else:
                e = t.nodes.get("bake_emit") or t.nodes.new("ShaderNodeEmission"); e.name = "bake_emit"
                src = socks.get(kind)
                if src is None:                         # (no glow on this material: bake black)
                    z = t.nodes.get("bake_zero") or t.nodes.new("ShaderNodeRGB"); z.name = "bake_zero"; z.outputs[0].default_value = (0, 0, 0, 1)
                    src = z.outputs[0]
                t.links.new(src, e.inputs["Color"]); t.links.new(e.outputs[0], out.inputs["Surface"])
        bpy.ops.object.select_all(action="DESELECT"); hi.select_set(True); lo.select_set(True); bpy.context.view_layer.objects.active = lo
        # (BAKE_EXT, if a build script sets it: big decimated forms sit further off their high mesh; the 14-stud v5
        # Titan baked black blotches where the rays fell short)
        ext = globals().get("BAKE_EXT") or 0.05 * out_size / 512
        bpy.ops.object.bake(type="NORMAL" if kind == "normal" else "EMIT", normal_space="TANGENT", use_selected_to_active=True,
                            cage_extrusion=max(0.08, ext), max_ray_distance=max(0.25, ext * 3), margin=16)
        imgs[kind].scale(out_size, out_size)            # (the 2x bake, filtered down)
        imgs[kind].filepath_raw = os.path.join(tdir, f"{name}_{kind}.png"); imgs[kind].file_format = "PNG"; imgs[kind].save()
    gt.links.new(tex["color"].outputs["Color"], gb.inputs["Base Color"])
    gt.links.new(tex["rough"].outputs["Color"], gb.inputs["Roughness"])
    nm = gt.nodes.new("ShaderNodeNormalMap"); gt.links.new(tex["normal"].outputs["Color"], nm.inputs["Color"]); gt.links.new(nm.outputs[0], gb.inputs["Normal"])
    for m, _ in mats:
        t = m.node_tree; t.links.new(t.nodes["Principled BSDF"].outputs[0], t.nodes["Material Output"].inputs["Surface"])


def make_low(hi, name, budget):
    """decimate ONLY the main body (material slot 0); eyes, spots, crystals keep their modelled geometry"""
    def part(keep_main):
        me = hi.data.copy()
        bm = bmesh.new(); bm.from_mesh(me)
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if (f.material_index == 0) != keep_main], context="FACES")
        bm.to_mesh(me); bm.free()
        o = bpy.data.objects.new(name + ("_main" if keep_main else "_rest"), me); bpy.context.scene.collection.objects.link(o)
        o.matrix_world = hi.matrix_world
        return o
    main, rest = part(True), part(False)
    others = tris(rest)
    cur = tris(main)
    target = max(400, budget - others)
    if cur > target:
        sel(main); d = main.modifiers.new("dec", "DECIMATE"); d.ratio = target / cur; apply_mods(main)
    lo = join([main, rest] if rest.data.polygons else [main]); lo.name = name
    sel(lo)
    bpy.ops.object.shade_smooth()
    # (HD pass, ChatGPT texture audit #1: texel space goes to the BODY. The eyes, teeth, crystals and spots are near
    # flat colour, so their islands are shrunk: their 3D size is cut to 55 % just for the unwrap (UV density follows 3D
    # area), then put back)
    me = lo.data
    small = {v for p in me.polygons if p.material_index != 0 for v in p.vertices}
    saved = {i: me.vertices[i].co.copy() for i in small}
    for i in small:
        me.vertices[i].co *= 0.55
    bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
    # (fewer, bigger islands at one even texel density, packed tight by shape: the 60-degree Smart UV left many small
    # islands and lots of empty space)
    bpy.ops.uv.smart_project(angle_limit=math.radians(72), island_margin=0.0)
    bpy.ops.uv.average_islands_scale()
    try:
        bpy.ops.uv.pack_islands(shape_method="CONCAVE", rotate=True, margin=0.002)
    except TypeError:
        print("PACK fallback (no shape_method)")
        bpy.ops.uv.pack_islands(rotate=True, margin=0.002)
    bpy.ops.object.mode_set(mode="OBJECT")
    for i, co in saved.items():
        me.vertices[i].co = co
    print("UVCOVER", name, round(uv_coverage(lo), 3))
    return lo


def uv_coverage(o):
    """the share of the 0-1 UV square the islands fill (texel space actually used)"""
    uv = o.data.uv_layers.active.data
    area = 0.0
    for p in o.data.polygons:
        pts = [uv[i].uv for i in p.loop_indices]
        for k in range(1, len(pts) - 1):
            a, b, c = pts[0], pts[k], pts[k + 1]
            area += abs((b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y)) / 2
    return area


def rig(name, lo, bones):
    arm = bpy.data.armatures.new(name + "Rig"); ao = bpy.data.objects.new(name + "Rig", arm)
    bpy.context.scene.collection.objects.link(ao)
    sel(ao); bpy.ops.object.mode_set(mode="EDIT")
    for bn, h, tl, p in bones:
        eb = arm.edit_bones.new(bn); eb.head = h; eb.tail = tl
        if p:
            eb.parent = arm.edit_bones[p]
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.select_all(action="DESELECT"); lo.select_set(True); ao.select_set(True); bpy.context.view_layer.objects.active = ao
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    sel(lo)
    g = lo.vertex_groups.get("Root")
    if g:
        lo.vertex_groups.remove(g)
    bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
    bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
    # loose parts (eyes, spots, crystals) that heat-weighting missed: give each to its nearest bone, weight 1
    from mathutils.geometry import intersect_point_line
    segs = []
    for b in arm.bones:
        if b.name == "Root":
            continue
        h, tl = ao.matrix_world @ b.head_local, ao.matrix_world @ b.tail_local
        segs.append((b.name, h, tl))
    fixed = 0
    for v in lo.data.vertices:
        if v.groups and sum(g.weight for g in v.groups) > 1e-4:
            continue
        p = lo.matrix_world @ v.co
        best, bd = None, 1e9
        for bn, h, tl in segs:
            q, t = intersect_point_line(p, h, tl); t = max(0.0, min(1.0, t)); q = h.lerp(tl, t)
            d = (p - q).length
            if d < bd:
                best, bd = bn, d
        lo.vertex_groups[best].add([v.index], 1.0, "REPLACE"); fixed += 1
    unweighted = sum(1 for v in lo.data.vertices if not v.groups)
    print("REWEIGHTED", name, fixed)
    return ao, unweighted


def preview(name, height):
    sc = bpy.context.scene
    bpy.ops.mesh.primitive_plane_add(size=height * 30, location=(0, 0, 0))
    floor = bpy.context.object; fm = bpy.data.materials.new("floor"); fm.use_nodes = True
    fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.42, 0.41, 0.4, 1); floor.data.materials.append(fm)
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN")); sc.collection.objects.link(sun)
    sun.data.energy = 4.0; sun.rotation_euler = (math.radians(50), 0, math.radians(-30))
    w = bpy.data.worlds.new("w"); sc.world = w; w.color = (0.08, 0.08, 0.1)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam")); sc.collection.objects.link(cam); sc.camera = cam
    cam.data.lens = 50; sc.render.resolution_x, sc.render.resolution_y = 1200, 800; sc.cycles.samples = 48
    for tag, yaw, el in (("front", math.radians(-20), 0.42), ("back", math.radians(150), 0.42), ("hero", math.radians(-50), 0.12)):
        d = Vector((math.sin(yaw), -math.cos(yaw), el)).normalized()
        cam.location = d * height * 3.0 + Vector((0, 0, height * 0.45))
        cam.rotation_euler = (Vector((0, 0, height * 0.45)) - cam.location).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(tdir, f"{name}_{tag}.png"); bpy.ops.render.render(write_still=True)
    for o in (floor, sun, cam):
        bpy.data.objects.remove(o)


def save(name, coll_name, lo, arm, hi, height, unweighted):
    coll = bpy.data.collections.new(coll_name); bpy.context.scene.collection.children.link(coll)
    for o in (arm, lo):
        for c in o.users_collection:
            c.objects.unlink(o)
        coll.objects.link(o)
    hi.hide_render = True; hi.hide_set(True)
    preview(name, max(height, max(lo.dimensions) * 0.75))
    print("FORM", name, "tris", tris(lo), "bones", len(arm.data.bones), "unweighted", unweighted, "height", round(max(v.co.z for v in lo.data.vertices), 2))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(bdir, f"{name}.blend"))


# ----------------------------------------------------------------------------------------------- SQUISH
SQ_PALETTES = {
    1: {"belly": (0.0, 0.22, 0.32, 1), "mid": (0.02, 0.62, 0.86, 1), "top": (0.15, 0.85, 1.0, 1), "cavity": (0.32, 0.12, 0.62, 1)},
    2: {"belly": (0.0, 0.16, 0.34, 1), "mid": (0.0, 0.55, 0.9, 1), "top": (0.12, 0.88, 1.0, 1), "cavity": (0.36, 0.1, 0.66, 1), "mottle": 0.18},
    3: {"belly": (0.04, 0.06, 0.3, 1), "mid": (0.0, 0.42, 0.85, 1), "top": (0.1, 0.85, 1.0, 1), "cavity": (0.42, 0.08, 0.7, 1), "mottle": 0.22},
    4: {"belly": (0.06, 0.02, 0.22, 1), "mid": (0.02, 0.3, 0.75, 1), "top": (0.12, 0.88, 1.0, 1), "cavity": (0.45, 0.06, 0.72, 1), "mottle": 0.2, "veins": True},
}


def brow(c, r, tilt, droop=-12, segs=24):
    """a goo ridge over the eye; tilt (deg, about Y) lowers one end: positive lowers the +X end"""
    o = ellipsoid(c, r, segs); o.rotation_euler = (math.radians(droop), math.radians(tilt), 0)
    return o


def fang(c, r, length, up=False):
    """a blunt cartoon fang (a stubby cone) pointing down (or up)"""
    return cone(c, r, r * 0.3, length, (0 if up else math.pi, 0, 0))


def spine(c, r, length, back_deg, out_deg=0.0):
    """a swept-back goo spine: tip toward +Y (back) and up"""
    return cone(c, r, r * 0.12, length, (math.radians(-back_deg), math.radians(out_deg), 0))


def squish(form):
    sc = reset()
    rnd = random.Random(form * 7)
    extra_goo, fangs, mouth = [], [], None
    iris_col, slit = (0.42, 0.14, 0.78, 1), False
    if form == 1:                                       # Baby: unchanged
        H, budget, tex = 2.5, 2200, 512
        body = [teardrop((0, 0, 1.2), 1.0, 2.3)]
        feet = [(-0.5, -0.45, 0.32), (0.5, -0.45, 0.32), (-0.5, 0.45, 0.32), (0.5, 0.45, 0.32)]
        eyes = [((0, -0.72, 1.55), 0.55)]
        spots = []
    elif form == 2:                                     # Troublemaker: lowered brow on one side, sharper peaks
        H, budget, tex = 4.0, 3000, 512
        body = [teardrop((-0.72, 0.05, 1.95), 1.12, 3.9, 0.42), teardrop((0.72, 0.05, 1.95), 1.12, 3.9, 0.42), ellipsoid((0, 0, 1.4), (1.55, 1.25, 1.2))]
        extra_goo = [brow((0.05, -1.15, 3.05), (1.05, 0.42, 0.3), 16, -14)]
        feet = [(-1.0, -0.65, 0.5), (1.0, -0.65, 0.5), (-1.0, 0.7, 0.48), (1.0, 0.7, 0.48)]
        eyes = [((0, -1.05, 2.3), 0.85)]
        spots = [((-0.95, -0.45, 2.95), 0.33), ((0.95, -0.45, 2.95), 0.33)]
    elif form == 3:                                     # Monster: heavy brow, slit pupil, sneer + fangs, 3 swept spines
        H, budget, tex = 6.5, 4500, 512
        body = [ellipsoid((sx * 1.2, sy * 1.0, 1.85), (1.6, 1.5, 1.45)) for sx in (-1, 1) for sy in (-1, 1)]
        body += [teardrop((0, -0.5, 3.8), 1.8, 4.2, 0.5), ellipsoid((0, 0, 2.5), (2.0, 1.8, 1.6))]
        extra_goo = [brow((0.2, -2.15, 5.45), (1.55, 0.62, 0.45), 18, -20),
                     spine((0, 1.0, 5.2), 0.85, 3.0, 55), spine((-1.35, 1.5, 3.9), 0.75, 2.6, 62, -20), spine((1.35, 1.5, 3.9), 0.75, 2.6, 62, 20)]
        feet = [(-1.9, -1.5, 0.95), (1.9, -1.5, 0.95), (-1.85, 1.55, 0.85), (1.85, 1.55, 0.85)]
        eyes = [((0, -2.0, 4.45), 1.1)]
        slit = True
        mouth = ellipsoid((0.25, -2.2, 2.95), (0.95, 0.4, 0.27), 16); mouth.rotation_euler = (0, math.radians(12), 0)
        fangs = [fang((0.75, -2.5, 3.0), 0.17, 0.5), fang((-0.2, -2.5, 2.85), 0.17, 0.5)]
        spots = [((sx * 2.15, -1.2, 2.3), 0.5) for sx in (-1, 1)] + [((sx * 2.35, 1.0, 3.0), 0.5) for sx in (-1, 1)]
    else:                                               # Boss: broad + low, head forward, V brow, 6 goo horns, fanged maw
        H, budget, tex = 13.0, 7500, 1024
        body = [ellipsoid((0, 0.8, 5.4), (5.7, 4.6, 4.0), 48),          # shoulders
                ellipsoid((0, -1.5, 6.6), (4.3, 3.6, 3.5), 40),          # head pushed forward
                ellipsoid((0, 0.2, 2.6), (6.1, 5.0, 2.5), 40)]           # low heavy belly
        for (x, y, ang, out, r1, ln) in ((-3.3, 0.2, 40, -38, 1.35, 3.6), (-1.9, -0.6, 30, -22, 1.55, 4.4), (-0.6, -0.9, 22, -8, 1.6, 4.8),
                                         (0.6, -0.9, 22, 8, 1.6, 4.8), (1.9, -0.6, 30, 22, 1.55, 4.4), (3.3, 0.2, 40, 38, 1.35, 3.6)):
            extra_goo.append(spine((x, y, 9.6 - abs(x) * 0.35), r1, ln, ang, out))
        extra_goo += [brow((-1.35, -5.0, 8.65), (2.1, 1.0, 0.75), 22, -18), brow((1.35, -5.0, 8.65), (2.1, 1.0, 0.75), -22, -18)]
        feet = [(-3.9, -3.0, 2.3), (3.9, -3.0, 2.3), (-3.7, 3.0, 1.8), (3.7, 3.0, 1.8)]
        eyes = [((0, -4.55, 7.3), 2.15)]
        iris_col, slit = (0.55, 0.06, 0.95, 1), True
        mouth = ellipsoid((0, -4.6, 3.8), (3.1, 1.2, 1.15), 20)
        fangs = [fang((x, -5.55, 4.55), 0.42, 1.25) for x in (-1.9, -0.7, 0.7, 1.9)] + [fang((x, -5.5, 3.0), 0.36, 1.0, up=True) for x in (-1.3, 1.3)]
        spots = []
        for cx, cy, cz in ((-4.6, -1.0, 3.6), (4.6, -1.0, 3.6), (-4.2, 1.2, 7.4), (4.2, 1.2, 7.4)):
            for k in range(4):
                spots.append(((cx + rnd.uniform(-0.7, 0.7), cy + rnd.uniform(-0.8, 0.8), cz + rnd.uniform(-0.9, 0.9)), rnd.uniform(0.45, 0.6)))
    for fx, fy, fr in feet:
        body.append(ellipsoid((fx, fy, fr * 0.7), (fr, fr * 1.15, fr * 0.7), 20))
    g = join(body + extra_goo); g.name = "goo"
    remesh(g, H / 120.0, 4)
    displace(g, "CLOUDS", 0.35 * H / 2.5, 0.01 * H)
    bpy.ops.object.shade_smooth()
    sclera, iris, pupil, catch = [], [], [], []
    for (c, r) in eyes:
        c = Vector(c)
        sclera.append(ellipsoid(tuple(c), (r, r * 0.78, r), 24))
        front = c + Vector((0, -r * 0.7, 0))
        iris.append(ellipsoid(tuple(front + Vector((0, -0.02 * r, 0))), (r * 0.6, r * 0.14, r * 0.6), 18))
        pr = (r * 0.11, r * 0.09, r * 0.4) if slit else (r * 0.3, r * 0.09, r * 0.3)
        pupil.append(ellipsoid(tuple(front + Vector((0, -0.1 * r, 0))), pr, 14))
        catch.append(ellipsoid(tuple(front + Vector((-0.24 * r, -0.17 * r, 0.24 * r))), (r * 0.09, r * 0.04, r * 0.09), 8))
    eye = join(sclera)
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
    parts = [(gm[0], gm[1], g), (em[0], em[1], eye), (im[0], im[1], join(iris)), (pm[0], pm[1], join(pupil)), (cm_[0], cm_[1], join(catch))]
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
    # the eyelid for the blink (James, 27 Oct), on its own Lid bone
    (ec, er) = eyes[0]
    lm = flat_material("lid", SQ_PALETTES[form]["mid"], 0.15)
    lid_slot = len(parts)
    parts.append((lm[0], lm[1], make_lid(ec, er))); mats.append(lm)
    hi = build_high(parts); hi.name = f"Squish{form}_high"
    lo = make_low(hi, f"SquishF{form}", budget)
    lv = lid_verts(lo, lid_slot)
    bv = body_verts(lo)
    bake(f"squish_f{form}", lo, hi, mats, tex)
    k = H / 2.5
    bones = [("Root", (0, 0, 0), (0, 0, 0.3 * k), None),
             ("Body", (0, 0, 0.35 * k), (0, 0, H * 0.48), "Root"),
             ("Top", (0, 0.02 * k, H * 0.48), (0, 0.08 * k, H * 0.96), "Body")]
    for bn, (fx, fy, fr) in zip(("FootFL", "FootFR", "FootBL", "FootBR"), feet):
        bones.append((bn, (fx, fy, fr * 1.3), (fx, fy, 0.02), "Root"))
    bones.append(("Lid", tuple(ec), (ec[0], ec[1] - er, ec[2]), "Top"))
    arm, unw = rig(f"SquishF{form}", lo, bones)
    strip_lid(lo, lv)
    rigid_parts(lo, bv)                                 # (the eye pieces move solid, no ripple)
    assign_lid(lo, lv)
    save(f"squish_f{form}", f"SquishF{form}", lo, arm, hi, H, unw)


# ----------------------------------------------------------------------------------------------- CRUNCH
def crystal(c, r, h, rot):
    bm = bmesh.new()
    base = [bm.verts.new((r * math.cos(i * math.pi / 3), r * math.sin(i * math.pi / 3), -0.15 * h)) for i in range(6)]
    mid = [bm.verts.new((r * 0.92 * math.cos(i * math.pi / 3), r * 0.92 * math.sin(i * math.pi / 3), h * 0.68)) for i in range(6)]
    tip = bm.verts.new((0, 0, h))
    bm.faces.new(base[::-1])
    for i in range(6):
        j = (i + 1) % 6
        bm.faces.new((base[i], base[j], mid[j], mid[i])); bm.faces.new((mid[i], mid[j], tip))
    me = bpy.data.meshes.new("cry"); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new("cry", me); bpy.context.scene.collection.objects.link(o)
    o.location = c; o.rotation_euler = rot
    return o


def crunch(form):
    sc = reset()
    rnd = random.Random(form * 13)
    # per form: size, body ellipsoid, head, horn, legs, shell sections (centres, radii) and their crystals
    if form == 1:
        H, W, budget, tex = 2.0, 3.0, 2600, 512
        body_c, body_r = (0, 0.1, 0.85), (1.35, 1.5, 0.55)
        head_c, head_r = (0, -1.35, 0.75), (0.58, 0.47, 0.41)
        horn = (None, 0.26, 0.95, 62)
        legs = [(-1.05, -0.65), (1.05, -0.65), (-1.05, 0.75), (1.05, 0.75)]; leg_r, leg_len, hip_z = 0.2, 0.75, 0.6
        sections = []
        crystals = [((-0.55, -0.55), 0.3, 0.9), ((0.55, -0.55), 0.3, 0.9), ((-0.62, 0.1), 0.3, 0.85), ((0.62, 0.1), 0.3, 0.85),
                    ((-0.5, 0.75), 0.28, 0.8), ((0.5, 0.75), 0.28, 0.8), ((0, -0.15), 0.36, 1.2), ((0, 0.55), 0.34, 1.1)]
        facets = 0
    elif form == 2:                                     # Shellback: two paired shell halves, bigger forelegs
        H, W, budget, tex = 3.5, 4.5, 3500, 512
        body_c, body_r = (0, 0.15, 1.45), (1.95, 2.2, 0.9)
        head_c, head_r = (0, -2.05, 1.25), (0.9, 0.75, 0.65)
        horn = (None, 0.48, 1.8, 58)
        legs = [(-1.6, -1.05), (1.6, -1.05), (-1.6, 1.15), (1.6, 1.15)]; leg_r, leg_len, hip_z = 0.36, 1.2, 1.05
        sections = [((-0.95, 0.2, 2.05), (0.95, 1.85, 0.42)), ((0.95, 0.2, 2.05), (0.95, 1.85, 0.42))]
        crystals = []
        for sx in (-1, 1):
            for y, h in ((-0.9, 1.0), (0.1, 1.25), (1.05, 0.95)):
                crystals.append(((sx * 0.95, y), 0.34, h))
        facets = 8
    elif form == 3:                                     # Shardhorn: four interlocked sections, angular body, big horn
        H, W, budget, tex = 6.0, 8.0, 5500, 512
        body_c, body_r = (0, 0.2, 2.6), (3.2, 3.7, 1.55)
        head_c, head_r = (0, -3.75, 2.5), (1.8, 1.45, 1.3)
        horn = (None, 0.85, 3.6, 52)
        legs = [(-2.8, -1.9), (2.8, -1.9), (-2.8, 2.1), (2.8, 2.1)]; leg_r, leg_len, hip_z = 0.65, 2.1, 1.9
        sections = [((sx * 1.55, sy * 1.6 + 0.2, 3.7), (1.45, 1.6, 0.6)) for sx in (-1, 1) for sy in (-1, 1)]
        sections.append(((0, -1.25, 4.15), (2.7, 1.9, 1.25)))           # forward shoulder hump, towers over the head
        crystals = [((0.0, -1.1), 0.62, 3.4), ((-0.75, -0.6), 0.45, 2.2), ((0.75, -0.6), 0.45, 2.2),   # central cluster on the hump
                    ((-2.3, -1.4), 0.62, 2.7), ((2.3, -1.4), 0.62, 2.7),                               # big shoulder crystals, splayed out
                    ((-1.2, 1.9), 0.38, 1.1), ((1.2, 1.9), 0.38, 1.1)]                                 # two small ones behind
        facets = 14
    else:                                               # Mountainback: huge quadruped, 4 ridges x 4 shards, enormous horn
        H, W, budget, tex = 12.0, 14.0, 9000, 1024
        body_c, body_r = (0, 0.4, 6.6), (5.4, 6.4, 3.0)
        head_c, head_r = (0, -6.6, 6.4), (3.0, 2.5, 2.3)
        horn = (None, 1.5, 7.2, 40)
        legs = [(-4.4, -3.6), (4.4, -3.6), (-4.4, 4.0), (4.4, 4.0)]; leg_r, leg_len, hip_z = 1.35, 5.4, 5.0
        sections = [((sx * 2.4, sy * 2.6 + 0.4, 9.0), (2.1, 2.5, 0.95)) for sx in (-1, 1) for sy in (-1, 1)]
        crystals = []
        for k, y in enumerate((-3.6, -1.8, 0.0, 1.8, 3.6)):          # central row: peaks over the shoulders
            crystals.append(((0.0, y + 0.4), 1.25, (4.4, 6.2, 6.6, 5.4, 3.8)[k]))
        for sx in (-1, 1):
            for k, y in enumerate((-2.7, -0.9, 0.9, 2.7)):
                crystals.append(((sx * 2.6, y + 0.4), 0.95, (3.2, 3.9, 3.6, 2.8)[k]))
        facets = 18
    parts = [ellipsoid(body_c, body_r, 40), ellipsoid(head_c, head_r, 24)]
    for (c, r) in sections:
        parts.append(ellipsoid(c, r, 24, (math.radians(-9), 0, 0)))
    if form >= 3:                                       # jagged shoulder armour: rock spikes jutting out and up
        ar, al = (0.75, 2.1) if form == 3 else (1.25, 3.6)
        for sx in (-1, 1):
            for k, (dy, dz, ang) in enumerate(((-0.45, 0.55, 48), (-0.1, 0.75, 38))):
                parts.append(cone((sx * body_r[0] * 0.82, body_c[1] + body_r[1] * dy, body_c[2] + body_r[2] * dz), ar * (1 - 0.2 * k), 0.05, al * (1 - 0.15 * k), (0, math.radians(sx * ang), 0)))
    if form >= 2:
        bw = {2: 0.32, 3: 0.4, 4: 0.46}[form]
        for sx in (-1, 1):
            b = ellipsoid((head_c[0] + 0.42 * head_r[0] * sx, head_c[1] - head_r[1] * 0.72, head_c[2] + head_r[2] * 0.62),
                          (bw * head_r[0] * 1.4, 0.3 * head_r[1], 0.17 * head_r[2]), 16)
            b.rotation_euler = (math.radians(-15), math.radians(-{2: 12, 3: 20, 4: 26}[form] * sx), 0)
            parts.append(b)
    for sx in (-1, 1):                                  # mandibles
        parts.append(cone((head_c[0] + 0.45 * head_r[0] * sx, head_c[1] - head_r[1] * 0.9, head_c[2] - head_r[2] * 0.3), 0.16 * head_r[0], 0.02, head_r[1] * 0.9, (math.radians(-80), 0, math.radians(25 * sx))))
    feet = []
    fore = {1: 1.0, 2: 1.18, 3: 1.25, 4: 1.45}[form]
    for lx, ly in legs:
        sx = 1 if lx > 0 else -1
        leg_r_base = leg_r
        leg_r = leg_r_base * (fore if ly < 0 else 1.0)
        fx = lx + leg_r * 1.4 * sx
        # thigh from the body side out/down, shin straight down, a flat foot
        parts.append(ellipsoid((lx + leg_r * 0.6 * sx, ly, hip_z), (leg_r * 1.5, leg_r * 1.3, leg_r * 1.2), 16))
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=leg_r, depth=hip_z, location=(fx, ly, hip_z / 2)); parts.append(bpy.context.object)
        parts.append(ellipsoid((fx, ly - leg_r * 0.2, leg_r * 0.4), (leg_r * 1.3, leg_r * 1.5, leg_r * 0.6), 16))
        feet.append((fx, ly))
        leg_r = leg_r_base
    rockbody = join(parts); rockbody.name = "rock"
    if facets:                                          # angular rock: plane slices on the body, in its local space
        slice_planes(rockbody, facets, rnd, 0.86, 0.98, zmin=0.1, centre=body_c)
    remesh(rockbody, W / 120.0, 2)
    displace(rockbody, "CLOUDS", 0.45 * W / 3.0, 0.035 * W, "VORONOI_F2")
    displace(rockbody, "CLOUDS", 0.12 * W / 3.0, 0.008 * W)
    bpy.ops.object.shade_smooth()
    # crystals on the shell (ray-cast down onto the top), horn crystal, eyes
    hits = surface_points(rockbody, [((x, y, H * 3), (x, y, 0)) for (x, y), r, h in crystals], 0.0)
    cobjs = []
    for (loc, nrm), ((x, y), r, h) in zip(hits, crystals):
        lean = Vector((x, y * 0.4, 0)) * (0.22 / max(1.0, W / 3.0))
        rr, hh = (r * 0.85, h * 1.25) if form >= 3 else (r, h)
        co = crystal(tuple(loc - Vector((0, 0, rr * 0.2))), rr, hh, (rnd.uniform(-0.15, 0.15) - lean.y, lean.x, 0.0 if form == 4 else rnd.uniform(0, 1.0)))
        if form == 3:                                   # cluster leans back a touch; shoulder crystals angle out hard
            co.rotation_euler = (math.radians(-10), math.radians(0 if abs(x) < 0.3 else (38 if abs(x) > 2 else 16) * (1 if x > 0 else -1)), 0.0)
        if form == 4:                                   # dorsal plates: flat blades along the spine, outer rows splay outward
            co.scale = (0.38, 1.35, 1.0)
            co.rotation_euler = (0.0, math.radians(18 * (1 if x > 0.1 else -1 if x < -0.1 else 0)), 0.0)
        cobjs.append(co)
    _, hr1, hl, hang = horn
    hd = Vector((0, -math.sin(math.radians(hang)), math.cos(math.radians(hang))))
    hbase = Vector((0, head_c[1] - head_r[1] * 0.5, head_c[2] + head_r[2] * (0.45 if form <= 2 else 0.8)))
    hb = cone(tuple(hbase + hd * hl * 0.42), hr1, hr1 * 0.06, hl, (math.radians(hang), 0, 0), 6)
    cobjs.append(hb)
    cry = join(cobjs)
    eyes = []
    for sx in (-1, 1):
        ec = (head_c[0] + 0.48 * head_r[0] * sx, head_c[1] - head_r[1] * 0.78, head_c[2] + head_r[2] * 0.3)
        if form >= 3:
            e = ellipsoid(ec, (0.34 * head_r[0], 0.2 * head_r[0], 0.12 * head_r[0]), 16)
            e.rotation_euler = (0, math.radians(-14 * sx), 0)
        else:
            e = ellipsoid(ec, (0.27 * head_r[0],) * 3, 16)
        eyes.append(e)
    # (sunk into the head, 75 %, with a thin charcoal socket: they floated in front of the face. James, 27 Oct)
    sink_eyes(rockbody, eyes, 0.75)
    sockets = join([eye_socket(e) for e in eyes])
    eye = join(eyes)
    rm = rock_material(W, 1.0 + 0.04 * form, {1: 0.024, 2: 0.026, 3: 0.03, 4: 0.04}[form], {1: (1.0, 0.62, 0.05, 1), 2: (1.0, 0.58, 0.04, 1), 3: (1.0, 0.5, 0.03, 1), 4: (1.0, 0.38, 0.02, 1)}[form])
    cm = crystal_material(H * 0.6, H * 1.3) if form <= 2 else crystal_material(H * 0.55, H * 1.45, (0.6, 0.1, 0.0, 1), (1.0, 0.6, 0.12, 1))
    gm = glow_material((1.0, 0.92, 0.35, 1), (1.0, 0.6, 0.05, 1)) if form <= 2 else glow_material((1.0, 0.55, 0.08, 1), (0.95, 0.12, 0.0, 1))
    km = flat_material("socket", (0.035, 0.03, 0.03, 1), 0.7)
    hi = build_high([(rm[0], rm[1], rockbody), (cm[0], cm[1], cry), (gm[0], gm[1], eye), (km[0], km[1], sockets)]); hi.name = f"Crunch{form}_high"
    lo = make_low(hi, f"CrunchF{form}", budget)
    bv = body_verts(lo)
    bake(f"crunch_f{form}", lo, hi, [rm, cm, gm, km], tex)
    bones = [("Root", (0, 0, 0), (0, 0, 0.3 * H / 2), None),
             ("Body", (0, body_r[1] * 0.4 + body_c[1], body_c[2]), (0, -body_r[1] * 0.4 + body_c[1], body_c[2]), "Root"),
             ("Head", (0, head_c[1] + head_r[1] * 0.6, head_c[2]), (0, head_c[1] - head_r[1] * 1.2, head_c[2]), "Body"),
             ("Shell", (0, body_c[1], body_c[2] + body_r[2] * 0.6), (0, body_c[1], body_c[2] + body_r[2] * 1.6), "Body")]
    for bn, (fx, fy) in zip(("LegFL", "LegFR", "LegBL", "LegBR"), feet):
        bones.append((bn, (fx, fy, hip_z), (fx, fy, 0.05), "Body"))
    arm, unw = rig(f"CrunchF{form}", lo, bones)
    rigid_parts(lo, bv)                                 # (eyes, sockets, crystals move solid)
    save(f"crunch_f{form}", f"CrunchF{form}", lo, arm, hi, H, unw)


for race, fn in (("squish", squish), ("crunch", crunch)):
    for f in (1, 2, 3, 4):
        key = f"{race}{f}"
        if ONLY and ONLY != key and ONLY != race:
            continue
        fn(f)
print("FORMS_OK")
