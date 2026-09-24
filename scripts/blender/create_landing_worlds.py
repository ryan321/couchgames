"""Original landing-page miniatures. Run with installed Blender, never downloads tools.

blender --background --threads 6 --python scripts/blender/create_landing_worlds.py
Optional arguments after --: jet car wizard, --draft, --skip-wire, --wire-only.
The three aligned PNG passes are composited into atlases by pack_landing_worlds.py.
"""
import math
import sys
from pathlib import Path
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'crates/platform/site/worlds'
WORK = Path('/tmp/gigacouch-world-renders')
WORK.mkdir(exist_ok=True, parents=True)
OUT.mkdir(exist_ok=True, parents=True)
ARGS = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
DRAFT = '--draft' in ARGS


def material(name, color, metal=0, rough=.4, glow=0, fabric=False):
    m = bpy.data.materials.new(name); m.diffuse_color = (*color, 1); m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Metallic'].default_value = metal; p.inputs['Roughness'].default_value = rough
    p.inputs['Coat Weight'].default_value = .32 if metal > .35 else 0
    p.inputs['Coat Roughness'].default_value = .18
    if glow:
        p.inputs['Emission Color'].default_value = (*color, 1)
        p.inputs['Emission Strength'].default_value = glow
    if fabric:
        p.inputs['Sheen Weight'].default_value = .32
        n = m.node_tree.nodes.new('ShaderNodeTexNoise'); n.inputs['Scale'].default_value = 185
        bump = m.node_tree.nodes.new('ShaderNodeBump'); bump.inputs['Strength'].default_value = .17; bump.inputs['Distance'].default_value = .013
        m.node_tree.links.new(n.outputs['Fac'], bump.inputs['Height']); m.node_tree.links.new(bump.outputs['Normal'], p.inputs['Normal'])
    return m


def mesh(name, verts, faces, mat, smooth=True, bevel=0):
    data = bpy.data.meshes.new(name); data.from_pydata(verts, [], faces); data.update()
    o = bpy.data.objects.new(name, data); bpy.context.scene.collection.objects.link(o)
    return finish(o, name, mat, smooth, bevel)


def finish(o, name, mat, smooth=True, bevel=0):
    o.name = name; o.data.materials.append(mat)
    if o.type == 'MESH':
        for p in o.data.polygons: p.use_smooth = smooth
    if bevel:
        b = o.modifiers.new('Machined edge radius', 'BEVEL'); b.width = bevel; b.segments = 3
        n = o.modifiers.new('Weighted normals', 'WEIGHTED_NORMAL'); n.keep_sharp = True
    return o


def ell(name, p, size, mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=20, radius=1, location=p)
    o = bpy.context.object; o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(o, name, mat)


def box(name, p, size, mat, bevel=.025):
    bpy.ops.mesh.primitive_cube_add(size=1, location=p); o = bpy.context.object; o.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(o, name, mat, False, bevel)


def tube(name, points, radius, mat, cyclic=False):
    curve = bpy.data.curves.new(name, 'CURVE'); curve.dimensions = '3D'; curve.resolution_u = 16
    curve.bevel_depth = radius; curve.bevel_resolution = 3
    spline = curve.splines.new('BEZIER'); spline.bezier_points.add(len(points)-1)
    for b, p in zip(spline.bezier_points, points):
        b.co = p; b.handle_left_type = 'AUTO'; b.handle_right_type = 'AUTO'
    spline.use_cyclic_u = cyclic
    o = bpy.data.objects.new(name, curve); bpy.context.scene.collection.objects.link(o); curve.materials.append(mat)
    return o


def cylinder(name, a, b, radius, mat, vertices=48):
    a, b = Vector(a), Vector(b)
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=(b-a).length, location=(a+b)/2)
    o = bpy.context.object; o.rotation_euler = (b-a).to_track_quat('Z', 'Y').to_euler()
    return finish(o, name, mat, True, .006)


def torus(name, p, radius, thickness, mat, rotation=(0,0,0)):
    bpy.ops.mesh.primitive_torus_add(major_segments=64, minor_segments=12, location=p, major_radius=radius, minor_radius=thickness, rotation=rotation)
    return finish(bpy.context.object, name, mat)


