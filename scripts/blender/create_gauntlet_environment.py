"""Original dungeon props, using the same Blender palette and geometry helpers as the cast.
Explicit authoring only; no runtime dependency or downloads. All dimensions are Godot meters.
"""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
import create_gauntlet_cast as c
from create_gauntlet_cast import bpy, math, v, box, ell, tube, loft, ring, gem, plate
ROOT=c.ROOT
OUT=ROOT/'sdk/examples/gauntlet/assets/environment'
OUT.mkdir(parents=True,exist_ok=True)
stone=c.mat('Carved limestone',(.27,.32,.33),0,.85)
grain=c.mat('Bread crust',(.48,.245,.073),0,.9)
food=c.mat('Roast and fruit',(.26,.065,.029),0,.65)
ceramic=c.mat('Oxidized turquoise glaze',(.034,.22,.195),.18,.32)

def key():
 o=ring('Key bow',(-.16,.28,0),.13,.028,c.gold);o.rotation_euler.x=math.pi/2
 tube('Fluted shaft',[(-.06,.28,0),(.34,.28,0)],[.032,.026],c.gold)
 for x in [.23,.32]:box('Key tooth',(x,.21,0),(.05,.14,.055),c.gold,.006)
 gem((-.16,.28,.015),.055,c.cloth)
 for x in [.01,.08]:
  o=ring('Collar',(x,.28,0),.037,.009,c.gold);o.rotation_euler.y=math.pi/2

def platter():
 loft('Pewter dish',[(0,.03,.34,.28,0),(0,.06,.39,.31,0),(0,.09,.36,.28,0)],c.steel)
 ell('Roast',(0,.15,0),(.39,.22,.30),food)
 tube('Bone handle',[(.09,.15,.08),(.28,.16,.17)],[.035,.028],c.bone)
 for x in [-.035,.02]:ell('Bone end',(.28+x,.16,.17),(.08,.065,.065),c.bone)
 ell('Bread',(-.20,.14,-.04),(.17,.15,.31),grain)
 for z in [-.10,-.035,.03]:tube('Crust scoring',[(-.26,.183,z),(-.21,.215,z+.02),(-.16,.183,z+.04)],[.005]*3,c.bone,6)
 for x,z in [(.15,-.14),(.24,-.07)]:ell('Apple',(x,.13,z),(.11,.12,.11),ceramic)

def urn():
 loft('Funerary urn',[(0,.82,.11,.11,0),(0,.70,.18,.18,0),(0,.61,.13,.13,0),(0,.48,.27,.27,0),(0,.22,.29,.29,0),(0,.08,.18,.18,0)],ceramic)
 for y,r in [(.10,.19),(.57,.17),(.72,.185)]:ring('Gilded lip',(0,y,0),r,.017,c.gold)
 for side in [-1,1]:tube('Urn handle',[(side*.17,.60,0),(side*.33,.56,0),(side*.34,.36,0),(side*.26,.30,0)],[.027]*4,c.gold)
 gem((0,.39,.29),.062,c.gold)

def barrel():
 for i in range(14):
  a=i*math.tau/14
  points=[(math.sin(a)*r,y,math.cos(a)*r) for y,r in [(.04,.24),(.18,.28),(.40,.30),(.64,.27),(.77,.235)]]
  tube('Oak stave',points,[.057]*5,c.wood if i%2 else c.leather,6)
 for y,r in [(.12,.275),(.62,.282)]:ring('Iron hoop',(0,y,0),r,.025,c.iron)
 for i in range(5):box('Lid plank',((i-2)*.081,.77,0),(.077,.04,math.sqrt(max(.001,.23**2-((i-2)*.081)**2))*2),c.wood,.008)

def grate():
 box('Inset frame',(0,.021,0),(.83,.035,.83),c.iron,.015)
 box('Dark well',(0,.041,0),(.72,.012,.72),c.shadow,0)
 for i in range(6):
  box('Grate bar',((i-2.5)*.12,.055,0),(.022,.021,.74),c.steel,.006)
 for side in [-1,1]:box('Cross brace',(0,.057,side*.26),(.74,.027,.028),c.steel,.005)

def shrine():
 box('Stepped pedestal',(0,.09,0),(1.06,.18,1.06),stone,.045)
 box('Pedestal tier',(0,.23,0),(.84,.12,.84),c.iron,.025)
 loft('Carved altar',[(0,.28,.35,.35,0),(0,.58,.28,.28,0),(0,.68,.39,.39,0)],stone)
 for i in range(4):
  a=i*math.pi/2+math.pi/4;x=math.sin(a)*.34;z=math.cos(a)*.34
  tube('Crystal cradle',[(x,.62,z),(x*1.1,.87,z*1.1),(x*.6,1.08,z*.6)],[.043,.031,.012],c.gold)
  gem((x,.43,z),.067,c.jade)
 ring('Altar rim',(0,.69,0),.38,.023,c.gold)

def dressed_stone():
 box('Dressed stone',(0,0,0),(1,1,1),stone,.055)

def relief():
 box('Wall tablet',(0,.40,0),(.65,.69,.12),stone,.045)
 box('Recessed field',(0,.41,.065),(.50,.53,.035),c.iron,.025)
 for side in [-1,1]:
  tube('Carved wing',[(0,.23,.10),(side*.12,.40,.10),(side*.20,.58,.10),(side*.14,.54,.10)],[.022]*4,c.gold)
 gem((0,.40,.12),.065,c.jade)

assets=[]
for name,builder in [('RunicKey',key),('FeastPlatter',platter),('CeramicUrn',urn),('OakBarrel',barrel),('FloorGrate',grate),('SummoningAltar',shrine),('WingRelief',relief),('DressedStone',dressed_stone)]:
 before=set(bpy.data.objects);builder();model=c.merge_new(before,name)
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_apply=True,export_cameras=False,export_lights=False)
 assets.append(model)
# Consolidate the existing original prop studies to one mesh per prop before integration.
for name in ['VaultChest','JadePotion','EmberBrazier']:
 before=set(bpy.data.objects)
 bpy.ops.import_scene.gltf(filepath=str(ROOT/'art/gauntlet/exports'/f'{name}.glb'))
 model=c.merge_new(before,name);model.parent=None
 bpy.ops.object.select_all(action='DESELECT');model.select_set(True);bpy.context.view_layer.objects.active=model
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_apply=True,export_cameras=False,export_lights=False)
 assets.append(model)
for i,o in enumerate(assets):o.location=v(((i%5)*1.7,0,-(i//5)*2))
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/gauntlet/gauntlet_environment.blend'))
print('Exported eleven original dungeon assets.')
