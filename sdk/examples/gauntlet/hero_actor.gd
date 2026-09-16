extends Node3D
## Shared textured character assets; animation is presentation-only and never moves the simulation.
const Costume = preload("res://examples/gauntlet/hero_costume.gd")
const Equipment = preload("res://examples/gauntlet/hero_equipment.gd")
const ASSETS := "res://examples/gauntlet/assets/characters/"
static var head_meshes: Dictionary = {}
static var animation_library: AnimationLibrary
var skeleton: Skeleton3D
var animator: AnimationPlayer
var kind := 0
var garment_color: Color
var motion: RefCounted
var outfit: Node3D
var managed := false
var fall := 0.0
var weapon: Node3D
var damage_feedback: Node3D
var robe_skirt: Node3D
var robe_trail := Vector3.ZERO

func _ready() -> void:
	damage_feedback = preload("res://examples/gauntlet/damage_feedback.gd").new()
	add_child(damage_feedback)
	damage_feedback.configure(outfit)
	motion = preload("res://examples/gauntlet/hero_motion.gd").new()
	motion.configure(outfit,animator,skeleton,kind)
	motion.tree.advance(0)
	if kind in [2,3]:
		var wrist := skeleton.find_bone("hand_l" if kind==3 else "hand_r")
		weapon.basis = skeleton.get_bone_global_pose(wrist).basis.inverse()

func _process(delta: float) -> void:
	if not managed and motion: motion.tree.advance(delta)

