class_name HaymakerFighter
extends CharacterBody3D
## Host-simulated brawler. Clients display interpolated copies of the same node.

const World = preload("res://examples/haymaker/world.gd")
const SPEED := 7.4
const GRAVITY := 26.0
const JUMP_SPEED := 9.6
const COLORS: Array[Color] = [Color("ed7559"), Color("5ba7db"), Color("d6ab43"), Color("ad84c6"),
	Color("57b99c"), Color("e38eb0"), Color("95a74c"), Color("dd9653")]

var fighter_id := 1
var peer_id := 1
var is_bot := false
var color := Color("ed7559")
var health := 100.0
var armor := 0.0
var weapon := ""
var weapon_left := 0.0
var alive := true
var look_yaw := 0.0
var punch_left := 0.0
var heavy_left := 0.0
var dodge_left := 0.0
var invuln_left := 0.0
var attacking := 0.0
var input_dir := Vector2.ZERO
var input_jump := false
var input_punch := false
var input_heavy := false
var input_dodge := false
var model: Node3D
var number: Label3D
var arm_r: Node3D
var fist_r: MeshInstance3D
var _time := 0.0
var _heavy_swing := false
var _coyote := 0.0
var _jump_buffer := 0.0
var _prev_punch := false
var _prev_heavy := false
var _prev_dodge := false
var _prev_jump := false


func setup(id: int, network_peer: int, bot: bool) -> void:
	fighter_id = id
	peer_id = network_peer
	is_bot = bot
	color = COLORS[(id - 1) % COLORS.size()]
	name = "Fighter_%d" % id


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 2
	floor_snap_length = 0.2
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.7
	collision.shape = capsule
	collision.position.y = 0.85
	add_child(collision)
	model = Node3D.new()
	add_child(model)
	var body := CapsuleMesh.new()
	body.radius = 0.48
	body.height = 1.18
	World.mesh(model, body, Vector3(0, 1.02, 0), color, 0.55)
	World.mesh(model, SphereMesh.new(), Vector3(0, 1.68, 0.06), Color("f3c7a0")).scale = Vector3(0.78, 0.78, 0.78)
	World.mesh(model, SphereMesh.new(), Vector3(0, 1.92, 0.0), color.darkened(0.15)).scale = Vector3(0.62, 0.28, 0.62)
	World.mesh(model, BoxMesh.new(), Vector3(0, 0.62, 0.02), Color("2b2b32"), 0.7).scale = Vector3(0.95, 0.42, 0.7)
	for side in [-1.0, 1.0]:
		World.mesh(model, SphereMesh.new(), Vector3(side * 0.17, 1.72, 0.30), Color("1c2a32")).scale = Vector3(0.11, 0.13, 0.07)
		World.mesh(model, SphereMesh.new(), Vector3(side * 0.22, 0.18, 0.06), Color("2a2420")).scale = Vector3(0.34, 0.26, 0.42)
	arm_r = Node3D.new()
	arm_r.position = Vector3(0.52, 1.12, 0.04)
	model.add_child(arm_r)
	World.mesh(arm_r, CapsuleMesh.new(), Vector3(0, -0.18, 0), color.lightened(0.08), 0.5).scale = Vector3(0.28, 0.55, 0.28)
	fist_r = World.mesh(arm_r, SphereMesh.new(), Vector3(0, -0.46, 0.02), Color("f3c7a0"), 0.45)
	fist_r.scale = Vector3(0.32, 0.32, 0.38)
	var arm_l := Node3D.new()
	arm_l.position = Vector3(-0.52, 1.12, 0.04)
	model.add_child(arm_l)
	World.mesh(arm_l, CapsuleMesh.new(), Vector3(0, -0.18, 0), color.lightened(0.08), 0.5).scale = Vector3(0.28, 0.55, 0.28)
	World.mesh(arm_l, SphereMesh.new(), Vector3(0, -0.46, 0.02), Color("f3c7a0"), 0.45).scale = Vector3(0.3, 0.3, 0.34)
	number = Label3D.new()
	number.position.y = 2.25
	number.font_size = 48
	number.pixel_size = 0.01
	number.outline_size = 10
	number.modulate = Color("fff9e9")
	number.outline_modulate = Color("243c4b")
	number.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(number)
	_refresh_label()


