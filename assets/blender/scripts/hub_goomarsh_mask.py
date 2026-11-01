# Goo Marsh: bake a UV-island MASK of chosen objects inside a shared atlas (31 Oct 2026). Used to split the "mush"
# atlas into two images on the SAME UV layout (Roblox kept rendering the uploaded mush colour map as blank grey, twice:
# likely an image-moderation reject, so the stalks and the caps/gills go up as separate, different-looking images).
#   blender -b <assets>\blender\hub\goomarsh_tex.blend --python hub_goomarsh_mask.py -- <out.png> <size> <obj> [<obj> ...]
import bpy, sys
args = sys.argv[sys.argv.index("--") + 1:]
out, size, names = args[0], int(args[1]), args[2:]
sc = bpy.context.scene; sc.render.engine = "CYCLES"; sc.cycles.samples = 1; sc.cycles.device = "CPU"
img = bpy.data.images.new("mask", size, size); img.generated_color = (0, 0, 0, 1)
m = bpy.data.materials.new("maskmat"); m.use_nodes = True; nt = m.node_tree
for n in list(nt.nodes):
    if n.type != "OUTPUT_MATERIAL": nt.nodes.remove(n)
em = nt.nodes.new("ShaderNodeEmission"); em.inputs["Color"].default_value = (1, 1, 1, 1)
nt.links.new(em.outputs[0], next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL").inputs["Surface"])
tn = nt.nodes.new("ShaderNodeTexImage"); tn.image = img; nt.nodes.active = tn
bpy.ops.object.select_all(action="DESELECT")
for n in names:
    o = bpy.data.objects[n]; o.data.materials.clear(); o.data.materials.append(m); o.select_set(True)
    bpy.context.view_layer.objects.active = o
bpy.ops.object.bake(type="EMIT", margin=6, use_clear=False)
img.filepath_raw = out; img.file_format = "PNG"; img.save()
print("MASK", out)
