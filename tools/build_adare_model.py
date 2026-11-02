"""Run with Blender --background --factory-startup --python this_file.

Exports an actual textured UV sphere with the weighted Adare surface and
night lights, portable to Godot, Blender and glTF viewers. No game integration.
"""
from pathlib import Path
import bpy

ROOT = Path(__file__).resolve().parents[1]
TEXTURES = ROOT / 'assets_reborn/pianeti'
OUT = ROOT / 'reborn/modelli/adare.glb'
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.mesh.primitive_uv_sphere_add(segments=128, ring_count=64, radius=1)
obj = bpy.context.object
obj.name = 'Adare_Urban4_Wild5_Surface9'
for poly in obj.data.polygons:
    poly.use_smooth = True
mat = bpy.data.materials.new('Adare_surface_weighted_environments')
mat.use_nodes = True
nodes, links = mat.node_tree.nodes, mat.node_tree.links
bsdf = nodes.get('Principled BSDF')
bsdf.inputs['Roughness'].default_value = .82
bsdf.inputs['Metallic'].default_value = .05
for suffix, input_name, colorspace in [('', 'Base Color', 'sRGB'),
                                      ('_emission', 'Emission Color', 'sRGB')]:
    tex = nodes.new('ShaderNodeTexImage')
    tex.image = bpy.data.images.load(str(TEXTURES / ('142' + suffix + '.png')))
    tex.image.colorspace_settings.name = colorspace
    links.new(tex.outputs['Color'], bsdf.inputs[input_name])
bsdf.inputs['Emission Strength'].default_value = .45
tex = nodes.new('ShaderNodeTexImage')
tex.image = bpy.data.images.load(str(TEXTURES / '142_normal.png'))
tex.image.colorspace_settings.name = 'Non-Color'
normal = nodes.new('ShaderNodeNormalMap')
normal.inputs['Strength'].default_value = .7
links.new(tex.outputs['Color'], normal.inputs['Color'])
links.new(normal.outputs['Normal'], bsdf.inputs['Normal'])
obj.data.materials.append(mat)
obj['surface_units'] = 9
obj['urban_fraction'] = 4 / 9
obj['wild_fraction'] = 5 / 9
obj['radius_rule'] = 'sqrt(sum(environment_sizes)/9)'
OUT.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(OUT), export_format='GLB',
                          use_selection=True, export_extras=True,
                          export_yup=True, export_image_format='AUTO')
print('EXPORTED', OUT)
