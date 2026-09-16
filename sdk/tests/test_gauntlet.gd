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
	game.sync_display()
	game.dungeon_view._process(0)
	var actor: Node3D = game.dungeon_view.actors["hero-1"]
	expect(actor.skeleton.get_bone_count()>50 and actor.animator.has_animation("walk"),"Textured heroes have an imported skeleton and movement animation")
	for female in [false,true]:
		var face_mesh: ArrayMesh = preload("res://examples/gauntlet/hero_actor.gd").make_head(female)
		var textured := face_mesh.get_surface_count()>0
		for surface in face_mesh.get_surface_count():
			textured = textured and face_mesh.surface_get_material(surface).albedo_texture!=null
		expect(textured,"Imported head, eyes and brows retain their texture maps")
	check_animation_layers()
	check_wizard_robe()
	var saved_positions := {}
	for id: int in game.heroes:
		saved_positions[id] = game.heroes[id].pos
		game.heroes[id].pos = Vector2(48+(id%4)*384,48+((id-1)/4)*176)
	game.dungeon_view.update_camera(1.0)
	var visible_area := Rect2(Vector2.ZERO,Vector2(game.dungeon_view.get_viewport().size))
	var all_visible := true
	for id: int in game.heroes:
		for height in [0.0,2.4]:
			var projected: Vector2 = game.dungeon_view.camera.unproject_position(game.dungeon_view.at3(game.heroes[id].pos,height))
			all_visible = all_visible and visible_area.has_point(projected)
		game.heroes[id].pos = saved_positions[id]
	expect(all_visible,"Shared camera keeps feet and labels visible when sixteen players spread across the map")
	game.dungeon_view.update_camera(1.0)
	expect(game.dungeon_view.camera.size>=14.0,"A gathered party retains a broad view of the dungeon")
	# Exercise one normal frame, not a settled camera: a distant fallen hero must stay visible.
	game.heroes[16].pos = Vector2(1232,48)
	var saved_health: float = game.heroes[16].hp
	game.heroes[16].hp = 0
	game.dungeon_view.update_camera(1.0/60)
	var immediate_fit := true
	for hero: Dictionary in game.heroes.values():
		for height in [0.0,2.4]:
			immediate_fit = immediate_fit and visible_area.has_point(game.dungeon_view.camera.unproject_position(game.dungeon_view.at3(hero.pos,height)))
	expect(immediate_fit,"Immediate expansion keeps both distant fallen teammates and the moving party visible")
	expect(game.heroes[16].pos==Vector2(1232,48) and game.heroes[1].pos==saved_positions[1],"Camera framing never moves or tethers a player")
	game.heroes[16].hp = saved_health
	game.heroes[16].pos = saved_positions[16]
	var map_key := InputEventKey.new()
	map_key.keycode = KEY_F3
	map_key.pressed = true
	game._unhandled_key_input(map_key)
	var map_visible: bool = game.dungeon_view.overview
	for corner in [Vector2.ZERO,Vector2(1280,0),Vector2(0,640),Vector2(1280,640)]:
		for height in [0.0,2.4]:
			map_visible = map_visible and visible_area.has_point(game.dungeon_view.camera.unproject_position(game.dungeon_view.at3(corner,height)))
	expect(map_visible,"F3 frames the entire dungeon, including raised objects at every map edge")
	game._unhandled_key_input(map_key)
	expect(not game.dungeon_view.overview,"F3 returns to automatic party framing")
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
	expect(game.phase=="lobby" and game.ready_players.get(1,false),"A quick confirm readies only its player without starting")
	button(0,JOY_BUTTON_A,true); button(0,JOY_BUTTON_A,false); tick(0.02)
	expect(game.ready_players.get(1,false),"Confirm while waiting for teammates keeps an already-ready player ready")
	game.request_start()
	expect(game.phase=="lobby","The party cannot start until every joined hero is ready")
	for id: int in game.heroes:
		if not game.ready_players.get(id,false): game.toggle_ready(id)
	button(0,JOY_BUTTON_A,true); button(0,JOY_BUTTON_A,false); tick(0.02)
	expect(game.phase=="playing","A separate controller confirm enters the vault after everyone is ready")
	game.phase = "paused"
	button(0,JOY_BUTTON_A,true); button(0,JOY_BUTTON_A,false); tick(0.1)
	expect(game.phase=="playing","The same confirm button resumes from focus pause")
	game.reset_level()
	button(0,JOY_BUTTON_X,true); tick(0.1); button(0,JOY_BUTTON_X,false)
	expect(game.heroes[1].hero_class==1 and game.heroes[2].hero_class==1,"Class selection changes only its owner")
	for id: int in game.heroes: game.toggle_ready(id)
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
	game.keyring = {"sapphire":1}
	var wrong_key: Vector2 = game.slide(game.heroes[2].pos,Vector2(64,0),10,true)
	expect(wrong_key.x<384 and game.keyring.sapphire==1 and game.doors.size()==4,"Sapphire key cannot open the first Ruby gate and is not consumed")
	game.keyring = {"ruby":1}
	var opened: Vector2 = game.slide(game.heroes[2].pos,Vector2(64,0),10,true)
	expect(opened.x>416 and game.keys==0 and game.doors.size()==2,"One shared key opens both cells of one door")
	game.keys = 1
	game.keyring = {"ruby":1}
	game.unlock(1)
	expect(game.doors.size()==2 and game.keys==1 and game.keyring.ruby==1,"Ruby key cannot open the second Sapphire gate")
	game.keys = 0
	game.keyring.clear()
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
	game.heroes[1].hero_class = 2
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
	expect(game.generators[0].hp>0,"Casting does not damage a generator before the wave arrives")
	game.update_sparks(0.17)
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
	check_lobby_and_menu()
	check_player_colors()
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
	expect(game.phase=="lobby" and game.ready_players.get(1,false),"Releasing and pressing native Wii 2 readies its hero")
	for slot in range(1,16):
		fleet.accept_packet(slot,{"generation":"test-%d"%slot,"buttons":0,"updated":100.07},100.07)
		tick(0.02)
		fleet.accept_packet(slot,{"generation":"test-%d"%slot,"buttons":1,"updated":100.08},100.08)
		tick(0.02)
	expect(game.all_ready() and game.phase=="lobby","Sixteen native Wii players ready using only physical button packets; last ready does not auto-start")
	fleet.accept_packet(0,{"generation":"test-0","buttons":0,"updated":100.09},100.09)
	tick(0.02)
	fleet.accept_packet(0,{"generation":"test-0","buttons":1,"updated":100.10},100.10)
	tick(0.02)
	expect(game.phase=="playing","Wii 2 enters the vault after everyone readies, without keyboard or direct start calls")
	var p1: Vector2 = game.heroes[1].pos
	expect(game.heroes[1].attack_serial==0,"Held lobby confirm does not leak into a combat attack")
	fleet.accept_packet(0,{"generation":"test-0","buttons":0,"updated":100.1},100.1)
	tick(0.02)
	fleet.accept_packet(0,{"generation":"test-0","buttons":0x401,"updated":100.1},100.1)
	tick(0.2)
	expect(game.heroes[1].pos.x>p1.x,"Sideways Wii D-pad maps to dungeon movement")
	expect(game.heroes[1].cooldown>0,"Held Wii 2 fires through the native adapter")
	fleet.accept_packet(0,{"generation":"test-0","buttons":0x1000,"updated":100.2},100.2)
	tick(0.02)
	expect(game.phase=="paused","Native Wii Plus opens the game menu")
	fleet.accept_packet(0,{"generation":"test-0","buttons":0x100,"updated":100.3},100.3)
	tick(0.02)
	expect(game.menu_index==1,"Sideways Wii D-pad selects a menu option")
	var camera_before: bool = game.dungeon_view.overview
	fleet.accept_packet(0,{"generation":"test-0","buttons":1,"updated":100.4},100.4)
	tick(0.02)
	expect(game.dungeon_view.overview!=camera_before and game.phase=="paused","Wii 2 activates the selected menu option")
	game.dungeon_view.toggle_overview()
	fleet.accept_packet(0,{"generation":"test-0","buttons":0x10,"updated":100.5},100.5)
	tick(0.02)
	expect(game.phase=="playing","Tapping Wii Minus backs out of the menu without leaving the party")
	fleet.accept_packet(0,null,103.0)
	expect(game.heroes.size()==15 and not game.heroes.has(1),"Stale native Wii channel removes only that hero")
	fleet._exit_tree()
	fleet.free()
	clear_players()
	check_class_attacks()
	check_damage_feedback()
	check_potion_wave()
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
			var capture_players := 16
			for option in OS.get_cmdline_user_args():
				if option.begins_with("--players="): capture_players = clampi(int(option.trim_prefix("--players=")),1,16)
			if "--stress" in OS.get_cmdline_user_args(): capture_players = 16
			for device in range(1,capture_players): join(device)
			if "--performance" in OS.get_cmdline_user_args(): game.dungeon_view.toggle_quality()
			if "--lobby" not in OS.get_cmdline_user_args(): game.start()
			game.message_time = 0
			tick(3)
			game.board.queue_redraw()
			# Give imported skeletons and animation blending time to reach their idle pose.
			for frame in 12: await process_frame
			if "--stress" in OS.get_cmdline_user_args():
				for id: int in game.heroes:
					game.heroes[id].pos = Vector2(96+((id-1)%4)*320,80+((id-1)/4)*160)
				game.dungeon_view.update_camera(1.0)
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
			expect(root.get_texture().get_image().save_png(argument.trim_prefix("--capture="))==OK,"Game view rendered and saved")
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
			if game.doors.has(next) and int(game.keyring.get(game.map.door_colors[game.doors[next]],0))==0: continue
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
	for device in bot_count: button(device,JOY_BUTTON_A,false)
	game.step(1.0/60)
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
	var target: Dictionary = game.generators[index]
	var approach: Vector2 = target.pos+(from-target.pos).normalized()*40
	if not walk_to(approach): return false
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

