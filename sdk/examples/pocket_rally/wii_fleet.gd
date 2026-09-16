extends Node
## Driving-only adapter. The existing Cloudbound native reader is unchanged.
const Packet = preload("res://addons/couchgames/native_wii.gd")
const FIRST_DEVICE := 1000
const CAPACITY := 16
var service: Node
var motion: Node
var directory := ""
var _connections: Dictionary = {}
var _previous: Dictionary = {}

func _physics_process(_delta: float) -> void:
	var now := Time.get_unix_time_from_system()
	for slot in CAPACITY:
		var state = null
		var path := directory.path_join("remote-%d.json" % slot)
		if FileAccess.file_exists(path):
			var file := FileAccess.open(path,FileAccess.READ)
			if file and file.get_length() <= 512:
				state = JSON.parse_string(file.get_as_text())
		accept_packet(slot,state,now)

func accept_packet(slot: int, state: Variant, now: float) -> void:
	if slot < 0 or slot >= CAPACITY:
		return
	var device := FIRST_DEVICE+slot
	if not _valid(state,now):
		_disconnect(slot)
		return
	if _connections.get(slot,"") != state["generation"]:
		_disconnect(slot)
		_connections[slot] = state["generation"]
		service.set_device_profile(device,"wii_remote")
	motion.submit(device,state.get("acceleration"),float(state["updated"]),str(state.get("calibration","approximate")))
	var mask := int(state["buttons"])
	var previous: int = _previous.get(slot,0)
	for bit: int in Packet.BUTTONS:
		if bool(mask&bit) != bool(previous&bit):
			var event := InputEventJoypadButton.new()
			event.device = device
			event.button_index = Packet.BUTTONS[bit]
			event.pressed = bool(mask&bit)
			service.handle_event(event)
	var player: int = service.player_for_device(device)
	if player:
		service.players[player]["name"] = "Wii Remote %d" % (slot+1)
		# Preserve the held gas button that also joined this car.
		for bit: int in Packet.BUTTONS:
			service.players[player]["buttons"][Packet.BUTTONS[bit]] = bool(mask&bit)
	_previous[slot] = mask

func _disconnect(slot: int) -> void:
	if _connections.has(slot):
		motion.remove_device(FIRST_DEVICE+slot)
		service.device_connection_changed(FIRST_DEVICE+slot,false)
	_connections.erase(slot)
	_previous.erase(slot)

func _exit_tree() -> void:
	for slot: int in _connections.keys():
		_disconnect(slot)

func _valid(state: Variant, now: float) -> bool:
	if not state is Dictionary or not state.get("generation") is String:
		return false
	if state["generation"].is_empty() or state["generation"].length() > 64:
		return false
	var buttons = state.get("buttons")
	var updated = state.get("updated")
	if not (buttons is int or buttons is float) or not (updated is int or updated is float):
		return false
	return is_finite(float(buttons)) and buttons == floor(float(buttons)) and buttons >= 0 and buttons <= 65535 \
		and is_finite(float(updated)) and now-updated <= 2 and updated <= now+0.05
