extends CharacterBody3D
const Art = preload("res://examples/sunbreak/art.gd")
var game: Node3D
var camera: Camera3D
var weapon: Node3D
var flash: MeshInstance3D
var health := 100.0
var shield := 100.0
var ammo := 30
var reload_left := 0.0
var fire_left := 0.0
var recoil := 0.0
var bob := 0.0
var aim := false
var jump_queued := false
var trigger_armed := false
var pad := -1
var jump_buffer := 0.0
var coyote := 0.0
var landing := 0.0
var was_grounded := false
var vertical_before := 0.0
var sprinting := false
var look_ready := false
const LOOK_DEAD_ZONE := 0.22

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	collider.shape = capsule
	collider.position.y = 0.9
	add_child(collider)
	camera = Camera3D.new()
	camera.position.y = 1.62
	camera.fov = 82
	camera.near = 0.05
	add_child(camera)
	camera.current = true
	weapon = preload("res://examples/sunbreak/weapon.gd").new()
	camera.add_child(weapon)
	flash = weapon.flash
	weapon.position = Vector3(0.22,-0.22,-0.48)

func reset() -> void:
	position = Vector3(0,0.1,24)
	velocity = Vector3.ZERO
	rotation = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	camera.fov = 82
	weapon.rotation = Vector3.ZERO
	weapon.position = Vector3(0.22,-0.22,-0.48)
	weapon.recoil_position = 0
	weapon.recoil_velocity = 0
	weapon.initialized = false
	jump_buffer = 0
	coyote = 0
	landing = 0
	was_grounded = false
	camera.position.y = 1.62
	camera.rotation.z = 0
	health = 100
	shield = 100
	ammo = 30
	reload_left = 0
	fire_left = 0
	recoil = 0
	jump_queued = false
	trigger_armed = false
	look_ready = false

func look_by(delta: Vector2) -> void:
	rotation.y -= delta.x
	camera.rotation.x = clampf(camera.rotation.x - delta.y,-1.35,1.35)

func reset_look() -> void:
	camera.rotation.x = 0
	look_ready = false

func controller_look(raw: Vector2, delta: float) -> void:
	# Never turn on a held/stale axis after joining, focus recovery, or recentering.
	if not look_ready:
		if raw.length() <= LOOK_DEAD_ZONE: look_ready = true
		return
	# A radial-only dead zone lets a small vertical offset through whenever X
	# is deflected. Filter each axis so a horizontal turn cannot lift the view.
	var filtered := Vector2(look_axis(raw.x),look_axis(raw.y)).limit_length()
	if filtered==Vector2.ZERO: return
	look_by(filtered*minf(delta,0.05)*2.4)

func look_axis(value: float) -> float:
	if not is_finite(value) or absf(value)<=LOOK_DEAD_ZONE: return 0.0
	return signf(value)*clampf((absf(value)-LOOK_DEAD_ZONE)/(1-LOOK_DEAD_ZONE),0,1)

func pad_axis(axis: int) -> float:
	return Input.get_joy_axis(pad,axis) if pad >= 0 else 0.0

func pad_button(button: int) -> bool:
	return pad >= 0 and Input.is_joy_button_pressed(pad,button)

func tick(delta: float) -> void:
	var move := Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
	var stick := Vector2(pad_axis(JOY_AXIS_LEFT_X),pad_axis(JOY_AXIS_LEFT_Y))
	if stick.length()>0.18: move += stick * ((stick.length()-0.18)/0.82)
	move = move.limit_length()
	var look := Vector2(pad_axis(JOY_AXIS_RIGHT_X),pad_axis(JOY_AXIS_RIGHT_Y))
	if game.control_mode=="controller": controller_look(look,delta)
	aim = (game.control_mode=="mouse" and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)) or (game.control_mode=="controller" and pad_axis(JOY_AXIS_TRIGGER_LEFT)>0.3)
	sprinting = (Input.is_physical_key_pressed(KEY_SHIFT) or pad_button(JOY_BUTTON_LEFT_STICK)) and not aim and reload_left<=0
	var sprint := sprinting
	var speed := 10.5 if sprint else (3.8 if aim else 6.4)
	var direction := basis * Vector3(move.x,0,move.y)
	var acceleration := 30.0 if is_on_floor() else 9.0
	velocity.x = move_toward(velocity.x,direction.x*speed,delta*acceleration)
	velocity.z = move_toward(velocity.z,direction.z*speed,delta*acceleration)
	velocity.y -= 22*delta
	if is_on_floor(): coyote = 0.10
	else: coyote = maxf(0,coyote-delta)
	jump_buffer = 0.12 if jump_queued else maxf(0,jump_buffer-delta)
	if coyote>0 and jump_buffer>0:
		velocity.y = 8.4
		coyote = 0
		jump_buffer = 0
	jump_queued = false
	vertical_before = velocity.y
	move_and_slide()
	if is_on_floor() and not was_grounded: landing = clampf(-vertical_before*0.004,0,0.055)
	was_grounded = is_on_floor()
	if position.y < -8: hurt(1000)
	fire_left = maxf(0,fire_left-delta)
	if reload_left>0:
		reload_left = maxf(0,reload_left-delta)
		if reload_left==0: ammo = 30
	var firing: bool = (game.control_mode=="mouse" and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) or (game.control_mode=="controller" and pad_axis(JOY_AXIS_TRIGGER_RIGHT)>0.3)
	if not firing: trigger_armed = true
	if firing and trigger_armed: shoot()
	var actual_speed := Vector2(velocity.x,velocity.z).length()
	bob += delta*actual_speed*1.7
	landing = move_toward(landing,0,delta*0.2)
	var moving := minf(actual_speed/6.4,1) if is_on_floor() else 0.0
	camera.position.y = lerpf(camera.position.y,1.62+sin(bob*2)*0.009*moving-landing,1-exp(-delta*15))
	camera.rotation.z = lerpf(camera.rotation.z,-move.x*0.009*moving,1-exp(-delta*8))
	weapon.present(delta,Vector2(rotation.y,camera.rotation.x),actual_speed,aim,sprint and move.length()>0,reload_left,bob)
	camera.fov = lerpf(camera.fov,64.0 if aim else (87.0 if sprint and move.length()>0 else 82.0),1-exp(-delta*8))
	flash.visible = fire_left>0.085

func reload() -> void:
	if reload_left>0 or ammo==30: return
	reload_left = 1.6
	game.sound.effect("reload")

func shoot() -> void:
	if game.phase != "playing" or fire_left>0 or reload_left>0: return
	if ammo<=0:
		reload()
		return
	ammo -= 1
	fire_left = 0.115
	recoil = 1
	weapon.kick()
	game.sound.effect("shot")
	var origin := camera.global_position
	var direction := -camera.global_basis.z
	var ray := PhysicsRayQueryParameters3D.create(origin,origin+direction*140,1|4)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	var end := origin+direction*140
	if not hit.is_empty():
		end = hit.position
		if hit.collider.has_method("take_hit"):
			var headshot: bool = hit.position.y-hit.collider.global_position.y>1.52
			hit.collider.take_hit(60 if headshot else 34)
			game.hit_left = 0.18
			game.sound.effect("hit")
		game.spark(end, "b6ffe7")
	game.tracer(flash.global_position,end,"b3ffe6")

func hurt(amount: float) -> void:
	if game.phase != "playing": return
	var absorbed := minf(shield,amount)
	shield -= absorbed
	health = maxf(0,health-(amount-absorbed))
	game.damage_left = 0.4
	game.sound.effect("hurt")
	if health<=0: game.finish(false)
