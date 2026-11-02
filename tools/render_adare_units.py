"""Real Blender render of Adare, environment platforms and existing unit art.

Run: blender -b --factory-startup -t 8 --python tools/render_adare_units.py
Characters use transparent standees, as in the game's current Sprite3D workflow;
they are not advertised as generated or rigged 3D character meshes.
"""
from pathlib import Path
import json
import math
import random
import sys
import bpy
import numpy as np
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

ROOT = Path(__file__).resolve().parents[1]
bpy.context.preferences.filepaths.save_version = 0
OUT = ROOT / 'reborn/anteprime'
OUT.mkdir(exist_ok=True, parents=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = 48
scene.cycles.use_denoising = False
scene.render.resolution_x, scene.render.resolution_y = 1920, 1080
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs[0].default_value = (.009,.016,.028,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value = .25
scene.view_settings.view_transform = 'AgX'
font = bpy.data.fonts.load(str(ROOT / 'assets/font/SairaCondensed-Bold.ttf'))
objects_to_check = []


def material(name, color, metallic=0, emission=0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color,1)
    m.use_nodes = True
    b = m.node_tree.nodes.get('Principled BSDF')
    b.inputs['Base Color'].default_value = (*color,1)
    b.inputs['Metallic'].default_value = metallic
    b.inputs['Roughness'].default_value = .37
    b.inputs['Emission Color'].default_value = (*color,1)
    b.inputs['Emission Strength'].default_value = emission
    return m


dark = material('Midnight alloy',(.016,.025,.037),.65)
gold = material('Warm brass',(.39,.24,.07),.75)
urban = material('Urban cyan',(.10,.43,.76),.3,2)
wild = material('Wild green',(.16,.65,.32),.3,1.5)
white = material('Readable warm white',(.85,.87,.76),0,1)


def planet_material(pid):
    m = material(f'Planet {pid}',(.5,.5,.5))
    b = m.node_tree.nodes.get('Principled BSDF')
    b.inputs['Roughness'].default_value = .86
    for suffix,socket in [('', 'Base Color'),('_emission','Emission Color')]:
        t = m.node_tree.nodes.new('ShaderNodeTexImage')
        t.image = bpy.data.images.load(str(ROOT / f'assets_reborn/pianeti/{pid}{suffix}.png'))
        m.node_tree.links.new(t.outputs['Color'],b.inputs[socket])
    b.inputs['Emission Strength'].default_value = .18
    t = m.node_tree.nodes.new('ShaderNodeTexImage')
    t.image = bpy.data.images.load(str(ROOT / f'assets_reborn/pianeti/{pid}_normal.png'))
    t.image.colorspace_settings.name = 'Non-Color'
    normal = m.node_tree.nodes.new('ShaderNodeNormalMap')
    normal.inputs['Strength'].default_value = .28
    m.node_tree.links.new(t.outputs['Color'], normal.inputs['Color'])
    m.node_tree.links.new(normal.outputs['Normal'], b.inputs['Normal'])
    return m


def sphere(name, pos, radius, mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=128, ring_count=64, radius=radius, location=pos)
    o = bpy.context.object
    o.name = name
    for p in o.data.polygons:p.use_smooth=True
    o.data.materials.append(mat)
    return o


def cylinder(name, pos, radius, depth, mat):
    bpy.ops.mesh.primitive_cylinder_add(vertices=96, radius=radius, depth=depth, location=pos)
    o=bpy.context.object;o.name=name;o.data.materials.append(mat)
    bevel=o.modifiers.new('Soft machined edges','BEVEL');bevel.width=.05;bevel.segments=3
    o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
    return o


def torus(name,pos,radius,mat,minor=.025):
    bpy.ops.mesh.primitive_torus_add(major_radius=radius,minor_radius=minor,location=pos)
    o=bpy.context.object;o.name=name;o.data.materials.append(mat)
    return o


def line(name,a,b,mat,width=.018):
    curve=bpy.data.curves.new(name,'CURVE');curve.dimensions='3D';curve.bevel_depth=width;curve.bevel_resolution=3
    spline=curve.splines.new('POLY');spline.points.add(1)
    spline.points[0].co=(*a,1);spline.points[1].co=(*b,1)
    obj=bpy.data.objects.new(name,curve);scene.collection.objects.link(obj);obj.data.materials.append(mat)
    return obj


def text(label,pos,size=.23,mat=white):
    c=bpy.data.curves.new(label,'FONT');c.body=label;c.font=font;c.align_x='CENTER';c.size=size;c.extrude=.001
    o=bpy.data.objects.new(label,c);scene.collection.objects.link(o);o.location=pos
    o.rotation_euler=scene.camera.rotation_euler;o.data.materials.append(mat)
    return o


def standee(name,key,pos,height,character=True):
    path=ROOT / ('assets_reborn/figure_intere' if character else 'assets_reborn/pedine') / (key+'.png')
    image=bpy.data.images.load(str(path));width=height*image.size[0]/image.size[1]
    center=Vector(pos);normal=Vector(scene.camera.location)-center;normal.z=0;normal.normalize()
    right=Vector((0,0,1)).cross(normal);up=Vector((0,0,1))
    pts=[center-right*width/2,center+right*width/2,center+right*width/2+up*height,center-right*width/2+up*height]
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(pts,[],[(0,1,2,3)]);mesh.uv_layers.new()
    for i,uv in enumerate([(0,0),(1,0),(1,1),(0,1)]):mesh.uv_layers.active.data[i].uv=uv
    obj=bpy.data.objects.new(name,mesh);scene.collection.objects.link(obj)
    m=bpy.data.materials.new(name);m.use_nodes=True;n=m.node_tree.nodes;n.clear()
    t=n.new('ShaderNodeTexImage');t.image=image
    transparent=n.new('ShaderNodeBsdfTransparent');em=n.new('ShaderNodeEmission');em.inputs['Strength'].default_value=.85
    mix=n.new('ShaderNodeMixShader');out=n.new('ShaderNodeOutputMaterial')
    m.node_tree.links.new(t.outputs['Color'],em.inputs['Color'])
    m.node_tree.links.new(t.outputs['Alpha'],mix.inputs[0]);m.node_tree.links.new(transparent.outputs[0],mix.inputs[1]);m.node_tree.links.new(em.outputs[0],mix.inputs[2]);m.node_tree.links.new(mix.outputs[0],out.inputs[0])
    obj.data.materials.append(m)
    cylinder(name+' base',(pos[0],pos[1],pos[2]-.035),.28,.07,gold)
    objects_to_check.append((name,obj,'personaggio' if character else 'unita'))
    return obj


def camera(pos,target,scale):
    bpy.ops.object.camera_add(location=pos)
    cam=bpy.context.object;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.type='ORTHO';cam.data.ortho_scale=scale;scene.camera=cam
    return cam


def light(name,pos,power,color,size=6):
    bpy.ops.object.light_add(type='AREA',location=pos)
    o=bpy.context.object;o.name=name;o.data.energy=power;o.data.color=color;o.data.shape='DISK';o.data.size=size
    o.rotation_euler=(Vector((0,0,1.5))-o.location).to_track_quat('-Z','Y').to_euler()


cam=camera((0,-18,11),(0,0,1.9),14.7)
light('Warm key',(-7,-8,12),2200,(1,.94,.85),8)
light('Cool fill',(7,-3,8),500,(.75,.83,1),7)
light('Rim',(0,7,8),1000,(.50,.70,1),5)
center=Vector((0,1.25,2.15));radius=2.3
globe=sphere('Adare · Urban4 Wild5',center,radius,planet_material(142))
# Source UV sphere is rotated to present both terrain regions in this composition.
globe.rotation_euler[2]=.55
atmosphere=bpy.data.materials.new('Thin atmosphere');atmosphere.use_nodes=True
n=atmosphere.node_tree.nodes;n.clear();lw=n.new('ShaderNodeFresnel');lw.inputs['IOR'].default_value=1.04;power=n.new('ShaderNodeMath');power.operation='POWER';power.inputs[1].default_value=2;em=n.new('ShaderNodeEmission');em.inputs[0].default_value=(.08,.32,.6,1);em.inputs[1].default_value=.4
tr=n.new('ShaderNodeBsdfTransparent');mix=n.new('ShaderNodeMixShader');out=n.new('ShaderNodeOutputMaterial')
atmosphere.node_tree.links.new(lw.outputs['Fac'],power.inputs[0]);atmosphere.node_tree.links.new(power.outputs[0],mix.inputs[0]);atmosphere.node_tree.links.new(tr.outputs[0],mix.inputs[1]);atmosphere.node_tree.links.new(em.outputs[0],mix.inputs[2]);atmosphere.node_tree.links.new(mix.outputs[0],out.inputs[0])
sphere('Atmosphere',center,radius*1.012,atmosphere)

bpy.context.view_layer.update()
mask_image=bpy.data.images.load(str(ROOT/'assets_reborn/pianeti/142_ambienti.png'))
mask_image.colorspace_settings.name='Non-Color'
mask_pixels=np.array(mask_image.pixels[:],dtype=np.float32).reshape(mask_image.size[1],mask_image.size[0],4)
anchors=[]
def surface_anchor(kind,target):
    color=np.array((64,122,235) if kind=='urbano' else (77,168,77))/255
    candidates=[]
    rotation=globe.matrix_world.to_3x3()
    for poly in globe.data.polygons:
        coords=[globe.data.uv_layers.active.data[i].uv for i in poly.loop_indices]
        u=sum(v.x for v in coords)/len(coords);v=sum(v.y for v in coords)/len(coords)
        pixel=mask_pixels[min(mask_image.size[1]-1,int(v*mask_image.size[1])),min(mask_image.size[0]-1,int(u*mask_image.size[0])),:3]
        if np.max(np.abs(pixel-color))>.01:continue
        normal=(rotation@poly.center).normalized()
        if normal.y>=-.25:continue
        candidates.append((normal.dot(target),normal,u,v))
    if not candidates:raise RuntimeError('No visible surface anchor for '+kind)
    _,normal,u,v=max(candidates,key=lambda x:x[0])
    anchors.append({'ambiente':kind,'uv':[u,v],'maschera_verificata':True})
    return center+normal*radius

platforms=[]
for x,mat,title in [(-4.4,urban,'URBANO · 4'),(4.4,wild,'SELVAGGIO · 5')]:
    p=Vector((x,-.65,.35));platforms.append(p)
    cylinder(title+' lower',p,1.72,.18,dark)
    cylinder(title+' deck',p+Vector((0,0,.11)),1.61,.06,dark)
    torus(title+' rim',p+Vector((0,0,.17)),1.63,mat,.035)
    torus(title+' inner',p+Vector((0,0,.17)),1.47,gold,.012)
    # Distinct visible footprint at the surface, with a lit leader to the platform.
    direction=Vector(((-.72 if x<0 else .72),-.65,-.12)).normalized()
    anchor=surface_anchor('urbano' if x<0 else 'selvaggio',direction)
    endpoint=p+Vector((1.65 if x<0 else -1.65,0,.15))
    elbow=(anchor+endpoint)/2;elbow.z+=.2
    line(title+' leader A',anchor,elbow,mat);line(title+' leader B',elbow,endpoint,mat)
    sphere(title+' surface pin',anchor,.065,mat)
    sphere(title+' docking pin',endpoint,.045,mat)
    text(title,(x,-2.52,.05),.29,mat)

standee('Linea imperiale','imp_linea',(-5.12,-.80,.56),1.08,False)
standee('Milizia imperiale','imp_milizia',(-3.72,-.80,.56),1.08,False)
text('LINEA ×2',(-5.12,-1.93,.64),.22)
text('MILIZIA ×1',(-3.72,-1.93,.64),.22)
standee('Zina Adora','pg_zina_adora',(3.82,-1.05,.56),1.67)
standee('Adam Starlight','pg_adam_starlight',(5.03,-1.05,.56),1.67)
standee('Truppe ribelli','rib_selvaggio_23',(4.42,.60,.56),.86,False)
text('ZINA',(3.82,-1.93,.64),.22)
text('ADAM',(5.03,-1.93,.64),.22)
text('RIBELLI ×2',(4.42,.70,1.61),.20)
text('ADARE',(0,1.0,5.04),.38)
text('9 environ · Urbano 44,44% · Selvaggio 55,56%',(0,.75,4.62),.19)
text('Schieramento dimostrativo · figure sagomate su piattaforme', (0,-3.0,-.65), .18)

# PDB strength 1 is represented by two orbital stations. These are diagrammatic
# strength markers, not additional independent combat units.
pdb_status=material('PDB operational green',(.08,.75,.23),.1,2)
pdb_hull=material('PDB titanium hull',(.44,.49,.54),.8)
pdb_orbit=torus('PDB orbit',center,2.95,pdb_status,.018)
pdb_orbit.rotation_euler.x=math.radians(20)
def station(name,angle):
    p=center+Vector((2.95*math.cos(angle),2.95*math.sin(angle)*math.cos(math.radians(20)),2.95*math.sin(angle)*math.sin(math.radians(20))))
    bpy.ops.mesh.primitive_cube_add(size=1,location=p)
    core=bpy.context.object;core.name=name;core.scale=(.22,.16,.14);core.data.materials.append(pdb_hull)
    bevel=core.modifiers.new('Beveled module','BEVEL');bevel.width=.12;bevel.segments=3
    for side in [-1,1]:
        bpy.ops.mesh.primitive_cube_add(size=1,location=p+Vector((side*.34,0,0)))
        wing=bpy.context.object;wing.name=name+' panel';wing.scale=(.23,.24,.025);wing.data.materials.append(pdb_status)
    sphere(name+' antenna',p+Vector((0,0,.22)),.07,pdb_status)
    line(name+' mast',p,p+Vector((0,0,.22)),pdb_hull,.018)
    text('L1',p+Vector((0,0,.38)),.20,pdb_status)
station('PDB A',.12)
station('PDB B',math.pi+.12)
pdb_label=text('PDB · FORZA 1 · 2 BASI · OPERATIVA',(0,-1.3,-.18),.25,pdb_status)

# Stable background stars, kept away from platform labels.
rng=random.Random(142)
star_mat=material('Distant stars',(.6,.7,.85),0,2)
for i in range(95):
    x=rng.uniform(-12,12);z=rng.uniform(-3,10)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=rng.uniform(.008,.021),location=(x,10,z))
    bpy.context.object.data.materials.append(star_mat)

bpy.context.view_layer.update()
checks=[]
for name,obj,kind in objects_to_check:
    points=[world_to_camera_view(scene,cam,obj.matrix_world@Vector(v)) for v in obj.bound_box]
    xs=[p.x*1920 for p in points];ys=[p.y*1080 for p in points]
    width,height=max(xs)-min(xs),max(ys)-min(ys)
    checks.append({'nome':name,'tipo':kind,'larghezza_px_1920':round(width,1),
                   'altezza_px_1920':round(height,1),'altezza_px_960':round(height/2,1),
                   'interamente_inquadrato':all(0<=p.x<=1 and 0<=p.y<=1 and p.z>0 for p in points)})
(ROOT/'reborn/verifica_visibilita_adare.json').write_text(json.dumps({
    'metodo':'projected quad bounds in actual orthographic Blender camera; visual occlusion checked separately',
    'immagine':[1920,1080],'elementi':checks,
    'ancore_superficie':anchors,
    'nota':'Bounding boxes include transparent art padding; visibility is not a user recognition study. Names are short labels; full detail requires close view.'},ensure_ascii=False,indent=2)+'\n')
scene.render.filepath=str(OUT/'adare_unita_3d.png')
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'reborn/modelli/adare_unita.blend'))
bpy.ops.render.render(write_still=True)
if '--pdb-only' in sys.argv:
    pdb_status.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.8,.03,.02,1)
    pdb_status.node_tree.nodes['Principled BSDF'].inputs['Emission Color'].default_value=(.8,.03,.02,1)
    pdb_label.data.body='PDB · FORZA 1 · 2 BASI · DOWN — ROTAZIONE FERMA'
    scene.render.filepath=str(OUT/'adare_unita_pdb_down.png')
    bpy.ops.render.render(write_still=True)
    print('RENDERED PDB UP and DOWN with identical station angles')
    sys.exit(0)
