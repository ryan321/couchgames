extends Node
## Device-isolated actions for up to 16 local players, over USB or wireless.
## Uses Godot/SDL's mapped buttons: south face = Xbox A / PlayStation Cross.

signal player_joined(player_id: int)
signal player_left(player_id: int)
signal roster_changed

const MAX_PLAYERS := 16
const KEYBOARD_DEVICE := -100
const DEAD_ZONE := 0.2
const LEAVE_HOLD_SECONDS := 1.25

var keyboard_enabled := false
var players: Dictionary = {}
var pending_claims: Dictionary = {}
var _devices: Dictionary = {}


func _ready() -> void:
	Input.joy_connection_changed.connect(device_connection_changed)


func _input(event: InputEvent) -> void:
	handle_event(event)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		clear_actions()


func _physics_process(delta: float) -> void:
	for id: int in players.keys():
		var state: Dictionary = players[id]
		if state["buttons"].get(JOY_BUTTON_B, false):
			state["leave_time"] += delta
			if state["leave_time"] >= LEAVE_HOLD_SECONDS:
				leave(id)
		else:
			state["leave_time"] = 0.0


func handle_event(event: InputEvent) -> void:
	if event is InputEventKey:
		if keyboard_enabled and not event.echo:
			_keyboard_event(event)
		return
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return
	var device := event.device
	if not _devices.has(device):
		if event is InputEventJoypadButton and event.pressed:
			if pending_claims.has(device):
				_claim_event(device, event.button_index)
			elif event.button_index in [JOY_BUTTON_A, JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_START]:
				_request_join(device)
		return
	var state: Dictionary = players[_devices[device]]
	if event is InputEventJoypadMotion:
		if event.axis == JOY_AXIS_LEFT_X:
			state["stick"].x = event.axis_value
		elif event.axis == JOY_AXIS_LEFT_Y:
			state["stick"].y = event.axis_value
	else:
		var was_pressed: bool = state["buttons"].get(event.button_index, false)
		state["buttons"][event.button_index] = event.pressed
		if event.button_index == JOY_BUTTON_A and event.pressed and not was_pressed:
			state["jump"] = true


func movement(player_id: int) -> Vector2:
	if not players.has(player_id) or not players[player_id]["connected"]:
		return Vector2.ZERO
	var state: Dictionary = players[player_id]
	var buttons: Dictionary = state["buttons"]
	var digital := Vector2(
		float(buttons.get(JOY_BUTTON_DPAD_RIGHT, false)) - float(buttons.get(JOY_BUTTON_DPAD_LEFT, false)),
		float(buttons.get(JOY_BUTTON_DPAD_DOWN, false)) - float(buttons.get(JOY_BUTTON_DPAD_UP, false)))
	if state["device"] == KEYBOARD_DEVICE:
		var keys: Dictionary = state["keys"]
		digital = Vector2(
			float(keys.get(KEY_D, false) or keys.get(KEY_RIGHT, false)) - float(keys.get(KEY_A, false) or keys.get(KEY_LEFT, false)),
			float(keys.get(KEY_S, false) or keys.get(KEY_DOWN, false)) - float(keys.get(KEY_W, false) or keys.get(KEY_UP, false)))
	if not digital.is_zero_approx():
		return digital.limit_length()
	var stick: Vector2 = state["stick"]
	var strength := stick.length()
	if strength <= DEAD_ZONE:
		return Vector2.ZERO
	return stick.normalized() * clampf((strength - DEAD_ZONE) / (1.0 - DEAD_ZONE), 0.0, 1.0)


func consume_jump(player_id: int) -> bool:
	if not players.has(player_id):
		return false
	var pressed: bool = players[player_id]["jump"]
	players[player_id]["jump"] = false
	return pressed


func player_for_device(device: int) -> int:
	return _devices.get(device, 0)


func leave(player_id: int) -> void:
	if not players.has(player_id):
		return
	_devices.erase(players[player_id]["device"])
	players.erase(player_id)
	player_left.emit(player_id)
	roster_changed.emit()


