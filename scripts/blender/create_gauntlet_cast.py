"""Author original Gauntlet equipment and creatures; Blender 5.2, no downloads.
Coordinates in model functions use Godot's X-right/Y-up/Z-forward convention.
"""
import math
from pathlib import Path
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'sdk/examples/gauntlet/assets/cast'
SOURCE=ROOT/'art/gauntlet/cast'
OUT.mkdir(parents=True,exist_ok=True);SOURCE.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene
scene.unit_settings.system='METRIC'

def v(p): return Vector((p[0],-p[2],p[1]))
def mat(name,color,metal=0,rough=.5,emission=0):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True;m.use_backface_culling=True
 bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*color,1)
 bs.inputs['Metallic'].default_value=metal;bs.inputs['Roughness'].default_value=rough
 if emission: bs.inputs['Emission Color'].default_value=(*color,1);bs.inputs['Emission Strength'].default_value=emission
 return m
steel=mat('Tempered steel',(.24,.32,.38),.78,.30)
edge=mat('Honed silver edges',(.61,.72,.77),.85,.23)
gold=mat('Aged brass',(.43,.25,.075),.73,.32)
iron=mat('Blackened iron',(.045,.064,.074),.7,.40)
leather=mat('Oiled leather',(.095,.044,.024),0,.69)
wood=mat('Dark yew',(.16,.075,.031),0,.67)
bone=mat('Old ivory',(.55,.48,.34),0,.68)
cloth=mat('IdentityCloth',(.085,.16,.19),0,.89)
jade=mat('Jade inlay',(.07,.34,.29),.35,.28)
aether=mat('Aether crystal',(.21,.52,.69),.25,.22,.65)
shade=mat('Wraith shroud',(.12,.20,.235),0,.93)
shadow=mat('Face shadow',(.006,.014,.020),0,.88)
soul=mat('Soul light',(.25,.76,.77),0,.30,1.6)
skin=mat('Raider slate skin',(.23,.29,.25),0,.84)
demon_skin=mat('Demon carmine hide',(.31,.065,.049),0,.72)
horn=mat('Charred horn',(.073,.058,.047),0,.7)
ember=mat('Ember eyes',(.95,.26,.027),0,.28,1.4)

# Modifiers are applied once at export; game instances share the resulting meshes.
def finish(o,name,m,bevel=0,smooth=False):
 o.name=name;o.data.materials.append(m)
 if smooth:
  for p in o.data.polygons:p.use_smooth=True
 if bevel:
  b=o.modifiers.new('Crafted bevel','BEVEL');b.width=bevel;b.segments=2
  n=o.modifiers.new('Weighted normals','WEIGHTED_NORMAL');n.keep_sharp=True
 return o

def box(name,p,size,m,bevel=.01):
 bpy.ops.mesh.primitive_cube_add(size=1,location=v(p));o=bpy.context.object
 o.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 return finish(o,name,m,bevel)

def ell(name,p,size,m):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=10,radius=1,location=v(p));o=bpy.context.object
 o.scale=(size[0]/2,size[2]/2,size[1]/2);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 return finish(o,name,m,smooth=True)

def tube(name,points,radii,m,sides=10):
 points=[v(p) for p in points];verts=[]
 for i,p in enumerate(points):
  tangent=(points[min(i+1,len(points)-1)]-points[max(0,i-1)]).normalized()
  u=tangent.cross(Vector((0,0,1)))
  if u.length<.01:u=tangent.cross(Vector((0,1,0)))
  u.normalize();w=tangent.cross(u).normalized()
  for j in range(sides):
   a=j*math.tau/sides;verts.append(p+radii[i]*(u*math.cos(a)+w*math.sin(a)))
 faces=[]
 for i in range(len(points)-1):
  for j in range(sides):
   a=i*sides+j;b=i*sides+(j+1)%sides;faces.append((a,b,b+sides,a+sides))
 faces.extend([tuple(reversed(range(sides))),tuple((len(points)-1)*sides+j for j in range(sides))])
 return mesh(name,verts,faces,m,True)

def mesh(name,verts,faces,m,smooth=False):
 data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.update()
 o=bpy.data.objects.new(name,data);scene.collection.objects.link(o)
 return finish(o,name,m,smooth=smooth)

