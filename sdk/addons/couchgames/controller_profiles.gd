extends RefCounted
## Semantic actions for Godot/SDL-mapped controllers, not raw Bluetooth packets.
## Wii layouts are experimental until physical tests confirm their mappings.

const IDS := ["gamepad", "wii_remote", "wii_nunchuk", "wii_classic", "wii_classic_pro", "wii_u_pro", "wii_unknown"]


static func get_profile(id: String) -> Dictionary:
	var profile := {"id": id, "label": "Standard gamepad", "experimental": false,
		"playable": true, "sideways": false, "join": [JOY_BUTTON_A, JOY_BUTTON_X, JOY_BUTTON_Y],
		"jump": [JOY_BUTTON_A], "leave": JOY_BUTTON_B,
		"prompt": "Stick / D-pad: move · south face: jump · hold east face: leave"}
	match id:
		"gamepad":
			pass
		"wii_remote":
			profile.merge({"label": "Wii Remote / Remote Plus", "experimental": true, "sideways": true,
				"join": [JOY_BUTTON_Y, JOY_BUTTON_B], "jump": [JOY_BUTTON_Y], "leave": JOY_BUTTON_BACK,
				"prompt": "Hold sideways, 1/2 on right · D-pad: move · 2: jump · hold minus: leave"}, true)
		"wii_nunchuk":
			profile.merge({"label": "Wii Remote + Nunchuk", "experimental": true,
				"join": [JOY_BUTTON_B, JOY_BUTTON_Y], "jump": [JOY_BUTTON_B], "leave": JOY_BUTTON_BACK,
				"prompt": "Nunchuk stick: move · remote A: jump · hold minus: leave"}, true)
		"wii_classic", "wii_classic_pro", "wii_u_pro":
			var labels := {"wii_classic": "Wii Classic Controller", "wii_classic_pro": "Wii Classic Controller Pro", "wii_u_pro": "Wii U Pro Controller"}
			profile.merge({"label": labels[id], "experimental": true,
				"join": [JOY_BUTTON_B, JOY_BUTTON_A], "jump": [JOY_BUTTON_B], "leave": JOY_BUTTON_BACK,
				"prompt": "Left stick / D-pad: move · A: jump · hold minus: leave"}, true)
		_:
			profile.merge({"id": "wii_unknown", "label": "Wii accessory — unsupported layout",
				"experimental": true, "playable": false, "join": [], "jump": [],
				"prompt": "This accessory needs its own input adapter; no player will be created."}, true)
	return profile


static func detect(device_name: String, info: Dictionary = {}) -> Dictionary:
	# Only use explicit driver names. Generic Nintendo IDs also cover other consoles.
	var names := [device_name.to_lower(), str(info.get("raw_name", "")).to_lower()]
	for name: String in names:
		if "balance board" in name or "unknown extension" in name or "wii u gamepad" in name:
			return get_profile("wii_unknown")
		if "wii" in name and ("guitar" in name or "drum" in name or "tablet" in name):
			return get_profile("wii_unknown")
		if "wii u pro" in name:
			return get_profile("wii_u_pro")
		if "classic controller pro" in name:
			return get_profile("wii_classic_pro")
		if "classic controller" in name:
			return get_profile("wii_classic")
		if "nunchuk" in name or "nunchuck" in name:
			return get_profile("wii_nunchuk")
		if name in ["nintendo wii remote", "nintendo wii remote plus", "wii remote", "wii remote plus"]:
			return get_profile("wii_remote")
	# Raw RVL names mean the SDL Wii driver has not identified the extension/layout.
	for name: String in names:
		if "rvl-cnt" in name:
			return get_profile("wii_unknown")
	return get_profile("gamepad")
