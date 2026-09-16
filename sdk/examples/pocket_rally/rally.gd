extends Node3D
## All viewports share one world and physics simulation; each camera follows its driver.
const Shapes = preload("res://examples/little_world/shapes.gd")
const Car = preload("res://examples/pocket_rally/car.gd")
const Fleet = preload("res://examples/pocket_rally/wii_fleet.gd")
const COLORS: Array[Color] = [Color("ed7559"),Color("5ba7db"),Color("d6ab43"),Color("ad84c6"),
	Color("57b99c"),Color("e38eb0"),Color("95a74c"),Color("dd9653"),Color("677fca"),
	Color("a87d66"),Color("6ec8d3"),Color("d95a78"),Color("c7b893"),Color("839cd3"),Color("bcbe58"),Color("d791cf")]
var cars: Dictionary = {}
var panes: Dictionary = {}
var service: Node
var motion: Node
var _screens: Control
var _count: Label
var _sun: DirectionalLight3D
var _previous_window_mode := DisplayServer.WINDOW_MODE_MAXIMIZED

func _ready() -> void:
	DisplayServer.window_set_title("Pocket Rally · Couch Games")
	service = get_node("/root/Platform").input
	motion = get_node("/root/Platform").motion
	service.keyboard_enabled = true
	motion.set_enabled(true)
	_build_track()
	_build_ui()
	service.player_joined.connect(_join)
	service.player_left.connect(_leave)
	for id: int in service.players:
		_join(id)
	if cars.is_empty():
		_add_pane(0)
	var fleet_directory := OS.get_environment("COUCH_WII_FLEET_DIR")
	if fleet_directory.is_absolute_path():
		var fleet := Fleet.new()
		fleet.service = service
		fleet.motion = motion
		fleet.directory = fleet_directory
		add_child(fleet)

func _exit_tree() -> void:
	motion.set_enabled(false)

func _join(id: int) -> void:
	if cars.has(id):
		return
	_remove_pane(0)
	var car := Car.new()
	car.player_id = id
	car.name = "Driver%02d" % id
	car.color = COLORS[id-1]
	car.service = service
	car.motion = motion
	car.track = self
	car.spawn = Vector3(-2-floori((id-1)/4.0)*3,0.08,-12-(id-1)%4*2.5)
	cars[id] = car
	add_child(car)
	_add_pane(id)

func _leave(id: int) -> void:
	_remove_pane(id)
	if cars.has(id):
		cars[id].queue_free()
		cars.erase(id)
	if cars.is_empty():
		_add_pane(0)
	_layout()

func _process(delta: float) -> void:
	for id: int in panes:
		var pane: Dictionary = panes[id]
		var camera: Camera3D = pane["camera"]
		if id == 0:
			continue
		var car = cars[id]
		var target: Vector3 = car.position + car.global_basis.z*7.5 + Vector3(0,6.5,0)
		camera.position = camera.position.lerp(target,1-exp(-7*delta))
		camera.look_at(car.position-car.global_basis.z*4+Vector3(0,0.7,0))
		pane["title"].text = "P%02d  ·  LAP %d  ·  %d km/h" % [id,car.laps,roundi(absf(car.speed)*3.6)]
		pane["status"].text = car.status
		pane["mode"].text = "Use stick" if car.use_motion else "Use tilt"
	_count.text = "%02d / 16 DRIVERS" % cars.size()

func on_road(at: Vector3) -> bool:
	return pow(at.x/33.0,2)+pow(at.z/23.0,2) <= 1.0 and pow(at.x/19.0,2)+pow(at.z/10.0,2) >= 1.0

func check_progress(car: Node, before: Vector3, after: Vector3) -> void:
	if not on_road(before) or not on_road(after):
		return
	var a := atan2(before.z/16.5,before.x/26.0)
	var b := atan2(after.z/16.5,after.x/26.0)
	var step := wrapf(b-a,-PI,PI)
	if step <= 0 or step > 0.35:
		return # Reverse driving and teleports cannot complete checkpoints.
	var gate_angle: float = car.next_gate*PI/2
	var to_gate := fposmod(gate_angle-a,TAU)
	if to_gate > step:
		return
	car.next_gate = (car.next_gate+1)%4
	if car.next_gate == 0:
		car.laps += 1
		if car.best_lap == 0 or car.lap_seconds < car.best_lap:
			car.best_lap = car.lap_seconds
		car.lap_seconds = 0

