extends Node2D
const Level = preload("res://examples/gauntlet/level.gd")
const DungeonView = preload("res://examples/gauntlet/dungeon_view.gd")
const AxeSwing = preload("res://examples/gauntlet/axe_swing.gd")
const Board = preload("res://examples/gauntlet/board.gd")
const Fleet = preload("res://examples/pocket_rally/wii_fleet.gd")
const Sounds = preload("res://examples/gauntlet/sound.gd")
const DIRECTIONS := [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]
var service: Node
var display: SubViewportContainer
var ready_players: Dictionary = {}
var navigation: Dictionary = {}
var lobby_focus: Dictionary = {}
var color_focus: Dictionary = {}
var preview_players: Dictionary = {}
var menu_index := 0
var confirm_leave := ""
var show_minimap := true
var board: Node2D
var dungeon_view: Node3D
var close_on_finish := true
var return_countdown := 6.0
var _confirm_armed: Dictionary = {}
var controller_voice: Node
var sound: Node
var heroes: Dictionary = {}
var walls: Dictionary = {}
var doors: Dictionary = {}
var generators: Array = []
var pickups: Array = []
var enemies: Array = []
var shots: Array = []
var melee_swings: Array = []
var combat_armed: Dictionary = {}
var sparks: Array = []
var flow: Dictionary = {}
var phase := "lobby"
var level_index := 0
var map: Dictionary = Level.definition(0)
var keyring: Dictionary = {}
var level_started_at := 0.0
var keys := 0
var score := 0
var elapsed := 0.0
var kills := 0
var message := "FOUR HEROES. ONE DUNGEON. BRING THE WHOLE COUCH."
var message_time := 8.0
var exit_time := 0.0
var clock := 0.0
var _flow_clock := 0.0
var _serial := 0
var _action_previous: Dictionary = {}
var _end_guard := 0.0
var help := false

func _ready() -> void:
	DisplayServer.window_set_title("Gauntlet · The Ember Vault · Couch Games")
	service = get_node("/root/Platform").input
	service.keyboard_enabled = true
	service.player_joined.connect(join)
	service.player_left.connect(leave)
	display = SubViewportContainer.new()
	display.position = Vector2(0,88)
	display.size = Vector2(1600,752)
	display.stretch = true
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(display)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1600,752)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	display.add_child(viewport)
	dungeon_view = DungeonView.new()
	dungeon_view.game = self
	viewport.add_child(dungeon_view)
	board = Board.new()
	board.game = self
	add_child(board)
	sound = Sounds.new()
	add_child(sound)
	controller_voice = preload("res://examples/gauntlet/controller_voice.gd").new()
	controller_voice.directory = OS.get_environment("COUCH_WII_FLEET_DIR")
	controller_voice.service = service
	add_child(controller_voice)
	controller_voice.fallback_requested.connect(sound.selection)
	reset_level()
	for id: int in service.players: join(id)
	var directory := OS.get_environment("COUCH_WII_FLEET_DIR")
	if not directory.is_empty():
		var fleet := Fleet.new()
		fleet.service = service
		fleet.motion = get_node("/root/Platform").motion
		fleet.directory = directory
		add_child(fleet)

func reset_level() -> void:
	if controller_voice: controller_voice.stop_all()
	level_index = 0
	load_map()
	enemies.clear()
	shots.clear()
	melee_swings.clear()
	combat_armed.clear()
	sparks.clear()
	flow.clear()
	keys = 0
	keyring.clear()
	level_started_at = 0
	score = 0
	kills = 0
	elapsed = 0
	exit_time = 0
	_flow_clock = 0
	phase = "lobby"
	help = false
	confirm_leave = ""
	ready_players.clear()
	navigation.clear()
	lobby_focus.clear()
	color_focus.clear()
	return_countdown = 6.0
	_confirm_armed.clear()
	for id: int in heroes:
		var chosen: int = heroes[id].hero_class
		heroes[id] = make_hero(id,chosen,heroes[id].color_index)
	message = "JOIN, CHOOSE YOUR HERO, AND READY UP. MENU / HOME STARTS WHEN EVERYONE IS READY."
	message_time = 8
	_end_guard = 0.7
	if dungeon_view: dungeon_view.rebuild()

func load_map() -> void:
	map = Level.definition(level_index)
	walls = map.walls
	doors = map.doors
	map.door_sites = doors.duplicate()
	generators = map.generators
	pickups = map.pickups

func enemy_health(kind: String) -> float:
	return (52.0 if kind=="grunt" else 34.0)*float(map.enemy_scale)

