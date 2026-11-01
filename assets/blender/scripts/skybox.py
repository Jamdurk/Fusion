# Alien Fusion: the Moon skybox (6 faces for a Roblox Sky), rendered in Blender.
#   blender --background --factory-startup --python skybox.py -- <out_dir> <debug|final> [size]
# Faces are named by the Roblox direction they look at: Lf=+X, Rt=-X, Up=+Y, Dn=-Y, Bk=+Z, Ft=-Z (Roblox axes, measured).
# Blender is Z-up: Roblox (x, y, z) = Blender (x, -z, y)... here we simply build the cameras in "Roblox space":
# Blender X = Roblox X, Blender Z = Roblox Y, Blender -Y = Roblox Z.
# debug: a direction-coloured latitude/longitude grid with face letters, to check seams + orientation in Studio.
# final: black space, real-looking star field (sizes, a few tinted), a faint galactic band, and the Earth.
import bpy, math, os, sys
from mathutils import Vector, Euler

argv = sys.argv[sys.argv.index("--") + 1:]
out, mode = argv[0], argv[1]
SIZE = int(argv[2]) if len(argv) > 2 else 1024
os.makedirs(out, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = 64
sc.render.resolution_x = sc.render.resolution_y = SIZE
sc.view_settings.view_transform = "Standard"
sc.render.film_transparent = False

world = bpy.data.worlds.new("space"); sc.world = world
nt = world.node_tree
for n in list(nt.nodes):
    nt.nodes.remove(n)
outw = nt.nodes.new("ShaderNodeOutputWorld")
bg = nt.nodes.new("ShaderNodeBackground"); nt.links.new(bg.outputs[0], outw.inputs[0])
tc = nt.nodes.new("ShaderNodeTexCoord")


def m(op, a, b=None):
    n = nt.nodes.new("ShaderNodeMath"); n.operation = op
    for i, v in enumerate((a, b)):
        if v is None:
            continue
        if isinstance(v, (int, float)):
            n.inputs[i].default_value = v
        else:
            nt.links.new(v, n.inputs[i])
    return n.outputs[0]


if mode == "debug":
    # colour = |direction| per axis, + grid lines every 15 degrees, so seams and rotations are obvious
    sep = nt.nodes.new("ShaderNodeSeparateXYZ"); nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    norm = nt.nodes.new("ShaderNodeVectorMath"); norm.operation = "NORMALIZE"; nt.links.new(tc.outputs["Generated"], norm.inputs[0])
    absn = nt.nodes.new("ShaderNodeVectorMath"); absn.operation = "MULTIPLY_ADD"; nt.links.new(norm.outputs[0], absn.inputs[0]); absn.inputs[1].default_value = (0.5, 0.5, 0.5); absn.inputs[2].default_value = (0.5, 0.5, 0.5)
    # lines: grid on the direction via a 3D checker-ish sine product
    s2 = nt.nodes.new("ShaderNodeSeparateXYZ"); nt.links.new(norm.outputs[0], s2.inputs[0])
    lat = m("ARCSINE", s2.outputs[2])                    # Blender z = Roblox up
    lon = m("ARCTAN2", s2.outputs[1], s2.outputs[0])
    gl = m("LESS_THAN", m("ABSOLUTE", m("SINE", m("MULTIPLY", lat, 12.0))), 0.06)
    gn = m("LESS_THAN", m("ABSOLUTE", m("SINE", m("MULTIPLY", lon, 12.0))), 0.06)
    lines = m("MAXIMUM", gl, gn)
    mix = nt.nodes.new("ShaderNodeMix"); mix.data_type = "RGBA"
    nt.links.new(lines, mix.inputs[0]); nt.links.new(absn.outputs[0], mix.inputs[6]); mix.inputs[7].default_value = (0, 0, 0, 1)
    nt.links.new(mix.outputs[2], bg.inputs["Color"])
else:
    # stars: Voronoi on the view direction (3D), tiny bright points with random size + slight colour, density varies
    dirv = nt.nodes.new("ShaderNodeVectorMath"); dirv.operation = "NORMALIZE"; nt.links.new(tc.outputs["Generated"], dirv.inputs[0])

    def stars(scale, thresh, bright):
        v = nt.nodes.new("ShaderNodeTexVoronoi"); v.inputs["Scale"].default_value = scale; v.inputs["Randomness"].default_value = 1.0
        nt.links.new(dirv.outputs[0], v.inputs["Vector"])
        sepc = nt.nodes.new("ShaderNodeSeparateColor"); nt.links.new(v.outputs["Color"], sepc.inputs[0])
        r = m("MULTIPLY", thresh, m("ADD", 0.25, m("POWER", sepc.outputs[0], 3.0)))   # most stars tiny, a few big
        core = m("MAXIMUM", m("SUBTRACT", 1.0, m("DIVIDE", v.outputs["Distance"], r)), 0.0)
        core = m("POWER", core, 2.2)
        return m("MULTIPLY", core, m("MULTIPLY", bright, m("ADD", 0.2, sepc.outputs[1]))), sepc.outputs[2]

    s1, tint = stars(120.0, 0.06, 3.0)
    s2_, _ = stars(320.0, 0.05, 1.4)
    s3, _ = stars(40.0, 0.035, 9.0)                      # the rare bright ones
    st = m("ADD", m("ADD", s1, s2_), s3)
    # faint galactic band: a tilted great circle with noise
    tilt = nt.nodes.new("ShaderNodeVectorRotate"); tilt.rotation_type = "EULER_XYZ"
    tilt.inputs["Rotation"].default_value = (math.radians(62), math.radians(18), 0)
    nt.links.new(dirv.outputs[0], tilt.inputs["Vector"])
    sb = nt.nodes.new("ShaderNodeSeparateXYZ"); nt.links.new(tilt.outputs[0], sb.inputs[0])
    band = m("EXPONENT", m("MULTIPLY", m("POWER", sb.outputs[2], 2.0), -18.0))
    nz = nt.nodes.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 4.0; nz.inputs["Detail"].default_value = 8
    nt.links.new(dirv.outputs[0], nz.inputs["Vector"])
    band = m("MULTIPLY", band, m("MULTIPLY", m("POWER", nz.outputs["Fac"], 2.5), 0.10))
    dense = m("MULTIPLY", band, 9.0)                    # more small stars inside the band
    st = m("ADD", st, m("MULTIPLY", s2_, dense))
    col = nt.nodes.new("ShaderNodeCombineColor")
    tintw = m("MULTIPLY", m("MULTIPLY", m("SUBTRACT", tint, 0.5), 0.5), st)   # star colour only on the stars
    nt.links.new(m("ADD", m("ADD", st, band), tintw), col.inputs[0])
    nt.links.new(m("ADD", st, m("MULTIPLY", band, 1.02)), col.inputs[1])
    nt.links.new(m("ADD", m("ADD", st, m("MULTIPLY", band, 1.12)), m("MULTIPLY", tintw, -1.0)), col.inputs[2])
    nt.links.new(col.outputs[0], bg.inputs["Color"])

    # the Earth: a sphere far away, procedural continents + clouds, lit by the sun from the side (a crescent-and-a-half)
    R, D = 190.0, 2000.0
    # direction: Roblox (+Z toward base B side wall? ) -> low over the arena's long axis, 16 degrees up
    yaw, pitch = math.radians(-80), math.radians(18)   # Blender yaw -90 = Roblox +Z (the Boulder Plain side)
    dx, dy, dz = math.cos(pitch) * math.cos(yaw), math.cos(pitch) * math.sin(yaw), math.sin(pitch)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=R, segments=96, ring_count=48, location=(dx * D, dy * D, dz * D))
    earth = bpy.context.object
    bpy.ops.object.shade_smooth()
    em = bpy.data.materials.new("earth"); em.use_nodes = True
    t = em.node_tree; b = t.nodes["Principled BSDF"]
    ob = t.nodes.new("ShaderNodeTexCoord")
    land = t.nodes.new("ShaderNodeTexNoise"); land.inputs["Scale"].default_value = 2.2; land.inputs["Detail"].default_value = 10; land.inputs["Roughness"].default_value = 0.6
    t.links.new(ob.outputs["Object"], land.inputs["Vector"])
    lr = t.nodes.new("ShaderNodeValToRGB"); t.links.new(land.outputs["Fac"], lr.inputs[0])
    e = lr.color_ramp.elements
    e[0].position, e[0].color = 0.5, (0.01, 0.07, 0.32, 1)
    e[1].position, e[1].color = 0.56, (0.09, 0.16, 0.06, 1)
    ee = e.new(0.66); ee.color = (0.30, 0.24, 0.13, 1)
    cl = t.nodes.new("ShaderNodeTexNoise"); cl.inputs["Scale"].default_value = 4.5; cl.inputs["Detail"].default_value = 12; cl.inputs["Distortion"].default_value = 1.2
    t.links.new(ob.outputs["Object"], cl.inputs["Vector"])
    cr = t.nodes.new("ShaderNodeValToRGB"); t.links.new(cl.outputs["Fac"], cr.inputs[0])
    cr.color_ramp.elements[0].position = 0.6; cr.color_ramp.elements[1].position = 0.74
    mixc = t.nodes.new("ShaderNodeMix"); mixc.data_type = "RGBA"
    t.links.new(cr.outputs["Color"], mixc.inputs[0]); t.links.new(lr.outputs["Color"], mixc.inputs[6]); mixc.inputs[7].default_value = (0.9, 0.92, 0.95, 1)
    t.links.new(mixc.outputs[2], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.6
    # thin blue atmosphere rim
    lw = t.nodes.new("ShaderNodeLayerWeight"); lw.inputs["Blend"].default_value = 0.25
    em_ = t.nodes.new("ShaderNodeEmission"); em_.inputs["Color"].default_value = (0.25, 0.5, 1.0, 1)
    rp = t.nodes.new("ShaderNodeMath"); rp.operation = "POWER"; t.links.new(lw.outputs["Facing"], rp.inputs[0]); rp.inputs[1].default_value = 4
    rpm = t.nodes.new("ShaderNodeMath"); rpm.operation = "MULTIPLY"; t.links.new(rp.outputs[0], rpm.inputs[0]); rpm.inputs[1].default_value = 1.6
    t.links.new(rpm.outputs[0], em_.inputs["Strength"])
    add = t.nodes.new("ShaderNodeAddShader")
    t.links.new(b.outputs[0], add.inputs[0]); t.links.new(em_.outputs[0], add.inputs[1])
    t.links.new(add.outputs[0], t.nodes["Material Output"].inputs["Surface"])
    earth.data.materials.append(em)
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN")); sc.collection.objects.link(sun)
    sun.data.energy = 5.0
    # light the Earth from the side opposite the camera a bit: a gibbous Earth
    # light from beside the viewer: a gibbous Earth (mostly lit, a dark limb on one side)
    ldir = Vector((dx, dy, dz)); ldir.rotate(Euler((0, 0, math.radians(-55))))
    sun.rotation_euler = ldir.to_track_quat("-Z", "Y").to_euler()

# six cameras in Roblox space
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam")); sc.collection.objects.link(cam); sc.camera = cam
cam.data.angle = math.radians(90); cam.data.clip_end = 10000
sc.render.pixel_aspect_x = sc.render.pixel_aspect_y = 1


def look(direction, up):
    d = Vector(direction).normalized(); u = Vector(up).normalized()
    r = d.cross(u).normalized(); u2 = r.cross(d)
    from mathutils import Matrix
    mat = Matrix((r, u2, -d)).transposed()
    return mat.to_euler()


# Roblox dir -> Blender dir: (x, y, z)_rbx -> (x, -z, y)_bl
def rb(x, y, z):
    return (x, -z, y)


faces = {   # measured in Studio 27 Oct 2026 with solid-colour test faces (see BUILD-LOG): Lf looks +X, Rt -X
    "Lf": (rb(1, 0, 0), rb(0, 1, 0)),
    "Rt": (rb(-1, 0, 0), rb(0, 1, 0)),
    "Bk": (rb(0, 0, 1), rb(0, 1, 0)),
    "Ft": (rb(0, 0, -1), rb(0, 1, 0)),
    "Up": (rb(0, 1, 0), rb(1, 0, 0)),     # image top = +X, image left = +Z
    "Dn": (rb(0, -1, 0), rb(-1, 0, 0)),   # image top = -X, image left = +Z
}
for name, (d, u) in faces.items():
    cam.rotation_euler = look(d, u)
    sc.render.filepath = os.path.join(out, f"sky_{mode}_{name}.png")
    bpy.ops.render.render(write_still=True)
print("SKY_OK", mode)
