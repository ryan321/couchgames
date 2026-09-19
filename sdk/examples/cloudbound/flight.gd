extends Node3D
## Single-pilot motion game. All art is generated locally; same shared Godot runtime.
const Shapes = preload("res://examples/little_world/shapes.gd")
const FlightControls = preload("res://examples/cloudbound/flight_controls.gd")
const Meter = preload("res://examples/cloudbound/motion_meter.gd")
const NATIVE_DEVICE := 1000
const RING_RADIUS := 4.2
const COURSE_LENGTH := 720.0

var controls = FlightControls.new()
var pilot := 0
var flying := false
var score := 0
var passed := 0
var distance := 0.0
var boost := 0.0
var plane: Node3D
var camera: Camera3D
var rings: Array[Node3D] = []
var scenery: Array[Node3D] = []
var _service: Node
var _motion: Node
var _elapsed := 0.0
var _message_time := 0.0
var _status: Label
var _score: Label
var _telemetry: Label
var _hint: Label
var _message: Label
var _meter: Control
var _stick_override := false
var _motion_selected := false
var _mode_button: Button
var _controls_hint: Label
var _previous_window_mode := DisplayServer.WINDOW_MODE_MAXIMIZED


func _ready() -> void:
	DisplayServer.window_set_title("Cloudbound · Giga Couch")
	_service = get_node("/root/Platform").input
	_motion = get_node("/root/Platform").motion
	_motion.set_enabled(true)
	_service.keyboard_enabled = true
	_service.player_joined.connect(_join)
	_service.player_left.connect(_leave)
	_build_world()
	_build_ui()


func _join(id: int) -> void:
	if pilot:
		_service.call_deferred("leave", id)
		return
	pilot = id
	controls.reset()
	_stick_override = false
	_motion_selected = false
	flying = false


func _exit_tree() -> void:
	_motion.set_enabled(false)


func _leave(id: int) -> void:
	if id == pilot:
		pilot = 0
		flying = false
		controls.reset()
		boost = 0.0


func _physics_process(delta: float) -> void:
	_elapsed += delta
	_message_time = maxf(0, _message_time - delta)
	_message.modulate.a = minf(1, _message_time)
	var sample: Dictionary = _motion.sample_for_player(pilot) if pilot else _motion.sample_for_device(NATIVE_DEVICE)
	var native: bool = pilot > 0 and _service.players.get(pilot, {}).get("device", -1) == NATIVE_DEVICE
	var steer := Vector2.ZERO
	if pilot:
		var device: int = _service.players[pilot]["device"]
		var motion_status: String = _motion.status_for_device(device)
		var profile_id: String = _service.players[pilot]["profile"]["id"]
		_motion_selected = _motion_selected or native or profile_id.begins_with("switch") or motion_status in ["available", "waiting"]
		if _motion_selected and not _stick_override:
			if _service.consume_jump(pilot):
				controls.reset()
			steer = controls.update(sample, delta)
			flying = controls.ready and not sample.is_empty()
			# Physical B is mapped to the south button by the native bridge.
			var buttons: Dictionary = _service.players[pilot]["buttons"]
			boost = 1.0 if buttons.get(JOY_BUTTON_A, false) and native else 0.0
			if not native and (buttons.get(JOY_BUTTON_LEFT_SHOULDER, false) or buttons.get(JOY_BUTTON_RIGHT_SHOULDER, false)):
				boost = 1.0
		else:
			var movement: Vector2 = _service.movement(pilot)
			steer = Vector2(movement.x, -movement.y)
			flying = true
			if _service.consume_jump(pilot):
				boost = 1.0
			boost = move_toward(boost, 0.0, delta * 0.4)
	else:
		flying = false
		plane.rotation.z = sin(_elapsed * 0.9) * 0.06
	if flying:
		advance_flight(delta, steer, 22.0 + boost * 15.0)
		plane.rotation.z = lerpf(plane.rotation.z, -steer.x * 0.65, 1 - exp(-6 * delta))
		plane.rotation.x = lerpf(plane.rotation.x, steer.y * 0.3, 1 - exp(-6 * delta))
	camera.position = camera.position.lerp(plane.position + Vector3(0, 4.5, 18), 1 - exp(-3 * delta))
	camera.look_at(plane.position + Vector3(0, 1, -35))
	_refresh_ui(sample, native, steer)


func advance_flight(delta: float, steer: Vector2, speed: float) -> void:
	var before := plane.position
	plane.position.x = clampf(plane.position.x + steer.x * 13.0 * delta, -25, 25)
	plane.position.y = clampf(plane.position.y + steer.y * 10.0 * delta, 3.0, 29.0)
	distance += speed * delta
	for ring in rings:
		var previous_z := ring.position.z
		ring.position.z += speed * delta
		if previous_z < 0 and ring.position.z >= 0:
			passed += 1
			# Swept plane crossing: boosts/slow frames cannot skip a ring.
			var fraction := -previous_z / (speed * delta)
			var crossing := before.lerp(plane.position, fraction)
			if Vector2(crossing.x - ring.position.x, crossing.y - ring.position.y).length() < RING_RADIUS - 0.55:
				score += 1
				_message.text = "NICE FLYING!  +1"
			else:
				_message.text = "Next ring ahead — keep gliding"
			_message_time = 2.5
		if ring.position.z > 24:
			ring.position.z -= COURSE_LENGTH
	for island in scenery:
		island.position.z += speed * delta
		if island.position.z > 55:
			island.position.z -= COURSE_LENGTH


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_F11: _fullscreen()
		KEY_C: controls.reset()
		KEY_M: _toggle_controls()
		KEY_R: _restart()
		KEY_ESCAPE: get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START:
		if pilot and _service.player_for_device(event.device) == pilot:
			_toggle_controls()