func check_animation_layers() -> void:
	for kind in 4:
		var fighter: Node3D = game.dungeon_view.hero_model(kind)
		var walker: Node3D = game.dungeon_view.hero_model(kind)
		game.dungeon_view.add_child(fighter)
		game.dungeon_view.add_child(walker)
		var hero: Dictionary = game.make_hero(1,kind)
		var other: Dictionary = hero.duplicate(true)
		var leg: int = fighter.skeleton.find_bone("thigh_l")
		var arm: int = fighter.skeleton.find_bone("upperarm_l" if kind==2 else "upperarm_r")
		var before: Quaternion = fighter.skeleton.get_bone_pose_rotation(leg)
		for frame in 30:
			hero.pos += Vector2(2,0)
			other.pos = hero.pos
			if frame==24: hero.attack_serial += 1
			fighter.present(hero,1.0/60,true)
			walker.present(other,1.0/60,true)
		expect(not before.is_equal_approx(fighter.skeleton.get_bone_pose_rotation(leg)),"Class %d has a moving stride through the live blend tree"%kind)
		expect(fighter.skeleton.get_bone_pose_rotation(leg).is_equal_approx(walker.skeleton.get_bone_pose_rotation(leg)),"Class %d keeps exactly the same leg stride while firing"%kind)
		expect(not fighter.skeleton.get_bone_pose_rotation(arm).is_equal_approx(walker.skeleton.get_bone_pose_rotation(arm)),"Class %d layers its own attack over the walking pose"%kind)
		if kind==2:
			var staff_arm: int = fighter.skeleton.find_bone("upperarm_r")
			expect(fighter.skeleton.get_bone_pose_rotation(staff_arm).is_equal_approx(walker.skeleton.get_bone_pose_rotation(staff_arm)),"Wizard keeps the staff arm steady while the free hand casts")
		var paused: Quaternion = fighter.skeleton.get_bone_pose_rotation(leg)
		fighter.present(hero,0.5,false)
		expect(paused.is_equal_approx(fighter.skeleton.get_bone_pose_rotation(leg)),"Pausing freezes class %d animation"%kind)
		for frame in 60: fighter.present(hero,1.0/60,true)
		expect(fighter.motion.speed<0.01,"Class %d eases back to idle when movement stops or is blocked"%kind)
		hero.hit_serial += 1
		fighter.present(hero,0.08,true)
		expect(fighter.motion.tree.get("parameters/hit/active"),"Class %d reacts to an actual damage event"%kind)
		hero.magic_serial += 1
		fighter.present(hero,0.08,true)
		expect(fighter.motion.tree.get("parameters/spell/active"),"Class %d presents potion casting independently of weapon fire"%kind)
		hero.hp = 0
		fighter.present(hero,0.1,true)
		expect(fighter.fall>0 and fighter.fall<1 and fighter.rotation.z==0,"Knockdown blends the body while keeping player labels upright")
		hero.hp = 500
		fighter.present(hero,0.5,true)
		expect(fighter.fall==0,"A revived hero recovers to an upright stance")
		fighter.free()
		walker.free()