def loft_x(name, rows, mat, segments=48):
    # x, half-width, height-center, half-height: continuous compound curves.
    verts = [(x, w*math.cos(j*math.tau/segments), z+h*math.sin(j*math.tau/segments)) for x,w,z,h in rows for j in range(segments)]
    faces = []
    for k in range(len(rows)-1):
        for j in range(segments):
            a=k*segments+j; b=k*segments+(j+1)%segments; faces.append((a,b,b+segments,a+segments))
    faces += [tuple(reversed(range(segments))), tuple((len(rows)-1)*segments+j for j in range(segments))]
    o=mesh(name,verts,faces,mat)
    sub=o.modifiers.new('Coachbuilt surface','SUBSURF');sub.levels=2;sub.render_levels=2
    return o


def plate(name, outline, thickness, mat):
    # Closed plate with an aerodynamic bevel. Outline lies in XY with custom Z.
    n=len(outline); verts=[(x,y,z+side*thickness/2) for side in [-1,1] for x,y,z in outline]
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh(name,verts,faces,mat,False,.016)


def jet():
    steel=material('Titanium silver',(.22,.29,.34),.78,.3)
    dark=material('Graphite composite',(.026,.042,.049),.6,.3)
    seam=material('Panel recesses',(.015,.023,.027),.35,.52)
    glass=material('Smoked bronze canopy',(.035,.095,.125),.7,.11)
    accent=material('Mint identification stripe',(.19,.7,.55),.5,.26)
    hot=material('Ion exhaust',(.19,.65,1),.1,.3,4)
    loft_x('Continuous fuselage',[(-2.05,.10,.02,.12),(-1.8,.31,.04,.21),(-1.1,.44,.06,.27),(-.2,.37,.07,.29),(.55,.29,.08,.26),(1.1,.22,.07,.19),(1.7,.12,.06,.105),(2.18,.008,.035,.009)],steel)
    ell('Canopy glass',(.45,0,.29),(.64,.215,.25),glass)
    tube('Canopy seal',[(-.15,-.13,.32),(.1,-.205,.34),(.63,-.17,.39),(1.03,0,.26),(.63,.17,.39),(.1,.205,.34),(-.15,.13,.32)],.018,dark,True)
    for side in [-1,1]:
        wing=[(-1.55,side*.28,-.005),(-1.63,side*1.76,-.07),(-1.15,side*1.83,-.045),(.5,side*.32,.005)]
        if side<0: wing.reverse()
        plate('Swept wing',wing,.07,steel)
        tube('Wing flap seam',[(-1.52,side*.52,.047),(-1.5,side*1.6,.018),(-1.25,side*1.69,.029)],.007,seam)
        tube('Wing leading edge',[(.4,side*.38,.045),(-.3,side*.98,.014),(-1.13,side*1.8,-.009)],.012,accent)
        plate('Tailplane',[(-2.0,side*.22,.17),(-2.07,side*.98,.24),(-1.66,side*.91,.24),(-1.11,side*.34,.2)],.05,dark)
        verts=[(-1.93,side*.32,.12),(-1.89,side*.53,.73),(-1.50,side*.48,.69),(-1.05,side*.27,.12)]
        o=mesh('Canted vertical stabilizer',verts,[(0,1,2,3)],steel,False)
        sol=o.modifiers.new('Fin thickness','SOLIDIFY');sol.thickness=.055
        bevel=o.modifiers.new('Fin edge','BEVEL');bevel.width=.015;bevel.segments=3
        for x in [-1.65,-1.48,-1.31]:
            tube('Tail panel',[(x,side*.41,.42),(x+.08,side*.44,.57)],.007,seam)
        cylinder('Engine nacelle',(-1.95,side*.33,-.10),(-.75,side*.33,-.10),.20,dark)
        cylinder('Nozzle titanium lip',(-2.06,side*.33,-.10),(-1.92,side*.33,-.10),.18,steel)
        cylinder('Exhaust cavity',(-2.071,side*.33,-.10),(-2.064,side*.33,-.10),.146,seam)
        torus('Nozzle glow',(-2.077,side*.33,-.10),.106,.018,hot,(0,math.pi/2,0))
        # Angled intake mouth and inlet surround below the wings.
        ell('Intake fairing',(-.33,side*.35,-.09),(.68,.16,.19),steel)
        ell('Intake throat',(.27,side*.35,-.09),(.05,.128,.128),seam)
    for x in [-1.1,-.63,.03,1.16]:
        tube('Fuselage panel seam',[(x,-.23,.17),(x,0,.33 if x<.4 else .23),(x,.23,.17)],.005,seam)
    tube('Nose instrumentation',[(1.78,0,.06),(2.29,0,.06)],.013,dark)
    return (7,-9,5.6),(0,0,.15),5.3,(768,576)