func _toggle_controls() -> void:
	if _motion_selected and not _stick_override:
		_stick_override = true
	else:
		_stick_override = false
		_motion_selected = true
	controls.reset()
	boost = 0.0


func _fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]:
		DisplayServer.window_set_mode(_previous_window_mode)
	else:
		_previous_window_mode = mode
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _restart() -> void:
	score = 0
	passed = 0
	distance = 0
	boost = 0
	_message_time = 0
	_message.text = ""
	plane.rotation = Vector3.ZERO
	plane.position = Vector3(0, 10, 0)
	for i in rings.size():
		rings[i].position = _ring_position(i)
	controls.reset()


func _ring_position(index: int) -> Vector3:
	return Vector3(sin(index * 0.66) * 11, 10 + sin(index * 0.43) * 6, -45.0 - index * 40)


func _build_world() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("4f9ccc")
	sky_material.sky_horizon_color = Color("f4dfbb")
	sky_material.ground_horizon_color = Color("f4dfbb")
	sky_material.ground_bottom_color = Color("72adb4")
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("cde6ef")
	environment.ambient_light_energy = 0.4
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -40, 0)
	sun.light_color = Color("ffe2b1")
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140
	add_child(sun)
	var ocean := Shapes.box(self, Vector3(0, -19, -250), Vector3(1800, 1, 1800), Color("74b2bf"))
	(ocean.material_override as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	plane = Node3D.new()
	plane.position = Vector3(0, 10, 0)
	add_child(plane)
	# Cream wings, coral fuselage, dark cockpit, and a striped tail.
	Shapes.ball(plane, Vector3.ZERO, Vector3(0.85, 0.75, 3.4), Color("e67d62"))
	var wing := Shapes.box(plane, Vector3(0, 0.05, 0.1), Vector3(6.4, 0.14, 1.0), Color("fff0cc"))
	wing.rotation.y = 0.02
	Shapes.box(plane, Vector3(-2.9, 0.1, 0.1), Vector3(0.32, 0.17, 1.03), Color("e67d62"))
	Shapes.box(plane, Vector3(2.9, 0.1, 0.1), Vector3(0.32, 0.17, 1.03), Color("e67d62"))
	Shapes.ball(plane, Vector3(0, 0.35, -0.35), Vector3(0.55, 0.55, 1.0), Color("315269"))
	Shapes.box(plane, Vector3(0, 0.18, 1.2), Vector3(2.2, 0.12, 0.6), Color("fff0cc"))
	Shapes.box(plane, Vector3(0, 0.55, 1.2), Vector3(0.12, 0.8, 0.65), Color("e67d62"))
	for i in 18:
		var ring := Node3D.new()
		ring.position = _ring_position(i)
		add_child(ring)
		var torus := TorusMesh.new()
		torus.inner_radius = RING_RADIUS - 0.18
		torus.outer_radius = RING_RADIUS + 0.18
		torus.rings = 32
		torus.ring_segments = 10
		var hoop := Shapes.mesh(ring, torus, Vector3.ZERO, Color("ffcb65"))
		hoop.rotation.x = PI / 2
		var mat := hoop.material_override as StandardMaterial3D
		mat.emission_enabled = true
		mat.emission = Color("ffb84c")
		mat.emission_energy_multiplier = 0.25
		rings.append(ring)
	var random := RandomNumberGenerator.new()
	random.seed = 730
	for i in 30:
		var island := Node3D.new()
		island.position = Vector3((-1 if i % 2 else 1) * random.randf_range(34, 100), random.randf_range(-16, -6), -i * 24.0)
		add_child(island)
		var radius := random.randf_range(5, 13)
		Shapes.cylinder(island, Vector3(0, -4, 0), radius * 0.3, 8, Color("aa9985"), false, radius)
		Shapes.cylinder(island, Vector3.ZERO, radius, 0.8, Color("94af82"))
		for tree in 3:
			var at := Vector3(random.randf_range(-radius * 0.6, radius * 0.6), 0, random.randf_range(-radius * 0.6, radius * 0.6))
			Shapes.cylinder(island, at + Vector3(0, 1, 0), 0.2, 2, Color("8c8370"))
			Shapes.ball(island, at + Vector3(0, 3, 0), Vector3(2.8, 4, 2.8), Color("598d7d"))
		scenery.append(island)
	for i in 24:
		var cloud := Node3D.new()
		cloud.position = Vector3(random.randf_range(-140, 140), random.randf_range(22, 55), -i * 30.0)
		add_child(cloud)
		for puff in 3:
			Shapes.ball(cloud, Vector3(puff * 5, sin(puff) * 2, 0), Vector3(14, 5, 8), Color("f9edda"))
		scenery.append(cloud)
	camera = Camera3D.new()
	camera.position = plane.position + Vector3(0, 4.5, 18)
	camera.fov = 64
	camera.far = 1000
	add_child(camera)
	camera.current = true


func _label(text: String, size: int, color := Color("fdf2d9")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)
	var heading := VBoxContainer.new()
	heading.position = Vector2(52, 38)
	root.add_child(heading)
	heading.add_child(_label("G I G A   C O U C H   /   0 0 2", 17, Color("244c61")))
	heading.add_child(_label("Cloudbound", 58, Color("173c52")))
	heading.add_child(_label("Find your wings.", 23, Color("315c6c")))
	var stats := VBoxContainer.new()
	stats.position = Vector2(1160, 45)
	stats.size = Vector2(388, 120)
	root.add_child(stats)
	_score = _label("00  RINGS", 38, Color("173c52"))
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stats.add_child(_score)
	_telemetry = _label("0 m  ·  EASY SKIES", 18, Color("315c6c"))
	_telemetry.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stats.add_child(_telemetry)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 52
	panel.offset_right = -52
	panel.offset_top = -216
	panel.offset_bottom = -38
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.17, 0.23, 0.92)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	panel.add_child(row)
	_meter = Meter.new()
	_meter.custom_minimum_size = Vector2(100, 100)
	row.add_child(_meter)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	_status = _label("HOLD SIDEWAYS · PRESS 2 TO FLY", 27)
	text.add_child(_status)
	_hint = _label("D-pad left, 1/2 buttons right. Turn left/right to bank; roll away to dive.", 19, Color("b9d6db"))
	text.add_child(_hint)
	_controls_hint = _label("Wii: 2 center · B boost    |    Gamepad: lower face centers · shoulder boosts", 17, Color("b9d6db"))
	text.add_child(_controls_hint)
	var buttons := VBoxContainer.new()
	row.add_child(buttons)
	for entry in [["Fullscreen · F11", _fullscreen], ["Restart flight · R", _restart]]:
		var button := Button.new()
		button.text = entry[0]
		button.custom_minimum_size = Vector2(190, 43)
		button.add_theme_font_size_override("font_size", 17)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(entry[1])
		buttons.add_child(button)
	_mode_button = Button.new()
	_mode_button.text = "Controls · M / Menu"
	_mode_button.custom_minimum_size = Vector2(190, 38)
	_mode_button.focus_mode = Control.FOCUS_NONE
	_mode_button.pressed.connect(_toggle_controls)
	buttons.add_child(_mode_button)
	_message = _label("", 30, Color("fff0cc"))
	_message.position = Vector2(450, 195)
	_message.size.x = 700
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_message)