func check_wizard_robe() -> void:
	var wizard: Node3D = game.dungeon_view.hero_model(2)
	game.dungeon_view.add_child(wizard)
	var hero: Dictionary = game.make_hero(1,2)
	wizard.present(hero)
	var cloth: ShaderMaterial = wizard.robe_skirt.get_node("LongRobe").mesh.surface_get_material(0)
	var trim: ShaderMaterial = wizard.robe_skirt.get_node("RobeTrim").mesh.surface_get_material(0)
	for direction: Vector2 in [Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP]:
		hero.face = direction
		for frame in 45:
			hero.pos += direction*1.75
			wizard.present(hero,1.0/60,true)
		var world_trail: Vector3 = wizard.outfit.basis*Vector3(cloth.get_shader_parameter("trail"))
		expect(world_trail.dot(Vector3(direction.x,0,direction.y))<-0.20,"Wizard robe trails behind movement in direction %s"%direction)
		expect(trim.get_shader_parameter("trail")==cloth.get_shader_parameter("trail"),"Robe trim follows the same cloth drag")
	expect(wizard.robe_skirt.basis.is_equal_approx(Basis.IDENTITY),"Walking hip rotation cannot pitch the robe forward")
	var paused: Vector3 = cloth.get_shader_parameter("trail")
	wizard.present(hero,0.5,false)
	expect(paused==cloth.get_shader_parameter("trail"),"Pause preserves robe drag")
	for frame in 90: wizard.present(hero,1.0/60,true)
	expect(Vector3(cloth.get_shader_parameter("trail")).length()<0.001,"Robe settles when the wizard stops or walks into a wall")
	wizard.free()