func _add_pane(id: int) -> void:
	var panel := Control.new()
	_screens.add_child(panel)
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(container)
	var viewport := SubViewport.new()
	viewport.world_3d = get_world_3d()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	var camera := Camera3D.new()
	camera.fov = 65
	camera.far = 220
	viewport.add_child(camera)
	camera.current = true
	if id:
		var car = cars[id]
		camera.position = car.position+car.global_basis.z*7.5+Vector3(0,6.5,0)
		camera.look_at(car.position-car.global_basis.z*4+Vector3(0,0.7,0))
	else:
		camera.position = Vector3(0,65,42)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 58
		camera.look_at(Vector3.ZERO)
	var strip := ColorRect.new()
	strip.color = Color(0.04,0.11,0.15,0.8)
	strip.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	strip.offset_bottom = 36
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(strip)
	var title := _label("PRESS 2 ON WII · FACE BUTTON ON GAMEPAD · ENTER ON KEYBOARD",20)
	title.position = Vector2(12,6)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(title)
	var status := _label("Hold your Wii sideways: D-pad left, 1/2 right.",18)
	status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	status.offset_left = 12
	status.offset_top = -30
	status.add_theme_constant_override("outline_size",6)
	status.add_theme_color_override("font_outline_color",Color("173c49"))
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(status)
	var mode := Button.new()
	mode.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	mode.offset_left = -100
	mode.offset_top = -34
	mode.offset_right = -6
	mode.offset_bottom = -5
	mode.focus_mode = Control.FOCUS_NONE
	mode.visible = id != 0
	panel.add_child(mode)
	if id:
		title.add_theme_color_override("font_color",COLORS[id-1].lightened(0.45))
		mode.pressed.connect(func(): cars[id].toggle_mode())
	panes[id] = {"panel":panel,"viewport":viewport,"camera":camera,"title":title,"status":status,"mode":mode}
	_layout()

func _remove_pane(id: int) -> void:
	if panes.has(id):
		panes[id]["panel"].queue_free()
		panes.erase(id)

func _layout() -> void:
	if not is_instance_valid(_screens) or panes.is_empty():
		return
	var ids: Array = panes.keys()
	ids.sort()
	var columns := ceili(sqrt(float(ids.size())))
	var rows := ceili(float(ids.size())/columns)
	var pane_size := (_screens.size-Vector2((columns-1)*6,(rows-1)*6))/Vector2(columns,rows)
	for i in ids.size():
		var pane: Dictionary = panes[ids[i]]
		pane["panel"].position = Vector2(i%columns,floori(float(i)/columns))*(pane_size+Vector2(6,6))
		pane["panel"].size = pane_size.max(Vector2(2,2))
		pane["title"].add_theme_font_size_override("font_size",16 if ids.size()>4 else 20)
		pane["status"].add_theme_font_size_override("font_size",15 if ids.size()>4 else 18)
	# Sixteen cameras share meshes/physics. Reduce shadow cost in crowded sessions.
	_sun.shadow_enabled = cars.size() <= 4

func _fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode in [DisplayServer.WINDOW_MODE_FULLSCREEN,DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]:
		DisplayServer.window_set_mode(_previous_window_mode)
	else:
		_previous_window_mode = mode
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _new_race() -> void:
	for car in cars.values():
		car.laps = 0
		car.best_lap = 0
		car.rescue()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			_fullscreen()
		if event.keycode == KEY_ESCAPE:
			get_tree().quit()

