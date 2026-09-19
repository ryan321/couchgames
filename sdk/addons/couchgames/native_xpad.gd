extends Node
## Opt-in host-created state for wired vendor-class Xbox 360-style pads.
## The host owns the native USB process; game code only consumes its input state.

const DEVICE := 1100
const MAX_PADS := 8
const BUTTONS := {
	1: JOY_BUTTON_A, 2: JOY_BUTTON_B, 4: JOY_BUTTON_X, 8: JOY_BUTTON_Y,
	16: JOY_BUTTON_LEFT_SHOULDER, 32: JOY_BUTTON_RIGHT_SHOULDER,
	64: JOY_BUTTON_BACK, 128: JOY_BUTTON_START,
	256: JOY_BUTTON_DPAD_UP, 512: JOY_BUTTON_DPAD_DOWN,
	1024: JOY_BUTTON_DPAD_LEFT, 2048: JOY_BUTTON_DPAD_RIGHT,
	4096: JOY_BUTTON_LEFT_STICK, 8192: JOY_BUTTON_RIGHT_STICK, 16384: JOY_BUTTON_GUIDE}
var service: Node
var state_path := ""
var previous := 0
var previous_stick := Vector2.INF
var active := false
var live_count := 0
var _pads: Dictionary = {}


func _physics_process(_delta: float) -> void:
	var state = null
	if FileAccess.file_exists(state_path):
		var file := FileAccess.open(state_path, FileAccess.READ)
		if file and file.get_length() <= 4096:
			state = JSON.parse_string(file.get_as_text())
	accept_state(state, Time.get_unix_time_from_system())


func accept_state(state: Variant, now: float) -> void:
	if not valid_snapshot(state, now):
		for device: int in _pads.keys():
			service.device_connection_changed(device, false)
		_pads.clear()
		active = false
		live_count = 0
		previous = 0
		previous_stick = Vector2.INF
		return
	var seen: Dictionary = {}
	for pad in _pad_rows(state):
		if not valid_pad(pad):
			continue
		var slot := int(pad.get("slot", seen.size()))
		if slot < 0 or slot >= MAX_PADS:
			continue
		var device := DEVICE + slot
		seen[device] = true
		_apply_pad(device, pad)
	for device: int in _pads.keys():
		if not seen.has(device):
			service.device_connection_changed(device, false)
			_pads.erase(device)
	live_count = _pads.size()
	active = live_count > 0
	if _pads.has(DEVICE):
		previous = int(_pads[DEVICE]["previous"])
		previous_stick = _pads[DEVICE]["stick"]
	else:
		previous = 0
		previous_stick = Vector2.INF


func valid_snapshot(state: Variant, now: float) -> bool:
	if not state is Dictionary:
		return false
	var updated = state.get("updated")
	if not (updated is int or updated is float):
		return false
	if not (is_finite(float(updated)) and now - updated <= 2.0 and updated <= now + 1.0):
		return false
	if state.has("pads"):
		return state["pads"] is Array
	return valid_pad(state)


func valid_state(state: Variant, now: float) -> bool:
	return valid_snapshot(state, now)


func valid_pad(pad: Variant) -> bool:
	if not pad is Dictionary:
		return false
	var mask = pad.get("buttons")
	if not (mask is int or mask is float):
		return false
	if not (is_finite(float(mask)) and mask == floor(float(mask)) and mask >= 0 and mask <= 32767):
		return false
	for key in ["lx", "ly"]:
		if pad.has(key):
			var axis = pad[key]
			if not (axis is int or axis is float) or not is_finite(float(axis)) or abs(float(axis)) > 1.5:
				return false
	return true


func _pad_rows(state: Dictionary) -> Array:
	if state.has("pads") and state["pads"] is Array:
		return state["pads"]
	return [state]


func _apply_pad(device: int, pad: Dictionary) -> void:
	if not _pads.has(device):
		service.set_device_profile(device, "gamepad")
		_pads[device] = {"previous": 0, "stick": Vector2.INF}
	var previous_mask: int = _pads[device]["previous"]
	var mask := int(pad["buttons"])
	for bit: int in BUTTONS:
		if bool(mask & bit) != bool(previous_mask & bit):
			var event := InputEventJoypadButton.new()
			event.device = device
			event.button_index = BUTTONS[bit]
			event.pressed = bool(mask & bit)
			service.handle_event(event)
	var stick := Vector2(float(pad.get("lx", 0.0)), float(pad.get("ly", 0.0)))
	if _pads[device]["stick"] != stick:
		_axis(device, JOY_AXIS_LEFT_X, stick.x)
		_axis(device, JOY_AXIS_LEFT_Y, stick.y)
		_pads[device]["stick"] = stick
	var player: int = service.player_for_device(device)
	if player:
		service.players[player]["name"] = str(pad.get("name", "Wired USB pad"))
	_pads[device]["previous"] = mask


func _axis(device: int, axis: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = axis
	event.axis_value = value
	service.handle_event(event)
