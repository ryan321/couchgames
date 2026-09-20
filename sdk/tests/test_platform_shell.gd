extends SceneTree
## Platform pause/quit/save. Does not quit the test tree or touch SQLite.

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var platform: Node = root.get_node("Platform")
	expect(platform.has_method("quit_to_platform"), "quit_to_platform exists")
	expect(platform.has_method("install_shell") and platform.has_method("save_data") and platform.has_method("load_data"),
		"install_shell, save_data, and load_data exist")

	var save_dir := OS.get_cache_dir().path_join("couch-save-test-%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(save_dir)
	OS.set_environment("COUCH_SAVE_DIR", save_dir)

	var payload := {"level": 3, "name": "couch", "ready": true, "items": ["flag", 2]}
	var saved: Dictionary = platform.save_data("slot-1_a", payload)
	expect(saved.get("ok") == true, "save_data roundtrip write succeeds")
	expect(FileAccess.file_exists(save_dir.path_join("slot-1_a.json")), "save writes save_dir/slot.json")
	expect(not FileAccess.file_exists(save_dir.path_join("slot-1_a.json.tmp")), "atomic write leaves no tmp file")
	var loaded: Dictionary = platform.load_data("slot-1_a")
	expect(loaded.get("ok") == true and loaded.get("data") is Dictionary, "load_data roundtrip succeeds")
	var data: Dictionary = loaded.get("data")
	expect(data.get("level") == 3 and data.get("name") == "couch" and data.get("ready") == true, "roundtrip preserves scalars")
	expect(data.get("items") is Array and data.get("items")[0] == "flag", "roundtrip preserves arrays")

	var longest := "a".repeat(32)
	expect(platform.save_data(longest, 1).get("ok") == true, "32-character slot is allowed")
	expect(platform.load_data(longest).get("data") == 1, "32-character slot loads")

	for slot in ["", " ", "bad slot", "slash/name", "dot.name", "../x", "a".repeat(33), "slot.json"]:
		expect(platform.save_data(slot, {}).get("ok") == false, "save rejects slot '%s'" % slot)
		expect(platform.load_data(slot).get("ok") == false, "load rejects slot '%s'" % slot)

	var huge := {"blob": "x".repeat(256 * 1024)}
	var oversized: Dictionary = platform.save_data("huge", huge)
	expect(oversized.get("ok") == false, "oversized payload is rejected")
	expect(not FileAccess.file_exists(save_dir.path_join("huge.json")), "rejected payload is not written")
	expect(platform.save_data("ok-slot", Vector2.ZERO).get("ok") == false, "non-JSON types are rejected")

	var missing: Dictionary = platform.load_data("missing-slot")
	expect(missing.get("ok") == false and missing.get("error") == "not found", "missing load returns ok false with not found")

	OS.unset_environment("COUCH_SAVE_DIR")
	for filename in DirAccess.get_files_at(save_dir):
		DirAccess.remove_absolute(save_dir.path_join(filename))
	DirAccess.remove_absolute(save_dir)

	platform.install_shell()
	expect(platform.has_node("PauseOverlay"), "install_shell adds PauseOverlay")
	var overlay: Node = platform.get_node("PauseOverlay")
	expect(overlay is CanvasLayer, "PauseOverlay is a CanvasLayer")
	expect(overlay.process_mode == Node.PROCESS_MODE_ALWAYS, "PauseOverlay always processes")
	var count := platform.get_child_count()
	platform.install_shell()
	expect(platform.get_child_count() == count, "install_shell is idempotent")

	if not failures:
		print("SDK platform shell checks passed: %d assertions." % checks)
	quit(1 if failures else 0)


func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
