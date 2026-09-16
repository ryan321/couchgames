extends RefCounted
## A per-hero blend tree: locomotion never stops when an upper-body action plays.
var tree: AnimationTree
var graph := AnimationNodeBlendTree.new()
var attack_clip := AnimationNodeAnimation.new()
var speed := 0.0
var last_position := Vector2.ZERO
var initialized := false
var attack_serial := 0
var magic_serial := 0
var hit_serial := 0
var kind := 0

func configure(outfit: Node3D, player: AnimationPlayer, skeleton: Skeleton3D, hero_class: int) -> void:
	kind = hero_class
	clip("idle","bow_idle" if kind==3 else ("mage_idle" if kind==2 else "idle"))
	clip("walk","walk")
	graph.add_node("stride",AnimationNodeTimeScale.new())
	graph.connect_node("stride",0,"walk")
	var locomotion := AnimationNodeBlend2.new()
	# Preserve the class's ready pose in the arms; blend the pelvis and legs into a stride.
	locomotion.filter_enabled = true
	for bone in ["pelvis","thigh_l","calf_l","foot_l","ball_l","thigh_r","calf_r","foot_r","ball_r"]:
		locomotion.set_filter_path(NodePath("Armature/Skeleton3D:"+bone),true)
	graph.add_node("locomotion",locomotion)
	graph.connect_node("locomotion",0,"idle")
	graph.connect_node("locomotion",1,"stride")
	attack_clip.animation = "attack"
	graph.add_node("attack_clip",attack_clip)
	graph.add_node("attack_speed",AnimationNodeTimeScale.new())
	graph.connect_node("attack_speed",0,"attack_clip")
	upper_action("attack","locomotion","attack_speed",skeleton)
	clip("spell_clip","mage_spell" if kind==2 else "cast")
	graph.add_node("spell_speed",AnimationNodeTimeScale.new())
	graph.connect_node("spell_speed",0,"spell_clip")
	upper_action("spell","attack","spell_speed",skeleton)
	clip("hit_clip","hit")
	graph.add_node("hit_speed",AnimationNodeTimeScale.new())
	graph.connect_node("hit_speed",0,"hit_clip")
	upper_action("hit","spell","hit_speed",skeleton)
	graph.connect_node("output",0,"hit")
	tree = AnimationTree.new()
	tree.name = "Motion"
	tree.tree_root = graph
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	outfit.add_child(tree)
	tree.anim_player = tree.get_path_to(player)
	tree.active = true
	tree.set("parameters/stride/scale",2.5)
	tree.set("parameters/spell_speed/scale",1.8)
	tree.set("parameters/hit_speed/scale",1.0)

func clip(node_name: String, animation: String) -> void:
	var node := AnimationNodeAnimation.new()
	node.animation = animation
	graph.add_node(node_name,node)

func upper_action(node_name: String, base: String, action: String, skeleton: Skeleton3D) -> void:
	var node := AnimationNodeOneShot.new()
	node.fadein_time = 0.045
	node.fadeout_time = 0.09
	node.filter_enabled = true
	var spine := skeleton.find_bone("spine_01")
	for bone in skeleton.get_bone_count():
		var parent := bone
		while parent>=0 and parent!=spine: parent = skeleton.get_bone_parent(parent)
		if parent==spine and (node_name!="hit" or skeleton.get_bone_name(bone) in ["spine_01","spine_02","Head"]):
			node.set_filter_path(NodePath("Armature/Skeleton3D:"+skeleton.get_bone_name(bone)),true)
	graph.add_node(node_name,node)
	graph.connect_node(node_name,0,base)
	graph.connect_node(node_name,1,action)