func advance_level() -> void:
	if phase!="complete" or level_index>=Level.COUNT-1: return
	level_index += 1
	load_map()
	enemies.clear()
	shots.clear()
	melee_swings.clear()
	sparks.clear()
	flow.clear()
	keyring.clear()
	keys = 0
	_flow_clock = 0
	level_started_at = elapsed
	combat_armed.clear()
	_confirm_armed.clear()
	for id: int in heroes:
		var old: Dictionary = heroes[id]
		var next := make_hero(id,old.hero_class,old.color_index)
		var maximum: float = Level.CLASSES[old.hero_class].health
		next.hp = clampf(old.hp+maximum*0.35,maximum*0.65,maximum)
		next.potions = maxi(2,old.potions)
		heroes[id] = next
	for entry: Dictionary in map.enemies:
		_serial += 1
		enemies.append({"id":_serial,"pos":entry.pos,"kind":entry.kind,"hp":enemy_health(entry.kind),"max_hp":enemy_health(entry.kind),"attack":1.5})
	phase = "playing"
	controller_voice.stop_all()
	return_countdown = 6.0
	dungeon_view.rebuild()
	dungeon_view.update_camera(1.0)
	announce("LEVEL %d · %s · MATCH COLORED KEYS TO DOORS"%[level_index+1,map.name.to_upper()])
	sound.effect("key")

func finish_screen_action() -> void:
	if phase!="complete": return
	if level_index<Level.COUNT-1: advance_level()
	else: return_to_library()

func make_hero(id: int, hero_class: int, color_index := -1) -> Dictionary:
	var stats: Dictionary = Level.CLASSES[hero_class]
	return {"id":id,"hero_class":hero_class,"color_index":posmod(id-1 if color_index<0 else color_index,Level.PLAYER_COLORS.size()),"pos":Level.spawn(id,level_index),"face":Vector2.DOWN,
		"attack_serial":0,"attack_started":-100.0,"attack_face":Vector2.DOWN,"magic_serial":0,"hit_serial":0,"hp":stats.health,"cooldown":0.0,"hurt":0.0,"potions":2,"revive":0.0,"escaped":false,"walk":0.0}

func join(id: int) -> void:
	if heroes.has(id): return
	heroes[id] = make_hero(id,(id-1)%4)
	preview_players[heroes[id].hero_class] = id
	# Mid-level recruits arrive beside the surviving party, never behind a locked door.
	if phase in ["playing","paused"]:
		for other: Dictionary in heroes.values():
			if other.id != id and other.hp>0 and not other.escaped:
				heroes[id].pos = other.pos
				break
	_action_previous[id] = {}
	_confirm_armed[id] = false
	if phase == "lobby": _end_guard = 0.25
	announce("PLAYER %02d ENTERS THE VAULT" % id)

func leave(id: int) -> void:
	sound.stop_selection(id)
	controller_voice.stop_all()
	heroes.erase(id)
	_action_previous.erase(id)
	_confirm_armed.erase(id)
	ready_players.erase(id)
	navigation.erase(id)
	lobby_focus.erase(id)
	color_focus.erase(id)
	combat_armed.erase(id)
	if heroes.is_empty():
		reset_level()
	else:
		announce("PLAYER %02d LEFT · SLOT AVAILABLE" % id)

func start() -> void:
	if heroes.is_empty(): return
	controller_voice.stop_all()
	phase = "playing"
	combat_armed.clear()
	announce("FIND THE KEYS. REACH THE EXIT. GET EVERY HERO OUT.")
	sound.effect("start")

func announce(text: String) -> void:
	message = text
	message_time = 4.0

func all_ready() -> bool:
	return not heroes.is_empty() and heroes.keys().all(func(id): return ready_players.get(id,false))

func toggle_ready(id: int) -> void:
	if phase!="lobby" or not heroes.has(id): return
	ready_players[id] = not ready_players.get(id,false)
	sound.effect("select")

func activate_lobby(index: int) -> void:
	match index:
		0: return_to_library()
		1: toggle_help()
		2: toggle_fullscreen()
		3: request_start()

func confirm_lobby(id: int) -> void:
	if color_focus.has(id): color_focus.erase(id)
	elif lobby_focus.has(id): activate_lobby(lobby_focus[id])
	elif all_ready(): request_start()
	elif not ready_players.get(id,false): toggle_ready(id)

func request_start() -> void:
	if phase!="lobby": return
	if all_ready(): start()
	else: announce("EVERY JOINED PLAYER MUST READY UP BEFORE STARTING")

