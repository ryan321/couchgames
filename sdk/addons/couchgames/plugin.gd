@tool
extends EditorPlugin

const RuntimeCheck = preload("res://addons/couchgames/runtime_check.gd")

var panel: VBoxContainer


func _enter_tree() -> void:
	panel = VBoxContainer.new()
	panel.custom_minimum_size = Vector2(0, 140)
	var report: Dictionary = RuntimeCheck.check()
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if report.get("supported", false):
		label.text = "Giga Couch: Godot %s is supported." % report["policy"]["godot_version"]
	else:
		label.text = "Giga Couch: runtime setup needed.\n" + "\n".join(report.get("instructions", []))
	panel.add_child(label)
	if not report.get("supported", false) and report.has("policy"):
		var button := Button.new()
		button.text = "Open supported Godot download page"
		var url: String = report["policy"]["download_url"]
		button.pressed.connect(func() -> void: OS.shell_open(url))
		panel.add_child(button)
	add_control_to_bottom_panel(panel, "Giga Couch")


func _exit_tree() -> void:
	if is_instance_valid(panel):
		remove_control_from_bottom_panel(panel)
		panel.queue_free()