def car():
    paint=material('Liquid copper pearl',(.62,.085,.017),.72,.22)
    dark=material('Carbon fiber',(.009,.017,.024),.4,.32)
    glass=material('Obsidian glazing',(.014,.036,.052),.73,.10)
    alloy=material('Brushed forged alloy',(.46,.49,.5),.92,.20)
    rubber=material('Tire rubber',(.008,.011,.014),0,.72)
    red=material('Brake calipers',(.65,.023,.011),.45,.32)
    white=material('LED signature',(.69,.9,1),0,.2,3)
    tail=material('Tail light',(.95,.015,.009),0,.25,2)
    body=loft_x('Sculpted monocoque',[(-2.28,.64,.47,.18),(-2.16,.89,.5,.29),(-1.53,.98,.57,.38),(-.95,.92,.54,.24),(-.25,.85,.47,.23),(.55,.91,.47,.24),(1.4,.99,.55,.36),(1.95,.88,.42,.20),(2.28,.73,.35,.10)],paint)
    # Real wheel arches cut through the smoothly subdivided body.
    bpy.context.view_layer.objects.active=body;body.select_set(True)
    bpy.ops.object.modifier_apply(modifier=body.modifiers[0].name)
    for x in [-1.42,1.4]:
        for side in [-1,1]:
            bpy.ops.mesh.primitive_cylinder_add(vertices=64,radius=.435,depth=.49,location=(x,side*.94,.36),rotation=(math.pi/2,0,0));cut=bpy.context.object
            mod=body.modifiers.new('Wheel arch','BOOLEAN');mod.operation='DIFFERENCE';mod.object=cut
            bpy.context.view_layer.objects.active=body;bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cut,do_unlink=True)
    b=body.modifiers.new('Arch lip','BEVEL');b.width=.012;b.segments=3
    loft_x('Panoramic canopy',[(-1.22,.67,.71,.02),(-.90,.67,.9,.25),(-.42,.60,1.01,.27),(.1,.56,1.00,.24),(.77,.58,.70,.045)],glass)
    loft_x('Roof spine',[(-.87,.15,1.09,.10),(-.4,.15,1.255,.048),(.07,.13,1.23,.037),(.47,.08,1.02,.025)],paint,24)
    for side in [-1,1]:
        tube('Window sill',[(-1.18,side*.65,.71),(-.56,side*.67,.75),(.19,side*.66,.71),(.77,side*.59,.67)],.019,dark)
        tube('A pillar',[(.73,side*.58,.70),(.48,side*.56,.96),(.07,side*.46,1.20)],.026,paint)
        tube('Door cut',[(-.88,side*.87,.71),(-.78,side*.89,.39),(.53,side*.88,.30),(.78,side*.9,.67)],.008,dark)
        tube('Side skirt',[(-1.03,side*.91,.27),(0,side*.88,.235),(.99,side*.92,.26)],.045,dark)
        ell('Side intake',(-.84,side*.933,.51),(.25,.018,.095),dark)
        box('Mirror stalk',(.53,side*.77,.82),(.08,.3,.035),dark,.015)
        ell('Mirror cap',(.54,side*.93,.84),(.17,.12,.067),paint)
        tube('LED headlight',[(1.79,side*.70,.58),(2.03,side*.61,.50),(2.12,side*.44,.48)],.024,white)
        tube('Rear light',[(-2.18,side*.35,.61),(-2.14,side*.62,.63),(-2.00,side*.81,.60)],.024,tail)
        ell('Front air intake',(2.2,side*.52,.32),(.026,.2,.058),dark)
        for x in [-1.42,1.4]:
            # Y is the axle; recessed metallic rims and five split spokes.
            p=(x,side*.89,.365)
            torus('Performance tire profile',p,.303,.085,rubber,(math.pi/2,0,0))
            cylinder('Wheel barrel',(x,side*.87,.365),(x,side*1.015,.365),.272,dark)
            torus('Forged rim',(x,side*1.018,.365),.247,.014,alloy,(math.pi/2,0,0))
            cylinder('Brake rotor',(x,side*.998,.365),(x,side*1.008,.365),.211,alloy)
            box('Red caliper',(x+.14,side*1.014,.365),(.071,.022,.23),red,.019)
            for n in range(5):
                a=n*math.tau/5
                for spread in [-.07,.07]:
                    start=(x+math.sin(a)*.055,side*1.035,.365+math.cos(a)*.055)
                    end=(x+math.sin(a+spread)*.236,side*1.027,.365+math.cos(a+spread)*.236)
                    tube('Split spoke',[start,end],.013,alloy)
            cylinder('Hub',(x,side*1.035,.365),(x,side*1.055,.365),.047,alloy)
            for n in range(24):
                a=n*math.tau/24
                ell('Ventilated brake perforation',(x+math.cos(a)*.179,side*1.011,.365+math.sin(a)*.179),(.008,.003,.008),dark)
    box('Front splitter',(2.05,0,.225),(.43,1.67,.034),dark,.02)
    for y in [-.54,-.27,0,.27,.54]: box('Rear diffuser fin',(-2.06,y,.20),(.47,.021,.13),dark,.006)
    for y in [-.57,.57]: box('Wing pedestal',(-1.85,y,.77),(.11,.04,.32),dark,.018)
    wing=box('Floating rear wing',(-1.92,0,.95),(.40,1.88,.06),dark,.035);wing.rotation_euler.y=-.09
    for y in [-.89,.89]:box('Wing endplate',(-1.92,y,1.0),(.40,.027,.13),paint,.015)
    return (6.6,-9,4.25),(0,0,.59),5.45,(768,512)


