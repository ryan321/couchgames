extends SceneTree
## 2D starter lobby then hop. Synthetic devices only.

var checks := 0
var failures := 0
const DEVICE := 140


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world = load("res://examples/flat_world/world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	var service = root.get_node("Platform").input
	await process_frame
	await physics_frame
	press(0, true)
	await process_frame
	press(0, false)
	await process_frame
	press(0, true)
	await process_frame
	press(0, false)
	for i in 40:
		await physics_frame
	expect(world.characters.size() == 1, "2D starter spawns after lobby ready")
	var hopper = world.characters[1]
	var before: Vector2 = hopper.position
	axis(1.0)
	await frames(20)
	axis(0.0)
	expect(hopper.position.distance_to(before) > 8.0, "2D hopper moves on analog")
	if not failures:
		print("Flat World checks passed: %d assertions." % checks)
	quit(1 if failures else 0)


func press(device: int, down: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = DEVICE + device
	event.button_index = JOY_BUTTON_A
	event.pressed = down
	Input.parse_input_event(event)


func axis(value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = DEVICE
	event.axis = JOY_AXIS_LEFT_X
	event.axis_value = value
	Input.parse_input_event(event)


func frames(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame


func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
