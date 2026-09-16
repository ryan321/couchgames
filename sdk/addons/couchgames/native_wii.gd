extends Node
## Opt-in host-created state file for the experimental single-Remote macOS reader.
## The host owns the native process; game code only consumes its input state.

const DEVICE := 1000
const BUTTONS := {0x0100:JOY_BUTTON_DPAD_LEFT, 0x0200:JOY_BUTTON_DPAD_RIGHT,
	0x0400:JOY_BUTTON_DPAD_DOWN, 0x0800:JOY_BUTTON_DPAD_UP,
	0x01:JOY_BUTTON_Y, 0x02:JOY_BUTTON_X, 0x04:JOY_BUTTON_A,
	0x08:JOY_BUTTON_B, 0x10:JOY_BUTTON_BACK, 0x80:JOY_BUTTON_GUIDE}
var service: Node
var motion_service: Node
var state_path := ""
var previous := 0
var active := false


func _physics_process(_delta: float) -> void:
	var state = null
	if FileAccess.file_exists(state_path):
		var file := FileAccess.open(state_path, FileAccess.READ)
		if file and file.get_length() <= 512:
			state = JSON.parse_string(file.get_as_text())
	accept_state(state, Time.get_unix_time_from_system())


func accept_state(state: Variant, now: float) -> void:
	if not valid_state(state, now):
		if motion_service:
			motion_service.remove_device(DEVICE)
		if active:
			service.device_connection_changed(DEVICE, false)
		active = false
		previous = 0
		return
	if motion_service:
		motion_service.submit(DEVICE, state.get("acceleration"), float(state["updated"]),
			str(state.get("calibration", "approximate")))
	if not active:
		service.set_device_profile(DEVICE, "wii_remote")
		active = true
	var mask := int(state["buttons"])
	for bit: int in BUTTONS:
		if bool(mask & bit) != bool(previous & bit):
			var event := InputEventJoypadButton.new()
			event.device = DEVICE
			event.button_index = BUTTONS[bit]
			event.pressed = bool(mask & bit)
			service.handle_event(event)
	var player: int = service.player_for_device(DEVICE)
	if player:
		service.players[player]["name"] = "Wii Remote (native reader)"
	previous = mask


func valid_state(state: Variant, now: float) -> bool:
	if not state is Dictionary:
		return false
	var mask = state.get("buttons")
	var updated = state.get("updated")
	if not (mask is int or mask is float) or not (updated is int or updated is float):
		return false
	return is_finite(float(mask)) and mask == floor(float(mask)) and mask >= 0 and mask <= 65535 \
		and is_finite(float(updated)) and now - updated <= 2.0 and updated <= now + 1.0