func sync_display() -> void:
	service.keyboard_enabled = phase in ["lobby","playing"] or service.player_for_device(service.KEYBOARD_DEVICE)!=0
	var rows := ceili(heroes.size()/8.0)
	var area := Vector2(1600,900-88-(24+rows*36))
	if display.size!=area:
		display.size = area

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_ESCAPE: menu_back()
		KEY_F2: dungeon_view.toggle_quality()
		KEY_F3: dungeon_view.toggle_overview()
		KEY_F11: toggle_fullscreen()
		KEY_F1: toggle_help()
		KEY_P: toggle_pause()
		KEY_ENTER:
			if help: help = false
			elif phase=="lobby":
				var id: int = service.player_for_device(service.KEYBOARD_DEVICE)
				if id and _confirm_armed.get(id,false): confirm_lobby(id)
			elif phase=="paused": activate_menu(menu_index)
			elif phase=="complete" and _end_guard<=0: finish_screen_action()
		KEY_UP:
			if phase=="paused": move_menu(-1)
		KEY_DOWN:
			if phase=="paused": move_menu(1)
		KEY_R:
			if phase in ["complete","defeat"]: reset_level()
		KEY_C:
			var id: int = service.player_for_device(service.KEYBOARD_DEVICE)
			if id and phase=="lobby" and not help: cycle_color(id)
		KEY_TAB:
			var id: int = service.player_for_device(service.KEYBOARD_DEVICE)
			if id and phase=="lobby" and not help: cycle_class(id)

func toggle_fullscreen() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func toggle_help() -> void:
	if help:
		help = false
		return
	if phase=="complete": return
	if phase=="playing": toggle_pause()
	help = true

func menu_back() -> void:
	if help: help = false
	elif not confirm_leave.is_empty(): confirm_leave = ""; menu_index = 0
	elif phase in ["playing","paused"]: toggle_pause()
	elif phase=="lobby": return_to_library()
	elif phase=="complete" and _end_guard<=0: finish_screen_action()

func toggle_pause() -> void:
	if phase=="lobby": request_start()
	elif phase=="playing":
		controller_voice.stop_all()
		phase = "paused"
		menu_index = 0
		confirm_leave = ""
		help = false
	elif phase=="paused":
		help = false
		confirm_leave = ""
		phase = "playing"
		combat_armed.clear()

func menu_labels() -> Array[String]:
	if help: return ["Back to menu"]
	if not confirm_leave.is_empty(): return ["Keep playing", "End run and return to "+confirm_leave]
	return ["Resume adventure", "Camera: "+("full dungeon" if dungeon_view.overview else "follow party"),
		"Minimap: "+("shown" if show_minimap else "hidden"),
		"Lighting: "+("cinematic" if dungeon_view.high_quality else "performance"),
		"Sound effects: "+("on" if sound.sfx_enabled else "off"), "Controls & how to play", "Return to hero lobby", "Return to game library", "Toggle fullscreen", "Music: "+("on" if sound.music_enabled else "off"), "Controller rumble: "+("on" if controller_voice.rumble_enabled else "off")]

func move_menu(direction: int) -> void:
	menu_index = posmod(menu_index+direction,menu_labels().size())
	sound.effect("select")

func activate_menu(index: int) -> void:
	if phase!="paused": return
	if help: help = false; menu_index = 0; return
	if not confirm_leave.is_empty():
		var destination := confirm_leave
		confirm_leave = ""
		menu_index = 0
		if index==0: toggle_pause()
		elif destination=="lobby": reset_level()
		else: return_to_library()
		return
	match index:
		0: toggle_pause()
		1: dungeon_view.toggle_overview()
		2: show_minimap = not show_minimap
		3: dungeon_view.toggle_quality()
		4:
			sound.sfx_enabled = not sound.sfx_enabled
			if not sound.sfx_enabled: controller_voice.stop_all()
		5: help = true; menu_index = 0
		6: confirm_leave = "lobby"; menu_index = 0
		7: confirm_leave = "library"; menu_index = 0
		8: toggle_fullscreen()
		9: sound.music_enabled = not sound.music_enabled
		10:
			controller_voice.rumble_enabled = not controller_voice.rumble_enabled
			if not controller_voice.rumble_enabled: controller_voice.stop_all()

func cycle_class(id: int, direction := 1) -> void:
	if phase!="lobby" or not heroes.has(id): return
	heroes[id] = make_hero(id,posmod(heroes[id].hero_class+direction,4),heroes[id].color_index)
	preview_players[heroes[id].hero_class] = id
	color_focus.erase(id)
	ready_players[id] = false
	lobby_focus.erase(id)
	if sound.enabled and sound.sfx_enabled: controller_voice.choose(id,heroes[id].hero_class)

func color_for(hero: Dictionary) -> Color:
	return Level.player_color(int(hero.get("color_index",hero.hero_class)))

func cycle_color(id: int, direction := 1) -> void:
	if phase!="lobby" or not heroes.has(id): return
	heroes[id].color_index = posmod(heroes[id].color_index+direction,Level.PLAYER_COLORS.size())
	ready_players[id] = false
	preview_players[heroes[id].hero_class] = id
	sound.effect("select")