func device_connection_changed(device: int, connected: bool) -> void:
	# Reused device IDs do not prove ownership. Always require an explicit claim.
	pending_claims.erase(device)
	if not connected and _devices.has(device):
		var id: int = _devices[device]
		_devices.erase(device)
		_clear_state(players[id])
		players[id]["connected"] = false
		players[id]["device"] = -1
	roster_changed.emit()


func clear_actions() -> void:
	for state: Dictionary in players.values():
		_clear_state(state)


func claim_options() -> Array[int]:
	var options: Array[int] = []
	for id: int in players:
		if not players[id]["connected"]:
			options.append(id)
	options.sort()
	if players.size() < MAX_PLAYERS:
		options.append(0) # Explicitly choose to join as a new player.
	return options


func claim_selection(device: int) -> int:
	var options := claim_options()
	var selected: int = pending_claims.get(device, -1)
	return selected if selected in options else -1


func _request_join(device: int) -> void:
	var options := claim_options()
	if options.is_empty():
		return
	if options.size() == 1 and options[0] == 0:
		_assign(device, 0)
	else:
		pending_claims[device] = options[0]
		roster_changed.emit()


func _claim_event(device: int, button: int) -> void:
	var options := claim_options()
	if options.is_empty() or button == JOY_BUTTON_B:
		pending_claims.erase(device)
	elif button in [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
		var step := 1 if button == JOY_BUTTON_DPAD_RIGHT else -1
		var index := options.find(int(pending_claims[device]))
		pending_claims[device] = options[0] if index < 0 else options[posmod(index + step, options.size())]
	elif button == JOY_BUTTON_A:
		var selected := claim_selection(device)
		if selected >= 0:
			pending_claims.erase(device)
			_assign(device, selected)
	roster_changed.emit()


func _assign(device: int, player_id: int) -> void:
	if _devices.has(device):
		return
	var is_new := player_id == 0
	if is_new:
		for candidate in range(1, MAX_PLAYERS + 1):
			if not players.has(candidate):
				player_id = candidate
				break
	if player_id == 0 or (players.has(player_id) and players[player_id]["connected"]):
		return
	var device_name := "Keyboard" if device == KEYBOARD_DEVICE else Input.get_joy_name(device)
	if device_name.is_empty():
		device_name = "Controller %d" % (device + 1)
	players[player_id] = {"device": device, "name": device_name, "connected": true,
		"stick": Vector2.ZERO, "buttons": {}, "keys": {}, "jump": false, "leave_time": 0.0}
	_devices[device] = player_id
	if is_new:
		player_joined.emit(player_id)
	roster_changed.emit()


func _keyboard_event(event: InputEventKey) -> void:
	var key := event.physical_keycode
	if key == 0:
		key = event.keycode
	if not _devices.has(KEYBOARD_DEVICE):
		if event.pressed and key in [KEY_ENTER, KEY_SPACE]:
			if pending_claims.has(KEYBOARD_DEVICE):
				_claim_event(KEYBOARD_DEVICE, JOY_BUTTON_A)
			else:
				_request_join(KEYBOARD_DEVICE)
		elif event.pressed and pending_claims.has(KEYBOARD_DEVICE):
			if key in [KEY_LEFT, KEY_RIGHT]:
				_claim_event(KEYBOARD_DEVICE, JOY_BUTTON_DPAD_LEFT if key == KEY_LEFT else JOY_BUTTON_DPAD_RIGHT)
			elif key == KEY_ESCAPE:
				_claim_event(KEYBOARD_DEVICE, JOY_BUTTON_B)
		return
	var id: int = _devices[KEYBOARD_DEVICE]
	if key == KEY_BACKSPACE and event.pressed:
		leave(id)
		return
	var state: Dictionary = players[id]
	var was_pressed: bool = state["keys"].get(key, false)
	state["keys"][key] = event.pressed
	if key == KEY_SPACE and event.pressed and not was_pressed:
		state["jump"] = true


func _clear_state(state: Dictionary) -> void:
	state["stick"] = Vector2.ZERO
	state["buttons"].clear()
	state["keys"].clear()
	state["jump"] = false
	state["leave_time"] = 0.0