func check_lobby_and_menu() -> void:
	game.reset_level()
	game.toggle_ready(1)
	game.cycle_class(1)
	expect(not game.ready_players[1],"Changing a class revokes readiness so choices cannot change under a ready party")
	for id: int in game.heroes: game.ready_players[id] = true
	service.device_connection_changed(20,false)
	expect(game.all_ready() and not game.ready_players.has(1),"Disconnect removes its readiness requirement")
	join(21)
	expect(not game.all_ready() and not game.ready_players.get(1,false),"Rejoining starts unready with no stale confirmation")
	game.sync_display()
	game.board._process(0)
	expect(game.board.start_button.visible and game.board.start_button.disabled,"Lobby start visibly waits for unready players")
	game.toggle_ready(1)
	game.board.start_button.pressed.emit()
	expect(game.phase=="playing","Mouse start uses the same all-ready gate")
	game.board._process(0)
	var hidden := true
	for controls: Array in game.board.slot_buttons:
		for control: Button in controls: hidden = hidden and not control.visible
	expect(hidden and not game.board.portraits[0].visible,"Lobby slots and portraits are absent from gameplay")
	expect(game.display.position.y==88 and game.display.size.y>632,"Expanded game viewport begins below the minimap and reclaims slot space")
	var pause := InputEventKey.new()
	pause.pressed = true
	pause.keycode = KEY_ESCAPE
	game._unhandled_key_input(pause)
	expect(game.phase=="paused" and game.menu_index==0,"Escape opens a safe pause menu instead of quitting")
	var elapsed_before: float = game.elapsed
	var health_before: float = game.heroes[1].hp
	tick(0.2)
	expect(game.elapsed==elapsed_before and game.heroes[1].hp==health_before,"Pause menu stops time and health drain")
	stick(1,Vector2.DOWN); tick(0.02); stick(1,Vector2.ZERO); tick(0.02)
	expect(game.menu_index==1,"Controller stick navigates pause options")
	var old_overview: bool = game.dungeon_view.overview
	button(1,JOY_BUTTON_A,true); button(1,JOY_BUTTON_A,false); tick(0.02)
	expect(game.dungeon_view.overview!=old_overview and game.phase=="paused","Controller confirm changes the selected option without resuming")
	game.dungeon_view.toggle_overview()
	var minimap: bool = game.show_minimap
	game.activate_menu(2)
	expect(game.show_minimap!=minimap,"Minimap can be hidden from the menu")
	game.activate_menu(2)
	game.activate_menu(5)
	expect(game.help and game.phase=="paused","Controls guide stays inside the paused game")
	game._unhandled_key_input(pause)
	expect(not game.help and game.phase=="paused","Escape closes help back to the menu")
	game.activate_menu(7)
	expect(game.confirm_leave=="library" and game.menu_index==0,"Leaving a live run defaults to keeping progress")
	game._unhandled_key_input(pause)
	expect(game.confirm_leave.is_empty() and game.phase=="paused","Exit confirmation can be cancelled without ending the run")
	game.activate_menu(6)
	game.activate_menu(1)
	expect(game.phase=="lobby" and game.heroes.size()==16 and game.ready_players.is_empty(),"Return to lobby resets the run and retains all connected heroes for fresh choices")

	stick(1,Vector2.DOWN); tick(0.02); stick(1,Vector2.ZERO); tick(0.02)
	expect(game.lobby_focus.get(2,-1)==3,"D-pad down selects Enter the vault without changing another player's selection")
	stick(1,Vector2.LEFT); tick(0.02); stick(1,Vector2.ZERO); tick(0.02)
	expect(game.lobby_focus[2]==2,"Fullscreen is reachable from the controller lobby row")
	stick(1,Vector2.LEFT); tick(0.02); stick(1,Vector2.ZERO); tick(0.02)
	button(1,JOY_BUTTON_A,true); button(1,JOY_BUTTON_A,false); tick(0.02)
	expect(game.help and not game.ready_players.get(2,false),"Controller opens lobby controls without changing readiness")
	button(1,JOY_BUTTON_A,true); button(1,JOY_BUTTON_A,false); tick(0.02)
	expect(not game.help and game.phase=="lobby","Controller confirm closes lobby help")
	stick(1,Vector2.LEFT); tick(0.02); stick(1,Vector2.ZERO); tick(0.02)
	expect(game.lobby_focus[2]==0,"Game library button is reachable with the controller")
	button(1,JOY_BUTTON_B,true); tick(0.02); button(1,JOY_BUTTON_B,false); tick(0.02)
	expect(not game.lobby_focus.has(2),"Back returns from lobby buttons to the player's hero card")

	clear_players()
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	service.keyboard_enabled = true
	service.handle_event(enter)
	game._unhandled_key_input(enter)
	var keyboard_id: int = service.player_for_device(service.KEYBOARD_DEVICE)
	expect(keyboard_id!=0 and not game.ready_players.get(keyboard_id,false),"Keyboard Enter joins without simultaneously readying")
	tick(0.02)
	enter.pressed = false
	service.handle_event(enter)
	enter.pressed = true
	service.handle_event(enter)
	game._unhandled_key_input(enter)
	expect(game.all_ready() and game.phase=="lobby","A second keyboard Enter readies without starting, including quick taps")
	var start_key := InputEventKey.new()
	start_key.keycode = KEY_P
	start_key.pressed = true
	game._unhandled_key_input(start_key)
	expect(game.phase=="playing","Keyboard P starts a ready party")
	game.toggle_pause()
	var down := InputEventKey.new()
	down.keycode = KEY_DOWN
	down.pressed = true
	service.handle_event(down)
	game._unhandled_key_input(down)
	tick(0.02)
	expect(game.menu_index==1,"Keyboard menu navigation does not double-count service and key events")
	clear_players()
	join(0)
	game.start()
	game.toggle_pause()
	game.sync_display()
	service.handle_event(enter)
	game._unhandled_key_input(enter)
	expect(game.heroes.size()==1 and game.phase=="playing","Keyboard can resume a controller party without joining an unwanted hero")
	clear_players()

