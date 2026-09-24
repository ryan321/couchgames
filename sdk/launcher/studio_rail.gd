extends Control
## Left brand rail, matching GDK Setup: gradient, mark, isometric worlds, play steps.

const MINT := Color("8ce8be")
const INK := Color("f2f5f8")
const MUTED := Color("a0afbf")
const BLUE := Color("9abef7")
var _fill: GradientTexture2D

class Accents:
	extends Control
	const MINT := Color("8ce8be")

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var origin := Vector2(150, 250)
		draw_line(Vector2(origin.x, origin.y + 14), Vector2(origin.x, origin.y - 64), MINT, 2.0, true)
		var flag := PackedVector2Array([
			Vector2(origin.x, origin.y - 62),
			Vector2(origin.x + 29, origin.y - 54),
			Vector2(origin.x, origin.y - 43),
		])
		draw_colored_polygon(flag, MINT)
		for point in [Vector2(65, origin.y - 73), Vector2(199, origin.y - 25), Vector2(191, origin.y + 80)]:
			draw_circle(point, 2.2, Color(MINT, 0.7))

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([Color("213d3c"), Color("16272d"), Color("111d2a")])
	_fill = GradientTexture2D.new()
	_fill.gradient = gradient
	_fill.fill_from = Vector2(0.5, 0.0)
	_fill.fill_to = Vector2(0.5, 1.0)
	_fill.width = 16
	_fill.height = 128
	resized.connect(queue_redraw)
	var accents := Accents.new()
	accents.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(accents)
	var pulse := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(accents, "modulate:a", 0.7, 1.5)
	pulse.tween_property(accents, "modulate:a", 1.0, 1.5)

func _draw() -> void:
	if _fill:
		draw_texture_rect(_fill, Rect2(Vector2.ZERO, size), false)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(104, 58), "GIGA", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, INK)
	draw_string(font, Vector2(104, 80), "COUCH", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, INK)
	draw_string(font, Vector2(30, 128), "GAME PLAYER", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MINT)
	var origin := Vector2(150, 250)
	for index in range(2, -1, -1):
		var y := origin.y + float(index) * 24.0
		var diamond := PackedVector2Array([
			Vector2(origin.x, y - 50),
			Vector2(origin.x + 86, y),
			Vector2(origin.x, y + 50),
			Vector2(origin.x - 86, y),
		])
		var fill := Color(MINT, 0.19) if index == 0 else Color(BLUE, 0.06)
		draw_colored_polygon(diamond, fill)
		var outline := diamond.duplicate()
		outline.append(diamond[0])
		draw_polyline(outline, MINT if index == 0 else Color(BLUE, 0.35), 1.0, true)
	var steps := [
		["01", "Grab a controller"],
		["02", "Pick tonight's game"],
		["03", "Press Play"],
		["04", "Make room on the couch"],
	]
	for i in steps.size():
		var y := 470.0 + float(i) * 42.0
		draw_string(font, Vector2(30, y), steps[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MINT)
		draw_string(font, Vector2(64, y), steps[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, INK)
	draw_string(font, Vector2(30, size.y - 64), "YOUR IDEAS. YOUR GAMES.", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MINT)
	draw_string(font, Vector2(30, size.y - 42), "Built for playing together.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MUTED)
