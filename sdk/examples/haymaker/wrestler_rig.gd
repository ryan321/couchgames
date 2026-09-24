extends Node3D
## Quaternius Universal Base humanoid with wrestler colors and a brawler blend tree.

const CHARACTERS := "res://examples/gauntlet/assets/characters/"
const SOLDIER := "res://examples/sunbreak/assets/characters/"
const PALETTES: Array[Color] = [Color("e24b4b"), Color("1f8a7a"), Color("7b3cff"), Color("e8b43a")]

static var library: AnimationLibrary

var kind := 0
var model: Node3D
var skeleton: Skeleton3D
var animator: AnimationPlayer
var tree: AnimationTree
var speed := 0.0
var hips_yaw := 0.0
var flash_left := 0.0
var move_name := "idle"


func setup(body_kind: int, tint: Color) -> void:
	kind = body_kind
	var female: bool = body_kind == 2 or body_kind == 3
	var path := CHARACTERS + ("Superhero_Female_FullBody.gltf" if female else "Superhero_Male_FullBody.gltf")
	model = load(path).instantiate()
	add_child(model)
	model.rotation.y = PI
	var scales := [Vector3(1.18, 1.04, 1.18), Vector3(1.04, 1.06, 1.04), Vector3(0.92, 0.9, 0.98), Vector3(0.88, 1.16, 0.88)]
	model.scale = scales[kind]
	skeleton = model.get_node("Armature/Skeleton3D")
	var paint: Color = PALETTES[kind]
	paint = paint.lerp(tint, 0.25)
	for part in skeleton.get_children():
		if not (part is MeshInstance3D):
			continue
		if part.name in ["Eyes", "Eyebrows", "Cape", "cape"]:
			if part.name in ["Cape", "cape"]:
				part.visible = false
			continue
		var mat: StandardMaterial3D = part.mesh.surface_get_material(0).duplicate()
		if part.name.to_lower().contains("hair"):
			mat.albedo_color = Color("1c1a22") if kind != 1 else Color("2a3a8a")
		else:
			mat.albedo_color = paint
			mat.roughness = 0.48
			mat.metallic = 0.08
		part.material_override = mat
	_gear(paint)
	animator = AnimationPlayer.new()
	model.add_child(animator)
	animator.add_animation_library("", animations())
	_make_tree()


func _gear(paint: Color) -> void:
	var belt := BoneAttachment3D.new()
	belt.bone_name = "spine_01"
	skeleton.add_child(belt)
	var band := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.11
	torus.outer_radius = 0.17
	band.mesh = torus
	band.position = Vector3(0, 0.02, 0)
	band.rotation_degrees = Vector3(90, 0, 0)
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color("f0c43a")
	gold.metallic = 0.7
	gold.roughness = 0.32
	band.material_override = gold
	belt.add_child(band)
	var chest := BoneAttachment3D.new()
	chest.bone_name = "spine_03"
	skeleton.add_child(chest)
	var strap := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.12, 0.42, 0.04)
	strap.mesh = box
	strap.position = Vector3(0.16, 0.08, 0.08)
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = paint.lightened(0.12)
	cloth.roughness = 0.7
	strap.material_override = cloth
	chest.add_child(strap)


