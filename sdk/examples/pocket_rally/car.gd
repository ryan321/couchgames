extends CharacterBody3D
const Shapes = preload("res://examples/little_world/shapes.gd")
const Steering = preload("res://examples/pocket_rally/steering.gd")
var player_id := 1
var color := Color("e98065")
var service: Node
var motion: Node
var track: Node
var calibration = Steering.new()
var use_motion := false
var manual_mode := false
var driving := false
var speed := 0.0
var steer := 0.0
var laps := 0
var next_gate := 0
var lap_seconds := 0.0
var best_lap := 0.0
var status := "READY"
var spawn := Vector3.ZERO
var _rescue_held := false
var badge: Label3D

func _ready() -> void:
	collision_layer = 2
	collision_mask = 3
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.3,0.8,2.25)
	collision.shape = shape
	collision.position.y = 0.4
	add_child(collision)
	Shapes.box(self,Vector3(0,0.62,0),Vector3(1.45,0.5,2.5),color)
	Shapes.box(self,Vector3(0,1,0.1),Vector3(1.15,0.45,1.2),color.lightened(0.13))
	Shapes.box(self,Vector3(0,1.04,-0.52),Vector3(1.05,0.33,0.06),Color("b5d8dc"))
	Shapes.box(self,Vector3(0,1.04,0.72),Vector3(1.05,0.25,0.06),Color("304959"))
	Shapes.box(self,Vector3(0,0.9,1.1),Vector3(1.65,0.12,0.32),color.darkened(0.15))
	for x in [-0.77,0.77]:
		for z in [-0.75,0.8]:
			var wheel := Shapes.cylinder(self,Vector3(x,0.36,z),0.36,0.22,Color("293d43"))
			wheel.rotation.z = PI / 2
	for x in [-0.48,0.48]:
		Shapes.box(self,Vector3(x,0.66,-1.27),Vector3(0.28,0.17,0.04),Color("fff2b7"))
	badge = Label3D.new()
	badge.text = "P%02d" % player_id
	badge.position = Vector3(0,2.4,0)
	badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	badge.no_depth_test = false
	badge.font_size = 64
	badge.pixel_size = 0.006
	badge.modulate = color.lightened(0.35)
	badge.outline_modulate = Color("193b48")
	badge.outline_size = 18
	add_child(badge)
	rescue()

func rescue() -> void:
	position = spawn
	rotation = Vector3(0,-PI/2,0)
	speed = 0
	velocity = Vector3.ZERO
	next_gate = 0
	lap_seconds = 0
	calibration.reset()

func toggle_mode() -> void:
	use_motion = not use_motion
	manual_mode = true
	calibration.reset()
	speed = 0

func _physics_process(delta: float) -> void:
	if not service.players.has(player_id):
		return
	var state: Dictionary = service.players[player_id]
	var device: int = state["device"]
	var profile: String = state["profile"]["id"]
	var wii: bool = profile == "wii_remote"
	var keys: Dictionary = state["keys"]
	var buttons: Dictionary = state["buttons"]
	var sample: Dictionary = motion.sample_for_player(player_id)
	if not manual_mode:
		use_motion = use_motion or wii or profile.begins_with("switch") or not sample.is_empty()
	var rescue_down: bool = buttons.get(JOY_BUTTON_GUIDE,false) or buttons.get(JOY_BUTTON_START,false) or keys.get(KEY_R,false)
	if rescue_down and not _rescue_held:
		rescue()
	_rescue_held = rescue_down
	var gas := 0.0
	var brake := 0.0
	if device == service.KEYBOARD_DEVICE:
		gas = float(keys.get(KEY_W,false) or keys.get(KEY_UP,false) or keys.get(KEY_SPACE,false))
		brake = float(keys.get(KEY_S,false) or keys.get(KEY_DOWN,false))
	else:
		gas = float(buttons.get(JOY_BUTTON_Y if wii else JOY_BUTTON_A,false))
		brake = float(buttons.get(JOY_BUTTON_X,false) or buttons.get(JOY_BUTTON_LEFT_SHOULDER,false))
	driving = true
	if use_motion:
		steer = calibration.update(sample,delta)
		driving = calibration.ready and not sample.is_empty()
		status = "TILT" if driving else ("HOLD STILL %d%%" % int(calibration.progress*100) if not sample.is_empty() else "NO MOTION")
	else:
		steer = service.movement(player_id).x
		status = "KEYS" if device == service.KEYBOARD_DEVICE else "STICK"
	var before := position
	if not driving:
		speed = 0
		velocity = Vector3.ZERO
		badge.text = "P%02d · %s" % [player_id,status]
		return
	lap_seconds += delta
	var limit := 15.0 if track.on_road(position) else 5.0
	var target := limit * gas
	if brake:
		target = 0 if speed > 0.7 else -5.0
	speed = move_toward(speed,target,delta*(24 if brake else 9))
	# Positive steering turns right relative to the car, including reversing.
	rotation.y -= steer * speed / 3.3 * delta * 0.7
	velocity = -global_basis.z * speed
	velocity.y = -2
	move_and_slide()
	if get_slide_collision_count() > 0:
		for i in get_slide_collision_count():
			if absf(get_slide_collision(i).get_normal().y) < 0.5:
				speed = move_toward(speed,0,delta*30)
	track.check_progress(self,before,position)
	badge.text = "P%02d" % player_id
