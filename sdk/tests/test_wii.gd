extends SceneTree
## Profile tests use SDL-mapped events, not raw Wii radio packets or real devices.

const Profiles = preload("res://addons/couchgames/controller_profiles.gd")
const PlayerInput = preload("res://addons/couchgames/player_input.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var cases := {"Nintendo Wii Remote": "wii_remote", "Nintendo Wii Remote Plus": "wii_remote",
		"Nintendo Wii Remote with Nunchuk": "wii_nunchuk", "Nintendo Wii Remote with Classic Controller": "wii_classic",
		"Wii Classic Controller Pro": "wii_classic_pro", "Nintendo Wii U Pro Controller": "wii_u_pro",
		"Nintendo Wii Remote with Unknown Extension": "wii_unknown", "Nintendo Wii Balance Board": "wii_unknown",
		"Nintendo RVL-CNT-01-TR": "wii_unknown", "Nintendo Wii U GamePad": "wii_unknown",
		"Xbox Wireless Controller": "gamepad", "DualSense Wireless Controller": "gamepad", "Nintendo Switch Pro Controller": "switch_pro"}
	for name: String in cases:
		expect(Profiles.detect(name)["id"] == cases[name], "Recognize controller layout: " + name)
	expect(Profiles.detect("Wireless Controller", {"raw_name": "Nintendo Wii Remote with Nunchuk"})["id"] == "wii_nunchuk", "Use explicit SDL raw name when available")
	var service := PlayerInput.new()
	root.add_child(service)
	service.set_process_input(false)
	service.set_physics_process(false)
	var device := 100
	for id: String in Profiles.IDS:
		if not id.begins_with("wii_") or id == "wii_unknown":
			continue
		service.set_device_profile(device, id)
		var profile := Profiles.get_profile(id)
		button(service, device, profile["join"][0], true)
		var player: int = service.player_for_device(device)
		expect(player > 0, id + " joins")
		button(service, device, profile["jump"][0], false)
		button(service, device, profile["jump"][0], true)
		expect(service.consume_jump(player), id + " maps its jump button")
		expect(not service.consume_jump(player), id + " consumes jump once")
		button(service, device, JOY_BUTTON_DPAD_UP, true)
		expect(service.movement(player) == (Vector2.LEFT if id == "wii_remote" else Vector2.UP), id + " uses correct orientation")
		button(service, device, JOY_BUTTON_DPAD_UP, false)
		axis(service, device, JOY_AXIS_LEFT_X, 0.6)
		if id != "wii_remote":
			expect(service.movement(player).is_equal_approx(Vector2(0.5, 0)), id + " reads proportional stick movement")
		button(service, device, profile["leave"], true)
		service._physics_process(1.3)
		expect(service.player_for_device(device) == 0, id + " leaves with minus")
		service.device_connection_changed(device, false)
		expect(service.device_profile_override(device) == "auto", "Disconnect forgets device ID override")
		device += 1
	# Mixed group: Wii mappings cannot change Xbox/PlayStation semantics.
	service.set_device_profile(200, "wii_nunchuk")
	service.set_device_profile(201, "gamepad")
	button(service, 200, JOY_BUTTON_B, true)
	button(service, 201, JOY_BUTTON_A, true)
	button(service, 200, JOY_BUTTON_B, false)
	button(service, 200, JOY_BUTTON_B, true)
	expect(service.consume_jump(1) and not service.consume_jump(2), "Wii A is isolated from a standard gamepad")
	button(service, 201, JOY_BUTTON_B, true)
	expect(not service.consume_jump(2), "Standard east face remains leave, not jump")
	service.set_device_profile(200, "wii_unknown")
	expect(not service.players.has(1), "Unsupported accessory cannot leave a stale player")
	button(service, 200, JOY_BUTTON_A, true)
	button(service, 200, JOY_BUTTON_Y, true)
	expect(service.player_for_device(200) == 0, "Unsupported accessory does not silently join with wrong controls")
	expect(not service.set_device_profile(200, "made_up"), "Reject unknown override")
	service.queue_free()
	await process_frame
	if not failures:
		print("Wii profile checks passed: %d synthetic assertions. Driver hint: %s. Physical Wii devices unverified." % [checks, OS.get_environment("SDL_JOYSTICK_HIDAPI_WII")])
	quit(1 if failures else 0)


func button(service: Node, device: int, index: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = index
	event.pressed = pressed
	service.handle_event(event)


func axis(service: Node, device: int, index: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = index
	event.axis_value = value
	service.handle_event(event)


func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
