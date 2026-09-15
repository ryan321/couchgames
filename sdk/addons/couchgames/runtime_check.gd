@tool
extends RefCounted
## The host detects missing installations; this checks the engine running the SDK.

const POLICY_PATH := "res://addons/couchgames/runtime_policy.json"


static func check() -> Dictionary:
	return assess(Engine.get_version_info(), OS.has_feature("C#"))


static func assess(info: Dictionary, dotnet: bool = false) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(POLICY_PATH))
	if not parsed is Dictionary:
		return {
			"status": "unusable", "supported": false,
			"instructions": ["Restore addons/couchgames/runtime_policy.json and include it in exports."],
		}
	var policy: Dictionary = parsed
	for field: String in ["runtime_id", "godot_version", "release_status", "build", "edition", "download_url"]:
		if not policy.get(field) is String or str(policy[field]).is_empty():
			return {
				"status": "unusable", "supported": false,
				"instructions": ["Restore a complete addons/couchgames/runtime_policy.json from the SDK."],
			}
	# JSON fixtures encode numbers as floats; Engine.get_version_info() uses ints.
	# Require whole numbers before formatting both forms identically.
	var version_parts: Array[int] = []
	for field: String in ["major", "minor", "patch"]:
		var number: Variant = info.get(field, -1)
		if (not number is int and not number is float) or number < 0 or number != floor(number):
			return {"status": "unusable", "supported": false, "instructions": ["Godot returned invalid version information."]}
		version_parts.append(int(number))
	var version := "%d.%d.%d" % [version_parts[0], version_parts[1], version_parts[2]]
	var edition := "dotnet" if dotnet else "standard"
	var matches: bool = (
		policy.get("policy_version") == 1
		and version == policy.get("godot_version")
		and info.get("status") == policy.get("release_status")
		and info.get("build") == policy.get("build")
		and edition == policy.get("edition")
	)
	return {
		"status": "supported" if matches else "unsupported",
		"supported": matches,
		"policy": policy,
		"detected": {"version": version, "status": info.get("status", "unknown"), "build": info.get("build", "unknown"), "edition": edition},
		"instructions": [
			"Use Godot %s standard stable from %s" % [policy.get("godot_version", "unknown"), policy.get("download_url", "")],
			"Close this project and reopen it with the supported Godot executable.",
			"Run couch doctor --require-godot to check the computer's installation. Use --godot or COUCH_GODOT for a custom location.",
			"Export templates and .NET are not required for SDK/editor tests. Nothing is installed automatically.",
		],
	}