func _label(text: String, size: int, color := Color("eff3e3")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	return label

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(root)
	var backdrop := ColorRect.new()
	backdrop.color = Color("173c49")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	var title := _label("POCKET RALLY",34)
	title.position = Vector2(28,15)
	root.add_child(title)
	_count = _label("00 / 16 DRIVERS",23,Color("b8d6d6"))
	_count.position = Vector2(400,25)
	root.add_child(_count)
	for entry in [["New race",_new_race],["Fullscreen · F11",_fullscreen]]:
		var button := Button.new()
		button.text = entry[0]
		button.position = Vector2(1220 if entry[0]=="New race" else 1370,15)
		button.size = Vector2(140 if entry[0]=="New race" else 200,42)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(entry[1])
		root.add_child(button)
	_screens = Control.new()
	_screens.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screens.offset_left = 12
	_screens.offset_right = -12
	_screens.offset_top = 74
	_screens.offset_bottom = -76
	root.add_child(_screens)
	_screens.resized.connect(_layout)
	var instructions := _label("WII: tilt to steer · 2 gas · 1 brake / reverse · Home rescue · hold − leave",20)
	instructions.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	instructions.offset_left = 28
	instructions.offset_top = -64
	root.add_child(instructions)
	var fallback := _label("GAMEPAD: stick + lower face gas + left face brake · Menu rescue    |    KEYBOARD: Enter joins · WASD / arrows · R rescue",17,Color("b8d6d6"))
	fallback.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	fallback.offset_left = 28
	fallback.offset_top = -34
	root.add_child(fallback)

func _build_track() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("b7d7df")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d8e8ee")
	environment.ambient_light_energy = 0.45
	world_environment.environment = environment
	add_child(world_environment)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-55,-35,0)
	_sun.light_color = Color("fff0d2")
	_sun.light_energy = 0.8
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 100
	add_child(_sun)
	Shapes.box(self,Vector3(0,-0.6,0),Vector3(110,1.2,85),Color("b9c496"),true)
	var road := Shapes.cylinder(self,Vector3(0,0.025,0),33,0.04,Color("52676e"))
	road.scale.z = 23.0/33
	var grass := Shapes.cylinder(self,Vector3(0,0.055,0),19,0.05,Color("97b97d"))
	grass.scale.z = 10.0/19
	for i in 80:
		var a := i*TAU/80
		var b := (i+1)*TAU/80
		for outer in [true,false]:
			var rx := 33.5 if outer else 19.0
			var rz := 23.5 if outer else 10.0
			var p := Vector3(cos(a)*rx,0,sin(a)*rz)
			var q := Vector3(cos(b)*rx,0,sin(b)*rz)
			var node := Node3D.new()
			node.position = (p+q)/2
			node.rotation.y = -atan2((q-p).z,(q-p).x)
			add_child(node)
			Shapes.box(node,Vector3(0,0.18 if outer else 0.07,0),Vector3(p.distance_to(q)+0.05,0.36 if outer else 0.1,0.55),Color("e88773") if i%2 else Color("f4edce"),outer)
		if i%2 == 0:
			var dash := Shapes.box(self,Vector3(cos(a)*26,0.06,sin(a)*16.5),Vector3(1.1,0.025,0.15),Color("e0d9b8"))
			dash.rotation.y = -atan2(16.5*cos(a),-26*sin(a))
	for row in 2:
		for cell in 12:
			Shapes.box(self,Vector3(1+row*0.65,0.08,-22+cell),Vector3(0.65,0.025,1),Color("f5edcf") if (cell+row)%2 else Color("293e49"))
	for at in [Vector3(-10,0,0),Vector3(11,0,1),Vector3(-36,0,-26),Vector3(36,0,25),Vector3(35,0,-27)]:
		Shapes.cylinder(self,at+Vector3(0,1.4,0),0.25,2.8,Color("aa9777"))
		Shapes.ball(self,at+Vector3(0,3.8,0),Vector3(3.8,4.5,3.8),Color("6b9b7d"))
	Shapes.box(self,Vector3(0,1.5,3),Vector3(8,3,4),Color("ecd5ad"))
	Shapes.box(self,Vector3(0,3.1,3),Vector3(8.6,0.35,4.7),Color("d9866d"))
	for i in 3:
		Shapes.box(self,Vector3(-2.5+i*2.5,1.1,0.95),Vector3(1.8,2,0.05),Color("65848b"))
	var sign := Label3D.new()
	sign.text = "POCKET RALLY"
	sign.position = Vector3(0,4.5,3)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.font_size = 48
	sign.pixel_size = 0.015
	sign.modulate = Color("fff0cb")
	add_child(sign)
