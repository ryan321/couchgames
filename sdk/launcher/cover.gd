extends Control
## Original vector cover art, rendered at the card's current size.
var game_id := "little-world"
var tint := Color("a5cfa1")
static var _top_light: GradientTexture2D
static var _vignette: GradientTexture2D
static var _scrim: GradientTexture2D

static func _fade(colors: PackedColorArray, from: Vector2, to: Vector2, radial := false) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = colors
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = from
	texture.fill_to = to
	if radial:
		texture.fill = GradientTexture2D.FILL_RADIAL
	texture.width = 440
	texture.height = 270
	return texture

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	if game_id == "world-1-1": texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func oval(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 64:
		points.append(center+Vector2(cos(i*TAU/64),sin(i*TAU/64))*radius)
	draw_colored_polygon(points,color)

func poly(points: Array, color: String) -> void:
	draw_colored_polygon(PackedVector2Array(points),Color(color))

func _draw() -> void:
	draw_set_transform(Vector2.ZERO,0,size/Vector2(440,270))
	draw_rect(Rect2(0,0,440,270),tint)
	draw_circle(Vector2(370,35),100,tint.lightened(0.13))
	if game_id == "little-world":
		oval(Vector2(220,199),Vector2(164,44),Color("73988c"))
		oval(Vector2(220,183),Vector2(169,51),Color("dbebad"))
		for at in [Vector2(114,134),Vector2(318,139),Vector2(271,109)]:
			draw_line(at+Vector2(0,17),at+Vector2(0,-30),Color("728875"),7)
			oval(at-Vector2(0,22),Vector2(19,28),Color("638f79"))
			oval(at-Vector2(6,29),Vector2(13,20),Color("8eb384"))
		for i in 5:
			var at := Vector2(152+i*34,181+sin(i*2)*16)
			var color: Color = [Color("df795e"),Color("548cba"),Color("daa347"),Color("9988bd"),Color("538e80")][i]
			oval(at+Vector2(3,9),Vector2(12,4),Color("9dad86"))
			draw_line(at+Vector2(-3,3),at+Vector2(-5,11),Color("355564"),4)
			draw_line(at+Vector2(3,3),at+Vector2(5,11),Color("355564"),4)
			draw_style_box(pill(color),Rect2(at-Vector2(7,16),Vector2(14,22)))
			draw_circle(at-Vector2(0,19),7,Color("f6d2a3"))
	elif game_id == "cloudbound":
		for at in [Vector2(78,87),Vector2(353,200),Vector2(323,50)]:
			oval(at,Vector2(53,13),Color("e5eeeb"))
			oval(at-Vector2(13,8),Vector2(25,15),Color("e5eeeb"))
		for i in 3:
			draw_arc(Vector2(288+i*43,83-i*15),27-i*6,0,TAU,48,Color("fff1bd"),7-i*1.5,true)
		oval(Vector2(217,204),Vector2(66,13),Color("7facb9"))
		poly([Vector2(91,164),Vector2(214,111),Vector2(339,155),Vector2(211,149)],"f9edd1")
		poly([Vector2(91,164),Vector2(211,149),Vector2(207,161)],"d79472")
		poly([Vector2(183,196),Vector2(213,93),Vector2(230,115),Vector2(211,196)],"de795f")
		poly([Vector2(152,203),Vector2(192,180),Vector2(247,198),Vector2(205,209)],"f9edd1")
	elif game_id == "sunbreak":
		draw_rect(Rect2(0,0,440,270),Color("73bcc4"))
		draw_circle(Vector2(338,54),29,Color("fff0c4"))
		poly([Vector2(0,193),Vector2(104,157),Vector2(288,159),Vector2(440,208),Vector2(440,270),Vector2(0,270)],"719e55")
		poly([Vector2(0,240),Vector2(190,173),Vector2(221,175),Vector2(186,270),Vector2(0,270)],"d5c291")
		for at in [Vector2(68,159),Vector2(270,161)]:
			draw_rect(Rect2(at,Vector2(96,48)),Color("e49771"))
			poly([at+Vector2(-9,0),at+Vector2(48,-33),at+Vector2(103,0)],"345b6b")
			draw_rect(Rect2(at+Vector2(16,12),Vector2(19,22)),Color("fbe6bb"))
			draw_rect(Rect2(at+Vector2(61,12),Vector2(19,22)),Color("fbe6bb"))
		draw_rect(Rect2(204,78,13,112),Color("487f8c"))
		draw_circle(Vector2(210,79),12,Color("a2ffdc"))
		poly([Vector2(286,270),Vector2(279,232),Vector2(243,184),Vector2(269,180),Vector2(337,232),Vector2(350,270)],"29434d")
		poly([Vector2(285,242),Vector2(247,190),Vector2(263,185),Vector2(322,237)],"dbe2d2")
		draw_line(Vector2(292,228),Vector2(310,244),Color("84f4d4"),5)
	elif game_id == "gauntlet":
		draw_rect(Rect2(0,0,440,270),Color("252431"))
		for y in 6:
			for x in 10:
				if y in [0,5] or x in [0,9] or (x==5 and y<3):
					draw_rect(Rect2(x*44+2,y*45+2,40,40),Color("625765"))
					draw_rect(Rect2(x*44+3,y*45+3,38,8),Color("847080"))
		for i in 4:
			var at := Vector2(108+i*70,170-(i%2)*32)
			var colors := [Color("ed775f"),Color("81c6e2"),Color("ba9aef"),Color("a4d478")]
			draw_circle(at+Vector2(0,15),18,Color("15151e"))
			draw_rect(Rect2(at-Vector2(11,12),Vector2(22,32)),colors[i])
			draw_rect(Rect2(at-Vector2(9,26),Vector2(18,16)),Color("ecc19a"))
			draw_line(at+Vector2(15,7),at+Vector2(26,-20),Color("eacb85"),5)
		draw_circle(Vector2(329,65),18,Color("c79ae9"))
	elif game_id == "haymaker":
		draw_rect(Rect2(0,0,440,270),Color("e39b5a"))
		draw_circle(Vector2(340,48),70,Color("f3c57a"))
		oval(Vector2(220,210),Vector2(170,48),Color("c45c4a"))
		oval(Vector2(220,196),Vector2(156,40),Color("f4e2b8"))
		for i in 18:
			var a := i*TAU/18
			draw_line(Vector2(220,196)+Vector2(cos(a)*120,sin(a)*32),Vector2(220,196)+Vector2(cos(a+0.12)*120,sin(a+0.12)*32),Color("7dffc3"),3,true)
		for entry in [[Vector2(168,168),Color("ed7559")],[Vector2(268,176),Color("5ba7db")]]:
			var at: Vector2 = entry[0]
			draw_style_box(pill(Color("2b4751")),Rect2(at-Vector2(16,4),Vector2(32,16)))
			draw_style_box(pill(entry[1]),Rect2(at-Vector2(14,28),Vector2(28,34)))
			draw_circle(at-Vector2(0,36),11,Color("f6d2a3"))
			draw_line(at+Vector2(16,-8),at+Vector2(34,-22),entry[1].lightened(0.1),5)
	elif game_id == "world-1-1":
		var map := preload("res://examples/world_1_1/assets/World1-1.png")
		draw_texture_rect_region(map,Rect2(0,0,440,270),Rect2(192,48,256,192))
		draw_texture_rect(preload("res://examples/world_1_1/assets/MarioStanding.png"),Rect2(54,202,20,23),false)
	else:
		oval(Vector2(221,161),Vector2(193,101),Color("b0806b"))
		oval(Vector2(221,153),Vector2(191,100),Color("f4e7c6"))
		oval(Vector2(221,153),Vector2(177,88),Color("52717b"))
		oval(Vector2(221,153),Vector2(101,38),Color("acc196"))
		for i in 24:
			var a := i*TAU/24
			draw_line(Vector2(221,153)+Vector2(cos(a)*141,sin(a)*64),Vector2(221,153)+Vector2(cos(a+0.09)*141,sin(a+0.09)*64),Color("eadab9"),3,true)
		for entry in [[Vector2(149,194),Color("e78367")],[Vector2(219,218),Color("75b4cb")]]:
			var at: Vector2 = entry[0]
			draw_style_box(pill(Color("2b4751")),Rect2(at-Vector2(26,5),Vector2(52,20)))
			draw_style_box(pill(entry[1]),Rect2(at-Vector2(23,21),Vector2(46,30)))
			draw_style_box(pill(entry[1].lightened(0.2)),Rect2(at-Vector2(15,32),Vector2(30,21)))
			draw_rect(Rect2(at-Vector2(11,27),Vector2(22,10)),Color("d6e8e5"))
	finish()
	draw_set_transform(Vector2.ZERO)

## Finishing pass over every cover: top light, edge vignette, bottom scrim.
func finish() -> void:
	if _top_light == null:
		_top_light = _fade(PackedColorArray([Color(1,1,1,0.06),Color(1,1,1,0)]), Vector2(0.5,0.0), Vector2(0.5,0.33))
		_vignette = _fade(PackedColorArray([Color(0,0,0,0),Color(0,0,0,0.25)]), Vector2(0.5,0.5), Vector2(1.0,1.0), true)
		_scrim = _fade(PackedColorArray([Color(0,0,0,0),Color(0,0,0,0.35)]), Vector2(0.5,0.75), Vector2(0.5,1.0))
	draw_texture_rect(_top_light, Rect2(0,0,440,270), false)
	draw_texture_rect(_vignette, Rect2(0,0,440,270), false)
	draw_texture_rect(_scrim, Rect2(0,0,440,270), false)

func pill(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(5)
	return style
