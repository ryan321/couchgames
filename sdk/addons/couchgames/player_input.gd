extends Node
## Device-isolated actions for up to 16 local players, over USB or wireless.
## Uses Godot/SDL's mapped buttons: south face = Xbox A / PlayStation Cross.

signal player_joined(player_id: int)
signal player_left(player_id: int)
signal roster_changed

const Profiles = preload("res://addons/couchgames/controller_profiles.gd")
const MAX_PLAYERS := 16
const KEYBOARD_DEVICE := -100
const DEAD_ZONE := 0.2
const LEAVE_HOLD_SECONDS := 1.25

var keyboard_enabled := false
var players: Dictionary = {}
var _devices: Dictionary = {}
var _profile_overrides: Dictionary = {}


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
		if state["buttons"].get(state["profile"]["leave"], false):
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
			if event.button_index in profile_for_device(device)["join"]:
				_assign(device)
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
		if event.button_index in state["profile"]["jump"] and event.pressed and not was_pressed:
			state["jump"] = true


func movement(player_id: int) -> Vector2:
	if not players.has(player_id) or not players[player_id]["connected"]:
		return Vector2.ZERO
	var state: Dictionary = players[player_id]
	var buttons: Dictionary = state["buttons"]
	var digital := Vector2(
		float(buttons.get(JOY_BUTTON_DPAD_RIGHT, false)) - float(buttons.get(JOY_BUTTON_DPAD_LEFT, false)),
		float(buttons.get(JOY_BUTTON_DPAD_DOWN, false)) - float(buttons.get(JOY_BUTTON_DPAD_UP, false)))
	if state["profile"]["sideways"]:
		digital = Vector2(digital.y, -digital.x)
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


func profile_for_device(device: int) -> Dictionary:
	if _profile_overrides.has(device):
		return Profiles.get_profile(_profile_overrides[device])
	return Profiles.detect(Input.get_joy_name(device), Input.get_joy_info(device))


func device_profile_override(device: int) -> String:
	return _profile_overrides.get(device, "auto")


func set_device_profile(device: int, profile_id: String) -> bool:
	# Overrides are session-only; never associate reused device IDs with old profiles.
	if profile_id != "auto" and profile_id not in Profiles.IDS:
		return false
	if profile_id == "auto":
		_profile_overrides.erase(device)
	else:
		_profile_overrides[device] = profile_id
	if _devices.has(device):
		var id: int = _devices[device]
		var profile := profile_for_device(device)
		if not profile["playable"]:
			leave(id)
		else:
			_clear_state(players[id])
			players[id]["profile"] = profile
	roster_changed.emit()
	return true


func leave(player_id: int) -> void:
	if not players.has(player_id):
		return
	_devices.erase(players[player_id]["device"])
	players.erase(player_id)
	player_left.emit(player_id)
	roster_changed.emit()


func device_connection_changed(device: int, connected: bool) -> void:
	# A disconnected device leaves immediately; reconnecting must join afresh.
	if not connected:
		_profile_overrides.erase(device)
	if not connected and _devices.has(device):
		leave(_devices[device])
	else:
		roster_changed.emit()


func clear_actions() -> void:
	for state: Dictionary in players.values():
		_clear_state(state)


func _assign(device: int) -> void:
	if _devices.has(device):
		return
	var player_id := 0
	for candidate in range(1, MAX_PLAYERS + 1):
		if not players.has(candidate):
			player_id = candidate
			break
	if player_id == 0:
		return
	var device_name := "Keyboard" if device == KEYBOARD_DEVICE else Input.get_joy_name(device)
	if device_name.is_empty():
		device_name = "Controller %d" % (device + 1)
	players[player_id] = {"device": device, "name": device_name, "connected": true,
		"stick": Vector2.ZERO, "buttons": {}, "keys": {}, "jump": false, "leave_time": 0.0,
		"profile": Profiles.get_profile("gamepad") if device == KEYBOARD_DEVICE else profile_for_device(device)}
	_devices[device] = player_id
	player_joined.emit(player_id)
	roster_changed.emit()


func _keyboard_event(event: InputEventKey) -> void:
	var key := event.physical_keycode
	if key == 0:
		key = event.keycode
	if not _devices.has(KEYBOARD_DEVICE):
		if event.pressed and key in [KEY_ENTER, KEY_SPACE]:
			_assign(KEYBOARD_DEVICE)
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
