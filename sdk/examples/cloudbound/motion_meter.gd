extends Control
var steering := Vector2.ZERO
var receiving := false

func _draw() -> void:
	var center := size / 2
	draw_circle(center, 45, Color(1, 1, 1, 0.09))
	draw_arc(center, 45, 0, TAU, 48, Color(1, 1, 1, 0.3), 1.5, true)
	draw_line(center - Vector2(35, 0), center + Vector2(35, 0), Color(1, 1, 1, 0.3), 1, true)
	draw_line(center - Vector2(0, 35), center + Vector2(0, 35), Color(1, 1, 1, 0.3), 1, true)
	draw_circle(center + Vector2(steering.x, -steering.y) * 33, 7,
		Color("ffe29d") if receiving else Color("809da4"))
