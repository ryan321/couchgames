extends Node
## SDK entry point. Player IDs are session-local, one-based numbers (1–16).

const RuntimeCheck = preload("res://addons/couchgames/runtime_check.gd")
const PlayerInput = preload("res://addons/couchgames/player_input.gd")
const NativeWii = preload("res://addons/couchgames/native_wii.gd")
const NativeXpad = preload("res://addons/couchgames/native_xpad.gd")
const ControllerMotion = preload("res://addons/couchgames/controller_motion.gd")
const PauseOverlay = preload("res://addons/couchgames/pause_overlay.gd")
const Saves = preload("res://addons/couchgames/saves.gd")

var runtime_status: Dictionary = {}
var input: PlayerInput
var motion: ControllerMotion


func _enter_tree() -> void:
	runtime_status = RuntimeCheck.check()
	if not runtime_status.get("supported", false):
		push_error("Giga Couch runtime unsupported: " + "\n".join(runtime_status.get("instructions", [])))
	input = PlayerInput.new()
	input.name = "PlayerInput"
	add_child(input)
	motion = ControllerMotion.new()
	motion.input_service = input
	add_child(motion)
	var native_state := OS.get_environment("COUCH_WII_NATIVE_STATE")
	if native_state.is_absolute_path():
		var reader := NativeWii.new()
		reader.service = input
		reader.motion_service = motion
		reader.state_path = native_state
		add_child(reader)
	var xpad_state := OS.get_environment("COUCH_XPAD_NATIVE_STATE")
	if xpad_state.is_absolute_path():
		var xpad := NativeXpad.new()
		xpad.name = "NativeXpad"
		xpad.service = input
		xpad.state_path = xpad_state
		add_child(xpad)


func is_runtime_supported() -> bool:
	return runtime_status.get("supported", false)


func quit_to_platform() -> void:
	get_tree().quit()


func install_shell() -> void:
	if has_node("PauseOverlay"):
		return
	for child in get_children():
		if child is PauseOverlay:
			return
	var overlay := PauseOverlay.new()
	overlay.name = "PauseOverlay"
	add_child(overlay)


func save_data(slot: String, data: Variant) -> Dictionary:
	return Saves.save_data(slot, data)


func load_data(slot: String) -> Dictionary:
	return Saves.load_data(slot)
