# Blender (headless) test scene: a small diorama room exported as glTF binary.
#   blender -b --factory-startup --python-exit-code 1 --python make_diorama.py -- OUT.glb
# Floor, two walls and a crate, each with its own coloured material: the same kind of
# asset a 2.5D room is made of.
import sys
import bpy

out = sys.argv[sys.argv.index("--") + 1]

bpy.ops.wm.read_factory_settings(use_empty=True)

def material(name, rgba):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = rgba
    return m

def box(name, loc, scale, mat):
    bpy.ops.mesh.primitive_cube_add(location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    o.data.materials.append(mat)
    return o

stone = material("stone", (0.36, 0.40, 0.55, 1))
wood = material("wood", (0.88, 0.69, 0.41, 1))
box("floor", (0, 0, -0.05), (4, 4, 0.05), stone)
box("wall_back", (0, 4, 1.5), (4, 0.1, 1.5), stone)
box("wall_left", (-4, 0, 1.5), (0.1, 4, 1.5), stone)
box("crate", (1, 1, 0.5), (0.5, 0.5, 0.5), wood)

bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_yup=True, export_apply=True)
print("exported", out)