func configure(view: Node3D, hero_class: int, color_index := -1) -> void:
	kind = hero_class
	set_meta("class",kind)
	set_meta("color_index",kind if color_index<0 else color_index)
	var outfit_name: String = ["Male_Ranger","Female_Ranger","Male_Peasant","Male_Ranger"][kind]
	outfit = load(ASSETS+outfit_name+".gltf").instantiate()
	add_child(outfit)
	# Scale the complete visual rig, including its equipment; simulation and player markers stay independent.
	outfit.scale = [Vector3(1.24,0.94,1.14),Vector3.ONE,Vector3.ONE,Vector3.ONE*0.86][kind]
	skeleton = outfit.get_node("Armature/Skeleton3D")
	# The base pack and outfits share the same neck/head rest transform.
	var head := attachment("Head")
	var face := MeshInstance3D.new()
	face.mesh = make_head(kind==1)
	face.transform = skeleton.get_bone_global_rest(skeleton.find_bone("Head")).affine_inverse()
	head.add_child(face)
	for item in skeleton.get_children():
		if item is MeshInstance3D and "Hood" in str(item.name): item.visible = kind==3
	var color: Color = view.Level.player_color(kind if color_index<0 else color_index)
	garment_color = color.darkened(0.52)
	var garment := garment_color
	for item in skeleton.get_children():
		if not item is MeshInstance3D: continue
		if str(item.name).ends_with("_Body") or str(item.name).ends_with("_Arms") or "Hood" in str(item.name):
			for surface in item.mesh.get_surface_count():
				var cloth: StandardMaterial3D = item.mesh.surface_get_material(surface).duplicate()
				if "Regular" in cloth.resource_name: continue
				cloth.albedo_texture = null
				cloth.albedo_color = garment
				cloth.roughness = 0.94
				item.set_surface_override_material(surface,cloth)
		if "Pauldron" in str(item.name) and kind<2:
			item.material_override = view.material(Color("78858c"),0.65)
	var chest := attachment("spine_03")
	var chest_detail := Node3D.new()
	chest.add_child(chest_detail)
	chest_detail.transform = skeleton.get_bone_global_rest(skeleton.find_bone("spine_03")).affine_inverse()
	var crown := Node3D.new()
	head.add_child(crown)
	crown.transform = skeleton.get_bone_global_rest(skeleton.find_bone("Head")).affine_inverse()
	if kind==2:
		Costume.wizard(view,self,crown,chest_detail)
		for side in ["l","r"]:
			var sleeve := attachment("upperarm_"+side)
			view.cylinder(sleeve,Vector3(0,0.13,0),0.115,0.27,garment,0.095)
			var cuff := attachment("lowerarm_"+side)
			view.cylinder(cuff,Vector3(0,0.10,0),0.095,0.20,garment,0.075)
			view.ring(cuff,Vector3(0,0.20,0),0.077,0.009,Color("8c7953"))
	elif kind==1:
		Costume.valkyrie(view,crown)
	elif kind==0:
		Costume.helmet(view,crown,kind)
	var hand := attachment("hand_l" if kind==3 else "hand_r")
	weapon = Node3D.new()
	hand.add_child(weapon)
	weapon.rotation.x = PI/2
	if kind==2:
		# Crooked wood, brass collars and a restrained crystal rather than a glowing lollipop.
		for section in 9:
			var y := -0.58+section*0.17
			Equipment.segment(view,weapon,Vector3(sin(section*0.6)*0.025,y,0),Vector3(sin((section+1)*0.6)*0.025,y+0.17,0),0.028,Color("594230"))
		for y in [0.65,0.78,0.87]: view.ring(weapon,Vector3(-0.02,y,0),0.035,0.009,Color("97815b"))
		for side in [-1,1]:
			Equipment.segment(view,weapon,Vector3(-0.02,0.88,0),Vector3(side*0.075,1.04,0),0.018,Color("756044"))
		view.ball(weapon,Vector3(-0.02,1.00,0),Vector3(0.085,0.16,0.085),Color("82a5b4"),0.45)
	elif kind==3:
		weapon.rotation = Vector3.ZERO
		weapon.rotation.z = PI/2
		Equipment.bow(view,weapon)
	else:
		view.cylinder(weapon,Vector3(0,0.03,0),0.028,0.28,Color("684332"))
		view.box(weapon,Vector3(0,0.17,0),Vector3(0.21,0.035,0.06),Color("d2b571"),0.75)
		Equipment.blade(view,weapon,kind==0)
		if kind==0: view.cylinder(weapon,Vector3(0,0.43,0),0.024,0.65,Color("684332"))
		for wrap in 6:
			view.ring(weapon,Vector3(0,-0.065+wrap*0.032,0),0.029,0.004,Color("b19362"))
		var shield_socket := attachment("hand_l")
		var shield_hand := Node3D.new()
		shield_socket.add_child(shield_hand)
		shield_hand.scale = Vector3.ONE*0.82
		var shield: MeshInstance3D = view.cylinder(shield_hand,Vector3(0,0.02,0.09),0.27,0.05,color,-1,0.55)
		shield.rotation.z = PI/2
		var rim: MeshInstance3D = view.ring(shield_hand,Vector3(0,0.02,0.09),0.26,0.021,Color("c1af7c"))
		rim.rotation.z = PI/2
		for rivet in 8:
			var angle := rivet*TAU/8
			view.ball(shield_hand,Vector3(0.035,0.02+cos(angle)*0.22,0.09+sin(angle)*0.22),Vector3.ONE*0.024,Color("cbbb90"))
		view.ball(shield_hand,Vector3(0,0.02,0.13),Vector3(0.12,0.12,0.06),Color("d6bd80"))
	animator = AnimationPlayer.new()
	outfit.add_child(animator)
	animator.add_animation_library("",get_library(skeleton))

func attachment(bone: String) -> BoneAttachment3D:
	var result := BoneAttachment3D.new()
	result.bone_name = bone
	skeleton.add_child(result)
	return result