func check_damage_feedback() -> void:
	game.reset_level()
	join(0)
	for choice in 3: game.cycle_class(1)
	game.start()
	var hero: Dictionary = game.heroes[1]
	hero.pos = Vector2(200,400)
	hero.face = Vector2.RIGHT
	game.enemies = [{"id":9001,"pos":Vector2(270,400),"kind":"ghost","hp":34.0,"max_hp":34.0,"attack":1.0},
		{"id":9002,"pos":Vector2(320,460),"kind":"ghost","hp":34.0,"max_hp":34.0,"attack":1.0}]
	game.dungeon_view._process(0)
	var target: Node3D = game.dungeon_view.actors["enemy-9001"]
	var feedback: Node3D = target.get_node("DamageFeedback")
	var neighbor: Node3D = game.dungeon_view.actors["enemy-9002"].get_node("DamageFeedback")
	expect(feedback.bar==null and neighbor.bar==null,"Untouched enemies have no health-bar geometry or hit overlay")
	game.fire(hero)
	game.update_shots(0.2)
	expect(game.enemies[0].hp==16 and game.enemies[0].max_hp==34,"An Elf arrow damages a ghost without losing its original maximum health")
	game.dungeon_view._process(0)
	expect(feedback.flashing and feedback.bar.visible,"A nonlethal arrow visibly flashes its target and reveals its health bar")
	expect(is_equal_approx(float(feedback.bar_material.get_shader_parameter("health")),16.0/34.0),"Ghost health bar shows the actual remaining fraction after one arrow")
	expect(not neighbor.flashing and neighbor.bar==null,"Hit effects remain local rather than coloring every shared ghost mesh")
	var location: Vector2 = game.enemies[0].pos
	game.elapsed += 0.06
	game.dungeon_view._process(0.06)
	expect(target.scale!=Vector3.ONE and game.enemies[0].pos==location,"Brief flinch changes presentation without knockback or hitbox movement")
	game.hurt(hero,30)
	var serial: int = hero.hit_serial
	game.hurt(hero,30)
	game.dungeon_view._process(0.06)
	expect(hero.hit_serial==serial and game.dungeon_view.actors["hero-1"].damage_feedback.flashing,"Real hero damage flashes once; invulnerability does not retrigger it")
	game.phase = "paused"
	var frozen: float = game.elapsed
	tick(1)
	game.dungeon_view._process(0.1)
	expect(game.elapsed==frozen and feedback.flashing,"Hit-feedback timing freezes with the paused game")
	game.phase = "playing"
	game.elapsed = 1.3
	game.dungeon_view._process(0)
	var fade: float = feedback.bar_material.get_shader_parameter("fade")
	expect(not feedback.flashing and feedback.bar.visible and fade>0 and fade<1,"Flash ends quickly and the recent-health bar fades afterward")
	game.elapsed = 1.6
	game.dungeon_view._process(0)
	expect(not feedback.bar.visible and feedback.meshes[0].material_overlay==null,"Idle enemies return to uncluttered rendering after the hit feedback expires")
	game.damage_enemy(game.enemies[0],1)
	game.dungeon_view._process(0)
	expect(feedback.bar.visible and game.enemies[0].max_hp==34,"A later hit refreshes the temporary bar without changing its denominator")
	game.fire(hero); game.update_shots(0.2); game.update_enemies(0)
	game.dungeon_view._process(0)
	expect(not game.dungeon_view.actors.has("enemy-9001"),"A lethal arrow removes the ghost and its temporary bar")
	game.cast_magic(1)
	game.update_sparks(Level.MAGIC_DURATION)
	expect(game.enemies[0].get("hit_serial",0)==1,"Area magic uses the same enemy damage feedback path")
	clear_players()

