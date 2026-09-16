extends Node2D
const Level = preload("res://examples/gauntlet/level.gd")
const DungeonView = preload("res://examples/gauntlet/dungeon_view.gd")
const Board = preload("res://examples/gauntlet/board.gd")
const Fleet = preload("res://examples/pocket_rally/wii_fleet.gd")
const Sounds = preload("res://examples/gauntlet/sound.gd")
const DIRECTIONS := [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]
var service: Node
var board: Node2D
var dungeon_view: Node3D
var close_on_finish := true
var return_countdown := 6.0
var _confirm_armed: Dictionary = {}
var sound: Node
var heroes: Dictionary = {}
var walls: Dictionary = {}
var doors: Dictionary = {}
var generators: Array = []
var pickups: Array = []
var enemies: Array = []
var shots: Array = []
var sparks: Array = []
var flow: Dictionary = {}
var phase := "lobby"
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
var _help_paused := false

func _ready() -> void:
	DisplayServer.window_set_title("Gauntlet · The Ember Vault · Couch Games")
	service = get_node("/root/Platform").input
	service.keyboard_enabled = true
	service.player_joined.connect(join)
	service.player_left.connect(leave)
	var display := SubViewportContainer.new()
	display.position = Vector2(40,104)
	display.size = Vector2(1520,632)
	display.stretch = true
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(display)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1520,632)
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
	walls = Level.walls()
	doors = Level.doors()
	generators = Level.generators()
	pickups = Level.pickups()
	enemies.clear()
	shots.clear()
	sparks.clear()
	flow.clear()
	keys = 0
	score = 0
	kills = 0
	elapsed = 0
	exit_time = 0
	_flow_clock = 0
	phase = "lobby"
	return_countdown = 6.0
	_confirm_armed.clear()
	for id: int in heroes:
		var chosen: int = heroes[id].hero_class
		heroes[id] = make_hero(id,chosen)
	message = "JOIN, CHOOSE YOUR HERO, THEN PRESS FIRE AGAIN TO START."
	message_time = 8
	_end_guard = 0.7
	if dungeon_view: dungeon_view.rebuild()

func make_hero(id: int, hero_class: int) -> Dictionary:
	var stats: Dictionary = Level.CLASSES[hero_class]
	return {"id":id,"hero_class":hero_class,"pos":Level.spawn(id),"face":Vector2.DOWN,
		"attack_serial":0,"magic_serial":0,"hit_serial":0,"hp":stats.health,"cooldown":0.0,"hurt":0.0,"potions":2,"revive":0.0,"escaped":false,"walk":0.0}

func join(id: int) -> void:
	if heroes.has(id): return
	heroes[id] = make_hero(id,(id-1)%4)
	# Mid-level recruits arrive beside the surviving party, never behind a locked door.
	if phase == "playing":
		for other: Dictionary in heroes.values():
			if other.id != id and other.hp>0 and not other.escaped:
				heroes[id].pos = other.pos
				break
	_action_previous[id] = {}
	_confirm_armed[id] = false
	if phase == "lobby": _end_guard = 0.25
	announce("PLAYER %02d ENTERS THE VAULT" % id)

func leave(id: int) -> void:
	heroes.erase(id)
	_action_previous.erase(id)
	_confirm_armed.erase(id)
	if heroes.is_empty():
		reset_level()
	else:
		announce("PLAYER %02d LEFT · SLOT AVAILABLE" % id)

func start() -> void:
	if heroes.is_empty(): return
	phase = "playing"
	announce("FIND THE KEYS. REACH THE EXIT. GET EVERY HERO OUT.")
	sound.effect("start")

func announce(text: String) -> void:
	message = text
	message_time = 4.0

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_ESCAPE: get_tree().quit()
		KEY_F2: dungeon_view.toggle_quality()
		KEY_F3: dungeon_view.toggle_overview()
		KEY_F11:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
		KEY_F1:
			help = not help
			if help:
				_help_paused = phase == "playing"
				if _help_paused: phase = "paused"
			elif _help_paused and phase == "paused": phase = "playing"
		KEY_P: toggle_pause()
		KEY_ENTER:
			if phase == "lobby" and _end_guard<=0: start()
		KEY_R:
			if phase in ["complete","defeat"]: reset_level()
		KEY_TAB:
			var id: int = service.player_for_device(service.KEYBOARD_DEVICE)
			if id and phase == "lobby": cycle_class(id)

