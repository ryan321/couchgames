extends Node
## SDK entry point. Player IDs are session-local, one-based numbers (1–16).

const RuntimeCheck = preload("res://addons/couchgames/runtime_check.gd")
const PlayerInput = preload("res://addons/couchgames/player_input.gd")

var runtime_status: Dictionary = {}
var input: PlayerInput


func _enter_tree() -> void:
	runtime_status = RuntimeCheck.check()
	if not runtime_status.get("supported", false):
		push_error("Couch Games runtime unsupported: " + "\n".join(runtime_status.get("instructions", [])))
	input = PlayerInput.new()
	input.name = "PlayerInput"
	add_child(input)


func is_runtime_supported() -> bool:
	return runtime_status.get("supported", false)