def loft(name,rows,m,folds=0,segments=32,start=0,end=math.tau):
 # Rows: center X, height, radius X, radius Z, center Z.
 verts=[]
 for k,(cx,y,rx,rz,cz) in enumerate(rows):
  for j in range(segments+1):
   a=start+(end-start)*j/segments;pleat=1+math.cos(a*12)*folds
   yy=y+(math.sin(a*7)*.075 if name=='Tattered hem' and k==0 else 0)
   verts.append(v((cx+math.sin(a)*rx*pleat,yy,cz+math.cos(a)*rz*pleat)))
 faces=[]
 for k in range(len(rows)-1):
  for j in range(segments):
   a=k*(segments+1)+j;b=a+segments+1;faces.append((a,a+1,b+1,b))
 return mesh(name,verts,faces,m,True)

def plate(name,outline,depth,m,z=0):
 # Extruded profile in the X/Y plane, useful for blade, armor and shield faces.
 area=sum(outline[i][0]*outline[(i+1)%len(outline)][1]-outline[(i+1)%len(outline)][0]*outline[i][1] for i in range(len(outline)))
 if area<0:outline=list(reversed(outline))
 n=len(outline);verts=[v((x,y,z+d)) for d in [-depth/2,depth/2] for x,y in outline]
 faces=[tuple(reversed(range(n))),tuple(n+i for i in range(n))]
 faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 o=mesh(name,verts,faces,m);b=o.modifiers.new('Edge chamfer','BEVEL');b.width=.007;b.segments=2
 return o

def ring(name,p,r,thick,m):
 bpy.ops.mesh.primitive_torus_add(major_segments=24,minor_segments=6,location=v(p),major_radius=r,minor_radius=thick)
 return finish(bpy.context.object,name,m,smooth=True)

def strap(a,b,r=.018,m=gold):return tube('Binding',[a,b],[r,r],m,8)
def gem(p,s=.04,m=jade):
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=s,location=v(p));return finish(bpy.context.object,'Cut gemstone',m)

def armor(kind):
 if kind in [0,1]:
  # Fitted cuirass, layered edges and a central ridge, clear of the upper arms.
  loft('Forged cuirass',[(0,1.05,.22,.16,0),(0,1.15,.25,.185,0),(0,1.34,.28,.18,0),(0,1.43,.21,.145,0)],steel if kind==0 else edge)
  for y,rx,rz in [(1.065,.229,.17),(1.10,.24,.183),(1.40,.235,.158)]:
   loft('Brass edge',[(0,y,rx,rz,0),(0,y+.014,rx,rz,0)],gold)
  plate('Breastplate ridge',[(-.015,1.14),(.015,1.14),(.045,1.34),(0,1.41),(-.045,1.34)],.014,gold,.19)
  for side in [-1,1]:
   for n in range(3):
    strap((side*.03,1.24+n*.045,.194),(side*.17,1.29+n*.027,.158),.006,iron if kind==0 else gold)
  gem((0,1.345,.213),.035,jade if kind==1 else aether)
  for side in [-1,1]:
   for row in range(5):
    gem((side*.20,1.14+row*.044,.162),.011,gold)
   for row in range(3):
    y=1.05-row*.047
    plate('Articulated fauld',[(side*.025,y),(side*.225,y+.018),(side*.24,y-.029),(side*.025,y-.043)],.018,steel if kind==0 else edge,.165)
   tube('Engraved scroll',[(side*.055,1.22,.199),(side*.115,1.25,.19),(side*.145,1.31,.178)],[.004]*3,gold,6)
 elif kind==2:
  # Ornament the existing animated robe, leaving the fitted hat and cloth simulation intact.
  for side in [-1,1]:
   tube('Embroidered stole',[(side*.09,1.47,.11),(side*.17,1.34,.178),(side*.14,1.12,.205)],[.022,.025,.019],gold)
   for j in range(4):gem((side*.15,1.19+j*.055,.21),.012,aether)
  gem((0,1.385,.225),.045,aether)
  for side in [-1,1]:
   for i in range(6):
    y=1.12+i*.044
    tube('Stole stitching',[(side*.12,y,.222),(side*.145,y+.017,.222),(side*.17,y,.202)],[.003]*3,bone,6)
  tube('Neck chain',[(-.08,1.49,.09),(0,1.38,.219),(.08,1.49,.09)],[.006]*3,gold)
  box('Spellbook',(-.25,1.08,-.02),(.10,.22,.15),leather)
  for y in [1.01,1.16]:box('Book clasp',(-.26,y,.02),(.11,.019,.13),gold,.003)
 else:
  loft('Ranger leather vest',[(0,1.05,.22,.17,0),(0,1.19,.25,.186,0),(0,1.36,.27,.172,0),(0,1.44,.19,.13,0)],leather)
  for side in [-1,1]:
   for i in range(3):
    plate('Leaf lamella',[(side*.035,1.16+i*.07),(side*.18,1.20+i*.07),(side*.10,1.27+i*.07)],.015,cloth,.187)
  for side in [-1,1]:
   for i in range(7):gem((side*.205,1.13+i*.037,.16),.006,bone)
   box('Belt pouch',(side*.22,1.04,.075),(.10,.13,.10),leather,.022)
   gem((side*.22,1.06,.13),.012,gold)
  tube('Crossbody belt',[(-.17,1.44,.15),(0,1.28,.20),(.20,1.09,.16)],[.022]*3,gold)
  tube('Leather quiver',[(.13,1.09,-.22),(.22,1.49,-.24)],[.073,.082],leather)
  for j in range(4):
   x=.17+j*.028
   strap((x,1.43,-.24),(x+.05,1.68,-.24),.008,wood)
   plate('Arrow feather',[(x+.01,1.55),(x+.075,1.63),(x+.048,1.65)],.007,bone,-.24)

