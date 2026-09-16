extends Node3D
## Presentation rig only: the CharacterBody3D remains authoritative for movement/hits.
const Art = preload("res://examples/sunbreak/art.gd")
const ASSETS := "res://examples/sunbreak/assets/characters/"
static var library: AnimationLibrary
var model: Node3D
var skeleton: Skeleton3D
var animator: AnimationPlayer
var tree: AnimationTree
var visor: MeshInstance3D
var gun: Node3D
var muzzle: Node3D
var speed := 0.0
var dead := false
var death_time := 0.0
var flash_left := 0.0
var hips_yaw := 0.0

func _ready() -> void:
	model = load(ASSETS+"Superhero_Male_FullBody.gltf").instantiate()
	add_child(model)
	model.rotation.y = PI
	model.scale = Vector3.ONE*1.07
	skeleton = model.get_node("Armature/Skeleton3D")
	for part in skeleton.get_children():
		if part is MeshInstance3D:
			if part.name in ["Eyes","Eyebrows"]:
				part.visible = false
				continue
			var suit: StandardMaterial3D = part.mesh.surface_get_material(0).duplicate()
			suit.albedo_texture = null
			suit.albedo_color = Color("293c43")
			suit.metallic = 0.25
			suit.roughness = 0.66
			part.material_override = suit
	var chest := socket("spine_03")
	Art.box(chest,Vector3(0,1.33,0.04),Vector3(0.49,0.37,0.33),"9e6657",false,0.6)
	for x in [-0.13,0.13]:
		Art.box(chest,Vector3(x,1.39,0.227),Vector3(0.20,0.13,0.08),"c49873",false,0.7)
		for y in [1.24,1.30]: Art.box(chest,Vector3(x,y,0.24),Vector3(0.17,0.025,0.015),"253c44")
	Art.box(chest,Vector3(0,1.34,0.245),Vector3(0.04,0.14,0.015),"ffe1a5").material_override = Art.material("ffad61",0,0.8)
	Art.box(chest,Vector3(0,1.29,-0.2),Vector3(0.38,0.44,0.16),"4f6668",false,0.5)
	var head := socket("Head")
	Art.sphere(head,Vector3(0,1.7,0),Vector3(0.155,0.19,0.16),"a1aea4").material_override = Art.material("a1aea4",0.65)
	Art.box(head,Vector3(0,1.66,0.13),Vector3(0.28,0.12,0.13),"263b44",false,0.65)
	visor = Art.box(head,Vector3(0,1.705,0.196),Vector3(0.245,0.042,0.015),"ff9c58")
	visor.material_override = Art.material("ff9c58",0.3,1.5)
	Art.box(head,Vector3(0,1.56,0.115),Vector3(0.16,0.06,0.14),"596d70",false,0.8)
	for side in ["l","r"]:
		var sign_x := 1 if side=="l" else -1
		var shoulder := socket("upperarm_"+side)
		Art.sphere(shoulder,Vector3(sign_x*0.235,1.45,-0.015),Vector3(0.16,0.14,0.17),"c39571").material_override = Art.material("c39571",0.5)
		var wrist := socket("lowerarm_"+side)
		Art.box(wrist,Vector3(sign_x*0.55,1.46,-0.02),Vector3(0.23,0.12,0.15),"778c89",false,0.65)
		var shin := socket("calf_"+side)
		Art.box(shin,Vector3(sign_x*0.116,0.37,0.022),Vector3(0.15,0.3,0.13),"9e6657",false,0.55)
		Art.sphere(shin,Vector3(sign_x*0.116,0.56,0.025),Vector3(0.10,0.10,0.10),"c9b898")
		var thigh := socket("thigh_"+side)
		Art.box(thigh,Vector3(sign_x*0.13,0.78,0.035),Vector3(0.16,0.2,0.12),"647574",false,0.4)
	animator = AnimationPlayer.new()
	model.add_child(animator)
	animator.add_animation_library("",animations())
	var graph := AnimationNodeBlendTree.new()
	for pair in [["idle","Pistol_Idle"],["walk","Walk"],["run","Jog_Fwd"],["aim","Pistol_Aim_Neutral"],["shot","Pistol_Shoot"],["hit","Hit_Chest"]]:
		var clip := AnimationNodeAnimation.new()
		clip.animation = pair[1]
		graph.add_node(pair[0],clip)
	graph.add_node("stride",AnimationNodeTimeScale.new())
	graph.connect_node("stride",0,"run")
	graph.add_node("locomotion",AnimationNodeBlend2.new())
	graph.connect_node("locomotion",0,"idle")
	graph.connect_node("locomotion",1,"stride")
	var aim := AnimationNodeBlend2.new()
	upper_filter(aim)
	graph.add_node("upper",aim)
	graph.connect_node("upper",0,"locomotion")
	graph.connect_node("upper",1,"aim")
	var shot := AnimationNodeOneShot.new()
	upper_filter(shot)
	shot.fadein_time = 0.025
	shot.fadeout_time = 0.12
	graph.add_node("shoot",shot)
	graph.connect_node("shoot",0,"upper")
	graph.connect_node("shoot",1,"shot")
	var hit := AnimationNodeOneShot.new()
	upper_filter(hit)
	hit.fadein_time = 0.035
	hit.fadeout_time = 0.16
	graph.add_node("flinch",hit)
	graph.connect_node("flinch",0,"shoot")
	graph.connect_node("flinch",1,"hit")
	graph.connect_node("output",0,"flinch")
	tree = AnimationTree.new()
	model.add_child(tree)
	tree.anim_player = tree.get_path_to(animator)
	tree.tree_root = graph
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	tree.active = true
	tree.set("parameters/upper/blend_amount",1.0)
	tree.advance(0)
	var hand := BoneAttachment3D.new()
	hand.bone_name = "hand_r"
	skeleton.add_child(hand)
	gun = Node3D.new()
	hand.add_child(gun)
	gun.basis = skeleton.get_bone_global_pose(skeleton.find_bone("hand_r")).basis.inverse()
	Art.box(gun,Vector3(0,0.045,0.08),Vector3(0.12,0.14,0.43),"334e59",false,0.65)
	Art.box(gun,Vector3(0,-0.06,0),Vector3(0.065,0.18,0.10),"23363c")
	Art.segment(gun,Vector3(0,0.065,0.28),Vector3(0,0.065,0.40),0.035,"748e91",0.7)
	muzzle = Node3D.new()
	gun.add_child(muzzle)
	muzzle.position = Vector3(0,0.065,0.42)