# Produce a real secondary camera, not an AI reconstruction, for the detail view.
cam.location=(4.4,-8,5.8);cam.rotation_euler=(Vector((4.4,-.4,1))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=4.7
scene.render.resolution_x,scene.render.resolution_y=1280,960
scene.render.filepath=str(OUT/'adare_unita_dettaglio.png')
bpy.ops.render.render(write_still=True)
# A common orthographic camera and coplanar centers preserve true size ratios.
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
cam=camera((0,-18,8),(0,0,1.4),16)
light('Scale key',(-7,-8,12),2200,(1,.88,.7),8)
light('Scale fill',(7,-3,9),1400,(.5,.75,1),7)
for pid,name,total,x in [(352,'KELTA',2,-4.7),(142,'ADARE',9,-.4),(432,'SOLVIA',12,4.85)]:
    r=2.3*math.sqrt(total/9)
    sphere(name,(x,0,1.2),r,planet_material(pid))
    text(name,(x,-1.3,-1.7),.29)
    text(f'{total} environ · r {r:.2f}',(x,-1.3,-2.1),.20)
text('SUPERFICIE PROPORZIONALE ALLA SOMMA DEGLI ENVIRON',(0,0,4.8),.25)
scene.render.resolution_x,scene.render.resolution_y=1920,1080
scene.render.filepath=str(OUT/'scala_pianeti_3d.png')
bpy.ops.render.render(write_still=True)
print('RENDERED Adare with units, detail and calibrated planet scale')
