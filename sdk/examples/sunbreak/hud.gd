extends Control
var game: Node3D
var panel: VBoxContainer
var font: Font = ThemeDB.fallback_font
const INK := Color("102a37")
const CREAM := Color("fff2d3")
const AQUA := Color("87f5d9")
var menu_open := true

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel = VBoxContainer.new()
	panel.add_theme_constant_override("separation",14)
	add_child(panel)
	resized.connect(layout)
	layout()

func layout() -> void:
	if panel == null: return
	panel.position = Vector2(size.x*0.07,size.y*0.47)
	panel.size = Vector2(minf(460,size.x*0.38),0)
	queue_redraw()

func button(text: String, action: Callable, primary := false) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = 58
	node.add_theme_font_size_override("font_size",22)
	for color_state in ["font_color","font_hover_color","font_focus_color","font_pressed_color"]:
		node.add_theme_color_override(color_state,INK if primary else CREAM)
	for state in ["normal","hover","focus","pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = AQUA if primary else Color("173b49")
		if state in ["hover","focus"]:
			style.bg_color = style.bg_color.lightened(0.14)
			style.set_border_width_all(2)
			style.border_color = CREAM
		style.set_corner_radius_all(5)
		node.add_theme_stylebox_override(state,style)
	node.pressed.connect(action)
	panel.add_child(node)
	return node

func show_menu() -> void:
	menu_open = true
	for child in panel.get_children():
		panel.remove_child(child)
		child.queue_free()
	var title := "DEPLOY TO ISLAND  →"
	var action: Callable = game.start_match
	if game.phase=="paused":
		title = "RESUME SKIRMISH  →"
		action = game.resume_match
	elif game.phase=="result": title = "PLAY AGAIN  →"
	var first := button(title,action,true)
	button("RETURN TO LIBRARY",func(): get_tree().quit())
	panel.visible = true
	first.grab_focus()
	layout()

func hide_menu() -> void:
	menu_open = false
	panel.visible = false
	queue_redraw()

func label(text: String, at: Vector2, pixels: int, color := CREAM) -> void:
	draw_string(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,color)

func rect(at: Vector2, dimensions: Vector2, color: Color) -> void:
	draw_style_box(style(color),Rect2(at,dimensions))

func style(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(6)
	return box

func _draw() -> void:
	if game==null: return
	draw_set_transform(Vector2.ZERO,0,size/Vector2(1600,900))
	if menu_open:
		# Broad translucent editorial panel preserves a view of the real island.
		draw_rect(Rect2(0,0,1600,900),Color(0.025,0.08,0.12,0.20))
		for i in 80:
			draw_rect(Rect2(i*12,0,12,900),Color(0.025,0.09,0.13,0.88*(1-float(i)/80)))
		label("COUCH GAMES   /   ORIGINALS",Vector2(112,96),18,AQUA)
		label("SUNBREAK",Vector2(106,245),86)
		label("SINGLE PLAYER  /  ISLAND SKIRMISH",Vector2(113,291),20,AQUA)
		var line := "Clear the outpost. Stay ahead of the storm."
		var sub := "Three waves. One island. Make it yours."
		if game.phase=="paused":
			line = "Taking a breather."
			sub = "Your match is paused."
		elif game.phase=="result":
			line = "ISLAND SECURED." if game.victory else "SIGNAL LOST."
			sub = "%d robots eliminated  ·  %02d:%02d elapsed" % [game.kills,int(game.time)/60,int(game.time)%60]
		label(line,Vector2(113,350),25)
		label(sub,Vector2(113,387),20,Color("d0e0d4"))
		label("MOVE  WASD     LOOK / AIM  RIGHT-DRAG     FIRE  LEFT CLICK",Vector2(112,693),17)
		label("MOUSE STAYS FREE     RELOAD  R     JUMP  SPACE",Vector2(112,726),17)
		label("SPRINT  SHIFT     BUILD COVER  Q     PAUSE  ESC",Vector2(112,759),17)
		label("GAMEPAD   Press a button to connect · Sticks look/move · R3 level view",Vector2(112,807),16,AQUA)
		label("01 / SUNLIT OUTPOST",Vector2(1260,838),18)
	else:
		rect(Vector2(40,34),Vector2(276,81),Color(0.04,0.13,0.18,0.86))
		label("SUNBREAK",Vector2(60,66),23)
		label("SUNLIT OUTPOST / SOLO",Vector2(61,95),14,AQUA)
		rect(Vector2(562,34),Vector2(476,54),Color(0.04,0.13,0.18,0.83))
		label("WAVE %d / 3" % game.wave,Vector2(583,68),20)
		label("%02d HOSTILES" % game.bots.size(),Vector2(767,68),20,AQUA)
		label("%02d:%02d" % [int(game.time)/60,int(game.time)%60],Vector2(954,68),18)
		# Radar marks real bot and player positions, and the current storm radius.
		var center := Vector2(1461,127)
		draw_circle(center,90,Color(0.035,0.14,0.19,0.9))
		draw_arc(center,game.storm_radius*1.35,0,TAU,80,Color("b7a0fa"),2,true)
		for bot in game.bots:
			draw_circle(center+Vector2(bot.position.x,bot.position.z)*1.35,3.5,Color("ffae83"))
		var player_at: Vector2 = center+Vector2(game.player.position.x,game.player.position.z)*1.35
		draw_circle(player_at,4,AQUA)
		var heading: Vector3 = -game.player.basis.z
		draw_line(player_at,player_at+Vector2(heading.x,heading.z)*12,AQUA,2,true)
		label("SAFE ZONE %dm" % int(game.storm_radius),Vector2(1385,242),16)
		var mid := Vector2(800,450)
		if game.hit_left>0:
			for angle in [0.25,0.75,1.25,1.75]:
				var direction := Vector2(cos(angle*PI),sin(angle*PI))
				draw_line(mid+direction*7,mid+direction*15,CREAM,3,true)
		else:
			draw_circle(mid,2,CREAM)
			for direction in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
				draw_line(mid+direction*8,mid+direction*14,Color(1,1,1,0.8),2,true)
		rect(Vector2(40,741),Vector2(360,118),Color(0.035,0.12,0.18,0.87))
		label("+   %03d" % int(game.player.health),Vector2(61,772),20)
		label("SHIELD  %03d" % int(game.player.shield),Vector2(239,772),16,AQUA)
		rect(Vector2(61,789),Vector2(318,13),Color("27404a"))
		rect(Vector2(61,789),Vector2(318*game.player.shield/100,13),Color("68d9e8"))
		rect(Vector2(61,810),Vector2(318,13),Color("27404a"))
		rect(Vector2(61,810),Vector2(318*game.player.health/100,13),Color("b9e684"))
		label("Q / Y   COVER × %d" % game.cover_charges,Vector2(62,847),14)
		rect(Vector2(1270,747),Vector2(290,112),Color(0.035,0.12,0.18,0.87))
		label("PULSE CARBINE",Vector2(1290,776),17,AQUA)
		label("%02d" % game.player.ammo,Vector2(1288,830),45)
		label("/  ∞",Vector2(1360,828),24)
		label("RELOADING" if game.player.reload_left>0 else "R / X  RELOAD",Vector2(1430,825),14)
		rect(Vector2(510,840),Vector2(580,34),Color(0.035,0.12,0.18,0.75))
		label("RMB drag / Stick  Look    R3  Level view    ESC / MENU  Pause",Vector2(526,864),14)
		if game.banner_left>0:
			rect(Vector2(490,141),Vector2(620,56),Color(0.04,0.13,0.18,0.9))
			draw_string(font,Vector2(490,177),game.banner,HORIZONTAL_ALIGNMENT_CENTER,620,22,CREAM)
		if Vector2(game.player.position.x,game.player.position.z).length()>game.storm_radius:
			label("IN THE STORM — MOVE TO THE CIRCLE",Vector2(548,692),24,Color("e7b1ff"))
		if game.damage_left>0:
			var alpha: float = game.damage_left*0.7
			for edge in [Rect2(0,0,1600,12),Rect2(0,888,1600,12),Rect2(0,0,12,900),Rect2(1588,0,12,900)]:
				draw_rect(edge,Color(1,0.2,0.15,alpha))
	draw_set_transform(Vector2.ZERO)