func socket(bone: String) -> Node3D:
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = bone
	skeleton.add_child(attachment)
	var space := Node3D.new()
	attachment.add_child(space)
	space.transform = skeleton.get_bone_global_rest(skeleton.find_bone(bone)).affine_inverse()
	return space

func upper_filter(node: AnimationNode) -> void:
	node.filter_enabled = true
	var spine := skeleton.find_bone("spine_01")
	for i in skeleton.get_bone_count():
		var parent := i
		while parent>=0 and parent!=spine: parent = skeleton.get_bone_parent(parent)
		if parent==spine: node.set_filter_path(NodePath("Armature/Skeleton3D:"+skeleton.get_bone_name(i)),true)

static func animations() -> AnimationLibrary:
	if library: return library
	library = AnimationLibrary.new()
	var source: Node3D = load(ASSETS+"soldier_animations.glb").instantiate()
	var player: AnimationPlayer = source.get_node("AnimationPlayer")
	for name in ["Pistol_Idle","Pistol_Aim_Neutral","Walk","Jog_Fwd","Pistol_Shoot","Hit_Chest","Death01"]:
		var clip: Animation = player.get_animation(name).duplicate()
		clip.loop_mode = Animation.LOOP_LINEAR if name in ["Pistol_Idle","Walk","Jog_Fwd"] else Animation.LOOP_NONE
		if name=="Pistol_Aim_Neutral":
			clip.loop_mode = Animation.LOOP_LINEAR
			clip.length = 2
			for track in clip.get_track_count():
				var value: Variant = clip.track_get_key_value(track,0)
				while clip.track_get_key_count(track)>0: clip.track_remove_key(track,0)
				clip.track_insert_key(track,0,value)
				clip.track_insert_key(track,2,value)
		library.add_animation(name,clip)
	source.free()
	return library

func advance(delta: float, movement: Vector3, charging: bool) -> void:
	if dead:
		death_time += delta
		animator.advance(delta)
		if death_time>2.7: position.y = -(death_time-2.7)*0.8
		return
	speed = lerpf(speed,Vector2(movement.x,movement.z).length(),1-exp(-delta*10))
	tree.set("parameters/locomotion/blend_amount",clampf(speed/0.7,0,1))
	var local_move := model.global_basis.inverse()*movement
	var desired := atan2(local_move.x,local_move.z) if speed>0.15 else 0.0
	var backwards := absf(desired)>PI*0.6
	if backwards: desired = wrapf(desired+PI,-PI,PI)
	hips_yaw = lerp_angle(hips_yaw,clampf(desired,-1.3,1.3),1-exp(-delta*8))
	tree.set("parameters/stride/scale",clampf(speed/2.6,0.15,1.7)*(-1 if backwards else 1))
	skeleton.reset_bone_pose(skeleton.find_bone("spine_01"))
	tree.advance(delta)
	var pelvis := skeleton.find_bone("pelvis")
	var spine := skeleton.find_bone("spine_01")
	turn_bone_about_up(pelvis,hips_yaw)
	turn_bone_about_up(spine,-hips_yaw)
	visor.scale = visor.scale.lerp(Vector3.ONE*(1.3 if charging else 1),1-exp(-delta*12))
	flash_left = maxf(0,flash_left-delta)
	gun.position.z = -flash_left*0.3

func turn_bone_about_up(bone: int, angle: float) -> void:
	# Pose rotations live in the parent bone frame, not world space. The root
	# of this imported rig is Z-up; using local Y rolls a strafing soldier over.
	var parent := skeleton.get_bone_parent(bone)
	var parent_basis := skeleton.get_bone_global_pose(parent).basis if parent>=0 else Basis.IDENTITY
	var up := (parent_basis.inverse()*Vector3.UP).normalized()
	skeleton.set_bone_pose_rotation(bone,Quaternion(up,angle)*skeleton.get_bone_pose_rotation(bone))

func fire() -> void:
	tree.set("parameters/shoot/request",AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	flash_left = 0.12

func hit() -> void:
	if not dead: tree.set("parameters/flinch/request",AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func die() -> void:
	dead = true
	tree.active = false
	animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	animator.play("Death01",0.12)
	animator.advance(0)