func preview_hero(kind: int) -> Dictionary:
	var id: int = preview_players.get(kind,0)
	if heroes.has(id) and heroes[id].hero_class==kind: return heroes[id]
	for hero: Dictionary in heroes.values():
		if hero.hero_class==kind: return hero
	return {}

func actions(id: int) -> Dictionary:
	var player: Dictionary = service.players.get(id,{})
	if player.is_empty(): return {}
	var buttons: Dictionary = player.buttons
	var keyboard: Dictionary = player.keys
	var wii: bool = player.profile.get("id","") == "wii_remote"
	var attack := bool(keyboard.get(KEY_SPACE,false))
	for button in player.profile.get("jump",[JOY_BUTTON_A]):
		attack = attack or bool(buttons.get(button,false))
	return {"attack":attack,
		"magic":bool(keyboard.get(KEY_X,false)) or bool(buttons.get(JOY_BUTTON_X,false)),
		"back":bool(buttons.get(player.profile.get("leave",JOY_BUTTON_B),false)),
		"start":bool(buttons.get(JOY_BUTTON_START,false)) or (wii and bool(buttons.get(JOY_BUTTON_GUIDE,false)))}

func _physics_process(delta: float) -> void:
	step(delta)
	board.queue_redraw()

func step(delta: float) -> void:
	clock += delta
	message_time = maxf(0,message_time-delta)
	_end_guard = maxf(0,_end_guard-delta)
	var start_pressed := false
	var confirm_pressed := false
	var back_pressed := false
	var attack_taps: Dictionary = {}
	var party_was_ready := all_ready()
	var lobby_action := -1
	for id: int in heroes:
		var act := actions(id)
		var previous: Dictionary = _action_previous.get(id,{})
		if not act.get("attack",false):
			_confirm_armed[id] = true
			combat_armed[id] = true
		var queued_confirm: bool = service.consume_jump(id)
		var confirm_edge: bool = (queued_confirm or (act.get("attack",false) and not previous.get("attack",false))) and _confirm_armed.get(id,false)
		confirm_pressed = confirm_pressed or confirm_edge
		if phase=="playing" and confirm_edge: attack_taps[id] = true
		var magic_edge: bool = act.get("magic",false) and not previous.get("magic",false)
		var start_edge: bool = act.get("start",false) and not previous.get("start",false)
		start_pressed = start_pressed or start_edge
		back_pressed = back_pressed or (act.get("back",false) and not previous.get("back",false))
		var move: Vector2 = service.movement(id)
		var nav := Vector2i(signf(move.x) if absf(move.x)>0.6 else 0,signf(move.y) if absf(move.y)>0.6 else 0)
		var old_nav: Vector2i = navigation.get(id,Vector2i.ZERO)
		var is_keyboard: bool = service.player_for_device(service.KEYBOARD_DEVICE)==id
		if phase=="lobby" and not help:
			if nav.y>0 and old_nav.y<=0:
				if color_focus.has(id): color_focus.erase(id)
				else: lobby_focus[id] = 3
			elif nav.y<0 and old_nav.y>=0:
				if lobby_focus.has(id): lobby_focus.erase(id)
				else: color_focus[id] = true
			if magic_edge: cycle_class(id)
			elif nav.x!=0 and nav.x!=old_nav.x:
				if lobby_focus.has(id): lobby_focus[id] = posmod(lobby_focus[id]+nav.x,4)
				elif color_focus.has(id): cycle_color(id,nav.x)
				else: cycle_class(id,nav.x)
			if act.get("back",false) and not previous.get("back",false):
				if lobby_focus.has(id): lobby_focus.erase(id)
				elif color_focus.has(id): color_focus.erase(id)
				else: ready_players[id] = false
			if confirm_edge:
				if color_focus.has(id): color_focus.erase(id)
				elif lobby_focus.has(id): lobby_action = lobby_focus[id]
				elif party_was_ready and all_ready(): lobby_action = 3
				elif not ready_players.get(id,false): toggle_ready(id)
		elif phase=="paused":
			if not is_keyboard and nav.y!=0 and nav.y!=old_nav.y: move_menu(nav.y)
		navigation[id] = nav
		if phase == "playing" and magic_edge: cast_magic(id)
		_action_previous[id] = act
	if help and (confirm_pressed or back_pressed):
		help = false
		return
	if back_pressed and phase=="paused":
		menu_back()
		return
	if back_pressed and phase=="defeat" and _end_guard<=0:
		return_to_library()
		return
	if phase=="lobby" and not help and lobby_action>=0:
		activate_lobby(lobby_action)
		return
	if start_pressed:
		if help or not confirm_leave.is_empty(): menu_back()
		elif phase=="lobby": request_start()
		elif phase=="complete":
			if _end_guard<=0: finish_screen_action()
		elif phase=="defeat":
			if _end_guard<=0: reset_level()
		else: toggle_pause()
		return
	if confirm_pressed and phase=="paused":
		activate_menu(menu_index)
		return
	if confirm_pressed and phase=="defeat" and _end_guard<=0:
		reset_level()
		return
	if confirm_pressed and phase == "complete" and _end_guard<=0:
		finish_screen_action()
		return
	if phase != "playing": return
	elapsed += delta
	for id: int in heroes:
		var hero: Dictionary = heroes[id]
		if hero.hp<=0 or hero.escaped: continue
		var stats: Dictionary = Level.CLASSES[hero.hero_class]
		hero.hurt = maxf(0,hero.hurt-delta)
		hero.cooldown = maxf(0,hero.cooldown-delta)
		hero.hp = maxf(0,hero.hp-delta*1.5)
		var direction: Vector2 = service.movement(id)
		if direction.length()>0.1:
			hero.face = direction.normalized()
			hero.pos = slide(hero.pos,direction*stats.speed*delta,10,true)
			hero.walk += delta*12
		if (actions(id).get("attack",false) or attack_taps.get(id,false)) and combat_armed.get(id,false) and hero.cooldown<=0:
			fire(hero)
		collect(hero)
		try_exit(hero)
	update_melee()
	_flow_clock -= delta
	if _flow_clock<=0:
		build_flow()
		_flow_clock = 0.3
	update_generators(delta)
	update_sparks(delta)
	update_enemies(delta)
	update_shots(delta)
	update_revives(delta)
	check_finish(delta)

