extends RefCounted
## Each driver owns their calibration. Horizontal sideways grip, D-pad left.
var ready := false
var progress := 0.0
var neutral := 0.0
var value := 0.0
var _sum := 0.0
var _stamp := -1.0

func reset() -> void:
	ready = false
	progress = 0
	value = 0
	_sum = 0
	_stamp = -1

func update(sample: Dictionary, delta: float) -> float:
	if sample.is_empty():
		reset()
		return 0.0
	var g: Vector3 = sample["acceleration"]
	var angle := atan2(-g.y, Vector2(g.x, g.z).length())
	if not ready:
		var stamp: float = sample["updated"]
		if stamp == _stamp:
			return 0
		var elapsed := clampf(stamp - _stamp, 0, 0.05) if _stamp >= 0 else 0.0
		_stamp = stamp
		if g.length() < 0.65 or g.length() > 1.35 or absf(angle) > 0.65 \
			or (progress > 0 and absf(angle - _sum / progress) > 0.05):
			progress = 0
			_sum = 0
			return 0
		_sum += angle * elapsed
		progress += elapsed
		if progress >= 1:
			neutral = _sum / progress
			ready = true
		return 0
	if g.length() >= 0.65 and g.length() <= 1.35:
		var target := (angle - neutral) / deg_to_rad(30)
		target = signf(target) * clampf((absf(target) - 0.08) / 0.92, 0, 1)
		value = lerpf(value, target, 1 - exp(-10 * delta))
	return value
