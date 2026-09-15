extends Node3D

const Shapes = preload("res://examples/little_world/shapes.gd")
const Character = preload("res://examples/little_world/character.gd")
const COLORS: Array[Color] = [Color("ed7559"), Color("5ba7db"), Color("d6ab43"), Color("ad84c6"),
	Color("57b99c"), Color("e38eb0"), Color("95a74c"), Color("dd9653"), Color("677fca"),
	Color("a87d66"), Color("6ec8d3"), Color("d95a78"), Color("c7b893"), Color("839cd3"),
	Color("bcbe58"), Color("d791cf")]

var characters: Dictionary = {}
var camera: Camera3D
var _input_service: Node
var _count: Label
var _join: Label
var _claims: Label
var _diagnostics: Label
var _slots: Array[Label] = []
var _flag: MeshInstance3D
var _elapsed := 0.0


func _ready() -> void:
	_input_service = get_node("/root/Platform").input
	_input_service.keyboard_enabled = true
	_build_world()
	_build_ui()
	_input_service.player_joined.connect(_spawn_player)
	_input_service.player_left.connect(_remove_player)
	_input_service.roster_changed.connect(_refresh_ui)
	for id: int in _input_service.players:
		_spawn_player(id)
	_refresh_ui()


func _process(delta: float) -> void:
	_elapsed += delta
	_flag.rotation.z = sin(_elapsed * 2.0) * 0.045


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		_diagnostics.visible = not _diagnostics.visible
		_refresh_ui()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)


func _build_world() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("bdd9dd")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("dae8f2")
	settings.ambient_light_energy = 0.35
	settings.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_color = Color("fff1d7")
	sun.light_energy = 0.75
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 36.0
	camera.position = Vector3(23, 23, 32)
	add_child(camera)
	camera.look_at(Vector3(0, 0, 0))
	camera.current = true
	# A floating garden, with a flat, accurately collidable top.
	Shapes.cylinder(self, Vector3(0, -0.6, 0), 17.0, 1.2, Color("9fbd8c"), true)
	Shapes.cylinder(self, Vector3(0, -1.35, 0), 15.9, 0.45, Color("e0ceac"), false, 16.8)
	Shapes.cylinder(self, Vector3(0, -2.3, 0), 12.6, 1.5, Color("b59e85"), false, 15.9)
	Shapes.cylinder(self, Vector3(0, 0.012, 0), 6.0, 0.02, Color("d4d9b3"))
	Shapes.cylinder(self, Vector3(0, 0.026, 0), 5.6, 0.02, Color("b3ca96"))
	# Low stepping stones lead to taller blocks, all reachable with one jump.
	for i in 5:
		var height := 0.65 * (i + 1)
		Shapes.box(self, Vector3(-10.0 + i * 2.6, height / 2.0, -7.5), Vector3(2.35, height, 3.0), Color("e9d8b2"), true)
		Shapes.box(self, Vector3(-10.0 + i * 2.6, height + 0.06, -7.5), Vector3(2.45, 0.12, 3.1), Color("f7ebcb"))
	for i in 4:
		var height := 0.7 + (i % 3) * 0.65
		Shapes.cylinder(self, Vector3(8.5, height / 2, -5.5 + i * 3.1), 1.2, height, Color("dcac86"), true)
		Shapes.cylinder(self, Vector3(8.5, height + 0.05, -5.5 + i * 3.1), 1.25, 0.1, Color("ffe0b5"))
	# Beacon at the end of the steps.
	Shapes.cylinder(self, Vector3(0.4, 4.7, -7.5), 0.08, 2.9, Color("655e56"))
	_flag = Shapes.box(self, Vector3(1.12, 5.6, -7.5), Vector3(1.5, 0.85, 0.08), Color("ef8768"))
	for at in [Vector3(-12, 0, -3), Vector3(-11, 0, 5), Vector3(-6, 0, -12), Vector3(5, 0, -12), Vector3(13, 0, 0)]:
		_tree(at)
	var random := RandomNumberGenerator.new()
	random.seed = 42
	for i in 65:
		var angle := random.randf_range(0, TAU)
		var radius := random.randf_range(12.8, 16.0)
		var at := Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		if i % 4 == 0:
			Shapes.ball(self, at + Vector3(0, 0.18, 0), Vector3(0.8, 0.5, 0.65), Color("d5d8c3"))
		else:
			Shapes.cylinder(self, at + Vector3(0, 0.15, 0), 0.035, 0.3, Color("658e68"))
			Shapes.ball(self, at + Vector3(0, 0.35, 0), Vector3(0.22, 0.2, 0.22), Color("fff0bc") if i % 2 else Color("edac9e"))
	# Small cloud banks sit behind and below the island.
	for at in [Vector3(-22, -4, -10), Vector3(18, -5, -18)]:
		for i in 3:
			Shapes.ball(self, at + Vector3(i * 2.4, sin(i) * 0.5, 0), Vector3(6, 2.4, 4), Color("e3ece7"))


