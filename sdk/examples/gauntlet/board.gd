extends Node2D
## Dedicated party lobby and compact gameplay chrome; HUD never covers the dungeon.
const Level = preload("res://examples/gauntlet/level.gd")
const INK := Color("f0e8d9")
const MUTED := Color("9eafbc")
const GOLD := Color("ead39d")
var game: Node
var font: Font = ThemeDB.fallback_font
var start_button: Button
var retry_button: Button
var library_button: Button
var pause_button: Button
var help_button: Button
var lobby_buttons: Array[Button] = []
var menu_buttons: Array[Button] = []
var slot_buttons: Array = []
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
	start_button = button("Enter the vault",Rect2(1240,824,336,48),func(): game.request_start())
	retry_button = button("Back to hero lobby",Rect2(600,550,400,50),func():
		if game.phase=="complete" and game.level_index<Level.COUNT-1: game.finish_screen_action()
		else: game.reset_level())
	library_button = button("Game library",Rect2(24,824,224,48),func(): game.return_to_library())
	pause_button = button("Menu  ·  Esc / Home",Rect2(1380,22,196,44),func(): game.toggle_pause())
	pause_button.add_theme_font_size_override("font_size",17)
	help_button = button("Back",Rect2(620,738,360,48),func(): game.help = false)
	var controls_button := button("Controls",Rect2(270,824,200,48),func(): game.toggle_help())
	var fullscreen := button("Fullscreen",Rect2(492,824,230,48),func(): game.toggle_fullscreen())
	lobby_buttons = [library_button,controls_button,fullscreen,start_button]
	for i in 11:
		var item := button("",Rect2(510,243+i*40,580,36),func(): game.activate_menu(i))
		item.mouse_entered.connect(func(): game.menu_index = i)
		menu_buttons.append(item)
	for i in 16:
		var id := i+1
		var at := slot_origin(i)
		var controls := [button("‹",Rect2(at+Vector2(206,16),Vector2(32,38)),func(): game.cycle_class(id,-1)),
			button("›",Rect2(at+Vector2(245,16),Vector2(32,38)),func(): game.cycle_class(id)),
			button("Ready",Rect2(at+Vector2(286,16),Vector2(74,38)),func(): game.toggle_ready(id)),
			button("Color",Rect2(at+Vector2(58,36),Vector2(137,27)),func(): game.cycle_color(id))]
		for control in controls: control.add_theme_font_size_override("font_size",16)
		slot_buttons.append(controls)
	for i in 4: make_portrait(i)

func slot_origin(index: int) -> Vector2:
	return Vector2(24+(index%4)*390,412+(index/4)*84)