def wizard():
    navy=material('Midnight velvet',(.026,.038,.095),0,.77,fabric=True)
    lining=material('Plum silk lining',(.17,.037,.085),0,.55,fabric=True)
    gold=material('Antique gold embroidery',(.49,.26,.062),.74,.33)
    leather=material('Worn oxblood leather',(.067,.022,.014),0,.65)
    skin=material('Warm aged skin',(.46,.25,.145),0,.6)
    hair=material('Silver beard',(.46,.43,.36),0,.72)
    shadow=material('Facial shadow',(.018,.009,.006),0,.7)
    eye=material('Amber iris',(.19,.105,.025),.1,.32)
    crystal=material('Aether crystal',(.08,.63,.87),.2,.22,2.6)
    wood=material('Twisted walnut staff',(.10,.038,.013),0,.59)
    # Cloth has a genuine draped, uneven surface rather than a cone silhouette.
    verts=[]; faces=[]; rows=30; sides=80
    for k in range(rows):
        t=k/(rows-1);z=.12+t*1.91
        radius=.56*(1-t)+.24*t+.10*math.exp(-((t-.87)*8)**2)
        for j in range(sides):
            a=j*math.tau/sides
            fold=(.035*math.sin(a*11+t*1.4)+.016*math.sin(a*19-t*2.2))*(1-.5*t)
            r=radius+fold;lean=.045*math.sin(t*3)
            verts.append((math.cos(a)*r+lean,math.sin(a)*r*.70+.055*math.sin(t*4),z+(.033*math.sin(a*7) if k==0 else 0)))
    for k in range(rows-1):
        for j in range(sides):
            a=k*sides+j;b=k*sides+(j+1)%sides;faces.append((a,b,b+sides,a+sides))
    robe=mesh('Tailored velvet robe',verts,faces,navy)
    sol=robe.modifiers.new('Cloth thickness','SOLIDIFY');sol.thickness=.012
    def robe_front(x,z):
        t=(z-.12)/1.91
        r=.56*(1-t)+.24*t+.10*math.exp(-((t-.87)*8)**2)
        return -math.sqrt(max(.005,r*r-x*x))*.70+.055*math.sin(t*4)-.015
    for side in [-1,1]:
        tube('Gold embroidered lapel',[(x,robe_front(x,z),z) for x,z in [(side*.28,1.98),(side*.20,1.71),(side*.09,1.27),(side*.24,.75),(side*.37,.17)]],.009,gold)
        # Draped arm and cuff have their own creases and weight.
        points=[(side*.26,0,1.90),(side*.40,-.045,1.7),(side*.49,-.12,1.50),(side*.53,-.23,1.35)]
        tube('Heavy robe sleeve',points,.17,navy)
        cuff=torus('Cuff embroidery',(side*.53,-.23,1.37),.162,.015,gold,(.4,side*.1,0))
        ell('Hand',(side*.54,-.255,1.29),(.078,.057,.12),skin)
        for n in range(4):
            tube('Fingers',[(side*.54+(n-1.5)*.024,-.29,1.29),(side*.54+(n-1.5)*.024,-.30,1.20),(side*.54+(n-1.5)*.023,-.265,1.17)],.013,skin)
    # Sculpted face, nose, eye sockets, brows and layered individual beard locks.
    ell('Head',(0,-.025,2.18),(.165,.15,.235),skin)
    ell('Nose bridge',(0,-.16,2.20),(.035,.052,.085),skin)
    ell('Nose tip',(0,-.208,2.155),(.044,.042,.034),skin)
    for side in [-1,1]:
        ell('Cheek',(side*.092,-.126,2.13),(.059,.043,.073),skin)
        ell('Eye socket',(side*.063,-.154,2.238),(.042,.015,.021),shadow)
        ell('Eye',(side*.064,-.168,2.238),(.027,.009,.012),eye)
        ell('Catchlight',(side*.068,-.177,2.241),(.004,.003,.004),crystal)
        tube('Bushy eyebrow',[(side*.023,-.172,2.27),(side*.060,-.177,2.277),(side*.101,-.148,2.27)],.012,hair)
        ell('Ear',(side*.161,-.015,2.19),(.035,.043,.077),skin)
        tube('Moustache',[(side*.008,-.204,2.115),(side*.051,-.211,2.10),(side*.102,-.179,2.08)],.021,hair)
    for n in range(31):
        a=(n/30-.5)*2.7;x=math.sin(a)*.132;y=-.1-math.cos(a)*.085
        endx=x*.28+.023*math.sin(n*1.7);zend=1.72+.10*abs(x)/.132
        tube('Flowing beard lock',[(x,y,2.105),(x*1.02,-.285,1.98),(x*.65,-.33,1.86),(endx,-.35,zend)],.011+(n%3)*.002,hair)
    # Organic bent felt hat with a wavy brim and stitched leather hatband.
    verts=[];faces=[];rings=[(2.39,.18,0),(2.48,.205,0),(2.60,.19,-.015),(2.76,.15,-.04),(2.92,.105,-.10),(3.06,.06,-.19),(3.15,.005,-.31)]
    for z,r,cx in rings:
        for j in range(64):
            a=j*math.tau/64;verts.append((cx+math.cos(a)*r,math.sin(a)*r*.92,z+.01*math.sin(a*5)))
    for k in range(len(rings)-1):
        for j in range(64):a=k*64+j;b=k*64+(j+1)%64;faces.append((a,b,b+64,a+64))
    mesh('Bent felt crown',verts,faces,navy)
    brim=[]
    for j in range(80):
        a=j*math.tau/80;brim.append((math.cos(a)*.415,math.sin(a)*.335,2.40+.045*math.sin(a*2+.3)))
    mesh('Shaped hat brim',[(0,0,2.40)]+brim,[(0,j+1,(j+1)%80+1) for j in range(80)],navy)
    tube('Brim gold stitch',brim,.008,gold,True)
    torus('Hat leather band',(0,0,2.49),.202,.027,leather)
    box('Hat buckle',(0,-.208,2.49),(.072,.018,.055),gold,.01)
    # Shoulder clasp, belt, fine decorative chains and a faceted amulet.
    torus('Leather belt',(0,0,1.10),.348,.034,leather)
    box('Belt buckle',(0,-.334,1.1),(.14,.035,.11),gold,.012)
    tube('Mantle chain',[(-.24,-.21,1.89),(0,-.29,1.77),(.24,-.21,1.89)],.009,gold)
    ell('Clasp',(-.24,-.21,1.89),(.037,.017,.043),gold)
    for side in [-1,1]:ell('Pointed boots',(side*.21,-.11,.12),(.13,.24,.11),leather)
    tube('Twisted staff',[(.64,-.22,.06),(.64,-.24,.8),(.60,-.26,1.35),(.67,-.23,2.0),(.62,-.22,2.59)],.035,wood)
    for z in [1.16,1.21,1.26,1.31,2.28,2.32]:torus('Staff binding',(.635,-.24,z),.039,.009,gold)
    for i in range(3):
        a=i*math.tau/3
        tube('Crystal crown branch',[(.62,-.22,2.43),(.62+math.cos(a)*.105,-.22+math.sin(a)*.105,2.64),(.62+math.cos(a)*.085,-.22+math.sin(a)*.085,2.82)],.017,wood)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=.15,location=(.62,-.22,2.72));o=bpy.context.object;o.scale=(.75,.75,1.5);finish(o,'Cut aether crystal',crystal,False)
    torus('Orbiting spell seal',(.62,-.22,2.72),.215,.008,gold,(.35,.5,.15))
    data=bpy.data.lights.new('Crystal glow','POINT');data.energy=7;data.color=(.16,.65,1);data.shadow_soft_size=.15
    o=bpy.data.objects.new('Crystal glow',data);bpy.context.scene.collection.objects.link(o);o.location=(.62,-.38,2.72)
    for i in range(7):
        a=i*2.3;ell('Spell mote',(.62+math.sin(a)*.23,-.22+math.cos(a)*.13,2.5+i*.065),(.012,.012,.012),crystal)
    return (3.6,-9,3.8),(0,0,1.63),3.7,(512,768)