func _make_tree() -> void:
	var graph := AnimationNodeBlendTree.new()
	for pair in [["idle", "idle"], ["walk", "walk"], ["run", "run"], ["strike", "strike"],
			["strike2", "strike2"], ["vicious", "vicious"], ["hit", "hit"]]:
		var clip := AnimationNodeAnimation.new()
		clip.animation = pair[1]
		graph.add_node(pair[0], clip)
	graph.add_node("stride", AnimationNodeTimeScale.new())
	graph.connect_node("stride", 0, "run")
	graph.add_node("locomotion", AnimationNodeBlend2.new())
	graph.connect_node("locomotion", 0, "idle")
	graph.connect_node("locomotion", 1, "stride")
	var strike := AnimationNodeOneShot.new()
	strike.fadein_time = 0.04
	strike.fadeout_time = 0.12
	graph.add_node("do_strike", strike)
	graph.connect_node("do_strike", 0, "locomotion")
	graph.connect_node("do_strike", 1, "strike")
	var strike2 := AnimationNodeOneShot.new()
	strike2.fadein_time = 0.04
	strike2.fadeout_time = 0.12
	graph.add_node("do_strike2", strike2)
	graph.connect_node("do_strike2", 0, "do_strike")
	graph.connect_node("do_strike2", 1, "strike2")
	var vicious := AnimationNodeOneShot.new()
	vicious.fadein_time = 0.05
	vicious.fadeout_time = 0.16
	graph.add_node("do_vicious", vicious)
	graph.connect_node("do_vicious", 0, "do_strike2")
	graph.connect_node("do_vicious", 1, "vicious")
	var hit := AnimationNodeOneShot.new()
	hit.fadein_time = 0.03
	hit.fadeout_time = 0.14
	graph.add_node("do_hit", hit)
	graph.connect_node("do_hit", 0, "do_vicious")
	graph.connect_node("do_hit", 1, "hit")
	graph.connect_node("output", 0, "do_hit")
	tree = AnimationTree.new()
	model.add_child(tree)
	tree.anim_player = tree.get_path_to(animator)
	tree.tree_root = graph
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	tree.active = true
	tree.advance(0)


func play_strike(step: int) -> void:
	if step >= 2:
		tree.set("parameters/do_strike2/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	else:
		tree.set("parameters/do_strike/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func play_vicious() -> void:
	tree.set("parameters/do_vicious/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func play_hit() -> void:
	tree.set("parameters/do_hit/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func advance(delta: float, movement: Vector3) -> void:
	if tree == null:
		return
	speed = lerpf(speed, Vector2(movement.x, movement.z).length(), 1.0 - exp(-delta * 10.0))
	tree.set("parameters/locomotion/blend_amount", clampf(speed / 0.8, 0.0, 1.0))
	tree.set("parameters/stride/scale", clampf(speed / 2.8, 0.2, 1.8))
	var local_move := model.global_basis.inverse() * movement
	var desired := atan2(local_move.x, local_move.z) if speed > 0.15 else 0.0
	hips_yaw = lerp_angle(hips_yaw, clampf(desired, -1.1, 1.1), 1.0 - exp(-delta * 8.0))
	tree.advance(delta)
	flash_left = maxf(0.0, flash_left - delta)


static func animations() -> AnimationLibrary:
	if library:
		return library
	library = AnimationLibrary.new()
	var hero: Node = load(CHARACTERS + "hero_animations.glb").instantiate()
	var player: AnimationPlayer = hero.get_node("AnimationPlayer")
	for pair in [["idle", "Idle_Shield"], ["walk", "Walk_Carry"], ["strike", "Sword_Regular_A"],
			["strike2", "Sword_Regular_B"], ["vicious", "OverhandThrow"], ["hit", "Hit_Knockback"]]:
		if player.has_animation(pair[1]):
			var clip: Animation = player.get_animation(pair[1]).duplicate()
			clip.loop_mode = Animation.LOOP_LINEAR if pair[0] in ["idle", "walk"] else Animation.LOOP_NONE
			library.add_animation(pair[0], clip)
	hero.queue_free()
	var soldier: Node = load(SOLDIER + "soldier_animations.glb").instantiate()
	var jog_player: AnimationPlayer = soldier.get_node("AnimationPlayer")
	if jog_player.has_animation("Jog_Fwd"):
		var jog: Animation = jog_player.get_animation("Jog_Fwd").duplicate()
		jog.loop_mode = Animation.LOOP_LINEAR
		library.add_animation("run", jog)
	elif library.has_animation("walk"):
		library.add_animation("run", library.get_animation("walk").duplicate())
	soldier.queue_free()
	for required in ["idle", "walk", "run", "strike", "strike2", "vicious", "hit"]:
		if not library.has_animation(required):
			var empty := Animation.new()
			empty.length = 0.3
			library.add_animation(required, empty)
	return library