func _refresh_ui(sample: Dictionary, native: bool, steer: Vector2) -> void:
	_score.text = "%02d  RINGS" % score
	_telemetry.text = "%d m   ·   %d / %d rings   ·   %s" % [int(distance), score, passed, "BOOST" if boost > 0.1 else "EASY SKIES"]
	var using_motion := _motion_selected and not _stick_override
	_meter.steering = steer
	_meter.receiving = not sample.is_empty() if using_motion or not pilot else true
	_meter.queue_redraw()
	_mode_button.text = "Use tilt · M / Menu" if not using_motion else "Use stick · M / Menu"
	_controls_hint.text = "Wii: 2 center · B boost · hold − leave" if native else "Lower face: center / stick boost · shoulder: tilt boost · hold right face: leave"
	if not pilot:
		_status.text = "PRESS A FACE BUTTON TO JOIN · WII: 2"
		_hint.text = "Wii: D-pad left · Joy-Con: SL/SR up · Pro / pair: normal grip · Keyboard: Enter."
	elif using_motion and sample.is_empty():
		var device: int = _service.players[pilot]["device"]
		var state: String = _motion.status_for_device(device)
		_status.text = "MOTION UNAVAILABLE · USE STICK TO FLY" if state == "unavailable" else "FLIGHT PAUSED · WAITING FOR MOTION"
		_hint.text = "Press Menu / + / − or click Use stick. Reconnect to retry motion; Wii needs its reader open."
	elif using_motion and not controls.ready:
		_status.text = "HOLD YOUR CONTROLLER STILL… %d%%" % int(minf(controls.progress, 1.0) * 100)
		_hint.text = "Wii: D-pad left · Joy-Con: SL/SR up · Pro / pair: normal grip. Hold steady."
	elif using_motion:
		_status.text = "TILT TO FLY · CHASE THE GOLDEN RINGS"
		var accel: Vector3 = sample["acceleration"]
		_hint.text = "Roll away to dive · toward you to climb. Motion %.2f / %.2f / %.2f g" % [accel.x, accel.y, accel.z]
	else:
		_status.text = "STICK CONTROLS · FLY THROUGH THE RINGS"
		_hint.text = "Arrows / left stick steer · Up climbs · Space / lower face boosts · M / Menu changes controls"
