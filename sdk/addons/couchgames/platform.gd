extends Node
## Initial SDK entry point. Input, saves, and lifecycle services are subsequent work.

const RuntimeCheck = preload("res://addons/couchgames/runtime_check.gd")

var runtime_status: Dictionary = {}


func _enter_tree() -> void:
	runtime_status = RuntimeCheck.check()
	if not runtime_status.get("supported", false):
		push_error("Couch Games runtime unsupported: " + "\n".join(runtime_status.get("instructions", [])))


func is_runtime_supported() -> bool:
	return runtime_status.get("supported", false)
