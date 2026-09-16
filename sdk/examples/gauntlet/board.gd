extends Node2D
## Crisp TV-sized interface over the lit dungeon. Mouse buttons complement controller input.
const Level = preload("res://examples/gauntlet/level.gd")
const INK := Color("f0e8d9")
const MUTED := Color("9eafbc")
const GOLD := Color("ead39d")
var game: Node
var font: Font = ThemeDB.fallback_font
var start_button: Button
var retry_button: Button
var library_button: Button
var portraits: Array[SubViewportContainer] = []

func text(value: String, at: Vector2, size := 18, color := INK) -> void:
	draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
func centered(value: String, y: float, size := 18, color := INK) -> void:
	text(value,Vector2(800-font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x/2,y),size,color)
func panel_box(rect: Rect2, fill: Color, border := Color("394954"), radius := 12) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	draw_style_box(style,rect)

func button(label: String, rect: Rect2, action: Callable) -> Button:
	var result := Button.new()
	result.text = label
	result.position = rect.position
	result.size = rect.size
	result.focus_mode = Control.FOCUS_NONE
	result.add_theme_font_size_override("font_size",21)
	for state in ["normal","hover","pressed","disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("d9bd7d") if state=="normal" else Color("f1d9a1")
		if state=="disabled": style.bg_color = Color("3d4c55")
		style.set_corner_radius_all(8)
		result.add_theme_stylebox_override(state,style)
	result.add_theme_color_override("font_color",Color("17232c"))
	result.add_theme_color_override("font_hover_color",Color("17232c"))
	result.add_theme_color_override("font_pressed_color",Color("17232c"))
	result.pressed.connect(action)
	add_child(result)
	return result

func _ready() -> void:
	start_button = button("Enter the vault",Rect2(590,609,420,52),func():
		if game.phase=="lobby": game.start()
		elif game.phase=="paused": game.toggle_pause())
	retry_button = button("Play again",Rect2(600,550,400,50),func(): game.reset_level())
	library_button = button("Return to library",Rect2(1370,30,190,43),func(): game.return_to_library())
	library_button.add_theme_font_size_override("font_size",17)
	for i in 4: make_portrait(i)

func make_portrait(kind: int) -> void:
	var container := SubViewportContainer.new()
	container.position = Vector2(334+kind*240,282)
	container.size = Vector2(212,166)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	portraits.append(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(424,332)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(viewport)
	var scene := Node3D.new()
	viewport.add_child(scene)
	var hero: Node3D = game.dungeon_view.hero_model(kind)
	hero.rotation.y = 0.4
	scene.add_child(hero)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45,-30,0)
	light.light_color = Color("ffe3bc")
	light.light_energy = 1.7
	scene.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20,140,0)
	fill.light_energy = 0.75
	fill.light_color = Color("a5d4ee")
	scene.add_child(fill)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.55
	camera.position = Vector3(0,1.65,4)
	scene.add_child(camera)
	camera.look_at(Vector3(0,1.05,0))
	camera.current = true

func _process(_delta: float) -> void:
	var lobby: bool = game.phase=="lobby" and not game.help
	start_button.visible = (lobby or game.phase=="paused") and not game.help
	start_button.disabled = game.heroes.is_empty()
	start_button.text = "Join a controller to begin" if game.heroes.is_empty() else ("Resume adventure" if game.phase=="paused" else "Enter the vault  →")
	retry_button.visible = game.phase in ["complete","defeat"] and not game.help
	for portrait in portraits:
		portrait.visible = lobby
		portrait.get_child(0).render_target_update_mode = SubViewport.UPDATE_ALWAYS if lobby else SubViewport.UPDATE_DISABLED

func _draw() -> void:
	# Leave the 3D viewport unobstructed; draw only the interface around it.
	for rect in [Rect2(0,0,1600,104),Rect2(0,736,1600,164),Rect2(0,104,40,632),Rect2(1560,104,40,632)]:
		draw_rect(rect,Color("111e28"))
	draw_line(Vector2(40,93),Vector2(1560,93),Color("46505a"),1)
	text("C O U C H   G A M E S",Vector2(40,27),11,MUTED)
	text("GAUNTLET",Vector2(39,75),40,GOLD)
	text("THE EMBER VAULT",Vector2(333,43),24)
	text("LEVEL 01   /   %d HEROES   /   %d ESCAPED" % [game.heroes.size(),game.escaped_count()],Vector2(335,72),14,MUTED)
	text("TREASURE",Vector2(926,34),11,MUTED)
	text("%06d"%game.score,Vector2(925,63),25,GOLD)
	text("KEYS %02d    GENERATORS %d/4" % [game.keys,game.destroyed()],Vector2(1090,42),14)
	text("%02d:%02d  ·  FIND YOUR WAY OUT" % [int(game.elapsed)/60,int(game.elapsed)%60],Vector2(1090,67),12,MUTED)
	for i in 16:
		var id := i+1
		var at := Vector2(40+(i%8)*190,753+(i/8)*56)
		var occupied: bool = game.heroes.has(id)
		panel_box(Rect2(at,Vector2(180,48)),Color("1e303d") if occupied else Color("162631"))
		if occupied:
			var hero: Dictionary = game.heroes[id]
			var stats: Dictionary = Level.CLASSES[hero.hero_class]
			var color := Color(stats.color)
			panel_box(Rect2(at+Vector2(7,7),Vector2(31,30)),color.darkened(0.58),color.darkened(0.15),6)
			text("%02d"%id,at+Vector2(11,29),17,color.lightened(0.3))
			text(stats.name.capitalize(),at+Vector2(46,19),15,color)
			text("ESCAPED ✓" if hero.escaped else ("DOWN · Revive" if hero.hp<=0 else "%d HP   ·   %d magic" % [ceili(hero.hp),hero.potions]),at+Vector2(46,35),12,Color("9becbe") if hero.escaped else INK)
			draw_rect(Rect2(at+Vector2(8,43),Vector2(163,2)),Color("0c1922"))
			draw_rect(Rect2(at+Vector2(8,43),Vector2(163*hero.hp/stats.health,2)),color)
		else:
			text("%02d" % id,at+Vector2(10,29),16,Color("6a808e"))
			text("A / Cross / Wii 2 to join",at+Vector2(42,29),11,Color("728996"))
	centered("MOVE  Stick / D-pad     FIRE  A / Cross / Wii 2     MAGIC  X / Square / Wii 1     F1  Help     F2  Lighting     F3  Map     F11  Fullscreen",884,15,MUTED)
	if game.phase=="playing":
		draw_minimap()
		if game.message_time>0:
			panel_box(Rect2(340,688,920,38),Color(0.04,0.10,0.14,0.94),Color("546b70"),8)
			centered(game.message,713,16,GOLD)
		if game.escaped_count()>0:
			panel_box(Rect2(1190,265,352,42),Color("1a403b"),Color("69bda4"),8)
			text("%d / %d safely through the portal" % [game.escaped_count(),game.heroes.size()],Vector2(1208,292),17,Color("b6f2d8"))
	if game.phase in ["lobby","paused","complete","defeat"] or game.help:
		draw_rect(Rect2(40,104,1520,632),Color(0.02,0.05,0.08,0.64))
		draw_panel()

