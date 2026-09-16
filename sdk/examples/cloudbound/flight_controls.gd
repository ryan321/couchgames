extends RefCounted
## Sideways grip: D-pad left, 1/2 right. One-second steady neutral pose.
var ready := false
var progress := 0.0
var neutral := Vector2.ZERO
var steering := Vector2.ZERO
var _sum := Vector2.ZERO
var _last_stamp := -1.0


func reset() -> void:
	ready = false
	progress = 0.0
	_sum = Vector2.ZERO
	steering = Vector2.ZERO
	_last_stamp = -1.0


static func angles(acceleration: Vector3) -> Vector2:
	# In this grip Wii +Y points toward the 1/2 end, +X toward the player.
	# Lowering the right end banks right; rolling away from the body dives.
	return Vector2(atan2(-acceleration.y, Vector2(acceleration.x, acceleration.z).length()),
		atan2(-acceleration.x, acceleration.z))


func update(sample: Dictionary, delta: float) -> Vector2:
	if sample.is_empty():
		reset()
		return Vector2.ZERO
	var acceleration: Vector3 = sample["acceleration"]
	var angle := angles(acceleration)
	if not ready:
		# Only new samples count; a repeated snapshot cannot complete calibration.
		var stamp: float = sample["updated"]
		if stamp == _last_stamp:
			return Vector2.ZERO
		var elapsed := clampf(stamp - _last_stamp, 0.0, 0.05) if _last_stamp >= 0.0 else 0.0
		_last_stamp = stamp
		if acceleration.length() < 0.65 or acceleration.length() > 1.35 \
			or absf(angle.x) > 0.65 or absf(angle.y) > 2.4 \
			or (progress > 0.0 and angle.distance_to(_sum / progress) > 0.05):
			progress = 0.0
			_sum = Vector2.ZERO
			return Vector2.ZERO
		_sum += angle * elapsed
		progress += elapsed
		if progress >= 1.0:
			neutral = _sum / progress
			ready = true
		return Vector2.ZERO
	# Shakes aren't tilt. Keep the last stable direction during brief acceleration spikes.
	if acceleration.length() >= 0.65 and acceleration.length() <= 1.35:
		var target := (angle - neutral) / deg_to_rad(30.0)
		for axis in 2:
			target[axis] = signf(target[axis]) * clampf((absf(target[axis]) - 0.08) / 0.92, 0.0, 1.0)
		steering = steering.lerp(target, 1.0 - exp(-8.0 * delta))
	return steering
