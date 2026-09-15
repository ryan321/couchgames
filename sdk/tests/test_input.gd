extends SceneTree
## Synthetic mapped events test SDK routing, not Bluetooth/USB hardware.

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
	expect(service.players.size() == 16 and service.player_for_device(16) == 0, "A seventeenth device cannot steal a slot")
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
	service.device_connection_changed(0, false)
	expect(service.movement(1) == Vector2.ZERO and not service.consume_jump(1), "Disconnect clears held actions")
	expect(service.players.size() == 16 and not service.players[1]["connected"], "Disconnect reserves the character")
	button(0, JOY_BUTTON_A, true)
	expect(service.pending_claims.has(0) and service.player_for_device(0) == 0, "Reused device ID must explicitly reclaim")
	button(0, JOY_BUTTON_A, true)
	expect(service.player_for_device(0) == 1, "Explicit confirmation reclaims original character")
	service.device_connection_changed(0, false)
	service.device_connection_changed(1, false)
	button(30, JOY_BUTTON_A, true)
	button(30, JOY_BUTTON_DPAD_RIGHT, true)
	expect(service.claim_selection(30) == 2, "Identical controllers can choose the correct reserved slot")
	button(32, JOY_BUTTON_A, true)
	button(32, JOY_BUTTON_DPAD_RIGHT, true)
	button(30, JOY_BUTTON_A, true)
	expect(service.player_for_device(30) == 2 and not service.players[1]["connected"], "Reclaim does not capture a different disconnected player")
	button(32, JOY_BUTTON_A, true)
	expect(service.claim_selection(32) == -1 and service.player_for_device(32) == 0,
		"Concurrent claim does not silently switch to a different reserved character")
	button(32, JOY_BUTTON_B, true)
	service.leave(16)
	button(31, JOY_BUTTON_A, true)
	button(31, JOY_BUTTON_DPAD_RIGHT, true)
	expect(service.claim_selection(31) == 0, "New player is an explicit alternative to reclaim")
	button(31, JOY_BUTTON_A, true)
	expect(service.player_for_device(31) == 16, "New player fills only an unreserved slot")
	service.clear_actions()
	for id: int in service.players:
		expect(service.movement(id) == Vector2.ZERO and not service.consume_jump(id), "Focus loss cannot leave stuck actions")
	button(30, JOY_BUTTON_B, true)
	service._physics_process(1.3)
	expect(not service.players.has(2), "Hold east face button releases a slot")
	# Keyboard is opt-in, occupies one of the same sixteen slots, and is isolated.
	service.keyboard_enabled = true
	key(KEY_ENTER, true)
	key(KEY_RIGHT, true) # Select new player instead of the remaining reserved slot.
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
	event.device = device
	event.button_index = index
	event.pressed = pressed
	service.handle_event(event)


func axis(device: int, index: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = device
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