def weapon(kind):
 if kind==0:
  tube('Ash haft',[(0,-.14,0),(0,.78,0)],[.027,.025],wood)
  for j in range(7):ring('Leather binding',(0,-.08+j*.033,0),.029,.006,leather)
  outline=[(-.04,.55),(.10,.52),(.28,.44),(.37,.50),(.39,.68),(.32,.87),(.17,.83),(.05,.72),(-.04,.73)]
  plate('Bearded axe',outline,.065,steel)
  plate('Honed cutting edge',[(.28,.44),(.37,.50),(.39,.68),(.32,.87),(.285,.83),(.345,.67),(.33,.52)],.015,edge)
  for y in [.58,.7]:gem((.03,y,.043),.017,gold)
  strap((-.04,.60,.038),(.23,.65,.038),.008,gold)
 elif kind==1:
  tube('Leather grip',[(0,-.11,0),(0,.16,0)],[.026,.026],leather)
  plate('Tapered sword',[(-.048,.19),(.048,.19),(.039,.70),(0,.94),(-.039,.70)],.043,edge)
  plate('Sword fuller',[(-.014,.25),(.014,.25),(.011,.66),(0,.82),(-.011,.66)],.046,steel)
  tube('Swept crossguard',[(-.15,.15,0),(-.08,.20,0),(.08,.20,0),(.15,.15,0)],[.02]*4,gold)
  gem((0,-.13,0),.037,gold);gem((0,.20,.033),.025,jade)
 elif kind==2:
  tube('Carved staff',[(0,-.58,0),(.025,-.2,0),(-.01,.25,0),(.03,.65,0),(0,.9,0)],[.028,.029,.026,.024,.022],wood)
  for side in [-1,1]:
   tube('Crystal cradle',[(0,.72,0),(side*.085,.87,0),(side*.055,1.06,0)],[.028,.021,.007],gold)
  o=gem((0,.96,0),.105,aether);o.scale=(.6,.6,1.45)
  for y in [.66,.71,-.35]:ring('Staff band',(0,y,0),.03,.008,gold)
 else:
  points=[(0,-.46,.03),(0,-.39,-.065),(0,-.24,-.15),(0,0,-.075),(0,.24,-.15),(0,.39,-.065),(0,.46,.03)]
  tube('Recurved yew bow',points,[.012,.02,.024,.029,.024,.02,.012],wood)
  tube('Ivory bow backing',[(x,y,z-.013) for x,y,z in points],[.009]*7,bone)
  tube('Bowstring',[points[0],points[-1]],[.0025,.0025],bone,6)
  tube('Grip',[(0,-.075,-.075),(0,.075,-.075)],[.033,.033],leather)
  for y in [-.10,.10]:gem((0,y,-.077),.025,gold)