def setup(camera_at, target, ortho, size):
    scene=bpy.context.scene
    scene.world=bpy.data.worlds.new('Reflection studio');scene.world.use_nodes=True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.23,.3,.38,1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value=.4
    for name,loc,power,color,light_size in [('Softbox key',(1,-4,6),650,(1,.91,.8),4),('Cool rim',(-3,2,4),950,(.48,.72,1),3),('Long reflection card',(4,3,3),700,(.77,1,.87),3),('Front fill',(-1,-5,2),180,(.78,.86,1),3)]:
        data=bpy.data.lights.new(name,'AREA');data.energy=power;data.color=color;data.shape='DISK';data.size=light_size
        o=bpy.data.objects.new(name,data);scene.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
    bpy.ops.object.camera_add(location=camera_at);camera=bpy.context.object;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.type='ORTHO';camera.data.ortho_scale=ortho;scene.camera=camera
    scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=16 if DRAFT else 48;scene.cycles.use_denoising=True
    scene.cycles.use_adaptive_sampling=True;scene.cycles.adaptive_threshold=.06
    scene.render.resolution_x=size[0];scene.render.resolution_y=size[1];scene.render.resolution_percentage=65 if DRAFT else 100
    scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA';scene.render.image_settings.color_depth='8'
    scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast'
    scene.render.threads_mode='FIXED';scene.render.threads=6
    return scene