func check_potion_wave() -> void:
	clear_players(); join(0)
	for kind in 4:
		game.reset_level()
		game.phase = "playing"
		var hero: Dictionary = game.heroes[1]
		hero.hero_class = kind
		hero.pos = Vector2(400,400)
		game.generators = [{"pos":Vector2(550,400),"hp":1000.0,"clock":100.0,"kind":"ghost"}]
		game.enemies = []
		for distance in [50,150,201]:
			game.enemies.append({"id":distance,"pos":hero.pos+Vector2(distance,0),"hp":1000.0,"kind":"ghost","attack":1.0})
		var health: float = hero.hp
		game.cast_magic(1)
		var wave: Dictionary = game.sparks.back()
		var damage: float = Level.CLASSES[kind].magic
		expect(game.enemies[0].hp==1000 and hero.potions==1,"Class %d consumes potion immediately but waits for wave contact"%kind)
		hero.pos += Vector2(0,300)
		game.update_sparks(0.15)
		expect(game.enemies[0].hp==1000 and wave.pos==Vector2(400,400),"Wave stays at its cast origin and does not hit early")
		game.update_sparks(0.02)
		expect(game.enemies[0].hp==1000-damage and game.enemies[1].hp==1000 and game.generators[0].hp==1000,"Only targets reached by the blast take the class's potion damage")
		game.dungeon_view._process(0)
		var visual: MeshInstance3D = game.dungeon_view.effects[0]
		expect(is_equal_approx(visual.scale.x*32.0,Level.magic_radius(wave.life)),"Rendered potion radius equals the damage radius")
		game.phase = "paused"
		var life: float = wave.life
		tick(0.1)
		expect(wave.life==life and game.enemies[1].hp==1000,"Pausing freezes both the blast and pending damage")
		game.phase = "playing"
		game.update_sparks(0.31)
		expect(game.enemies[1].hp==1000 and game.generators[0].hp==1000,"Distant targets survive until the blast reaches them")
		game.update_sparks(0.02)
		expect(game.enemies[1].hp==1000-damage and game.generators[0].hp==1000-damage,"Distant enemies and generators are hit on wave arrival")
		game.update_sparks(0.5)
		expect(game.enemies[0].hp==1000-damage and game.enemies[1].hp==1000-damage and game.enemies[2].hp==1000 and hero.hp==health,"Each target is hit once; outside targets and players are safe even on a long frame")
		expect(game.sparks.filter(func(s): return s.kind=="magic").is_empty(),"Finished potion waves expire")
	# Independent overlapping casts can each hit, without reapplying either wave every frame.
	game.heroes[1].pos = Vector2(400,400)
	game.heroes[1].potions = 2
	game.enemies[0].hp = 1000
	game.cast_magic(1); game.cast_magic(1)
	game.update_sparks(0.2)
	expect(game.enemies[0].hp==760,"Two overlapping Elf potions each apply their damage once")
	game.reset_level()
	expect(game.sparks.is_empty(),"Returning to the lobby clears pending potion damage")
	clear_players()

