extends SceneTree
var checks := 0
var failures := 0
var game: Control
func _initialize() -> void: call_deferred("run")
func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func steps(count: int, axis := 0.0, jump := false, run := false, down := false) -> void:
	for i in count: game.advance(1.0/60,axis,jump,run,down)
func reset() -> void:
	game.reset_run()
	game.enemies.clear()
	game.last_jump = false
func run() -> void:
	game = load("res://examples/world_1_1/world.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	game.sound.enabled = false
	expect(game.enemies.size()==17,"Original enemy roster: sixteen Goombas and one Koopa")
	expect(game.blocks.size()==44,"Original block inventory transcribed")
	var service = root.get_node("Platform").input
	var event := InputEventJoypadButton.new()
	event.device = 321
	event.button_index = JOY_BUTTON_A
	event.pressed = true
	service.handle_event(event)
	expect(game.pilot==1 and game.phase=="playing","SDK join starts Mario")
	event.device = 322
	service.handle_event(event)
	expect(service.players.size()==1,"World 1-1 has one active player")
	# Native Wii button mapping reaches the same scene without acquiring hardware.
	service.device_connection_changed(321,false)
	service.set_device_profile(1000,"wii_remote")
	event.device = 1000
	event.button_index = JOY_BUTTON_Y
	service.handle_event(event)
	game._physics_process(0.02)
	event.pressed = false
	service.handle_event(event)
	game._physics_process(0.02)
	event.pressed = true
	service.handle_event(event)
	game._physics_process(0.02)
	expect(game.mario.v.y<0,"Native Wii 2 joins and jumps through SDK input")
	event.button_index = JOY_BUTTON_X
	service.handle_event(event)
	for i in 100: game._physics_process(0.02)
	expect(game.pilot==1 and service.players.has(1),"Holding Wii 1 to run does not leave the game")
	service.device_connection_changed(1000,false)
	event.device = 321
	event.button_index = JOY_BUTTON_A
	service.handle_event(event)
	reset()
	steps(30,1)
	expect(game.mario.p.x>65 and game.mario.ground,"Mario accelerates and stays on the floor")
	var walk_speed: float = game.mario.v.x
	steps(30,1,false,true)
	expect(game.mario.v.x>walk_speed,"Run is faster than walking")
	steps(30)
	expect(absf(game.mario.v.x)<0.1,"Release input applies friction")
	reset()
	steps(1,0,true)
	steps(15,0,true)
	var high_y: float = game.mario.p.y
	reset()
	steps(1,0,true)
	steps(15,0,false)
	expect(high_y<game.mario.p.y-15,"Holding jump reaches higher than tapping")
	steps(80)
	expect(game.mario.ground and absf(game.mario.p.y-208)<0.1,"Jump returns to floor")
	reset()
	var apex := 208.0
	for i in 75:
		steps(1,0,true)
		apex = minf(apex,game.mario.p.y)
	expect(208-apex>=78 and 208-apex<90,"Standing held jump comfortably exceeds a 64-pixel pipe")
	reset()
	steps(1,0,true)
	var tap_apex: float = game.mario.p.y
	for i in 45:
		steps(1)
		tap_apex = minf(tap_apex,game.mario.p.y)
	expect(208-tap_apex>=16 and 208-tap_apex<32,"Quick taps remain useful short hops")
	for pipe in [[28,2],[38,3],[46,4]]:
		reset()
		game.mario.p = Vector2(pipe[0]*16-28-pipe[1]*6,208)
		game.mario.v.x = 90
		steps(100,1,true,false)
		expect(game.phase=="playing" and game.mario.p.x>(pipe[0]+2)*16,"Walking jump clears pipe height %d without run"%pipe[1])
	reset()
	game.mario.p = Vector2(432,208)
	steps(60,1)
	expect(game.mario.p.x<=442.01,"Pipe side blocks walking")
	game.mario.p = Vector2(470,140)
	game.mario.v = Vector2(0,30)
	steps(50)
	expect(absf(game.mario.p.y-176)<0.1,"Mario lands on pipe top")
	reset()
	game.mario.p = Vector2(264,208)
	steps(1,0,true)
	steps(50,0,true)
	expect(game.coins==1 and game.blocks[Vector2i(16,9)].kind=="used","Head collision dispenses a question-block coin once")
	game.hit_block(Vector2i(16,9))
	expect(game.coins==1,"Used question block cannot dispense twice")
	game.hit_block(Vector2i(21,9))
	expect(game.items.size()==1 and game.items[0].kind=="mushroom","First power block produces mushroom for small Mario")
	game.collect("mushroom")
	steps(30)
	expect(game.power==1 and game.mario.size.y==32,"Mushroom grows collision body")
	game.hit_block(Vector2i(20,9))
	expect(not game.blocks.has(Vector2i(20,9)),"Big Mario breaks bricks")
	game.hit_block(Vector2i(78,9))
	expect(game.items[-1].kind=="flower","Power block upgrades big Mario to fire flower")
	game.collect("flower")
	steps(30)
	game.last_run = false
	steps(1,0,false,true)
	expect(game.shots.size()==1,"Fire Mario can shoot")
	game.hurt()
	expect(game.power==0 and game.invincible>0,"Damage shrinks Mario and gives recovery time")
	game.hurt()
	expect(game.phase=="playing","Recovery time prevents repeated instant damage")
	reset()
	game.hit_block(Vector2i(64,8))
	expect(game.items[0].kind=="life","Hidden block reveals a 1-up")
	game.collect("life")
	expect(game.lives==4,"1-up adds a life")
	game.hit_block(Vector2i(101,9))
	expect(game.items[-1].kind=="star","Star is inside its original brick")
	game.collect("star")
	game.hurt()
	expect(game.phase=="playing" and game.star>0,"Star prevents contact damage")
	reset()
	for i in 10:
		game.hit_block(Vector2i(94,9))
		game.blocks[Vector2i(94,9)].bump = 0
	expect(game.coins==10 and game.blocks[Vector2i(94,9)].kind=="used","Ten-coin block exhausts its supply")
	reset()
	game.mario.p = Vector2(1118,208)
	steps(50)
	expect(game.phase=="dead" and game.lives==2,"Falling in first pit costs one life")
	steps(150)
	expect(game.phase=="playing" and game.mario.p.x==40,"Death restarts the level")
	reset()
	game.mario.p = Vector2(928,144)
	game.mario.ground = true
	steps(1,0,false,false,true)
	expect(game.phase=="warp","Down on fourth pipe starts secret entrance")
	steps(50)
	expect(game.underground and game.room_coins.size()==19,"Bonus room has nineteen coins")
	game.mario.p = game.room_coins[0]+Vector2(5,14)
	steps(1)
	expect(game.coins==1 and game.room_coins.size()==18,"Underground coin can be collected once")
	game.mario.p = Vector2(201.5,208)
	steps(1,1)
	steps(50)
	expect(not game.underground and game.mario.p.x>=2624,"Bonus room returns to fifth pipe")
	reset()
	game.mario.p = Vector2(3172,80)
	steps(1)
	expect(game.phase=="flag","Touching pole starts level finish")
	steps(400)
	expect(game.phase=="complete" and game.time_left<=0,"Flag slide, castle walk and time bonus finish the course")
	reset()
	game.mario.p = Vector2(662,208)
	game.mario.v.x = 150
	steps(68,1,true,true)
	expect(game.phase=="playing" and game.mario.p.x>785,"Running jump clears a four-tile-high pipe")
	reset()
	game.mario.p = Vector2(1300,208)
	game.mario.v.x = 150
	steps(68,1,true,true)
	expect(game.phase=="playing" and game.mario.p.x>1430 and game.mario.p.y<=208,"Running jump crosses the three-tile pit")
	reset()
	var goomba: Dictionary = game.body(Vector2(120,208),Vector2(14,16))
	goomba.merge({"kind":"goomba","active":true,"mode":"walk","timer":0.0,"ignore":0.0})
	game.enemies.append(goomba)
	game.mario.p = Vector2(120,194)
	game.mario.v.y = 50
	game._tick_enemies(0.01,Vector2(120,188))
	expect(goomba.mode=="flat" and game.mario.v.y<0,"Falling on Goomba stomps it and bounces Mario")
	var koopa: Dictionary = game.body(Vector2(160,208),Vector2(14,24))
	koopa.merge({"kind":"koopa","active":true,"mode":"walk","timer":0.0,"ignore":0.0})
	game.enemies.append(koopa)
	game.mario.p = Vector2(160,186)
	game.mario.v.y = 50
	game._tick_enemies(0.01,Vector2(160,180))
	expect(koopa.mode=="shell" and koopa.v.x==0,"Stomping Koopa creates a stationary shell")
	koopa.ignore = 0
	game.mario.p = Vector2(151,208)
	game.mario.v.y = 0
	game._tick_enemies(0.01,game.mario.p)
	expect(koopa.v.x>100,"Walking into a stopped shell kicks it")
	reset()
	var hazard: Dictionary = game.body(Vector2(48,208),Vector2(14,16))
	hazard.merge({"kind":"goomba","active":true,"mode":"walk","timer":0.0,"ignore":0.0})
	game.enemies.append(hazard)
	game._tick_enemies(0.01,game.mario.p)
	expect(game.phase=="dead","Side contact with an enemy kills small Mario")
	reset()
	game.mario.p = Vector2(352,208)
	steps(1,0,true)
	steps(35,0,true)
	expect(game.mario.p.y>=176,"Hitting between adjacent ceiling blocks never teleports Mario on top")
	reset()
	game.time_left = 0.01
	steps(1)
	expect(game.phase=="dead","Timer expiry costs a life")
	service.device_connection_changed(321,false)
	expect(game.phase=="disconnected" and game.pilot==0,"Disconnect pauses the session")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			game.reset_run()
			game.phase = "playing"
			await capture(argument.trim_prefix("--capture=")+"-start.png")
			game.camera_x = 1120
			game.mario.p = Vector2(1180,208)
			await capture(argument.trim_prefix("--capture=")+"-middle.png")
			game.enter_room()
			await capture(argument.trim_prefix("--capture=")+"-room.png")
			game.exit_room()
			game.camera_x = 3072
			game.mario.p = Vector2(3120,208)
			await capture(argument.trim_prefix("--capture=")+"-end.png")
	if not failures: print("World 1-1 checks passed: %d synthetic gameplay assertions."%checks)
	quit(1 if failures else 0)
func capture(path: String) -> void:
	game.board.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	expect(root.get_texture().get_image().save_png(path)==OK,"World 1-1 capture saved")