func toggle_pause() -> void:
	if phase == "playing": phase = "paused"
	elif phase == "paused": phase = "playing"

func cycle_class(id: int) -> void:
	heroes[id] = make_hero(id,(heroes[id].hero_class+1)%4)
	sound.effect("select")

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
	for id: int in heroes:
		var act := actions(id)
		var previous: Dictionary = _action_previous.get(id,{})
		if not act.get("attack",false): _confirm_armed[id] = true
		var queued_confirm: bool = service.consume_jump(id)
		var confirm_edge: bool = (queued_confirm or (act.get("attack",false) and not previous.get("attack",false))) and _confirm_armed.get(id,false)
		confirm_pressed = confirm_pressed or confirm_edge
		var magic_edge: bool = act.get("magic",false) and not previous.get("magic",false)
		var start_edge: bool = act.get("start",false) and not previous.get("start",false)
		start_pressed = start_pressed or start_edge
		if phase == "lobby":
			if magic_edge: cycle_class(id)
		elif phase == "playing" and magic_edge: cast_magic(id)
		_action_previous[id] = act
	if not help and (start_pressed or (confirm_pressed and phase in ["lobby","paused","defeat"])):
		if phase == "lobby":
			start()
			# Starting never consumes a potion or fires a stray projectile.
			return
		elif phase in ["complete","defeat"]:
			if _end_guard<=0: reset_level()
		else: toggle_pause()
	if confirm_pressed and phase == "complete" and _end_guard<=0:
		return_to_library()
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
		if actions(id).get("attack",false) and hero.cooldown<=0:
			fire(hero)
		collect(hero)
		try_exit(hero)
	_flow_clock -= delta
	if _flow_clock<=0:
		build_flow()
		_flow_clock = 0.3
	update_generators(delta)
	update_enemies(delta)
	update_shots(delta)
	update_revives(delta)
	for spark: Dictionary in sparks: spark.life -= delta
	sparks = sparks.filter(func(s): return s.life>0)
	check_finish(delta)

func blocked(at: Vector2, radius: float) -> bool:
	for corner in [Vector2(-radius,-radius),Vector2(radius,-radius),Vector2(-radius,radius),Vector2(radius,radius)]:
		var cell := Level.cell(at+corner)
		if cell.x<0 or cell.y<0 or cell.x>=Level.WIDTH or cell.y>=Level.HEIGHT or walls.has(cell) or doors.has(cell): return true
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
	if keys<=0:
		if message_time<=0: announce("FIND A GOLD KEY TO OPEN THIS DOOR")
		return
	keys -= 1
	for cell: Vector2i in doors.keys():
		if doors[cell]==group: doors.erase(cell)
	_flow_clock = 0
	announce("DOOR OPENED · KEYS ARE SHARED BY THE PARTY")
	sound.effect("key")

func fire(hero: Dictionary) -> void:
	var stats: Dictionary = Level.CLASSES[hero.hero_class]
	hero.cooldown = stats.rate
	hero.attack_serial += 1
	shots.append({"pos":hero.pos,"velocity":hero.face*360,"damage":stats.damage,"life":1.35,"owner":hero.id,"hero_class":hero.hero_class})
	sound.effect("shoot")

func cast_magic(id: int) -> void:
	var hero: Dictionary = heroes[id]
	if hero.hp<=0 or hero.escaped or hero.potions<=0: return
	hero.potions -= 1
	hero.magic_serial += 1
	var damage: float = Level.CLASSES[hero.hero_class].magic
	for enemy: Dictionary in enemies:
		if enemy.pos.distance_to(hero.pos)<200: enemy.hp -= damage
	for generator: Dictionary in generators:
		if generator.pos.distance_to(hero.pos)<200: damage_generator(generator,damage)
	sparks.append({"pos":hero.pos,"life":0.65,"kind":"magic","color":Color(Level.CLASSES[hero.hero_class].color)})
	sound.effect("magic")
	announce("PLAYER %02d CASTS MAGIC!" % id)