func advance(hero: Dictionary, delta: float, playing: bool) -> void:
	if not initialized:
		last_position = hero.pos
		attack_serial = hero.get("attack_serial",0)
		magic_serial = hero.get("magic_serial",0)
		hit_serial = hero.get("hit_serial",0)
		initialized = true
	var distance: float = last_position.distance_to(hero.pos)/32.0
	last_position = hero.pos
	if not playing or delta<=0: return
	var measured := minf(4.5,distance/maxf(delta,0.001)) if distance<2.0 else 0.0
	speed = lerpf(speed,measured,1.0-exp(-delta*14.0))
	if hero.hp<=0 or hero.escaped: speed = 0.0
	tree.set("parameters/locomotion/blend_amount",clampf(speed/0.8,0,1))
	tree.set("parameters/stride/scale",clampf(speed/1.3,0.35,3.5))
	if hero.hp>0 and not hero.escaped:
		if hero.get("attack_serial",0)!=attack_serial:
			attack_serial = hero.attack_serial
			attack_clip.animation = ["axe_hold","attack" if attack_serial%2 else "attack_b","mage_shot","bow_shot"][kind]
			var duration: float = tree.get_node(tree.anim_player).get_animation(attack_clip.animation).length
			var cadence: float = preload("res://examples/gauntlet/level.gd").CLASSES[kind].rate
			tree.set("parameters/attack_speed/scale",duration/cadence)
			tree.set("parameters/attack/request",AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		if hero.get("magic_serial",0)!=magic_serial:
			magic_serial = hero.magic_serial
			tree.set("parameters/spell/request",AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		if hero.get("hit_serial",0)!=hit_serial:
			hit_serial = hero.hit_serial
			tree.set("parameters/hit/request",AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	tree.advance(delta)

static func bow_animation(skeleton: Skeleton3D, firing: bool) -> Animation:
	var animation := Animation.new()
	animation.length = 0.40 if firing else 2.5
	animation.loop_mode = Animation.LOOP_NONE if firing else Animation.LOOP_LINEAR
	for side in ["l","r"]:
		var tracks := []
		for name in ["upperarm_","lowerarm_"]:
			var track := animation.add_track(Animation.TYPE_ROTATION_3D)
			animation.track_set_path(track,NodePath("Armature/Skeleton3D:"+name+side))
			tracks.append(track)
		for frame in 5:
			var t := frame/4.0
			var release := sin(t*PI) if firing else 0.0
			var target := Vector3(0.20,1.40,0.44) if side=="l" else Vector3(0.08,1.43,0.13+release*0.15)
			var rotations := arm_pose(skeleton,side,target)
			for i in 2: animation.rotation_track_insert_key(tracks[i],t*animation.length,rotations[i])
	return animation

static func arm_pose(skeleton: Skeleton3D, side: String, hand: Vector3) -> Array[Quaternion]:
	var upper := skeleton.find_bone("upperarm_"+side)
	var lower := skeleton.find_bone("lowerarm_"+side)
	var wrist := skeleton.find_bone("hand_"+side)
	var a := skeleton.get_bone_global_rest(upper)
	var b := skeleton.get_bone_global_rest(lower)
	var c := skeleton.get_bone_global_rest(wrist)
	var first := a.origin.distance_to(b.origin)
	var second := b.origin.distance_to(c.origin)
	var direction := (hand-a.origin).normalized()
	var distance := clampf(hand.distance_to(a.origin),0.05,first+second-0.001)
	var along := (first*first-second*second+distance*distance)/(2*distance)
	var pole := Vector3(1 if side=="l" else -1,-0.3,0)
	var bend := (pole-direction*pole.dot(direction)).normalized()
	var elbow := a.origin+direction*along+bend*sqrt(maxf(0,first*first-along*along))
	var upper_basis := Basis(Quaternion((b.origin-a.origin).normalized(),(elbow-a.origin).normalized()))*a.basis
	var lower_basis := Basis(Quaternion((c.origin-b.origin).normalized(),(hand-elbow).normalized()))*b.basis
	var parent := skeleton.get_bone_global_rest(skeleton.get_bone_parent(upper)).basis
	return [(parent.inverse()*upper_basis).get_rotation_quaternion(),(upper_basis.inverse()*lower_basis).get_rotation_quaternion()]

static func mage_animation(skeleton: Skeleton3D, action: String) -> Animation:
	var animation := Animation.new()
	animation.length = 2.5 if action=="idle" else (0.7 if action=="spell" else 0.3)
	animation.loop_mode = Animation.LOOP_LINEAR if action=="idle" else Animation.LOOP_NONE
	for side in ["l","r"]:
		var tracks := []
		for name in ["upperarm_","lowerarm_"]:
			var track := animation.add_track(Animation.TYPE_ROTATION_3D)
			animation.track_set_path(track,NodePath("Armature/Skeleton3D:"+name+side))
			tracks.append(track)
		for frame in 5:
			var t := frame/4.0
			var pulse := sin(t*PI) if action!="idle" else 0.0
			# Keep the staff in the right hand; cast with the free hand instead of throwing the staff.
			var target := Vector3(-0.26,1.15,0.25) if side=="r" else Vector3(0.30-pulse*0.10,1.14+pulse*(0.39 if action=="spell" else 0.25),0.13+pulse*0.29)
			var rotations := arm_pose(skeleton,side,target)
			for i in 2: animation.rotation_track_insert_key(tracks[i],t*animation.length,rotations[i])
	return animation

static func hit_animation(rig: Skeleton3D) -> Animation:
	var animation := Animation.new()
	animation.length = 0.24
	# A few degrees through the torso and head; arms keep their current attack/casting pose.
	for name in ["spine_01","spine_02","Head"]:
		var index := rig.find_bone(name)
		var rest := rig.get_bone_rest(index).basis.get_rotation_quaternion()
		var track := animation.add_track(Animation.TYPE_ROTATION_3D)
		animation.track_set_path(track,NodePath("Armature/Skeleton3D:"+name))
		for key in 4:
			var angle: float = [0.0,0.075,-0.018,0.0][key]
			animation.rotation_track_insert_key(track,[0.0,0.055,0.14,0.24][key],rest*Quaternion(Vector3.RIGHT,angle*(0.6 if name=="Head" else 1.0)))
	return animation

static func quiet_idle(source: Animation) -> Animation:
	# Hold the ready pose. Imported shield/lantern idles include periodic arm gestures that read as attacks.
	var animation: Animation = source.duplicate()
	animation.length = 2.5
	animation.loop_mode = Animation.LOOP_LINEAR
	for track in animation.get_track_count():
		if animation.track_get_key_count(track)==0: continue
		var value: Variant = animation.track_get_key_value(track,0)
		while animation.track_get_key_count(track)>0: animation.track_remove_key(track,0)
		animation.track_insert_key(track,0,value)
		animation.track_insert_key(track,2.5,value)
	return animation
