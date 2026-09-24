class_name HaymakerFighter
extends CharacterBody3D
## Host-simulated brawler. Quaternius humanoid presentation; physics stay on this body.

const World = preload("res://examples/haymaker/world.gd")
const Rig = preload("res://examples/haymaker/wrestler_rig.gd")
const SPEED := 7.4
const DASH_SPEED := 12.2
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
var blocking := false
var dashing := false
var combo := 0
var combo_left := 0.0
var move := "idle"
var grab_target: HaymakerFighter
var grab_left := 0.0
var input_dir := Vector2.ZERO
var input_jump := false
var input_punch := false
var input_heavy := false
var input_dodge := false
var input_dash := false
var input_block := false
var model: Node3D
var number: Label3D
var rig: Node3D
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
	rig = Rig.new()
	model.add_child(rig)
	rig.setup((fighter_id - 1) % 4, color)
	number = Label3D.new()
	number.position.y = 2.35
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
	var step := 12.0 + float(combo) * 8.0
	return (step + 10.0) if weapon == "bat" else step


func heavy_damage() -> float:
	return 48.0 if weapon == "bat" else 34.0


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
	combo_left = maxf(0.0, combo_left - delta)
	if combo_left <= 0.0:
		combo = 0
	weapon_left = maxf(0.0, weapon_left - delta)
	if weapon_left <= 0.0:
		weapon = ""
	blocking = input_block and alive and dodge_left <= 0.0 and grab_left <= 0.0
	dashing = input_dash and alive and is_on_floor() and not blocking
	if grab_left > 0.0:
		_tick_grab(delta, authoritative)
	if not alive:
		velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
		velocity.y -= GRAVITY * delta
		if authoritative:
			move_and_slide()
		_refresh_label()
		return
	var direction := Basis(Vector3.UP, look_yaw) * Vector3(input_dir.x, 0.0, input_dir.y)
	var speed := DASH_SPEED if dashing else SPEED
	if blocking:
		speed *= 0.35
	if attacking > 0.12 and move != "dropkick":
		speed *= 0.4
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
			move = "jump"
		else:
			velocity.y -= GRAVITY * delta
		move_and_slide()
	if direction.length() > 0.08:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(direction.x, direction.z), 14.0 * delta)
	elif attacking > 0.0:
		var look := facing()
		model.rotation.y = lerp_angle(model.rotation.y, atan2(look.x, look.z), 16.0 * delta)
	if rig:
		rig.advance(delta, Vector3(velocity.x, 0.0, velocity.z))
	_refresh_label()


func begin_strike() -> void:
	if combo_left > 0.0 and combo < 3:
		combo += 1
	else:
		combo = 1
	combo_left = 0.45
	_heavy_swing = combo >= 3
	punch_left = 0.16 if combo < 3 else 0.32
	attacking = 0.22 if combo < 3 else 0.38
	move = "strike%d" % combo
	velocity += facing() * (4.2 + combo * 1.4)
	if rig:
		rig.play_strike(combo)


func begin_vicious(target: HaymakerFighter) -> void:
	_heavy_swing = true
	heavy_left = 0.7
	attacking = 0.55
	move = "vicious"
	if rig:
		rig.play_vicious()
	if target and target.alive:
		grab_target = target
		grab_left = 0.5
		target.invuln_left = 0.0
	else:
		velocity += facing() * 9.0


func begin_dropkick() -> void:
	_heavy_swing = true
	punch_left = 0.4
	attacking = 0.4
	move = "dropkick"
	var dash := facing() * 16.0
	velocity.x = dash.x
	velocity.z = dash.z
	velocity.y = maxf(velocity.y, 3.5)
	if rig:
		rig.play_strike(2)


func begin_elbow() -> void:
	_heavy_swing = true
	punch_left = 0.35
	attacking = 0.35
	move = "elbow"
	velocity.y = minf(velocity.y, -6.0)
	if rig:
		rig.play_strike(2)


func begin_dodge() -> void:
	dodge_left = 0.38
	invuln_left = 0.32
	move = "dodge"
	var away := facing()
	if input_dir.length() > 0.2:
		away = (Basis(Vector3.UP, look_yaw) * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	velocity.x = away.x * 12.5
	velocity.z = away.z * 12.5


func begin_punch(heavy: bool) -> void:
	if heavy:
		begin_vicious(null)
	else:
		begin_strike()


func _tick_grab(delta: float, authoritative: bool) -> void:
	grab_left = maxf(0.0, grab_left - delta)
	if grab_target == null or not is_instance_valid(grab_target) or not grab_target.alive:
		grab_left = 0.0
		grab_target = null
		return
	var hold := global_position + Vector3(0, 1.35, 0) + facing() * 0.85
	if authoritative:
		grab_target.global_position = grab_target.global_position.lerp(hold, 1.0 - exp(-delta * 18.0))
		grab_target.velocity = Vector3.ZERO
	if grab_left <= 0.18 and grab_target.health > 0.0:
		var launch := facing() * 14.0 + Vector3(0, 8.0, 0)
		grab_target.take_hit(heavy_damage(), facing(), true)
		grab_target.velocity = launch
		grab_target = null
		grab_left = 0.0


func take_hit(amount: float, from_dir: Vector3, knockdown := true) -> void:
	if not alive or invuln_left > 0.0:
		return
	if blocking and not knockdown:
		amount *= 0.28
	elif blocking:
		amount *= 0.45
	var absorbed := minf(armor, amount)
	armor -= absorbed
	health = maxf(0.0, health - (amount - absorbed))
	invuln_left = 0.12
	if rig:
		rig.play_hit()
		rig.flash_left = 0.12
	var push := from_dir
	push.y = 0.0
	if push.length() > 0.01:
		push = push.normalized()
		velocity += push * (7.5 + amount * 0.08)
		if knockdown:
			velocity.y = maxf(velocity.y, 3.2)
	if health <= 0.0:
		alive = false
		health = 0.0
		armor = 0.0
		move = "down"


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
		"move": move,
		"combo": combo,
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
	move = str(data.get("move", move))
	combo = int(data.get("combo", combo))
	_refresh_label()


func _refresh_label() -> void:
	if number == null:
		return
	var tag := "BOT" if is_bot else "P%d" % fighter_id
	if not alive:
		number.text = "%s · OUT" % tag
		number.modulate = Color("ffcf8b")
	elif blocking:
		number.text = "%s · BLOCK" % tag
		number.modulate = Color("9ad8ff")
	elif weapon == "bat":
		number.text = "%s · BAT" % tag
		number.modulate = Color("ffe28a")
	else:
		number.text = tag
		number.modulate = Color("fff9e9")