func draw_panel() -> void:
	panel_box(Rect2(285,158,1030,530),Color("152935"),Color("728477"),18)
	if game.help:
		centered("A guide to the vault",219,32,GOLD)
		var lines := ["Move and aim with the left stick or D-pad. Hold A / Cross / Wii 2 to fire.","Cast magic with X / Square / Wii 1. Keyboard: Space fires; X casts.","Shared keys open doors. Food heals your party. Generators award bonus treasure.","Enter the glowing portal to escape. Escaped heroes are safe and leave the dungeon.","Every connected hero must escape. Stand near fallen teammates to revive them.","Pause: Menu / Options / Wii Home / P. Press fire to resume.","F1 closes this guide. F3 toggles the full map. F11 toggles fullscreen. Escape returns to the library."]
		for i in lines.size(): centered(lines[i],275+i*47,18,MUTED)
	elif game.phase=="lobby":
		centered("The Ember Vault",214,40,GOLD)
		centered("Choose your hero. Find the keys. Get everyone out.",250,21,MUTED)
		for i in 4:
			var at := Vector2(324+i*240,275)
			var color := Color(Level.CLASSES[i].color)
			panel_box(Rect2(at,Vector2(222,234)),Color("203541"),color.darkened(0.55),10)
			text(Level.CLASSES[i].name.capitalize(),at+Vector2(18,202),24,color)
			text(["Powerful axe · More health","Armored · Sword and shield","Arcane staff · Strong magic","Swift feet · Rapid arrows"][i],at+Vector2(18,223),13,MUTED)
		centered("A / Cross / Wii 2: join     ·     X / Square / Wii 1: choose class",546,19)
		centered("Release, then press A / Cross / Wii 2 again to begin.",576,21,GOLD)
		centered("Keyboard: Enter to join/start · Tab to change class",596,14,MUTED)
	elif game.phase=="paused":
		centered("Take a breather",297,44,GOLD)
		centered("Your party is safe while the dungeon is paused.",354,23,MUTED)
		centered("Press A / Cross / Wii 2 to continue",425,28)
		centered("Menu / Options / Wii Home / P also resumes",472,19,MUTED)
	else:
		var won: bool = game.phase=="complete"
		centered("Everybody made it out!" if won else "The vault claimed the party",263,40,GOLD)
		centered("THE EMBER VAULT  /  LEVEL COMPLETE" if won else "Regroup, revive one another, and try again.",311,20,MUTED)
		centered("%d / %d escaped    ·    %06d treasure" % [game.escaped_count(),game.heroes.size(),game.score],384,29)
		centered("%d monsters defeated    ·    %d generators destroyed" % [game.kills,game.destroyed()],432,21,MUTED)
		if won:
			centered("Returning to your library in %d…" % maxi(1,ceili(game.return_countdown)),492,23,Color("b1e0c7"))
		else: centered("Menu / Wii Home / R to play again",492,22,GOLD)

func draw_minimap() -> void:
	var origin := Vector2(1310,122)
	var scale := 5.6
	panel_box(Rect2(origin-Vector2(10,10),Vector2(244,144)),Color(0.035,0.075,0.1,0.93),Color("617c80"),8)
	for cell: Vector2i in game.walls:
		draw_rect(Rect2(origin+Vector2(cell)*scale,Vector2.ONE*scale),Color("556770"))
	for cell: Vector2i in game.doors:
		draw_rect(Rect2(origin+Vector2(cell)*scale,Vector2.ONE*scale),GOLD)
	for pickup: Dictionary in game.pickups:
		if pickup.kind=="key": draw_circle(origin+pickup.pos/32*scale,2.5,GOLD)
	draw_circle(origin+Level.EXIT/32*scale,4,Color("8ff2cb"))
	for hero: Dictionary in game.heroes.values():
		if not hero.escaped:
			draw_circle(origin+hero.pos/32*scale,3.0,Color(Level.CLASSES[hero.hero_class].color))
	text("THE VAULT",origin+Vector2(0,128),11,MUTED)