func make_portrait(kind: int) -> void:
	var container := SubViewportContainer.new()
	container.position = Vector2(36+kind*390,158)
	container.size = Vector2(136,174)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	portraits.append(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(272,348)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(viewport)
	var scene := Node3D.new()
	viewport.add_child(scene)
	var hero: Node3D = game.dungeon_view.hero_model(kind)
	hero.name = "HeroPreview"
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
	start_button.visible = lobby
	start_button.disabled = not game.all_ready()
	start_button.text = "A / Cross / Wii 2: Enter vault" if game.all_ready() else "Waiting for everyone to ready"
	start_button.add_theme_font_size_override("font_size",18)
	var transition: bool = game.phase=="complete" and game.level_index<Level.COUNT-1
	retry_button.text = "Continue  ·  A / Cross / Wii 2" if transition else "Back to hero lobby"
	retry_button.position.y = 716 if transition else 550
	retry_button.disabled = transition and game.return_countdown>4.0
	retry_button.visible = game.phase in ["complete","defeat"] and not game.help
	library_button.visible = (lobby or game.phase=="defeat" or (game.phase=="complete" and not transition)) and not game.help
	pause_button.visible = game.phase=="playing" and not game.help
	help_button.visible = game.help
	for i in 16:
		for control in slot_buttons[i]: control.visible = lobby and game.heroes.has(i+1)
		slot_buttons[i][2].text = "Edit" if game.ready_players.get(i+1,false) else "Ready"
		if game.heroes.has(i+1):
			var hero: Dictionary = game.heroes[i+1]
			var swatch: Button = slot_buttons[i][3]
			swatch.text = "‹                         ›" if game.color_focus.has(i+1) else ""
			swatch.add_theme_font_size_override("font_size",14)
			var style: StyleBoxFlat = swatch.get_theme_stylebox("normal").duplicate()
			style.bg_color = game.color_for(hero)
			style.set_border_width_all(2 if game.color_focus.has(i+1) else 0)
			style.border_color = Color.WHITE
			swatch.add_theme_stylebox_override("normal",style)
			for state in ["hover","pressed"]:
				var hover: StyleBoxFlat = style.duplicate()
				hover.set_border_width_all(2)
				hover.border_color = Color.WHITE
				swatch.add_theme_stylebox_override(state,hover)
	for index in lobby_buttons.size():
		var control := lobby_buttons[index]
		if index in [1,2]: control.visible = lobby
		var selected: bool = lobby and game.lobby_focus.values().has(index)
		for state in ["normal","disabled"]:
			var style: StyleBoxFlat = control.get_theme_stylebox(state).duplicate()
			style.set_border_width_all(3 if selected else 0)
			style.border_color = Color("a6dcee")
			control.add_theme_stylebox_override(state,style)
	var labels: Array = game.menu_labels()
	for i in menu_buttons.size():
		var control := menu_buttons[i]
		control.visible = game.phase=="paused" and not game.help and i<labels.size()
		if not control.visible: continue
		control.text = ("›   " if i==game.menu_index else "")+labels[i]
		var style: StyleBoxFlat = control.get_theme_stylebox("normal").duplicate()
		style.bg_color = Color("ead39d") if i==game.menu_index else Color("2b4352")
		control.add_theme_stylebox_override("normal",style)
		control.add_theme_color_override("font_color",Color("17232c") if i==game.menu_index else INK)
	for kind in portraits.size():
		var item := portraits[kind]
		if lobby:
			var selected: Dictionary = game.preview_hero(kind)
			var color_index: int = selected.get("color_index",kind)
			var scene: Node3D = item.get_child(0).get_child(0)
			var model: Node3D = scene.get_node("HeroPreview")
			if model.get_meta("color_index")!=color_index:
				scene.remove_child(model)
				model.queue_free()
				model = game.dungeon_view.hero_model(kind,color_index)
				model.name = "HeroPreview"
				model.rotation.y = 0.4
				scene.add_child(model)
		item.visible = lobby
		item.get_child(0).render_target_update_mode = SubViewport.UPDATE_ALWAYS if lobby else SubViewport.UPDATE_DISABLED

func _draw() -> void:
	if game.phase=="lobby": draw_lobby()
	else: draw_hud()
	if game.help: draw_help()
	elif game.phase=="paused": draw_menu()
	elif game.phase=="complete" and game.level_index<Level.COUNT-1: draw_transition()
	elif game.phase in ["complete","defeat"]: draw_results()

func draw_lobby() -> void:
	draw_rect(Rect2(0,0,1600,900),Color("111e28"))
	draw_rect(Rect2(0,0,1600,128),Color("192f3c"))
	text("GAUNTLET  /  THREE VAULTS",Vector2(26,33),16,GOLD)
	text("Build your party",Vector2(24,90),44)
	text("01  JOIN     /     02  CHOOSE A HERO     /     03  READY UP",Vector2(650,84),21,MUTED)
	text("%02d / 16 joined"%game.heroes.size(),Vector2(1370,35),20,GOLD)
	for i in 4:
		var at := Vector2(24+i*390,144)
		var stats: Dictionary = Level.CLASSES[i]
		var color := Color(stats.color)
		panel_box(Rect2(at,Vector2(372,210)),Color("1b303e"),color.darkened(0.5))
		text(stats.name.capitalize(),at+Vector2(158,42),27,color.lightened(0.2))
		text(["Heavy axe","Sword & shield","Arcane staff","Recurved bow"][i],at+Vector2(158,76),19)
		text(["Slow, heavy melee","Quick, armored melee","Magic bolts & area spells","Fast feet & arrows"][i],at+Vector2(158,106),16,MUTED)
		text("%d health"%stats.health,at+Vector2(158,154),17,GOLD)
		text("%d damage · %.2fs"%[stats.damage,stats.rate],at+Vector2(158,179),16,MUTED)
		var preview: Dictionary = game.preview_hero(i)
		if not preview.is_empty():
			text("P%02d"%preview.id,at+Vector2(14,198),13,game.color_for(preview))
			draw_rect(Rect2(at+Vector2(48,188),Vector2(18,10)),game.color_for(preview))
	text("YOUR PARTY",Vector2(26,393),19,GOLD)
	text("Each controller chooses independently. Duplicate heroes are welcome.",Vector2(218,393),18,MUTED)
	var ready_count: int = game.heroes.keys().filter(func(id): return game.ready_players.get(id,false)).size()
	text("%d / %d ready"%[ready_count,game.heroes.size()],Vector2(1415,393),18,GOLD)
	for i in 16:
		var id := i+1
		var at := slot_origin(i)
		var occupied: bool = game.heroes.has(id)
		var ready: bool = game.ready_players.get(id,false)
		var color: Color = game.color_for(game.heroes[id]) if occupied else Color("466070")
		panel_box(Rect2(at,Vector2(372,72)),Color("21473f") if ready else Color("1a2d39"),Color("6bb998") if ready else Color("3b5361"),8)
		text("%02d"%id,at+Vector2(13,30),23,color.lightened(0.25))
		if occupied:
			text(Level.CLASSES[game.heroes[id].hero_class].name.capitalize(),at+Vector2(58,28),21,color.lightened(0.2))
			text("↓" if game.lobby_focus.has(id) else ("✓" if ready else ""),at+Vector2(18,55),18,Color("a8e7c2") if ready else MUTED)
		else:
			text("Press A / Cross / Wii 2 to join",at+Vector2(58,31),17,MUTED)
			text("Keyboard: Enter",at+Vector2(58,53),14,Color("6d8797"))
	centered("Left / right: hero · Up, then left / right: color · A / Cross / Wii 2: confirm / ready · Down: lobby buttons · B / Circle / Minus: back",775,18)
	centered("Everyone ready? Press A / Cross / Wii 2 again to enter. Menu / Options / Wii + or Home also starts.",801,18,GOLD)
	centered("Lobby buttons: left / right to choose, confirm to select · Keyboard: Enter confirms, Tab changes hero, C changes color, P starts",894,15,MUTED)

func draw_hud() -> void:
	var bottom: float = 88+game.display.size.y
	draw_rect(Rect2(0,0,1600,88),Color("111e28"))
	draw_rect(Rect2(0,bottom,1600,900-bottom),Color("111e28"))
	text("GAUNTLET",Vector2(24,41),30,GOLD)
	text("%d / 3 · %s"%[game.level_index+1,game.map.name.to_upper()],Vector2(25,66),12,MUTED)
	text("%06d treasure"%game.score,Vector2(275,37),20)
	var key_x := 475.0
	for color: String in Level.Campaign.KEY_COLORS:
		var count: int = game.keyring.get(color,0)
		if count<=0: continue
		draw_circle(Vector2(key_x,29),9,Level.Campaign.KEY_COLORS[color])
		text("%s %d"%[Level.Campaign.KEY_MARKS[color],count],Vector2(key_x+13,35),14)
		key_x += 61
	text("%d / %d escaped    ·    %d / %d generators    ·    %02d:%02d"%[game.escaped_count(),game.heroes.size(),game.destroyed(),game.generators.size(),int(game.elapsed)/60,int(game.elapsed)%60],Vector2(275,65),16,MUTED)
	if game.message_time>0: text(game.message.left(56),Vector2(740,49),13,GOLD)
	if game.show_minimap: draw_minimap()
	var ids: Array = game.heroes.keys()
	ids.sort()
	for i in ids.size():
		var hero: Dictionary = game.heroes[ids[i]]
		var stats: Dictionary = Level.CLASSES[hero.hero_class]
		var color: Color = game.color_for(hero)
		var at := Vector2(16+(i%8)*198,bottom+4+(i/8)*36)
		text("%02d"%hero.id,at+Vector2(0,21),18,color.lightened(0.3))
		var status: String = "ESCAPED" if hero.escaped else ("DOWN · revive" if hero.hp<=0 else "%d HP · %d magic"%[ceili(hero.hp),hero.potions])
		text(status,at+Vector2(33,19),14,Color("a8e7c2") if hero.escaped else INK)
		draw_rect(Rect2(at+Vector2(33,25),Vector2(142,3)),Color("2b404c"))
		draw_rect(Rect2(at+Vector2(33,25),Vector2(142*hero.hp/stats.health,3)),color)
	centered("MOVE  Stick / D-pad    ·    ATTACK  A / Cross / Wii 2    ·    MAGIC  X / Square / Wii 1    ·    MENU  Esc / Menu / Options / Home    ·    F3  Full map",894,14,MUTED)

func draw_menu() -> void:
	draw_rect(Rect2(0,0,1600,900),Color(0.02,0.05,0.08,0.72))
	panel_box(Rect2(470,140,660,620),Color("152935"),Color("728477"),18)
	centered("Adventure paused" if game.confirm_leave.is_empty() else "End this run?",201,36,GOLD)
	centered("Your party is safe while you choose." if game.confirm_leave.is_empty() else "Current level progress will be reset.",231,19,MUTED)
	centered("Up / down to choose · A / Cross / Wii 2 / Enter to select",698,18)
	centered("Esc / B / Circle / Wii Minus / Home to go back",727,17,MUTED)

func draw_help() -> void:
	draw_rect(Rect2(0,0,1600,900),Color(0.02,0.05,0.08,0.85))
	panel_box(Rect2(140,120,1320,680),Color("152935"),Color("728477"),18)
	centered("A guide to the vault",193,36,GOLD)
	var lines := ["LOBBY: left / right chooses a hero. Up selects color; left / right changes it. Confirm color, then ready up.",
		"Everyone ready? Press A / Cross / Wii 2 again to enter. Down selects lobby buttons; left / right chooses.",
		"MOVE: stick / D-pad / WASD. ATTACK: A / Cross / Wii 2 / Space. MAGIC: X / Square / Wii 1.",
		"Match key colors/letters to locks; keys can be in distant branches. Keys and food are shared.",
		"All heroes through the portal advances the party. Conquer three increasingly difficult vaults.",
		"Stand near a fallen teammate to revive them before the last hero escapes.",
		"MENU: Esc / Menu / Options / Wii + / Home / P. Change options or return to the lobby or library.",
		"F1: help · F2: lighting · F3: full-dungeon view · F11: fullscreen · F1 / Esc / confirm: close guide."]
	for i in lines.size(): centered(lines[i],263+i*55,19,MUTED)

func draw_transition() -> void:
	var progress: float = clampf((6.0-game.return_countdown)/6.0,0,1)
	var age := progress*6.0
	draw_rect(Rect2(0,0,1600,900),Color("0d1b28"))
	# Expanding portal rings and motes carry the party into the next chapter.
	var portal_center := Vector2(800,340)
	for i in 5:
		var cycle := fmod(age*0.28+i*0.2,1.0)
		draw_arc(portal_center,65+cycle*245,0,TAU,100,Color(0.36,0.79,0.72,(1-cycle)*0.28),2,true)
	for i in 48:
		var angle := i*2.399+age*0.16
		var radius := 75+fmod(i*21.7+age*44.0,240.0)
		draw_circle(portal_center+Vector2(cos(angle),sin(angle))*radius,1.0+(i%3)*0.6,Color(0.62,0.91,0.81,0.38))
	centered("LEVEL %d COMPLETE"%(game.level_index+1),115,20,Color("8fdbc3"))
	centered(game.map.name,170,46,GOLD)
	centered("Everybody made it out",223,23)
	var ids: Array = game.heroes.keys()
	ids.sort()
	for i in ids.size():
		var x := 800+(i-(ids.size()-1)*0.5)*46
		var y := 334+sin(age*3.5+i*0.6)*7
		var color: Color = game.color_for(game.heroes[ids[i]])
		draw_circle(Vector2(x,y),16,color)
		text("%02d"%ids[i],Vector2(x-10,y+6),14,Color("10212a"))
	centered("%d heroes safe   ·   %06d treasure   ·   %d foes defeated"%[ids.size(),game.score,game.kills],418,21,MUTED)
	for chapter in 3:
		var at := Vector2(580+chapter*220,508)
		if chapter<2: draw_line(at,at+Vector2(220,0),Color("334d5a"),3)
		draw_circle(at,14,Color("90dcc2") if chapter<=game.level_index else Color("344d60"))
		if chapter==game.level_index+1: draw_arc(at,21+sin(age*3)*2,0,TAU,48,GOLD,2,true)
		text(str(chapter+1),at+Vector2(-5,6),16,Color("13232b") if chapter<=game.level_index else INK)
	centered("NEXT · "+Level.Campaign.NAMES[game.level_index+1].to_upper(),587,29,GOLD)
	centered("Health restored · At least two potions each · Heroes, colors and treasure carried forward",628,18,MUTED)
	draw_rect(Rect2(500,673,600,3),Color("304954"))
	draw_rect(Rect2(500,673,600*progress,3),Color("90dcc2"))
	centered("Entering in %d…"%maxi(1,ceili(game.return_countdown)),811,18,MUTED)

func draw_results() -> void:
	draw_rect(Rect2(0,88,1600,700),Color(0.02,0.05,0.08,0.72))
	panel_box(Rect2(285,158,1030,530),Color("152935"),Color("728477"),18)
	var won: bool = game.phase=="complete"
	centered("Everybody made it out!" if won else "The vault claimed the party",263,40,GOLD)
	centered("ALL THREE VAULTS CONQUERED" if won else "Regroup, revive one another, and try again.",311,20,MUTED)
	centered("%d / %d escaped    ·    %06d treasure"%[game.escaped_count(),game.heroes.size(),game.score],384,29)
	centered("%d monsters defeated    ·    %d generators destroyed"%[game.kills,game.destroyed()],432,21,MUTED)
	centered("Returning to your library in %d…"%maxi(1,ceili(game.return_countdown)) if won else "A / Cross / Wii 2: retry · B / Circle / Wii Minus: game library",492,22,GOLD)

func draw_minimap() -> void:
	# Dedicated header space, outside the game viewport: no dungeon or portal can be obscured.
	var origin := Vector2(1200,10)
	var scale: float = minf(150.0/game.map.width,68.0/game.map.height)
	for cell: Vector2i in game.walls:
		if game.map.has("visible_cells") and not game.map.visible_cells.has(cell): continue
		var sight: float = game.dungeon_view.visibility.visibility_at(Vector2(cell)+Vector2.ONE*.5)
		draw_rect(Rect2(origin+Vector2(cell)*scale,Vector2.ONE*scale),Color(0.5,0.64,0.69,0.48*sight))
	for cell: Vector2i in game.doors:
		if game.dungeon_view.visibility.visibility_at(Vector2(cell)+Vector2.ONE*.5)<.5: continue
		draw_rect(Rect2(origin+Vector2(cell)*scale,Vector2.ONE*scale),Level.Campaign.KEY_COLORS[game.map.door_colors.get(game.doors[cell],"gold")])
	for pickup: Dictionary in game.pickups:
		if game.dungeon_view.visibility.visibility_at(pickup.pos/32.0)<.5: continue
		if pickup.kind=="key": draw_circle(origin+pickup.pos/32*scale,2,Level.Campaign.KEY_COLORS[pickup.get("key_color","gold")])
	if game.dungeon_view.visibility.visibility_at(game.map.exit/32.0)>=.5:
		draw_circle(origin+game.map.exit/32*scale,3.5,Color("8ff2cb"))
	for hero: Dictionary in game.heroes.values():
		if not hero.escaped: draw_circle(origin+hero.pos/32*scale,2.5,game.color_for(hero))