func facing() -> Vector3:
	return (Basis(Vector3.UP, look_yaw) * Vector3(0, 0, -1)).normalized()


func punch_damage() -> float:
	return 28.0 if weapon == "bat" else 16.0


func heavy_damage() -> float:
	return 42.0 if weapon == "bat" else 28.0


func consume_edges() -> Dictionary:
	var punch := input_punch and not _prev_punch
	var heavy := input_heavy and not _prev_heavy
	var dodge := input_dodge and not _prev_dodge
	var jump := input_jump and not _prev_jump
	_prev_punch = input_punch
	_prev_heavy = input_heavy
	_prev_dodge = input_dodge
	_prev_jump = input_jump
	return {"punch": punch, "heavy": heavy, "dodge": dodge, "jump": jump}


func simulate(delta: float, authoritative: bool) -> void:
	_time += delta
	punch_left = maxf(0.0, punch_left - delta)
	heavy_left = maxf(0.0, heavy_left - delta)
	dodge_left = maxf(0.0, dodge_left - delta)
	invuln_left = maxf(0.0, invuln_left - delta)
	attacking = maxf(0.0, attacking - delta)
	weapon_left = maxf(0.0, weapon_left - delta)
	if weapon_left <= 0.0:
		weapon = ""
	if not alive:
		velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
		velocity.y -= GRAVITY * delta
		if authoritative:
			move_and_slide()
		_refresh_label()
		return
	var direction := Basis(Vector3.UP, look_yaw) * Vector3(input_dir.x, 0.0, input_dir.y)
	var speed := SPEED * (1.55 if dodge_left > 0.18 else 1.0)
	if attacking > 0.12:
		speed *= 0.45
	if authoritative:
		velocity.x = move_toward(velocity.x, direction.x * speed, 38.0 * delta)
		velocity.z = move_toward(velocity.z, direction.z * speed, 38.0 * delta)
		_coyote = 0.1 if is_on_floor() else maxf(0.0, _coyote - delta)
		_jump_buffer = maxf(0.0, _jump_buffer - delta)
		if input_jump:
			_jump_buffer = 0.12
		if _jump_buffer > 0.0 and _coyote > 0.0:
			velocity.y = JUMP_SPEED
			_coyote = 0.0
			_jump_buffer = 0.0
		else:
			velocity.y -= GRAVITY * delta
		move_and_slide()
	if direction.length() > 0.08:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(direction.x, direction.z), 14.0 * delta)
	elif attacking > 0.0:
		var look := facing()
		model.rotation.y = lerp_angle(model.rotation.y, atan2(look.x, look.z), 16.0 * delta)
	var stride := sin(_time * 14.0) * minf(Vector2(velocity.x, velocity.z).length() / SPEED, 1.0)
	model.position.y = absf(stride) * 0.04 if is_on_floor() else 0.08
	_pose_arms()
	_refresh_label()


func begin_punch(heavy: bool) -> void:
	_heavy_swing = heavy
	if heavy:
		heavy_left = 0.72
		attacking = 0.42
		velocity += facing() * 7.5
		velocity.y = maxf(velocity.y, 1.2)
	else:
		punch_left = 0.28
		attacking = 0.26
		velocity += facing() * 5.2


func begin_dodge() -> void:
	dodge_left = 0.34
	invuln_left = 0.28
	var dash := facing() * 11.0
	velocity.x = dash.x
	velocity.z = dash.z


