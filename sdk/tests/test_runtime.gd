extends SceneTree

const RuntimeCheck = preload("res://addons/couchgames/runtime_check.gd")


func _initialize() -> void:
	var cases: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/runtime_versions.json"))
	for case: Dictionary in cases:
		var report: Dictionary = RuntimeCheck.assess(case["info"], case["dotnet"])
		if report["supported"] != case["supported"]:
			push_error("Runtime policy mismatch: " + case["raw"] + " => " + JSON.stringify(report))
			quit(1)
			return
	var actual := RuntimeCheck.check()
	print(JSON.stringify(actual))
	if not actual["supported"]:
		push_error("Run SDK tests with the supported Godot release.")
		quit(1)
		return
	print("SDK runtime checks passed: %d policy cases plus current engine." % cases.size())
	quit(0)