func blocked(at: Vector2, radius: float) -> bool:
	for corner in [Vector2(-radius,-radius),Vector2(radius,-radius),Vector2(-radius,radius),Vector2(radius,radius)]:
		var cell := Level.cell(at+corner)
		if cell.x<0 or cell.y<0 or cell.x>=map.width or cell.y>=map.height or walls.has(cell) or doors.has(cell): return true
	return false

func slide(at: Vector2, movement: Vector2, radius: float, open_doors := false) -> Vector2:
	# Small substeps prevent a frame hitch or fast projectile crossing a wall.
	var parts := maxi(1,ceili(movement.length()/6))
	var increment := movement/parts
	for i in parts:
		for axis in [Vector2(increment.x,0),Vector2(0,increment.y)]:
			var target: Vector2 = at+axis
			if open_doors:
				for corner in [Vector2(-radius,-radius),Vector2(radius,-radius),Vector2(-radius,radius),Vector2(radius,radius)]:
					var cell := Level.cell(target+corner)
					if doors.has(cell): unlock(int(doors[cell]))
			if not blocked(target,radius): at = target
	return at

func unlock(group: int) -> void:
	var color: String = map.door_colors.get(group,"gold")
	var available: int = keyring.get(color,0)
	if available<=0:
		if message_time<=0: announce("FIND THE %s KEY · EXPLORE THE OTHER CHAMBERS"%color.to_upper())
		return
	keys -= 1
	keyring[color] = maxi(0,int(keyring.get(color,0))-1)
	for cell: Vector2i in doors.keys():
		if doors[cell]==group: doors.erase(cell)
	_flow_clock = 0
	announce("DOOR OPENED · KEYS ARE SHARED BY THE PARTY")
	sound.effect("key")

func fire(hero: Dictionary) -> void:
	if hero.hp<=0 or hero.escaped: return
	var stats: Dictionary = Level.CLASSES[hero.hero_class]
	hero.cooldown = stats.rate
	hero.attack_serial += 1
	hero.attack_started = elapsed
	hero.attack_face = hero.face
	if hero.hero_class<2:
		melee_swings.append({"owner":hero.id,"face":hero.face,"at":elapsed+stats.windup,"hero_class":hero.hero_class,"started":elapsed,"sampled":0.0,"hit_enemies":{},"hit_generators":{}})
		sound.effect("axe" if hero.hero_class==0 else "sword")
	else:
		var arrow: bool = hero.hero_class==3
		shots.append({"pos":hero.pos,"velocity":hero.face*(480 if arrow else 340),"damage":stats.damage,
			"life":1.35,"owner":hero.id,"hero_class":hero.hero_class,"kind":"arrow" if arrow else "arcane"})
		sound.effect("bow" if arrow else "shoot")

func melee_reaches(origin: Vector2, facing: Vector2, target: Vector2, reach: float, target_radius: float, check_arc := true) -> bool:
	var offset := target-origin
	if offset.length()>reach+target_radius: return false
	if check_arc and offset.length()>target_radius and facing.dot(offset.normalized())<0.35: return false
	# Sweep visibility through the same walls and closed doors as projectiles.
	var parts := maxi(1,ceili(offset.length()/6.0))
	for part in range(1,parts+1):
		if blocked(origin+offset*float(part)/parts,0): return false
	return true

