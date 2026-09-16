extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func expect(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func run() -> void:
	var args := OS.get_cmdline_user_args()
	var projects = load("res://projects.gd")
	var template := args[0]
	var parent := args[1]
	var made: Dictionary = projects.create(template,parent,"Our First Game")
	expect(made.has("path"),"Independent project is created from installed template")
	if made.has("path"):
		var config := ConfigFile.new()
		config.load(made.path.path_join("project.godot"))
		expect(config.get_value("application","config/name")=="Our First Game","Game name is saved as a config value")
		expect(FileAccess.file_exists(made.path.path_join("addons/couchgames/runtime_policy.json")),"Project contains its own SDK policy")
		expect(not DirAccess.dir_exists_absolute(made.path.path_join(".godot")),"Project excludes generated import caches")
		var original := FileAccess.get_file_as_string(made.path.path_join("project.godot"))
		var duplicate: Dictionary = projects.create(template,parent,"Our First Game")
		expect(duplicate.has("error") and original==FileAccess.get_file_as_string(made.path.path_join("project.godot")),"Creating the same project again never replaces existing work")
	var bad: Dictionary = projects.create(parent.path_join("missing-template"),parent,"Broken")
	expect(bad.has("error") and not DirAccess.dir_exists_absolute(parent.path_join("broken")),"Missing template leaves no partial project")
	var empty: Dictionary = projects.create(template,parent,"")
	expect(empty.has("error"),"Empty project name is rejected")
	var hub = load("res://hub.tscn").instantiate()
	root.add_child(hub)
	await process_frame
	expect(hub.get_node_or_null(".")!=null,"Installed Creator Hub builds its UI")
	hub.queue_free()
	await process_frame
	if failures==0: print("Creator Hub checks passed: 8 project/UI assertions.")
	quit(1 if failures else 0)