func check_class_attacks() -> void:
	clear_players(); join(0)
	game.start()
	tick(0.02)
	var hero: Dictionary = game.heroes[1]
	hero.pos = Vector2(200,400)
	hero.face = Vector2.RIGHT
	game.enemies = [{"id":9101,"pos":Vector2(240,400),"kind":"grunt","hp":200.0,"attack":1.0},
		{"id":9102,"pos":Vector2(160,400),"kind":"grunt","hp":200.0,"attack":1.0},
		{"id":9103,"pos":Vector2(300,400),"kind":"grunt","hp":200.0,"attack":1.0}]
	game.fire(hero)
	expect(game.shots.is_empty() and game.melee_swings.size()==1,"Warrior starts an axe swing without spawning a projectile")
	game.update_melee()
	expect(game.enemies[0].hp==200,"Heavy axe has a short windup before impact")
	game.elapsed += 0.15
	game.update_melee()
	expect(game.enemies[0].hp==118 and game.enemies[1].hp==200 and game.enemies[2].hp==200,"Axe deals heavy damage only to nearby enemies in front")
	game.update_melee()
	expect(game.enemies[0].hp==118,"Each swing hits each target only once")
	game.walls[Vector2i(7,12)] = true
	expect(not game.melee_reaches(Vector2(210,400),Vector2.RIGHT,Vector2(250,400),44,12),"Melee cannot hit through walls")
	game.walls.erase(Vector2i(7,12))
	hero.hero_class = 1
	game.fire(hero); game.elapsed += 0.09; game.update_melee()
	expect(game.shots.is_empty() and game.enemies[0].hp==76,"Valkyrie uses a lighter sword strike rather than a projectile")
	hero.hero_class = 3
	game.fire(hero)
	expect(game.shots.back().kind=="arrow" and game.shots.back().damage==18,"Elf fires an arrow with lighter per-hit damage")
	hero.hero_class = 2
	game.fire(hero)
	expect(game.shots.back().kind=="arcane" and game.shots.back().damage==38,"Wizard fires a magic bolt with its own damage")
	expect(Level.CLASSES[0].damage>Level.CLASSES[3].damage and Level.CLASSES[0].rate>Level.CLASSES[3].rate,"Heavy axe hits harder and less often than the rapid bow")
	game.reset_level(); game.start()
	game.enemies.clear()
	for generator: Dictionary in game.generators: generator.hp = 0
	var serial: int = game.heroes[1].attack_serial
	tick(2.6)
	expect(game.heroes[1].attack_serial==serial and game.shots.is_empty() and game.melee_swings.is_empty(),"Standing still without attack input never starts attacks")
	game.dungeon_view._process(0)
	var actor: Node3D = game.dungeon_view.actors["hero-1"]
	var arm: int = actor.skeleton.find_bone("upperarm_r")
	actor.present(game.heroes[1],0.1,true)
	var pose: Quaternion = actor.skeleton.get_bone_pose_rotation(arm)
	for frame in 180: actor.present(game.heroes[1],1.0/60,true)
	expect(pose.is_equal_approx(actor.skeleton.get_bone_pose_rotation(arm)),"Idle animation holds a quiet ready pose instead of periodic weapon gestures")
	button(0,JOY_BUTTON_A,true); button(0,JOY_BUTTON_A,false); tick(0.02)
	expect(game.heroes[1].attack_serial==serial+1,"A quick attack tap between physics frames still triggers one attack")
	button(0,JOY_BUTTON_A,true); tick(1.1)
	var attacks: int = game.heroes[1].attack_serial
	expect(attacks>0,"Fresh held attack input repeats at the class cadence")
	game.toggle_pause(); game.toggle_pause(); tick(1.1)
	expect(game.heroes[1].attack_serial==attacks,"Holding a button while resuming cannot cause unintended attacks")
	button(0,JOY_BUTTON_A,false); tick(0.02)
	button(0,JOY_BUTTON_A,true); tick(0.6)
	expect(game.heroes[1].attack_serial>attacks,"Releasing and pressing attack after resume restores combat")
	clear_players()