def shield(kind):
 if kind==0:
  rows=[]
  # Turn a shallow domed disk from the Y-axis to face +Z.
  before=set(bpy.data.objects)
  loft('Domed shield',[(0,0,.29,.29,0),(0,.025,.30,.30,0),(0,.06,.24,.24,0),(0,.085,.08,.08,0),(0,.09,.001,.001,0)],cloth,0,48)
  ring('Rolled rim',(0,.022,0),.293,.019,edge)
  for o in set(bpy.data.objects)-before:
   o.rotation_euler.x=math.pi/2
  # In Godot coordinates the turned dome points forward (+Z).
  ell('Shield backing',(0,0,-.006),(.575,.575,.022),wood)
  ell('Shield boss',(0,0,.10),(.15,.15,.10),steel)
  for i in range(10):
   a=i*math.tau/10;gem((math.sin(a)*.265,math.cos(a)*.265,.042),.013,gold)
  for side in [-1,1]:
   strap((side*.06,-.20,.065),(side*.06,.20,.065),.009,gold)
 else:
  outline=[(-.23,.20),(0,.28),(.23,.20),(.20,-.12),(0,-.36),(-.20,-.12)]
  plate('Kite shield rim',outline,.065,edge)
  plate('Inset painted field',[(x*.88,y*.88) for x,y in outline],.07,cloth)
  for side in [-1,1]:
   tube('Winged crest',[(0,-.16,.047),(side*.09,.08,.047),(side*.15,.16,.047)],[.014,.013,.004],gold)
  gem((0,.075,.06),.035,jade)
 for side in [-1,1]:
  box('Rear grip',(side*.09,0,-.05),(.035,.20,.035),leather,.008)

