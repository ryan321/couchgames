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
	weapon = Node3D.new()
	camera.add_child(weapon)
	# A layered original pulse carbine with visible hands, rails and illuminated cells.
	Art.box(weapon, Vector3(0,0,0),Vector3(0.16,0.18,0.48),"e3e6d6",false,0.6)
	Art.box(weapon, Vector3(0,-0.025,-0.35),Vector3(0.12,0.12,0.3),"304953",false,0.8)
	Art.box(weapon, Vector3(0,0.035,-0.16),Vector3(0.18,0.035,0.32),"ebad51",false,0.5)
	Art.box(weapon, Vector3(0,-0.14,0.05),Vector3(0.09,0.24,0.12),"29444c")
	Art.box(weapon, Vector3(0,-0.15,-0.12),Vector3(0.09,0.23,0.14),"517580",false,0.5)
	Art.box(weapon, Vector3(0,0.14,0.02),Vector3(0.1,0.07,0.04),"2d4854")
	Art.box(weapon, Vector3(0,0.11,-0.31),Vector3(0.025,0.04,0.025),"80f3df")
	for i in 5: Art.box(weapon,Vector3(0,0.102,-0.2+i*0.055),Vector3(0.14,0.02,0.025),"304953")
	for x in [-0.086,0.086]:
		var cell := Art.box(weapon,Vector3(x,0,-0.06),Vector3(0.015,0.05,0.18),"68f9de")
		cell.material_override = Art.material("68f9de",0.3,1.7)
	Art.sphere(weapon,Vector3(0.06,-0.16,0.13),Vector3(0.085,0.09,0.14),"314b54")
	Art.sphere(weapon,Vector3(-0.1,-0.11,-0.22),Vector3(0.08,0.09,0.14),"314b54")
	Art.box(weapon,Vector3(0.08,-0.21,0.28),Vector3(0.13,0.14,0.26),"d9a26e")
	Art.box(weapon,Vector3(-0.18,-0.18,-0.08),Vector3(0.12,0.13,0.25),"d9a26e")
	flash = Art.sphere(weapon,Vector3(0,0,-0.55),Vector3(0.085,0.085,0.17),"b1ffee")
	flash.material_override = Art.material("b1ffee",0,5)
	flash.visible = false
	weapon.position = Vector3(0.3,-0.25,-0.52)

func reset() -> void:
	position = Vector3(0,0.1,24)
	velocity = Vector3.ZERO
	rotation = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	camera.fov = 82
	weapon.rotation = Vector3.ZERO
	weapon.position = Vector3(0.3,-0.25,-0.52)
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
	var magnitude := raw.length()
	if magnitude <= LOOK_DEAD_ZONE: return
	var strength := clampf((magnitude-LOOK_DEAD_ZONE)/(1-LOOK_DEAD_ZONE),0,1)
	look_by(raw.normalized()*strength*minf(delta,0.05)*2.4)

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
	var sprint := (Input.is_physical_key_pressed(KEY_SHIFT) or pad_button(JOY_BUTTON_LEFT_STICK)) and not aim
	var speed := 10.5 if sprint else (3.8 if aim else 6.4)
	var direction := basis * Vector3(move.x,0,move.y)
	velocity.x = move_toward(velocity.x,direction.x*speed,delta*38)
	velocity.z = move_toward(velocity.z,direction.z*speed,delta*38)
	velocity.y -= 22*delta
	if is_on_floor() and jump_queued: velocity.y = 8.4
	jump_queued = false
	move_and_slide()
	if position.y < -8: hurt(1000)
	fire_left = maxf(0,fire_left-delta)
	if reload_left>0:
		reload_left = maxf(0,reload_left-delta)
		if reload_left==0: ammo = 30
	var firing: bool = (game.control_mode=="mouse" and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) or (game.control_mode=="controller" and pad_axis(JOY_AXIS_TRIGGER_RIGHT)>0.3)
	if not firing: trigger_armed = true
	if firing and trigger_armed: shoot()
	recoil = move_toward(recoil,0,delta*7)
	bob += delta * (11 if sprint else 8) * move.length()
	var target := Vector3(0.02,-0.21,-0.45) if aim else Vector3(0.3,-0.25,-0.52)
	target += Vector3(sin(bob)*0.008,absf(cos(bob))*0.009,recoil*0.09)
	if reload_left>0: target.y -= sin(reload_left/1.6*PI)*0.3
	weapon.position = weapon.position.lerp(target,1-exp(-delta*16))
	weapon.rotation.z = sin(reload_left/1.6*PI)*-0.4
	weapon.rotation.x = recoil*0.055
	camera.fov = lerpf(camera.fov,58.0 if aim else (89.0 if sprint and move.length()>0 else 82.0),1-exp(-delta*9))
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
