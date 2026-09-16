"""Run explicitly with Blender --background --python; creates an original prop study.
No network access, external textures, add-ons, or packages are required.
"""
import math
from pathlib import Path
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'art/gauntlet'
OUT.mkdir(parents=True, exist_ok=True)
(OUT / 'exports').mkdir(exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'


def material(name, color, metal=0, rough=.5, glow=0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    m.use_backface_culling = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Metallic'].default_value = metal
    p.inputs['Roughness'].default_value = rough
    if glow:
        p.inputs['Emission Color'].default_value = (*color, 1)
        p.inputs['Emission Strength'].default_value = glow
    return m

wood = material('Smoked walnut', (.12,.047,.022))
wood_light = material('Walnut end grain', (.20,.088,.037))
iron = material('Blue black iron', (.055,.085,.095), .8, .32)
brass = material('Worn brass', (.55,.30,.09), .75, .3)
teal = material('Glazed jade ceramic', (.018,.29,.25), .25, .22)
stone = material('Cool limestone', (.25,.32,.34), 0, .8)
cork = material('Cork', (.28,.15,.065), 0, .9)
fire = material('Amber crystal', (1,.20,.018), .1, .26, 1.8)


def finish(obj, name, mat, bevel=0):
    obj.name = name
    obj.data.materials.append(mat)
    if bevel:
        mod = obj.modifiers.new('Soft crafted edges', 'BEVEL')
        mod.width = bevel
        mod.segments = 3
        mod = obj.modifiers.new('Weighted corner normals', 'WEIGHTED_NORMAL')
        mod.keep_sharp = True
    return obj


def box(name, location, size, mat, bevel=.025):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    o = bpy.context.object
    o.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(o, name, mat, bevel)


def lathe(name, profile, mat, segments=16):
    verts = [(r*math.cos(i*math.tau/segments), r*math.sin(i*math.tau/segments), z)
             for r,z in profile for i in range(segments)]
    faces = []
    for row in range(len(profile)-1):
        for i in range(segments):
            a = row*segments+i
            b = row*segments+(i+1)%segments
            faces.append((a,b,b+segments,a+segments))
    faces += [tuple(reversed(range(segments))),
              tuple((len(profile)-1)*segments+i for i in range(segments))]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(obj)
    return finish(obj, name, mat, .008)


def lid(name, x0, x1, radius, mat):
    # Closed half-cylinder; long axis is X, front faces -Y.
    ring = [(radius*math.cos(i*math.pi/12), .70+radius*math.sin(i*math.pi/12)) for i in range(13)]
    verts = [(x,y,z) for x in (x0,x1) for y,z in ring]
    faces = [(i,i+1,i+14,i+13) for i in range(12)]
    faces += [tuple(range(12,-1,-1)), tuple(range(13,26)), (0,13,25,12)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(obj)
    return finish(obj, name, mat, .01)


def chest():
    for i in range(5):
        box('Walnut plank', ((i-2)*.265,0,.40), (.255,.80,.58), wood if i%2 else wood_light)
    box('Lower rim', (0,0,.12), (1.43,.91,.14), iron)
    box('Upper rim', (0,0,.70), (1.44,.91,.10), iron)
    lid('Domed walnut lid', -.67,.67,.40,wood)
    for x in (-.52,.52):
        lid('Curved brass strap', x-.055,x+.055,.423,brass)
        for y in (-.426,.426):
            box('Vertical strap', (x,y,.40), (.11,.045,.57), brass,.01)
            for z in (.21,.55):
                bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=4, radius=.028, location=(x,y*1.065,z))
                finish(bpy.context.object, 'Hammered rivet', brass)
    box('Lock plate', (0,-.47,.66), (.23,.09,.28), brass)
    box('Keyhole', (0,-.519,.66), (.035,.012,.075), iron,.006)
    for x in (-.52,.52):
        for y in (-.31,.31):
            box('Foot', (x,y,.06), (.22,.22,.12), iron)


def potion():
    lathe('Faceted jade flask', [(.13,0),(.25,.06),(.34,.26),(.32,.47),(.17,.65),(.13,.69),(.13,.86)], teal)
    lathe('Brass neck collar', [(.145,.70),(.16,.72),(.16,.78),(.145,.80)], brass)
    lathe('Cork stopper', [(.113,.81),(.12,.91),(.11,.95)], cork,12)
    lathe('Foot ring', [(.15,.02),(.23,.055),(.235,.095)], brass)
    o = box('Diamond medallion', (0,-.331,.34), (.18,.045,.18), brass,.02)
    o.rotation_euler.y = math.pi/4
    o = box('Jade inset', (0,-.36,.34), (.09,.02,.09), teal,.01)
    o.rotation_euler.y = math.pi/4


def brazier():
    box('Stone plinth', (0,0,.075), (.78,.78,.15), stone,.045)
    box('Stepped base', (0,0,.18), (.60,.60,.09), stone)
    lathe('Fluted pedestal', [(.23,.22),(.16,.31),(.14,.66),(.24,.75)], iron,12)
    lathe('Brass pedestal ring', [(.17,.32),(.18,.34),(.18,.40),(.165,.42)], brass)
    lathe('Fire bowl', [(.22,.70),(.39,.84),(.43,.94),(.38,.95),(.33,.84),(.16,.79)], iron)
    lathe('Brass bowl rim', [(.426,.91),(.44,.93),(.44,.97),(.41,.98)], brass)
    for i in range(5):
        angle = i*math.tau/5
        o = lathe('Ember crystal', [(.06,.81),(.115,.91),(.06,1.16),(.005,1.40 if i==0 else 1.24)], fire,5)
        o.location = (.19*math.cos(angle),.19*math.sin(angle),0)
        o.rotation_euler = (.1*math.cos(angle),.13*math.sin(angle),angle)


assets = []
for name, builder in [('VaultChest',chest),('JadePotion',potion),('EmberBrazier',brazier)]:
    before = set(bpy.data.objects)
    builder()
    objects = list(set(bpy.data.objects)-before)
    root = bpy.data.objects.new(name, None)
    scene.collection.objects.link(root)
    for obj in objects:
        obj.parent = root
    bpy.ops.object.select_all(action='DESELECT')
    for obj in [root,*objects]: obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(filepath=str(OUT/'exports'/f'{name}.glb'), export_format='GLB',
                              use_selection=True, export_apply=True, export_cameras=False, export_lights=False)
    assets.append(root)

# Presentation objects are excluded from each GLB; every exported prop has a floor-centered origin.
for obj, x in zip(assets,(-2,0,2)):
    obj.location.x = x
    box('Display plinth', (x,0,-.17), (1.75,1.65,.32), iron,.06)
box('Studio floor', (0,0,-.39), (200,200,.10), material('Studio charcoal',(.018,.028,.035)),0)
scene.world = bpy.data.worlds.new('Studio')
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs[0].default_value = (.12,.17,.23,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value = .35
for name,loc,power,color,size in [('Warm key',(-3,-4,7),1300,(1,.80,.60),5),('Cool fill',(4,-1,4),1000,(.52,.76,1),4),('Rim',(1,4,6),1800,(1,.56,.23),3)]:
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.color=color;data.shape='DISK';data.size=size
    obj=bpy.data.objects.new(name,data);scene.collection.objects.link(obj);obj.location=loc
    obj.rotation_euler=(Vector((0,0,.4))-obj.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(5,-9,6))
camera=bpy.context.object
camera.rotation_euler=(Vector((0,0,.42))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO';camera.data.ortho_scale=7.8;scene.camera=camera
scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
scene.render.resolution_x=1400;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.filepath=str(OUT/'preview.png')
# Start in a useful camera view when opening the source project.
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_perspective='CAMERA'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'gauntlet_props.blend'))
bpy.ops.render.render(write_still=True)
print('Created Blender source, three GLB props and preview:',OUT)
