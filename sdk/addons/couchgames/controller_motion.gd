extends Node
## Acceleration in g including gravity, in a shared grip frame:
## +X toward player, +Y right, +Z out through buttons (up when held flat).
## Native Wii is already in this frame when held sideways, D-pad left.
## Godot normalizes individual horizontal Joy-Cons and Pro-style controllers.
const MAX_AGE := 0.25
const GRAVITY := 9.80665
var input_service: Node
var backend: Object = Input
var enabled := false
var _samples: Dictionary = {}
var _owned_sensors: Dictionary = {}
var _connected: Array = []


func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		for device: int in _owned_sensors:
			if device in backend.get_connected_joypads():
				backend.set_joy_motion_sensors_enabled(device, false)
		_owned_sensors.clear()
		for device: int in _connected:
			remove_device(device)
		_connected.clear()


func _exit_tree() -> void:
	set_enabled(false)


func _physics_process(_delta: float) -> void:
	if enabled:
		poll(Time.get_unix_time_from_system())


func poll(now: float) -> void:
	if not enabled:
		return
	var connected: Array = Array(backend.get_connected_joypads())
	for device: int in _connected:
		if device not in connected:
			remove_device(device)
			_owned_sensors.erase(device)
	_connected = connected
	for device: int in connected:
		if not backend.has_joy_motion_sensors(device):
			remove_device(device)
			continue
		if not backend.is_joy_motion_sensors_enabled(device):
			backend.set_joy_motion_sensors_enabled(device, true)
			_owned_sensors[device] = true
		if not backend.is_joy_motion_sensors_enabled(device):
			remove_device(device)
			continue
		var acceleration: Vector3 = backend.get_joy_accelerometer(device)
		# Some devices expose gyro only, or return zero before their first report.
		if not acceleration.is_finite() or acceleration.length() < 0.1:
			remove_device(device)
			continue
		submit_engine(device, acceleration, backend.get_joy_gyroscope(device), now)


func submit_engine(device: int, acceleration: Vector3, gyroscope: Vector3, now: float) -> void:
	# Godot 4.7.2 negates SDL's right/up/toward-player acceleration (m/s²).
	# SDL already rotates each horizontal Joy-Con: do NOT rotate it twice.
	var grip := Vector3(-acceleration.z, -acceleration.x, -acceleration.y) / GRAVITY
	submit(device, [grip.x, grip.y, grip.z], now, "driver")
	if _samples.has(device):
		_samples[device]["source"] = "godot"
		# Raw angular rates use Godot's documented X/Y/Z axes, in rad/s.
		_samples[device]["gyroscope"] = gyroscope if gyroscope.is_finite() else Vector3.ZERO
		_samples[device]["freshness"] = "polled"


func submit(device: int, values: Variant, updated: float, calibration: String) -> void:
	if not values is Array or values.size() != 3 or not is_finite(updated):
		remove_device(device)
		return
	for value in values:
		if not (value is float or value is int) or not is_finite(float(value)) or absf(value) > 8.0:
			remove_device(device)
			return
	_samples[device] = {"acceleration": Vector3(values[0], values[1], values[2]),
		"updated": updated, "calibration": calibration, "source": "native", "freshness": "report"}


func status_for_device(device: int) -> String:
	if not sample_for_device(device).is_empty():
		return "available"
	if device == 1000:
		return "waiting"
	if device not in backend.get_connected_joypads():
		return "disconnected"
	if not backend.has_joy_motion_sensors(device):
		return "unavailable"
	return "waiting" if enabled else "disabled"


func sample_for_device(device: int, now: float = -1.0) -> Dictionary:
	if now < 0:
		now = Time.get_unix_time_from_system()
	var sample: Dictionary = _samples.get(device, {})
	if sample.is_empty() or not is_finite(float(sample["updated"])) \
		or now - sample["updated"] > MAX_AGE or sample["updated"] > now + 0.05:
		return {}
	return sample.duplicate()


func sample_for_player(player_id: int) -> Dictionary:
	if not input_service.players.has(player_id):
		return {}
	return sample_for_device(input_service.players[player_id]["device"])


func remove_device(device: int) -> void:
	_samples.erase(device)
