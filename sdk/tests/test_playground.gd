extends SceneTree
## Exercises the real scene, SDK input path and 3D physics with synthetic input.

var failures := 0
var checks := 0
# Keep synthetic dispatch separate from controllers used during live dogfooding.
const DEVICE_OFFSET := 100


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world = load("res://examples/little_world/world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	var service = root.get_node("Platform").input
	for device in 16:
		button(device, true)
	await frames(35)
	expect(world.characters.size() == 16, "Real scene spawns all sixteen characters")
	for character in world.characters.values():
		expect(character.is_on_floor(), "Character settles on the island floor")
	var first = world.characters[1]
	var second = world.characters[2]
	var before: Vector3 = first.position
	var other_before: Vector3 = second.position
	axis(0, 1.0)
	await frames(25)
	axis(0, 0.0)
	expect(first.position.distance_to(before) > 1.0, "Analog input moves a character in the 3D world")
	expect(second.position.distance_to(other_before) < 0.05, "A different character stays still")
	button(0, false)
	button(0, true)
	await frames(12)
	expect(first.position.y > 0.6, "Mapped south button jumps")
	button(0, false)
	await frames(65)
	expect(first.is_on_floor(), "Character lands after jumping")
	# Settle onto the first stair, proving its obstacle collision.
	first.position = Vector3(-10, 0.66, -7.5)
	first.velocity = Vector3.ZERO
	await frames(10)
	expect(first.is_on_floor() and first.position.y > 0.6, "Steps have real collisions")
	first.position.y = -9.0
	await frames(3)
	expect(first.position.distance_to(first.spawn) < 0.2, "Falling respawns at the player's own spawn")
	expect(world.characters.size() == 16 and world.characters[1] == first, "Falling does not create another character")
	service.device_connection_changed(DEVICE_OFFSET, false)
	axis(0, 1.0)
	expect(service.movement(1) == Vector2.ZERO, "A disconnected device cannot keep moving")
	await frames(2)
	expect(world.characters.size() == 15 and not world.characters.has(1), "Disconnect removes the character from the scene")
	expect(not is_instance_valid(first), "Disconnected character node is freed")
	expect(world.characters[2] == second, "Disconnect leaves other characters untouched")
	button(40, true)
	await frames(2)
	expect(service.player_for_device(DEVICE_OFFSET + 40) == 1 and world.characters.size() == 16, "One button rejoins with a fresh character")
	# Exercise the actual layout selector callback with two synthetic device rows.
	world._diagnostics.visible = true
	world._refresh_ui()
	world._add_device_controls(DEVICE_OFFSET + 40)
	world._add_device_controls(DEVICE_OFFSET + 1)
	var selectors: Array[OptionButton] = []
	for child in world._diagnostic_rows.get_children():
		if child is OptionButton:
			selectors.append(child)
	selectors[-2].item_selected.emit(2) # Auto, standard, Wii Remote.
	expect(service.device_profile_override(DEVICE_OFFSET + 40) == "wii_remote", "UI selector updates its own device")
	expect(service.device_profile_override(DEVICE_OFFSET + 1) == "auto", "UI selector leaves the other device alone")
	service.set_device_profile(DEVICE_OFFSET + 40, "auto")
	expect(world.characters.size() == 16 and world.characters[2] == second, "Changing profiles preserves active characters")
	world._diagnostics.visible = false
	# Optional rendered capture is for visual inspection, separate from headless tests.
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			await frames(3)
			await RenderingServer.frame_post_draw
			var picture := root.get_texture().get_image()
			expect(picture.save_png(argument.trim_prefix("--capture=")) == OK, "Rendered screenshot saved")
	if not failures:
		print("Playground checks passed: %d scene/physics assertions; synthetic controllers." % checks)
	quit(1 if failures else 0)


func frames(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame


func button(device: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = DEVICE_OFFSET + device
	event.button_index = JOY_BUTTON_A
	event.pressed = pressed
	Input.parse_input_event(event)


func axis(device: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = DEVICE_OFFSET + device
	event.axis = JOY_AXIS_LEFT_X
	event.axis_value = value
	Input.parse_input_event(event)


func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