# Parts are joined before export, limiting node and draw overhead for a crowded dungeon.
def merge_new(before,name,pivot=(0,0,0)):
 objs=[o for o in bpy.data.objects if o not in before and o.type=='MESH']
 bpy.ops.object.select_all(action='DESELECT')
 for o in objs:
  bpy.context.view_layer.objects.active=o
  for mod in list(o.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
  o.select_set(True)
 bpy.context.view_layer.objects.active=objs[0];bpy.ops.object.join();o=bpy.context.object;o.name=name
 scene.cursor.location=v(pivot);bpy.ops.object.origin_set(type='ORIGIN_CURSOR');return o

def enemy(kind):
 before=set(bpy.data.objects)
 if kind=='Wraith':
  loft('Tattered hem',[(0,.16,.34,.23,0),(0,.36,.29,.20,0),(0,.65,.24,.16,0),(0,.94,.21,.14,0),(0,1.12,.14,.10,0)],shade,.08)
  ell('Hood',(0,1.17,0),(.43,.50,.36),shade)
  ell('Hollow face',(0,1.19,.156),(.255,.31,.055),shadow)
  for side in [-1,1]:
   tube('Hood binding',[(side*.13,1.04,.16),(side*.16,1.22,.16),(side*.08,1.37,.09),(0,1.40,.035)],[.012]*4,bone)
   ell('Spectral eye',(side*.064,1.23,.188),(.062,.025,.016),soul)
  loft('Mantle',[(0,.87,.30,.20,0),(0,1.01,.29,.20,0),(0,1.10,.19,.13,0)],shade,.045)
  gem((0,.95,.205),.037,soul)
 else:
  m=skin if kind=='Raider' else demon_skin
  loft('Torso',[(0,.47,.15,.12,0),(0,.65,.20,.145,0),(0,.88,.29,.17,-.025),(0,1.01,.20,.14,0)],m,.0)
  ell('Neck',(0,1.04,.015),(.22,.25,.22),m)
  ell('Cranium',(0,1.23,.025),(.37,.40,.29),m)
  ell('Jaw',(0,1.12,.13),(.28,.18,.20),m)
  ell('Muzzle',(0,1.18,.185),(.18,.09,.13),m)
  for side in [-1,1]:
   ell('Eye socket',(side*.093,1.29,.151),(.115,.073,.038),shadow)
   ell('Eye',(side*.092,1.286,.174),(.06,.026,.015),ember)
   tube('Angled brow',[(side*.032,1.325,.16),(side*.15,1.34,.11)],[.029,.017],m)
   tube('Swept ear',[(side*.14,1.25,0),(side*.25,1.33,-.03),(side*.31,1.37,-.11)],[.075,.052,.002],m)
   tube('Lower tusk',[(side*.09,1.09,.21),(side*.095,1.19,.22)],[.025,.003],bone)
  if kind=='Raider':
   loft('Raider cuirass',[(0,.62,.21,.155,0),(0,.89,.30,.185,-.025),(0,.97,.21,.15,0)],iron)
   for side in [-1,1]:
    ell('Shoulder plate',(side*.27,.93,-.015),(.26,.22,.30),steel)
    for i in range(2):gem((side*(.22+i*.07),.99,.112),.018,gold)
   strap((-.15,.89,.185),(.14,.67,.16),.016,leather)
   loft('War belt',[(0,.58,.20,.15,0),(0,.65,.22,.165,0)],leather)
   gem((0,.62,.17),.038,gold)
  else:
   for side in [-1,1]:
    tube('Swept horns',[(side*.13,1.36,-.02),(side*.21,1.50,-.08),(side*.18,1.67,-.15),(side*.09,1.72,-.18)],[.073,.056,.027,.001],horn)
    for i in range(3):
     tube('Rib armor',[(side*.04,.77+i*.07,.16),(side*.21,.82+i*.06,.10)],[.017,.013],horn)
   for side in [-1,1]:
    for j in range(3):
     tube('Shoulder spines',[(side*(.20+j*.038),.98-j*.035,-.04),(side*(.24+j*.056),1.10-j*.045,-.13)],[.037,.001],horn)
   for y in [.60,.74,.88]:gem((0,y,-.19),.045,horn)
 merge_new(before,'Body')
 for side,label in [(-1,'L'),(1,'R')]:
  before=set(bpy.data.objects)
  if kind=='Wraith':
   tube('Drooping sleeve',[(side*.22,.98,0),(side*.37,.75,.07),(side*.44,.66,.22)],[.115,.12,.07],shade)
   ell('Spectral hand',(side*.43,.66,.25),(.12,.13,.12),bone)
   for finger in range(3):
    tube('Long fingers',[(side*(.40+finger*.027),.65,.28),(side*(.40+finger*.027),.56,.36)],[.014,.003],bone,6)
  else:
   m=skin if kind=='Raider' else demon_skin
   tube('Arm',[(side*.27,.94,0),(side*.38,.73,.035),(side*.37,.57,.16)],[.11,.078,.063],m)
   ell('Knuckles',(side*.37,.56,.18),(.14,.15,.14),m)
   if kind=='Raider':
    tube('Bracer',[(side*.375,.65,.105),(side*.37,.59,.15)],[.087,.081],iron)
    if side==1:
     tube('Mace shaft',[(.37,.42,.18),(.40,1.02,.21)],[.026,.027],wood)
     ell('Flanged mace',(.40,1.0,.21),(.20,.25,.19),iron)
     for i in range(4):
      a=i*math.tau/4;gem((.40+math.cos(a)*.10,1.02,.21+math.sin(a)*.10),.045,steel)
   else:
    for f in range(3):tube('Claw',[(side*(.33+f*.037),.53,.23),(side*(.33+f*.037),.41,.29)],[.019,.002],horn,6)
  merge_new(before,'Arm_'+label,(side*.25,.96,0))
  if kind!='Wraith':
   before=set(bpy.data.objects);m=skin if kind=='Raider' else demon_skin
   tube('Thigh',[(side*.125,.54,0),(side*.16,.30,.02)],[.105,.078],m)
   merge_new(before,'Leg_'+label,(side*.125,.53,0))
   before=set(bpy.data.objects)
   tube('Shin',[(side*.16,.30,.02),(side*.18,.10,0)],[.078,.06],m)
   ell('Boot' if kind=='Raider' else 'Cloven foot',(side*.18,.085,.085),(.19,.16,.30),iron if kind=='Raider' else horn)
   if kind=='Raider':ell('Knee guard',(side*.16,.32,.08),(.16,.18,.07),steel)
   merge_new(before,'Calf_'+label,(side*.16,.30,.02))
 if kind=='EmberDemon':
  before=set(bpy.data.objects)
  tube('Spined tail',[(0,.54,-.08),(.10,.36,-.32),(.31,.33,-.49),(.36,.55,-.56)],[.075,.058,.032,.003],demon_skin)
  plate('Tail barb',[(.29,.52),(.36,.68),(.43,.52)],.026,horn,-.56)
  merge_new(before,'Tail',(0,.54,-.08))

# One vertex-colored material per creature mesh keeps sixteen-player enemy crowds affordable.
palette=mat('CreaturePalette',(1,1,1),.12,.74)
paint=palette.node_tree.nodes.new('ShaderNodeVertexColor');paint.layer_name='Paint'
palette.node_tree.links.new(paint.outputs['Color'],palette.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
def paint_creature(objects):
 for obj in objects:
  if obj.type!='MESH':continue
  colors=obj.data.color_attributes.new(name='Paint',type='BYTE_COLOR',domain='CORNER')
  for face in obj.data.polygons:
   color=obj.data.materials[face.material_index].diffuse_color
   for loop in face.loop_indices:colors.data[loop].color=color
   face.material_index=0
  obj.data.materials.clear();obj.data.materials.append(palette)

def main():
 assets=[]
 for name,fn in [(n,lambda k=k:armor(k)) for k,n in enumerate(['WarriorArmor','ValkyrieArmor','WizardDetails','ElfArmor'])]+[(n,lambda k=k:weapon(k)) for k,n in enumerate(['WarriorAxe','ValkyrieSword','WizardStaff','ElfBow'])]+[(n,lambda k=k:shield(k)) for k,n in enumerate(['WarriorShield','ValkyrieShield'])]+[(n,lambda n=n:enemy(n)) for n in ['Wraith','Raider','EmberDemon']]:
  before=set(bpy.data.objects);fn()
  if name not in ['Wraith','Raider','EmberDemon']:merge_new(before,'Model')
  objects=[o for o in bpy.data.objects if o not in before]
  if name in ['Wraith','Raider','EmberDemon']:paint_creature(objects)
  root=bpy.data.objects.new(name,None);scene.collection.objects.link(root)
  for o in objects:o.parent=root
  bpy.ops.object.select_all(action='DESELECT')
  for o in [root,*objects]:o.select_set(True)
  bpy.context.view_layer.objects.active=root
  bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_apply=True,export_cameras=False,export_lights=False)
  assets.append(root)
 # Blender working layout: equipment above, creatures below, all with independent editable parts.
 for i,o in enumerate(assets):o.location=v(((i%4)*2.1,0,-(i//4)*2.7))
 scene.world=bpy.data.worlds.new('Atelier');scene.world.use_nodes=True
 scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.10,.14,.20,1)
 scene.world.node_tree.nodes['Background'].inputs[1].default_value=.4
 box('Studio floor',(3,-.07,-2),(18,.10,16),mat('Studio',(.03,.045,.055)),0)
 for p,power,color in [((-2,8,5),1600,(1,.81,.62)),((9,6,0),1400,(.55,.77,1)),((3,7,-9),2000,(1,.48,.2))]:
  d=bpy.data.lights.new('Softbox','AREA');d.energy=power;d.color=color;d.shape='DISK';d.size=5
  o=bpy.data.objects.new('Softbox',d);scene.collection.objects.link(o);o.location=v(p);o.rotation_euler=(v((3,0,-2))-o.location).to_track_quat('-Z','Y').to_euler()
 bpy.ops.object.camera_add(location=v((11,9,12)));camera=bpy.context.object
 camera.rotation_euler=(v((3,.6,-2.7))-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.ortho_scale=12;scene.camera=camera
 scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
 scene.render.resolution_x=1500;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
 scene.render.filepath=str(SOURCE/'atelier.png')
 bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'gauntlet_cast.blend'))
 bpy.ops.render.render(write_still=True)
 print('Exported thirteen original Blender cast assets.')

if __name__=='__main__': main()