func update_melee() -> void:
	for i in range(melee_swings.size()-1,-1,-1):
		var swing: Dictionary = melee_swings[i]
		if elapsed<swing.at: continue
		var hero: Dictionary = heroes.get(swing.owner,{})
		if hero.is_empty() or hero.hp<=0 or hero.escaped or hero.hero_class!=swing.hero_class:
			melee_swings.remove_at(i)
			continue
		if swing.hero_class==0:
			update_axe(swing,hero)
			if elapsed-swing.started>=AxeSwing.STRIKE_END: melee_swings.remove_at(i)
			continue
		melee_swings.remove_at(i)
		var stats: Dictionary = Level.CLASSES[hero.hero_class]
		for enemy: Dictionary in enemies:
			if enemy.hp>0 and melee_reaches(hero.pos,swing.face,enemy.pos,stats.reach,12): damage_enemy(enemy,stats.damage)
		for generator: Dictionary in generators:
			if generator.hp>0 and melee_reaches(hero.pos,swing.face,generator.pos,stats.reach,19): damage_generator(generator,stats.damage)

func update_axe(swing: Dictionary, hero: Dictionary) -> void:
	var age: float = elapsed-swing.started
	var damage: float = Level.CLASSES[0].damage
	for enemy: Dictionary in enemies:
		if enemy.hp<=0 or swing.hit_enemies.has(enemy.id): continue
		if AxeSwing.touches(hero.pos,swing.face,enemy.pos,12,swing.sampled,age) and melee_reaches(hero.pos,swing.face,enemy.pos,Level.CLASSES[0].reach,12,false):
			damage_enemy(enemy,damage)
			swing.hit_enemies[enemy.id] = true
	for index in generators.size():
		var generator: Dictionary = generators[index]
		if generator.hp<=0 or swing.hit_generators.has(index): continue
		if AxeSwing.touches(hero.pos,swing.face,generator.pos,19,swing.sampled,age) and melee_reaches(hero.pos,swing.face,generator.pos,Level.CLASSES[0].reach,19,false):
			damage_generator(generator,damage)
			swing.hit_generators[index] = true
	swing.sampled = age

func cast_magic(id: int) -> void:
	var hero: Dictionary = heroes[id]
	if hero.hp<=0 or hero.escaped or hero.potions<=0: return
	hero.potions -= 1
	hero.magic_serial += 1
	sparks.append({"pos":hero.pos,"life":Level.MAGIC_DURATION,"kind":"magic","color":color_for(hero),
		"damage":Level.CLASSES[hero.hero_class].magic,"hit_enemies":{},"hit_generators":{}})
	sound.effect("magic")
	announce("PLAYER %02d CASTS MAGIC!" % id)

func update_sparks(delta: float) -> void:
	# Damage and rendering share one wave clock/radius. Damage may append impact sparks.
	for spark: Dictionary in sparks.duplicate():
		spark.life -= delta
		if spark.kind!="magic": continue
		var radius := Level.magic_radius(spark.life)
		for enemy: Dictionary in enemies:
			if enemy.hp>0 and not spark.hit_enemies.has(enemy.id) and enemy.pos.distance_to(spark.pos)<=radius:
				spark.hit_enemies[enemy.id] = true
				damage_enemy(enemy,spark.damage)
		for index in generators.size():
			var generator: Dictionary = generators[index]
			if generator.hp>0 and not spark.hit_generators.has(index) and generator.pos.distance_to(spark.pos)<=radius:
				spark.hit_generators[index] = true
				damage_generator(generator,spark.damage)
	sparks = sparks.filter(func(s): return s.life>0)

func collect(hero: Dictionary) -> void:
	for i in range(pickups.size()-1,-1,-1):
		var pickup: Dictionary = pickups[i]
		if pickup.pos.distance_to(hero.pos)>23: continue
		match pickup.kind:
			"key":
				var color: String = pickup.get("key_color","gold")
				keys += 1
				keyring[color] = int(keyring.get(color,0))+1
				announce("%s KEY FOUND · SHARED BY THE PARTY"%color.to_upper())
			"gold": score += 250
			"potion": hero.potions += 1; announce("MAGIC POTION · X / SQUARE / WII 1 TO CAST")
			"food":
				# A feast heals every living hero; supplies scale fairly to sixteen players.
				var hungry := false
				for ally: Dictionary in heroes.values():
					if ally.hp>0 and not ally.escaped and ally.hp<Level.CLASSES[ally.hero_class].health-5: hungry = true
				if not hungry: continue
				for ally: Dictionary in heroes.values():
					if ally.hp>0 and not ally.escaped: ally.hp = minf(Level.CLASSES[ally.hero_class].health,ally.hp+220)
				announce("FOOD! THE PARTY RECOVERS 220 HEALTH")
		pickups.remove_at(i)
		sound.effect("pickup")