func take_hit(amount: float, from_dir: Vector3) -> void:
	if not alive or invuln_left > 0.0:
		return
	var absorbed := minf(armor, amount)
	armor -= absorbed
	health = maxf(0.0, health - (amount - absorbed))
	invuln_left = 0.14
	_flash(Color("ff6b5a"))
	var push := from_dir
	push.y = 0.0
	if push.length() > 0.01:
		push = push.normalized()
		velocity += push * (7.5 + amount * 0.08)
		velocity.y = maxf(velocity.y, 3.2)
	if health <= 0.0:
		alive = false
		health = 0.0
		armor = 0.0


func heal(amount: float) -> void:
	if not alive:
		return
	health = minf(100.0, health + amount)


func add_armor(amount: float) -> void:
	if not alive:
		return
	armor = minf(80.0, armor + amount)


func give_bat(seconds: float = 18.0) -> void:
	if not alive:
		return
	weapon = "bat"
	weapon_left = seconds


func snapshot() -> Dictionary:
	return {
		"id": fighter_id,
		"peer": peer_id,
		"bot": is_bot,
		"pos": [position.x, position.y, position.z],
		"vel": [velocity.x, velocity.y, velocity.z],
		"yaw": look_yaw,
		"health": health,
		"armor": armor,
		"weapon": weapon,
		"alive": alive,
		"attacking": attacking,
	}


func apply_snapshot(data: Dictionary) -> void:
	fighter_id = int(data.get("id", fighter_id))
	peer_id = int(data.get("peer", peer_id))
	is_bot = bool(data.get("bot", is_bot))
	var pos: Array = data.get("pos", [position.x, position.y, position.z])
	position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	var vel: Array = data.get("vel", [velocity.x, velocity.y, velocity.z])
	velocity = Vector3(float(vel[0]), float(vel[1]), float(vel[2]))
	look_yaw = float(data.get("yaw", look_yaw))
	health = float(data.get("health", health))
	armor = float(data.get("armor", armor))
	weapon = str(data.get("weapon", weapon))
	alive = bool(data.get("alive", alive))
	attacking = float(data.get("attacking", attacking))
	_refresh_label()


func _pose_arms() -> void:
	if arm_r == null:
		return
	if attacking > 0.0:
		var span := 0.42 if _heavy_swing else 0.26
		var t := 1.0 - clampf(attacking / span, 0.0, 1.0)
		var swing := sin(t * PI)
		arm_r.rotation_degrees = Vector3(-18.0 - swing * (70.0 if _heavy_swing else 48.0), 18.0, 8.0)
		arm_r.position = Vector3(0.52, 1.12, -swing * (0.55 if _heavy_swing else 0.38))
		if fist_r:
			fist_r.scale = Vector3(0.38, 0.38, 0.5) * (1.0 + swing * 0.35)
	else:
		arm_r.rotation_degrees = Vector3(-8.0, 8.0, 6.0)
		arm_r.position = Vector3(0.52, 1.12, 0.04)
		if fist_r:
			fist_r.scale = Vector3(0.32, 0.32, 0.38)


func _flash(tint: Color) -> void:
	if model == null:
		return
	for child in model.get_children():
		if child is MeshInstance3D and child.material_override is StandardMaterial3D:
			(child.material_override as StandardMaterial3D).emission_enabled = true
			(child.material_override as StandardMaterial3D).emission = tint
			(child.material_override as StandardMaterial3D).emission_energy_multiplier = 1.6
	get_tree().create_timer(0.12).timeout.connect(func():
		if not is_instance_valid(model):
			return
		for child in model.get_children():
			if child is MeshInstance3D and child.material_override is StandardMaterial3D:
				(child.material_override as StandardMaterial3D).emission_energy_multiplier = 0.0)


func _refresh_label() -> void:
	if number == null:
		return
	var tag := "BOT" if is_bot else "P%d" % fighter_id
	if not alive:
		number.text = "%s · OUT" % tag
		number.modulate = Color("ffcf8b")
	elif weapon == "bat":
		number.text = "%s · BAT" % tag
		number.modulate = Color("ffe28a")
	else:
		number.text = tag
		number.modulate = Color("fff9e9")