func _tree(at: Vector3) -> void:
	Shapes.cylinder(self, at + Vector3(0, 1.1, 0), 0.24, 2.2, Color("b29879"), true)
	Shapes.ball(self, at + Vector3(0, 3.0, 0), Vector3(2.8, 3.8, 2.6), Color("6d9b83"))
	Shapes.ball(self, at + Vector3(0.85, 2.7, 0.3), Vector3(1.8, 2.5, 1.9), Color("82ad88"))


func _spawn_player(id: int) -> void:
	var character := Character.new()
	character.player_id = id
	character.color = COLORS[id - 1]
	character.input_service = _input_service
	character.camera = camera
	character.scale = Vector3.ONE * 1.25
	var angle := (id - 1) * TAU / 16.0
	character.spawn = Vector3(sin(angle) * 4.1, 0.3, cos(angle) * 4.1)
	character.name = "Player%d" % id
	characters[id] = character
	add_child(character)
	_refresh_ui()


func _remove_player(id: int) -> void:
	if characters.has(id):
		characters[id].queue_free()
		characters.erase(id)


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)
	var header := HBoxContainer.new()
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 55
	header.offset_right = -55
	header.offset_top = 36
	root.add_child(header)
	var title := VBoxContainer.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	title.add_child(_label("C O U C H   G A M E S   /   0 0 1", 17, Color("497078")))
	title.add_child(_label("Little World", 52, Color("294d56")))
	title.add_child(_label("A tiny island. A whole couch of friends.", 21, Color("50777b")))
	var status := VBoxContainer.new()
	header.add_child(status)
	_count = _label("00 / 16 PLAYERS", 30, Color("294d56"))
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.add_child(_count)
	var connection := _label("Xbox + PlayStation  ·  wireless or USB", 18, Color("50777b"))
	status.add_child(connection)
	_join = _label("Press A / Cross to join\nKeyboard: press Enter", 25, Color("365d64"))
	_join.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.add_child(_join)
	var pairing := _label("Pair in your computer's Bluetooth settings.", 18, Color("50777b"))
	pairing.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.add_child(pairing)
	_claims = _label("", 22, Color("294d56"))
	_claims.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_claims.position = Vector2(55, 205)
	root.add_child(_claims)
	_diagnostics = _label("", 18, Color("294d56"))
	_diagnostics.position = Vector2(55, 235)
	_diagnostics.visible = false
	root.add_child(_diagnostics)
	var bottom := VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 55
	bottom.offset_right = -55
	bottom.offset_top = -186
	bottom.offset_bottom = -30
	bottom.add_theme_constant_override("separation", 12)
	root.add_child(bottom)
	var instructions := _label("LEFT STICK / D-PAD   move       A / CROSS   jump       HOLD B / CIRCLE   leave", 23, Color("294d56"))
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(instructions)
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	bottom.add_child(grid)
	for id in range(1, 17):
		var slot := _label("%02d  ·  JOIN" % id, 19, Color("658186"))
		slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.custom_minimum_size = Vector2(0, 33)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(slot)
		_slots.append(slot)
	var keyboard := _label("Keyboard: WASD / arrows + Space   ·   Backspace to leave   ·   F11 fullscreen   ·   F3 controllers", 18, Color("50777b"))
	keyboard.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(keyboard)


func _refresh_ui() -> void:
	if not is_instance_valid(_count):
		return
	var connected := 0
	for state: Dictionary in _input_service.players.values():
		if state["connected"]:
			connected += 1
	_count.text = "%02d / 16 PLAYERS" % connected
	_join.text = "Press A / Cross to join\nKeyboard: press Enter" if _input_service.players.size() < 16 else "All 16 places taken"
	for id in range(1, 17):
		var slot := _slots[id - 1]
		if _input_service.players.has(id):
			var state: Dictionary = _input_service.players[id]
			slot.text = "%02d  ·  %s" % [id, "KEYS" if state["device"] == -100 else ("READY" if state["connected"] else "REJOIN")]
			slot.add_theme_color_override("font_color", COLORS[id - 1].darkened(0.4))
		else:
			slot.text = "%02d  ·  JOIN" % id
			slot.add_theme_color_override("font_color", Color("658186"))
	var lines := PackedStringArray()
	for device: int in _input_service.pending_claims:
		var selection: int = _input_service.claim_selection(device)
		var device_name := "Keyboard" if device == -100 else Input.get_joy_name(device)
		if device_name.is_empty():
			device_name = "Controller %d" % (device + 1)
		var choice := "New player" if selection == 0 else "Reclaim player %02d" % selection
		if selection < 0:
			choice = "Slot taken — choose another"
		lines.append("%s → %s" % [device_name, choice])
	if not lines.is_empty():
		lines.append("D-pad ← → to choose · A / Cross to confirm · B / Circle to cancel")
	_claims.text = "\n".join(lines)
	var diagnostics := PackedStringArray(["CONTROLLERS REPORTED BY GODOT: %d" % Input.get_connected_joypads().size()])
	for device: int in Input.get_connected_joypads():
		diagnostics.append("Device %d · %s · %s · Player %d" % [device, Input.get_joy_name(device),
			"mapped" if Input.is_joy_known(device) else "unknown mapping", _input_service.player_for_device(device)])
	_diagnostics.text = "\n".join(diagnostics)
	_diagnostics.position.y = 235 if lines.is_empty() else 235 + _claims.get_minimum_size().y


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label