func collect(hero: Dictionary) -> void:
	for i in range(pickups.size()-1,-1,-1):
		var pickup: Dictionary = pickups[i]
		if pickup.pos.distance_to(hero.pos)>23: continue
		match pickup.kind:
			"key": keys += 1; announce("KEY FOUND · ANY HERO CAN OPEN THE NEXT DOOR")
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
			if next.x<=0 or next.y<=0 or next.x>=39 or next.y>=19 or walls.has(next) or doors.has(next) or flow.has(next): continue
			flow[next] = int(flow[cell])+1
			queue.append(next)

func update_generators(delta: float) -> void:
	var active := living().size()
	for generator: Dictionary in generators:
		if generator.hp<=0: continue
		generator.clock -= delta
		if generator.clock>0 or enemies.size()>=mini(96,14+active*6): continue
		# Closed doors isolate the rooms until the party can reach them.
		if not flow.has(Level.cell(generator.pos)): continue
		generator.clock = maxf(0.65,2.6/(1.0+active*0.14))
		_serial += 1
		var spawn: Vector2 = generator.pos
		for offset: Vector2i in DIRECTIONS:
			var candidate: Vector2 = generator.pos+Vector2(offset)*24
			if not blocked(candidate,9):
				spawn = candidate
				break
		enemies.append({"id":_serial,"pos":spawn,"kind":generator.kind,"hp":52.0 if generator.kind=="grunt" else 34.0,"attack":1.0})

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
		var speed := 53.0 if enemy.kind=="grunt" else 65.0
		enemy.pos = slide(enemy.pos,(aim-enemy.pos).normalized()*speed*delta,9)
		enemy.attack -= delta
		if distance<23: hurt(target,24.0 if enemy.kind=="grunt" else 18.0)
		if enemy.kind=="demon" and distance<250 and enemy.attack<=0:
			enemy.attack = 2.4
			shots.append({"pos":enemy.pos,"velocity":(target.pos-enemy.pos).normalized()*160,"damage":30.0,"life":2.0,"owner":0,"hero_class":0})
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
	sound.effect("hurt")
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
							enemy.hp -= shot.damage
							shot.life = 0
							break
			if shot.life<=0: break
		if shot.life<=0: shots.remove_at(i)

func damage_generator(generator: Dictionary, amount: float) -> void:
	if generator.hp<=0: return
	generator.hp = maxf(0,generator.hp-amount)
	burst(generator.pos,Color("d9b976"))
	if generator.hp<=0:
		score += 1000
		sound.effect("destroy")
		announce("GENERATOR DESTROYED · %d / 4" % destroyed())
		if destroyed()==4: announce("ALL GENERATORS DESTROYED! BONUS SECURED. HEAD FOR THE EXIT.")

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
	if hero.escaped or hero.hp<=0 or hero.pos.distance_to(Level.EXIT)>30: return
	# Keep a rescuer inside if a teammate is down; nobody is silently left behind.
	if living().size()==1:
		for ally: Dictionary in heroes.values():
			if not ally.escaped and ally.hp<=0:
				if message_time<=0 or not message.begins_with("REVIVE PLAYER"): announce("REVIVE PLAYER %02d BEFORE THE LAST HERO EXITS" % ally.id)
				return
	hero.escaped = true
	hero.exit_at = clock
	hero.pos = Level.EXIT
	score += 1000
	sound.effect("pickup")
	burst(Level.EXIT,Color("84f5d1"))
	announce("PLAYER %02d ESCAPED!  %d / %d SAFE" % [hero.id,escaped_count(),heroes.size()])
	_flow_clock = 0

func check_finish(_delta: float) -> void:
	if heroes.is_empty() or phase!="playing": return
	for hero: Dictionary in heroes.values(): try_exit(hero)
	if escaped_count()==heroes.size():
		phase = "complete"
		_end_guard = 0.8
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
		if return_countdown<=0: return_to_library()
	if is_instance_valid(board): board.queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and phase == "playing":
		phase = "paused"