def render_model(name, builder):
    if '--wire-only' in ARGS:
        bpy.ops.wm.open_mainfile(filepath=str(WORK/f'{name}.blend'))
        render_wire(name, bpy.context.scene)
        return
    bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
    camera,target,ortho,size=builder();scene=setup(camera,target,ortho,size)
    # Editable source is generated into /tmp; the deterministic script is versioned.
    bpy.ops.wm.save_as_mainfile(filepath=str(WORK/f'{name}.blend'),compress=True)
    scene.render.filepath=str(WORK/f'{name}-final.png');bpy.ops.render.render(write_still=True)
    clay=material('Porcelain development pass',(.23,.33,.35),.05,.6)
    for o in list(scene.objects):
        if o.type in {'MESH','CURVE'}:
            o.data.materials.clear();o.data.materials.append(clay)
    scene.cycles.samples=16;scene.render.filepath=str(WORK/f'{name}-clay.png');bpy.ops.render.render(write_still=True)
    if '--skip-wire' in ARGS:return
    render_wire(name, scene)


def render_wire(name, scene):
    wire=material('Cyan construction lines',(.22,.72,.63),0,.4,1.5)
    for o in list(scene.objects):
        if o.type not in {'MESH','CURVE'}:continue
        bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
        bpy.ops.object.convert(target='MESH');o=bpy.context.object
        dec=o.modifiers.new('Readable construction topology','DECIMATE');dec.ratio=.025
        bpy.ops.object.modifier_apply(modifier=dec.name)
        o.data.materials.clear();o.data.materials.append(wire)
        wf=o.modifiers.new('Holographic skeleton','WIREFRAME');wf.thickness=.003 if name!='wizard' else .002;wf.use_replace=True
        # Boolean wheel arches contain acute triangles. Even thickness expands
        # their corners into spikes; a constant normal offset keeps the silhouette.
        wf.use_even_offset=False
    scene.cycles.samples=8;scene.render.filepath=str(WORK/f'{name}-wire.png');bpy.ops.render.render(write_still=True)
    print('LANDING_RENDER_COMPLETE',name,flush=True)


for name,builder in [('jet',jet),('car',car),('wizard',wizard)]:
    if not any(a in {'jet','car','wizard'} for a in ARGS) or name in ARGS:render_model(name,builder)