static func get_library(rig: Skeleton3D) -> AnimationLibrary:
	if animation_library: return animation_library
	animation_library = AnimationLibrary.new()
	var source: Node = load(ASSETS+"hero_animations.glb").instantiate()
	var player: AnimationPlayer = source.get_node("AnimationPlayer")
	for pair in [["idle","Idle_Shield"],["mage_idle","Idle_Lantern"],["walk","Walk_Carry"],["attack","Sword_Regular_A"],["attack_b","Sword_Regular_B"],["cast","OverhandThrow"],["hit","Hit_Knockback"]]:
		var animation: Animation = player.get_animation(pair[1]).duplicate()
		animation.loop_mode = Animation.LOOP_LINEAR if pair[0] in ["idle","mage_idle","walk"] else Animation.LOOP_NONE
		# Keep pelvis translation for natural footfall; the in-place source has no root motion.
		if pair[0] in ["idle","mage_idle"]: animation = preload("res://examples/gauntlet/hero_motion.gd").quiet_idle(animation)
		animation_library.add_animation(pair[0],animation)
	animation_library.remove_animation("hit")
	animation_library.add_animation("hit",preload("res://examples/gauntlet/hero_motion.gd").hit_animation(rig))
	for firing in [false,true]:
		var bow: Animation = preload("res://examples/gauntlet/hero_motion.gd").bow_animation(rig,firing)
		var base: Animation = animation_library.get_animation("idle").duplicate()
		base.length = bow.length
		base.loop_mode = bow.loop_mode
		for track in bow.get_track_count():
			var existing := base.find_track(bow.track_get_path(track),Animation.TYPE_ROTATION_3D)
			if existing>=0: base.remove_track(existing)
			bow.copy_track(track,base)
		animation_library.add_animation("bow_shot" if firing else "bow_idle",base)
	for action in ["idle","shot","spell"]:
		var arms: Animation = preload("res://examples/gauntlet/hero_motion.gd").mage_animation(rig,action)
		var base: Animation = animation_library.get_animation("mage_idle").duplicate()
		base.length = arms.length
		base.loop_mode = arms.loop_mode
		for track in arms.get_track_count():
			var existing := base.find_track(arms.track_get_path(track),Animation.TYPE_ROTATION_3D)
			if existing>=0: base.remove_track(existing)
			arms.copy_track(track,base)
		var key: String = "mage_"+action
		if animation_library.has_animation(key): animation_library.remove_animation(key)
		animation_library.add_animation(key,base)
	source.free()
	return animation_library

func present(hero: Dictionary, delta := 1.0/60, playing := true) -> void:
	managed = true
	var displacement: Vector2 = hero.pos-motion.last_position if motion.initialized else Vector2.ZERO
	motion.advance(hero,delta,playing)
	if not playing: return
	# Aim changes smoothly; collision and projectile direction remain responsive in the simulation.
	outfit.rotation.y = lerp_angle(outfit.rotation.y,atan2(hero.face.x,hero.face.y),1.0-exp(-delta*20.0))
	fall = move_toward(fall,1.0 if hero.hp<=0 else 0.0,delta*3.0)
	outfit.rotation.z = -smoothstep(0,1,fall)*PI/2
	outfit.position.y = 0.12*fall
	if robe_skirt and delta>0:
		var velocity := Vector3.ZERO
		if hero.hp>0 and not hero.escaped and displacement.length()<64.0:
			velocity = Vector3(displacement.x,0,displacement.y)/(32.0*maxf(delta,0.001))
		# Simulated movement, not facing, determines drag; this also handles turns and blocked movement.
		robe_trail = robe_trail.lerp((-velocity*0.075).limit_length(0.30),1.0-exp(-delta*10.0))
		var pelvis := skeleton.find_bone("pelvis")
		robe_skirt.position = skeleton.get_bone_global_pose(pelvis).origin-skeleton.get_bone_global_rest(pelvis).origin
		var local_trail := outfit.basis.inverse()*robe_trail
		for cloth: MeshInstance3D in robe_skirt.get_children():
			cloth.mesh.surface_get_material(0).set_shader_parameter("trail",local_trail)

static func make_head(female: bool) -> ArrayMesh:
	var key := "female" if female else "male"
	if head_meshes.has(key): return head_meshes[key]
	var source: Node = load(ASSETS+"Superhero_"+("Female" if female else "Male")+"_FullBody.gltf").instantiate()
	var result := ArrayMesh.new()
	# Retain only head triangles, eyes and eyebrows, using the original UVs/materials.
	for item in source.get_node("Armature/Skeleton3D").get_children():
		if not item is MeshInstance3D: continue
		for surface in item.mesh.get_surface_count():
			var arrays: Array = item.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var builder := SurfaceTool.new()
			builder.begin(Mesh.PRIMITIVE_TRIANGLES)
			var count := 0
			for i in range(0,indices.size(),3):
				if vertices[indices[i]].y<1.53 or vertices[indices[i+1]].y<1.53 or vertices[indices[i+2]].y<1.53: continue
				for j in 3:
					var index := indices[i+j]
					builder.set_normal(normals[index])
					builder.set_uv(uvs[index])
					builder.add_vertex(vertices[index])
					count += 1
			if count:
				builder.set_material(item.mesh.surface_get_material(surface))
				builder.generate_tangents()
				builder.index()
				builder.commit(result)
	source.free()
	head_meshes[key] = result
	return result