func build_flow() -> void:
	flow.clear()
	var queue: Array[Vector2i] = []
	for hero: Dictionary in heroes.values():
		if hero.hp<=0 or hero.escaped: continue
		var cell := Level.cell(hero.pos)
		if not flow.has(cell):
			flow[cell] = 0
			queue.append(cell)
	var cursor := 0
	while cursor<queue.size():
		var cell := queue[cursor]
		cursor += 1
		for direction: Vector2i in DIRECTIONS:
			var next := cell+direction
			if next.x<=0 or next.y<=0 or next.x>=map.width-1 or next.y>=map.height-1 or walls.has(next) or doors.has(next) or flow.has(next): continue
			flow[next] = int(flow[cell])+1
			queue.append(next)

func update_generators(delta: float) -> void:
	var active := living().size()
	for generator: Dictionary in generators:
		if generator.hp<=0: continue
		generator.clock -= delta
		if generator.clock>0 or enemies.size()>=mini(96 if level_index==0 else 128,int(map.enemy_cap)+active*6): continue
		# Closed doors isolate the rooms until the party can reach them.
		if not flow.has(Level.cell(generator.pos)): continue
		generator.clock = maxf(0.55,2.6*float(map.spawn_rate)/(1.0+active*0.14))
		_serial += 1
		var spawn: Vector2 = generator.pos
		for offset: Vector2i in DIRECTIONS:
			var candidate: Vector2 = generator.pos+Vector2(offset)*24
			if not blocked(candidate,9):
				spawn = candidate
				break
		enemies.append({"id":_serial,"pos":spawn,"kind":generator.kind,"hp":enemy_health(generator.kind),"max_hp":enemy_health(generator.kind),"attack":1.0})

func living() -> Array:
	return heroes.values().filter(func(h): return h.hp>0 and not h.escaped)

func update_enemies(delta: float) -> void:
	var targets := living()
	for enemy: Dictionary in enemies:
		if enemy.hp<=0: continue
		var target: Dictionary = {}
		var distance := INF
		for hero: Dictionary in targets:
			var d: float = enemy.pos.distance_to(hero.pos)
			if d<distance: distance = d; target = hero
		if target.is_empty(): continue
		var cell := Level.cell(enemy.pos)
		var aim: Vector2 = target.pos
		if distance>36:
			var best: int = flow.get(cell,99999)
			var next := cell
			for direction: Vector2i in DIRECTIONS:
				var value: int = flow.get(cell+direction,99999)
				if value<best: best = value; next = cell+direction
			if next==cell: continue
			# Align on the corridor center before turning around a corner.
			aim = Level.center(next)
			var center := Level.center(cell)
			if next.x!=cell.x and absf(enemy.pos.y-center.y)>3: aim = center
			if next.y!=cell.y and absf(enemy.pos.x-center.x)>3: aim = center
		var speed: float = (53.0 if enemy.kind=="grunt" else 65.0)*(1.0+level_index*0.045)
		enemy.pos = slide(enemy.pos,(aim-enemy.pos).normalized()*speed*delta,9)
		enemy.attack -= delta
		if distance<23:
			var before: int = target.hit_serial
			hurt(target,(24.0 if enemy.kind=="grunt" else 18.0)*(1.0+level_index*0.1))
			if target.hit_serial!=before: enemy.attack_serial = int(enemy.get("attack_serial",0))+1
		if enemy.kind=="demon" and distance<250 and enemy.attack<=0:
			enemy.attack = 2.4
			enemy.attack_serial = int(enemy.get("attack_serial",0))+1
			shots.append({"pos":enemy.pos,"velocity":(target.pos-enemy.pos).normalized()*160,"damage":30.0*(1.0+level_index*0.1),"life":2.0,"owner":0,"hero_class":0})
	for i in range(enemies.size()-1,-1,-1):
		if enemies[i].hp<=0:
			burst(enemies[i].pos,Color("dfa679"))
			enemies.remove_at(i)
			score += 50
			kills += 1

func hurt(hero: Dictionary, damage: float) -> void:
	if hero.hurt>0 or hero.hp<=0 or hero.escaped: return
	var armor := 0.65 if hero.hero_class==1 else 1.0
	hero.hp = maxf(0,hero.hp-damage*armor)
	hero.hurt = 0.65
	hero.hit_serial += 1
	hero.hit_at = elapsed
	sound.hurt(hero.hero_class,hero.id)
	controller_voice.hurt(hero.id,hero.hero_class,int(sound.hurt_variants.get(hero.id,1))-1,sound.enabled and sound.sfx_enabled)
	if hero.hp<=0: announce("PLAYER %02d IS DOWN · STAND NEAR THEM TO REVIVE" % hero.id)

