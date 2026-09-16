extends Node
## SDK entry point. Player IDs are session-local, one-based numbers (1–16).

const RuntimeCheck = preload("res://addons/couchgames/runtime_check.gd")
const PlayerInput = preload("res://addons/couchgames/player_input.gd")
const NativeWii = preload("res://addons/couchgames/native_wii.gd")
const ControllerMotion = preload("res://addons/couchgames/controller_motion.gd")

var runtime_status: Dictionary = {}
var input: PlayerInput
var motion: ControllerMotion


func _enter_tree() -> void:
	runtime_status = RuntimeCheck.check()
	if not runtime_status.get("supported", false):
		push_error("Couch Games runtime unsupported: " + "\n".join(runtime_status.get("instructions", [])))
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


func is_runtime_supported() -> bool:
	return runtime_status.get("supported", false)
