extends SceneTree

const NativeXpad = preload("res://addons/couchgames/native_xpad.gd")
const PlayerInput = preload("res://addons/couchgames/player_input.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var service := PlayerInput.new()
	root.add_child(service)
	service.set_process_input(false)
	service.set_physics_process(false)
	var reader := NativeXpad.new()
	reader.service = service
	for invalid in [null, {}, {"buttons": "1", "updated": 100}, {"buttons": 1.5, "updated": 100},
			{"buttons": 32768, "updated": 100}, {"buttons": -1, "updated": 100},
			{"buttons": 1, "updated": 90}, {"buttons": 1, "updated": 110},
			{"buttons": 1, "updated": 100, "lx": 2}]:
		expect(not reader.valid_state(invalid, 100), "Reject malformed or stale native Xpad input")
	reader.accept_state({"buttons": 1, "lx": 0, "ly": 0, "updated": 100}, 100)
	expect(service.player_for_device(reader.DEVICE) == 1, "A joins a player")
	expect(not service.consume_jump(1), "Joining A does not also jump")
	reader.accept_state({"buttons": 0, "lx": 0, "ly": 0, "updated": 100}, 100)
	reader.accept_state({"buttons": 1, "lx": 0, "ly": 0, "updated": 100}, 100)
	expect(service.consume_jump(1), "Second A press jumps")
	reader.accept_state({"buttons": 1, "lx": 0, "ly": 0, "updated": 100}, 100)
	expect(not service.consume_jump(1), "Held A does not repeat jump")
	reader.accept_state({"buttons": 0, "lx": 1, "ly": 0, "updated": 100}, 100)
	expect(service.movement(1).x > 0.9, "Left stick right moves")
	reader.accept_state({"buttons": 0, "lx": 0, "ly": -1, "updated": 100}, 100)
	expect(service.movement(1).y < -0.9, "Left stick up moves")
	reader.accept_state({"buttons": 256, "lx": 0, "ly": 0, "updated": 100}, 100)
	expect(service.movement(1) == Vector2.UP, "D-pad up moves")
	reader.accept_state({"buttons": 128, "lx": 0, "ly": 0, "updated": 100}, 100)
	expect(service.players[1].buttons.get(JOY_BUTTON_START, false), "Start maps to the menu button")
	expect(service.players[1]["name"] == "Wired USB pad", "Default native name")
	reader.accept_state({"buttons": 0, "lx": 0, "ly": 0, "updated": 100, "name": "PC Compact Controller"}, 100)
	expect(service.players[1]["name"] == "PC Compact Controller", "Host name is forwarded")
	reader.accept_state({"updated": 100, "pads": [
		{"slot": 0, "buttons": 0, "lx": 0, "ly": 0, "name": "Nacon Compact"},
		{"slot": 1, "buttons": 1, "lx": 0, "ly": 0, "name": "Afterglow Gamepad"}]}, 100)
	expect(service.player_for_device(reader.DEVICE) == 1, "First pad keeps its player")
	expect(service.player_for_device(reader.DEVICE + 1) == 2, "Second pad joins a second player")
	expect(reader.live_count == 2, "Two live USB pads")
	reader.accept_state({"updated": 100, "pads": [
		{"slot": 1, "buttons": 0, "lx": 0, "ly": 0, "name": "Afterglow Gamepad"}]}, 100)
	expect(service.player_for_device(reader.DEVICE) == 0, "Dropped pad removes its player")
	expect(service.player_for_device(reader.DEVICE + 1) == 2, "Remaining pad keeps its player")
	reader.accept_state({"buttons": 0, "lx": 0, "ly": 0, "updated": 103}, 100)
	expect(service.players.is_empty(), "Expired reader removes its player")
	reader.accept_state({"buttons": 0, "lx": 0, "ly": 0, "updated": 104}, 104)
	expect(service.players.is_empty(), "Reconnect waits for A")
	reader.accept_state({"buttons": 1, "lx": 0, "ly": 0, "updated": 104}, 104)
	expect(service.player_for_device(reader.DEVICE) == 1, "Rejoin reuses the freed slot")
	reader.accept_state(null, 104)
	expect(service.players.is_empty(), "Missing state removes the native player")
	reader.free()
	service.queue_free()
	await process_frame
	if not failures:
		print("Native Xpad checks passed: %d synthetic assertions." % checks)
	quit(1 if failures else 0)


func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