func update_shots(delta: float) -> void:
	for i in range(shots.size()-1,-1,-1):
		var shot: Dictionary = shots[i]
		shot.life -= delta
		var parts := maxi(1,ceili(shot.velocity.length()*delta/6))
		for part in parts:
			shot.pos += shot.velocity*delta/parts
			if blocked(shot.pos,2): shot.life = 0; break
			if shot.owner==0:
				for hero: Dictionary in living():
					if hero.pos.distance_to(shot.pos)<13: hurt(hero,shot.damage); shot.life = 0; break
			else:
				for generator: Dictionary in generators:
					if generator.hp>0 and generator.pos.distance_to(shot.pos)<19:
						damage_generator(generator,shot.damage)
						shot.life = 0
						break
				if shot.life>0:
					for enemy: Dictionary in enemies:
						if enemy.hp>0 and enemy.pos.distance_to(shot.pos)<14:
							damage_enemy(enemy,shot.damage)
							shot.life = 0
							break
			if shot.life<=0: break
		if shot.life<=0: shots.remove_at(i)

func damage_enemy(enemy: Dictionary, amount: float) -> void:
	if enemy.hp<=0 or amount<=0: return
	if not enemy.has("max_hp"): enemy.max_hp = enemy.hp
	enemy.hp = maxf(0,enemy.hp-amount)
	enemy.hit_at = elapsed
	enemy.hit_serial = int(enemy.get("hit_serial",0))+1
	sound.effect("enemy_"+str(enemy.get("kind","grunt")))

func damage_generator(generator: Dictionary, amount: float) -> void:
	if generator.hp<=0: return
	generator.hp = maxf(0,generator.hp-amount)
	if generator.hp>0: sound.effect("stone")
	burst(generator.pos,Color("d9b976"))
	if generator.hp<=0:
		score += 1000
		sound.effect("destroy")
		announce("GENERATOR DESTROYED · %d / %d" % [destroyed(),generators.size()])
		if destroyed()==generators.size(): announce("ALL GENERATORS DESTROYED! BONUS SECURED. HEAD FOR THE EXIT.")

func destroyed() -> int:
	return generators.filter(func(g): return g.hp<=0).size()

func burst(at: Vector2, color: Color) -> void:
	sparks.append({"pos":at,"color":color,"life":0.35,"kind":"hit"})
	if sparks.size()>80: sparks.pop_front()

func update_revives(delta: float) -> void:
	for hero: Dictionary in heroes.values():
		if hero.hp>0 or hero.escaped: continue
		var nearby := false
		for ally: Dictionary in living():
			if ally.pos.distance_to(hero.pos)<48: nearby = true; break
		hero.revive = minf(2.5,hero.revive+delta) if nearby else maxf(0,hero.revive-delta)
		if hero.revive>=2.5:
			hero.hp = Level.CLASSES[hero.hero_class].health*0.4
			hero.hurt = 3.0
			hero.revive = 0
			announce("PLAYER %02d IS BACK IN THE FIGHT" % hero.id)
			sound.effect("pickup")

func escaped_count() -> int:
	return heroes.values().filter(func(h): return h.escaped).size()

func try_exit(hero: Dictionary) -> void:
	if hero.escaped or hero.hp<=0 or hero.pos.distance_to(map.exit)>30: return
	# Keep a rescuer inside if a teammate is down; nobody is silently left behind.
	if living().size()==1:
		for ally: Dictionary in heroes.values():
			if not ally.escaped and ally.hp<=0:
				if message_time<=0 or not message.begins_with("REVIVE PLAYER"): announce("REVIVE PLAYER %02d BEFORE THE LAST HERO EXITS" % ally.id)
				return
	hero.escaped = true
	hero.exit_at = clock
	hero.pos = map.exit
	score += 1000
	sound.effect("pickup")
	burst(map.exit,Color("84f5d1"))
	announce("PLAYER %02d ESCAPED!  %d / %d SAFE" % [hero.id,escaped_count(),heroes.size()])
	_flow_clock = 0

func check_finish(_delta: float) -> void:
	if heroes.is_empty() or phase!="playing": return
	for hero: Dictionary in heroes.values(): try_exit(hero)
	if escaped_count()==heroes.size():
		phase = "complete"
		_end_guard = 2.0
		return_countdown = 6.0
		_confirm_armed.clear()
		sound.effect("win")
	elif living().is_empty():
		phase = "defeat"
		_end_guard = 0.8
		sound.effect("defeat")

func return_to_library() -> void:
	if close_on_finish: get_tree().quit()

func _process(delta: float) -> void:
	if phase=="complete":
		return_countdown = maxf(0,return_countdown-delta)
		if return_countdown<=0: finish_screen_action()
	if is_instance_valid(board):
		sync_display()
		board.queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and phase == "playing":
		toggle_pause()