func check_player_colors() -> void:
	clear_players(); join(0); join(1)
	tick(0.02)
	game.toggle_ready(1)
	stick(0,Vector2.UP); tick(0.02); stick(0,Vector2.ZERO); tick(0.02)
	expect(game.color_focus.has(1),"Controller Up focuses the player's color chooser")
	stick(0,Vector2.LEFT); tick(0.02); stick(0,Vector2.ZERO); tick(0.02)
	expect(game.heroes[1].color_index==15 and not game.ready_players[1],"Color choice wraps backward and revokes readiness")
	expect(game.heroes[2].color_index==1 and game.heroes[1].hero_class==0,"Changing color affects only its player, not class or teammates")
	for choice in 6:
		stick(0,Vector2.RIGHT); tick(0.02); stick(0,Vector2.ZERO); tick(0.02)
	button(0,JOY_BUTTON_A,true); button(0,JOY_BUTTON_A,false); tick(0.02)
	expect(game.heroes[1].color_index==5 and not game.color_focus.has(1) and not game.ready_players[1],"Confirm commits the color choice before the separate ready step")
	button(0,JOY_BUTTON_X,true); tick(0.02); button(0,JOY_BUTTON_X,false); tick(0.02)
	expect(game.heroes[1].hero_class==1 and game.heroes[1].color_index==5,"Changing hero preserves the player's selected color")
	game.board._process(0)
	var portrait: Node3D = game.board.portraits[1].get_child(0).get_child(0).get_node("HeroPreview")
	expect(portrait.get_meta("color_index")==5,"Live class preview shows the most recently edited player's color")
	game.board.slot_buttons[1][3].pressed.emit()
	expect(game.heroes[2].color_index==2 and game.heroes[1].color_index==5,"Mouse color swatch changes only its corresponding player")
	game.reset_level()
	expect(game.heroes[1].color_index==5 and game.heroes[2].color_index==2,"Returning to the lobby retains each connected player's color")
	game.start()
	game.dungeon_view._process(0)
	var first: Node3D = game.dungeon_view.actors["hero-1"]
	var second: Node3D = game.dungeon_view.actors["hero-2"]
	expect(first.get_meta("color_index")==5 and second.get_meta("color_index")==2 and first.garment_color!=second.garment_color,"Same-class teammates use independent outfit colors")
	expect(first.get_node("Number").modulate.is_equal_approx(game.color_for(game.heroes[1]).lightened(0.3)),"Player labels match the selected color")
	expect(first.get_node("Halo").material_override.albedo_color.is_equal_approx(game.color_for(game.heroes[1])),"Player floor marker matches the selected color")
	var chosen: int = game.heroes[1].color_index
	game.cycle_color(1)
	expect(game.heroes[1].color_index==chosen,"Colors cannot change during active combat")
	game.cast_magic(1)
	expect(game.sparks.back().color.is_equal_approx(game.color_for(game.heroes[1])),"Player magic rings also retain player identity")
	clear_players()
	var fleet := Fleet.new()
	fleet.service = service
	fleet.motion = root.get_node("Platform").motion
	for mask in [1,0,0x200,0,0x400,0]:
		fleet.accept_packet(0,{"generation":"color-test","buttons":mask,"updated":100.0},100.0)
		tick(0.02)
	expect(game.color_focus.has(1) and game.heroes[1].color_index==1,"Sideways native Wii Up and Right select and change color through real packet mappings")
	fleet._exit_tree(); fleet.free()
	clear_players()
