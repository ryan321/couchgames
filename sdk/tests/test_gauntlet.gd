extends SceneTree
const Level = preload("res://examples/gauntlet/level.gd")
const Fleet = preload("res://examples/pocket_rally/wii_fleet.gd")
var game: Node
var service: Node
var checks := 0
var failures := 0
var bot_count := 1
func _initialize() -> void: call_deferred("run")
func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func button(device: int, index: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = index
	event.pressed = pressed
	service.handle_event(event)
func stick(device: int, direction: Vector2) -> void:
	for axis in 2:
		var event := InputEventJoypadMotion.new()
		event.device = device
		event.axis = axis
		event.axis_value = direction.x if axis==0 else direction.y
		service.handle_event(event)
func tick(seconds: float) -> void:
	for i in ceili(seconds*60): game.step(1.0/60)
func clear_players() -> void:
	for id: int in service.players.keys(): service.leave(id)
func join(device: int) -> void:
	service.set_device_profile(device,"gamepad")
	button(device,JOY_BUTTON_A,true)
	button(device,JOY_BUTTON_A,false)
func run() -> void:
	game = load("res://examples/gauntlet/dungeon.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.close_on_finish = false
	game.set_physics_process(false)
	game.set_process(false)
	game.sound.enabled = false
	service = game.service
	service.set_process_input(false)
	service.set_physics_process(false)
	for device in 16: join(device)
	expect(game.heroes.size()==16,"Sixteen independent players can enter")
	var positions := {}
	for hero: Dictionary in game.heroes.values():
		positions[hero.pos] = true
		expect(not game.blocked(hero.pos,10),"Every spawn is clear of walls")
	expect(positions.size()==16,"All sixteen players have distinct starting positions")
	join(16)
	expect(game.heroes.size()==16,"Seventeenth controller cannot take a player slot")
	expect(game.phase=="lobby","Joining never accidentally begins the dungeon")
	tick(0.1)
	button(0,JOY_BUTTON_A,true); button(0,JOY_BUTTON_A,false); tick(0.1)
	expect(game.phase=="playing","A quick press and release of A after joining starts the dungeon")
	game.phase = "paused"
	button(0,JOY_BUTTON_A,true); button(0,JOY_BUTTON_A,false); tick(0.1)
	expect(game.phase=="playing","The same confirm button resumes from focus pause")
	game.reset_level()
	button(0,JOY_BUTTON_X,true); tick(0.1); button(0,JOY_BUTTON_X,false)
	expect(game.heroes[1].hero_class==1 and game.heroes[2].hero_class==1,"Class selection changes only its owner")
	button(0,JOY_BUTTON_START,true); button(1,JOY_BUTTON_START,true); tick(0.1)
	expect(game.phase=="playing","Simultaneous Start presses begin once")
	button(0,JOY_BUTTON_START,false); button(1,JOY_BUTTON_START,false)
	var p2: Vector2 = game.heroes[2].pos
	stick(0,Vector2.RIGHT); tick(0.2); stick(0,Vector2.ZERO)
	expect(game.heroes[1].pos.x>Level.spawn(1).x and game.heroes[2].pos==p2,"Stick input moves only its hero")
	service.device_connection_changed(0,false)
	expect(not game.heroes.has(1) and game.heroes.size()==15,"Disconnect removes the exact hero")
	join(20)
	expect(game.heroes.has(1) and game.heroes[2].pos==p2,"Rejoin reuses the vacant slot without moving another player")
	game.heroes[2].pos = Level.center(Vector2i(11,14))
	var locked: Vector2 = game.slide(game.heroes[2].pos,Vector2(64,0),10,true)
	expect(locked.x<384 and game.doors.size()==4,"Door collision blocks passage without a key")
	game.keys = 1
	var opened: Vector2 = game.slide(game.heroes[2].pos,Vector2(64,0),10,true)
	expect(opened.x>416 and game.keys==0 and game.doors.size()==2,"One shared key opens both cells of one door")
	expect(game.slide(Vector2(48,48),Vector2(-1000,0),10).x>=42,"Large movement cannot tunnel through dungeon walls")
	game.heroes[2].hp = 0
	game.heroes[1].pos = game.heroes[2].pos+Vector2(20,0)
	tick(2.6)
	expect(game.heroes[2].hp>0,"A nearby ally revives a fallen hero")
	game.heroes[2].hp = 0
	game.heroes[1].pos = Vector2(80,80)
	game.heroes[2].pos = Vector2(800,550)
	tick(0.5)
	expect(game.heroes[2].hp==0,"Distant allies do not revive a hero")
	game.heroes[2].hp = 400
	game.heroes[1].hp = 400
	game.pickups = [{"pos":game.heroes[1].pos,"kind":"food"}]
	game.collect(game.heroes[1])
	expect(game.heroes[1].hp==620 and game.heroes[2].hp==620,"One feast heals the whole living party")
	game.enemies.clear()
	game.shots.clear()
	game.heroes[1].pos = Vector2(200,400)
	game.heroes[2].pos = Vector2(240,400)
	game.heroes[1].face = Vector2.RIGHT
	var health: float = game.heroes[2].hp
	game.fire(game.heroes[1]); game.update_shots(0.2)
	expect(game.heroes[2].hp==health,"Friendly projectiles cannot hurt another player")
	game.enemies = [{"id":1,"pos":Vector2(270,400),"hp":20.0,"kind":"grunt","attack":1.0}]
	game.shots.clear(); game.fire(game.heroes[1]); game.update_shots(0.2)
	expect(game.enemies[0].hp<=0,"A fired projectile hits an enemy along its swept path")
	game.enemies.clear()
	game.heroes[1].pos = game.generators[0].pos+Vector2(50,0)
	game.heroes[1].hero_class = 2
	game.heroes[1].potions = 1
	game.cast_magic(1)
	expect(game.generators[0].hp==0 and game.heroes[1].potions==0,"Wizard magic destroys a nearby generator and consumes a potion")
	var destroyed: int = game.destroyed()
	game.cast_magic(1)
	expect(game.destroyed()==destroyed,"An empty potion inventory cannot cast again")
	game.phase = "paused"
	var before: float = game.elapsed
	tick(2)
	expect(game.elapsed==before,"Pause stops health drain, enemies, projectiles and timer")
	game.phase = "playing"
	for hero: Dictionary in game.heroes.values(): hero.hp=0
	game.check_finish(0.1)
	expect(game.phase=="defeat","A fallen party reaches a retry screen")
	game.reset_level()
	expect(game.phase=="lobby" and game.destroyed()==0 and game.doors.size()==4 and game.heroes.size()==16,"Retry rebuilds the dungeon and retains connected heroes")
	# The actual fleet adapter supplies independent Wii joins, orientation and buttons.
	clear_players()
	var fleet := Fleet.new()
	fleet.service = service
	fleet.motion = root.get_node("Platform").motion
	for slot in 16:
		fleet.accept_packet(slot,{"generation":"test-%d"%slot,"buttons":0,"updated":100.0},100.0)
		fleet.accept_packet(slot,{"generation":"test-%d"%slot,"buttons":1,"updated":100.0},100.0)
	expect(game.heroes.size()==16,"Sixteen synthetic native Wii channels join the dungeon")
	tick(0.1)
	expect(game.phase=="lobby","Holding native Wii 2 to join does not auto-start")
	fleet.accept_packet(0,{"generation":"test-0","buttons":0,"updated":100.05},100.05)
	tick(0.1)
	fleet.accept_packet(0,{"generation":"test-0","buttons":1,"updated":100.06},100.06)
	tick(0.1)
	expect(game.phase=="playing","Releasing and pressing native Wii 2 starts the real scene")
	var p1: Vector2 = game.heroes[1].pos
	fleet.accept_packet(0,{"generation":"test-0","buttons":0x401,"updated":100.1},100.1)
	tick(0.2)
	expect(game.heroes[1].pos.x>p1.x,"Sideways Wii D-pad maps to dungeon movement")
	expect(game.heroes[1].cooldown>0,"Held Wii 2 fires through the native adapter")
	fleet.accept_packet(0,null,103.0)
	expect(game.heroes.size()==15 and not game.heroes.has(1),"Stale native Wii channel removes only that hero")
	fleet._exit_tree()
	fleet.free()
	clear_players()
	# Full single-player route uses real movement/fire actions and intact level content.
	join(0)
	game.start()
	var completed := play_level()
	expect(completed,"One hero can play from entrance through all generators, keys, doors and exit")
	expect(game.destroyed()==4 and game.doors.is_empty() and game.phase=="complete","Full route clears every objective without skipping locks")
	print("Solo route: %d health, %d monsters, %.1f seconds." % [game.heroes[1].hp,game.kills,game.elapsed])
	clear_players()
	for device in 16: join(device)
	bot_count = 16
	game.start()
	expect(play_level(),"Sixteen heroes traverse the complete dungeon using isolated movement and fire actions")
	expect(game.escaped_count()==16 and game.phase=="complete","The full party individually escapes and completes the level")
	clear_players(); join(0)
	bot_count = 1
	# The exit is always usable; generators are optional bonus objectives.
	game.reset_level(); join(1); game.start()
	game.heroes[1].pos = Level.EXIT
	game.heroes[2].pos = Level.EXIT-Vector2(200,0)
	game.check_finish(0.1)
	expect(game.heroes[1].escaped and game.destroyed()==0,"Entering the portal escapes immediately without a generator checklist")
	expect(game.phase=="playing" and game.escaped_count()==1,"The first escape waits for the other connected hero")
	var escaped_health: float = game.heroes[1].hp
	stick(0,Vector2.LEFT); tick(1); stick(0,Vector2.ZERO)
	expect(game.heroes[1].pos==Level.EXIT and game.heroes[1].hp==escaped_health,"Escaped heroes cannot move, drain health or be attacked")
	game.heroes[2].pos = Level.EXIT
	game.check_finish(0.1)
	expect(game.phase=="complete" and game.escaped_count()==2,"The last hero entering the portal wins the game")
	var complete_score: int = game.score
	game.check_finish(1)
	expect(game.score==complete_score,"Completion cannot award the escape bonus twice")
	game._process(2)
	expect(game.return_countdown==4,"Victory advances the return-to-library countdown")
	game.reset_level(); game.start()
	game.heroes[1].pos = Level.EXIT
	game.heroes[2].hp = 0
	game.check_finish(0.1)
	expect(not game.heroes[1].escaped and game.phase=="playing","The last rescuer cannot leave a fallen teammate stranded")
	game.heroes[2].hp = 500
	game.check_finish(0.1)
	service.device_connection_changed(1,false)
	game.check_finish(0.1)
	expect(game.phase=="complete","A disconnected teammate cannot leave a phantom exit requirement")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			game.reset_level()
			for device in range(1,16): join(device)
			if "--lobby" not in OS.get_cmdline_user_args(): game.start()
			game.message_time = 0
			tick(3)
			game.board.queue_redraw()
			await process_frame
			if "--stress" in OS.get_cmdline_user_args():
				game.enemies.clear()
				for n in 96:
					game.enemies.append({"id":2000+n,"pos":Level.center(Vector2i(14+n%11,2+(n/11))),"hp":52.0,"kind":["ghost","grunt","demon"][n%3],"attack":1.0})
				var started := Time.get_ticks_msec()
				for frame in 120:
					game.clock += 1.0/60
					await process_frame
				print("Rendered stress: 16 heroes + 96 monsters, 120 frames in %d ms." % (Time.get_ticks_msec()-started))
			# A focus change during the stress wait must not make the capture inconsistent.
			game.phase = "lobby" if "--lobby" in OS.get_cmdline_user_args() else "playing"
			game.board._process(0)
			game.board.queue_redraw()
			await RenderingServer.frame_post_draw
			expect(root.get_texture().get_image().save_png(argument.trim_prefix("--capture="))==OK,"Sixteen-player render saved")
	if not failures: print("Gauntlet checks passed: %d gameplay/input assertions; synthetic controllers." % checks)
	quit(1 if failures else 0)

func route(target: Vector2) -> Array:
	var from := Level.cell(game.heroes[1].pos)
	var to := Level.cell(target)
	var queue: Array[Vector2i] = [from]
	var previous := {from:from}
	var cursor := 0
	while cursor<queue.size() and not previous.has(to):
		var cell := queue[cursor]; cursor += 1
		for direction: Vector2i in game.DIRECTIONS:
			var next := cell+direction
			if next.x<=0 or next.y<=0 or next.x>=39 or next.y>=19 or game.walls.has(next) or previous.has(next): continue
			if game.doors.has(next) and game.keys==0: continue
			previous[next] = cell
			queue.append(next)
	if not previous.has(to): return []
	var path: Array = [target]
	var cell := to
	while cell!=from:
		path.push_front(Level.center(cell))
		cell = previous[cell]
	# Center on the current tile before turning in tight corridors.
	path.push_front(Level.center(from))
	return path

func walk_to(target: Vector2) -> bool:
	var path := route(target)
	if path.is_empty(): return false
	for device in bot_count: button(device,JOY_BUTTON_A,true)
	for waypoint: Vector2 in path:
		var frames := 0
		while not party_at(waypoint) and frames<360:
			for device in bot_count:
				var difference: Vector2 = waypoint-game.heroes[device+1].pos
				stick(device,difference.normalized() if difference.length()>3 else Vector2.ZERO)
			game.step(1.0/60)
			frames += 1
			if game.phase=="complete": return true
			if game.phase!="playing": return false
		if frames>=360:
			print("Route blocked: ",game.heroes[1].pos," -> ",waypoint)
			return false
	for device in bot_count:
		stick(device,Vector2.ZERO)
		button(device,JOY_BUTTON_A,false)
	return true

func attack_generator(index: int, from: Vector2) -> bool:
	if not walk_to(from): return false
	var target: Dictionary = game.generators[index]
	for device in bot_count: stick(device,(target.pos-game.heroes[device+1].pos).normalized())
	game.step(1.0/60)
	for device in bot_count:
		stick(device,Vector2.ZERO)
		button(device,JOY_BUTTON_A,true)
	var frames := 0
	while target.hp>0 and frames<1800 and game.phase=="playing":
		game.step(1.0/60)
		frames += 1
	for device in bot_count: button(device,JOY_BUTTON_A,false)
	return target.hp<=0

func play_level() -> bool:
	if not attack_generator(0,Level.center(Vector2i(9,2))): return false
	if not walk_to(Level.center(Vector2i(9,13))): return false
	if not walk_to(Level.center(Vector2i(14,14))): return false
	if not attack_generator(1,Level.center(Vector2i(16,16))): return false
	if not walk_to(Level.center(Vector2i(20,8))): return false
	if not attack_generator(2,Level.center(Vector2i(22,7))): return false
	if not walk_to(Level.center(Vector2i(24,2))): return false
	if not walk_to(Level.center(Vector2i(28,5))): return false
	if not attack_generator(3,Level.center(Vector2i(34,7))): return false
	if not walk_to(Level.EXIT): return false
	tick(1.6)
	return game.phase=="complete"

func party_at(at: Vector2) -> bool:
	for device in bot_count:
		if not game.heroes[device+1].escaped and game.heroes[device+1].pos.distance_to(at)>3: return false
	return true
