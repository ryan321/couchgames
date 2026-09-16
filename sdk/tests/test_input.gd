extends SceneTree
## Synthetic mapped events test SDK routing, not Bluetooth/USB hardware.

const DEVICE_OFFSET := 100
const PlayerInput = preload("res://addons/couchgames/player_input.gd")
var failures := 0
var checks := 0
var service: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	service = PlayerInput.new()
	root.add_child(service)
	service.set_process_input(false)
	service.set_physics_process(false)
	for device in 16:
		button(device, JOY_BUTTON_A, true)
	expect(service.players.size() == 16, "All sixteen controller slots join")
	button(16, JOY_BUTTON_A, true)
	expect(service.players.size() == 16 and service.player_for_device(DEVICE_OFFSET + 16) == 0, "A seventeenth device cannot steal a slot")
	for device in 16:
		axis(device, JOY_AXIS_LEFT_X, 1.0)
		button(device, JOY_BUTTON_A, false)
		button(device, JOY_BUTTON_A, true)
		for id in range(1, 17):
			expect(service.movement(id) == (Vector2.RIGHT if id == device + 1 else Vector2.ZERO), "Movement belongs to exactly one player")
			expect(service.consume_jump(id) == (id == device + 1), "Jump belongs to exactly one player")
		axis(device, JOY_AXIS_LEFT_X, 0.0)
	axis(0, JOY_AXIS_LEFT_X, 0.1)
	expect(service.movement(1) == Vector2.ZERO, "Stick drift is filtered")
	axis(0, JOY_AXIS_LEFT_X, 1.0)
	axis(0, JOY_AXIS_LEFT_Y, 1.0)
	expect(is_equal_approx(service.movement(1).length(), 1.0), "Diagonal movement is bounded")
	button(1, JOY_BUTTON_DPAD_LEFT, true)
	expect(service.movement(2) == Vector2.LEFT, "Mapped D-pad works")
	service.device_connection_changed(DEVICE_OFFSET + 0, false)
	expect(service.movement(1) == Vector2.ZERO and not service.consume_jump(1), "Disconnect clears held actions")
	expect(service.players.size() == 15 and not service.players.has(1), "Disconnect immediately frees the player slot")
	expect(service.player_for_device(DEVICE_OFFSET + 0) == 0, "Disconnect removes device ownership")
	service.device_connection_changed(DEVICE_OFFSET + 0, true)
	expect(service.players.size() == 15, "Connecting alone does not create a character")
	button(50, JOY_BUTTON_START, true)
	expect(service.player_for_device(DEVICE_OFFSET + 50) == 0, "Display shortcut cannot create an extra player")
	button(0, JOY_BUTTON_A, true)
	expect(service.player_for_device(DEVICE_OFFSET + 0) == 1 and service.players.size() == 16, "One button rejoins the free slot")
	expect(service.movement(1) == Vector2.ZERO and not service.consume_jump(1), "Rejoining starts with fresh input")
	service.device_connection_changed(DEVICE_OFFSET + 0, false)
	service.device_connection_changed(DEVICE_OFFSET + 1, false)
	button(30, JOY_BUTTON_A, true)
	button(31, JOY_BUTTON_A, true)
	expect(service.players.size() == 16 and service.player_for_device(DEVICE_OFFSET + 30) == 1 and service.player_for_device(DEVICE_OFFSET + 31) == 2,
		"New device IDs reuse only vacant slots")
	expect(service.player_for_device(DEVICE_OFFSET + 2) == 3, "Other players keep their assignments")
	for cycle in 5:
		service.device_connection_changed(DEVICE_OFFSET + 30, false)
		service.device_connection_changed(DEVICE_OFFSET + 30, false)
		expect(service.players.size() == 15, "Repeated disconnect notifications do not remove other players")
		button(30, JOY_BUTTON_A, true)
		expect(service.players.size() == 16 and service.player_for_device(DEVICE_OFFSET + 30) == 1, "Reconnect cycles do not accumulate ghost players")
	service.clear_actions()
	for id: int in service.players:
		expect(service.movement(id) == Vector2.ZERO and not service.consume_jump(id), "Focus loss cannot leave stuck actions")
	button(31, JOY_BUTTON_B, true)
	service._physics_process(1.3)
	expect(not service.players.has(2), "Hold east face button releases a slot")
	# Keyboard is opt-in, occupies one of the same sixteen slots, and is isolated.
	service.keyboard_enabled = true
	key(KEY_ENTER, true)
	expect(service.player_for_device(PlayerInput.KEYBOARD_DEVICE) == 2, "Keyboard joins a free slot")
	key(KEY_W, true)
	key(KEY_SPACE, true)
	expect(service.movement(2) == Vector2.UP and service.consume_jump(2), "Keyboard has equivalent actions")
	expect(service.movement(3) == Vector2.ZERO, "Keyboard cannot control another player")
	key(KEY_BACKSPACE, true)
	expect(not service.players.has(2), "Keyboard can leave")
	service.queue_free()
	await process_frame
	if not failures:
		print("SDK input checks passed: %d synthetic assertions; physical controllers not tested." % checks)
	quit(1 if failures else 0)


func button(device: int, index: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = DEVICE_OFFSET + device
	event.button_index = index
	event.pressed = pressed
	service.handle_event(event)


func axis(device: int, index: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = DEVICE_OFFSET + device
	event.axis = index
	event.axis_value = value
	service.handle_event(event)


func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	service.handle_event(event)


func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
