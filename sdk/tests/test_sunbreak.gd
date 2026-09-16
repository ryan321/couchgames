extends SceneTree
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func run() -> void:
	var game = load("res://examples/sunbreak/island.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.set_process_input(false)
	await physics_frame
	expect(game.phase=="menu" and game.hud.panel.visible,"Game starts with an actionable menu")
	game.start_match()
	expect(game.phase=="playing" and game.bots.size()==4 and game.wave==1,"Deploy starts first wave")
	expect(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE and game.player.pad==-1,"Deploy keeps pointer free and does not select an idle controller")
	for i in 12:
		await physics_frame
		game.player.tick(1.0/60)
	expect(game.player.is_on_floor(),"Player settles on real island collision")
	var grounded: float = game.player.position.y
	game.player.jump_queued = true
	game.player.tick(1.0/60)
	expect(game.player.velocity.y>0 and game.player.position.y>grounded,"Jump lifts the actual physics body")
	for i in 65:
		await physics_frame
		game.player.tick(1.0/60)
	expect(game.player.is_on_floor(),"Player lands after jumping")
	var before_move: Vector3 = game.player.position
	var move_key := InputEventKey.new()
	move_key.physical_keycode = KEY_W
	move_key.pressed = true
	Input.parse_input_event(move_key)
	for i in 8:
		await physics_frame
		game.player.tick(1.0/60)
	move_key.pressed = false
	Input.parse_input_event(move_key)
	expect(game.player.position.z<before_move.z-0.2,"WASD input moves the first-person physics body")
	game.player.position = Vector3(0,0.01,24)
	game.player.velocity = Vector3.ZERO
	game.player.look_by(Vector2(0,100))
	expect(is_equal_approx(game.player.camera.rotation.x,-1.35),"Mouse look clamps vertical rotation")
	game.player.camera.rotation = Vector3.ZERO
	game.player.pad = 2
	game.player.ammo = 20
	var reload_button := InputEventJoypadButton.new()
	reload_button.button_index = JOY_BUTTON_X
	reload_button.pressed = true
	reload_button.device = 3
	game._unhandled_input(reload_button)
	expect(game.player.reload_left==0,"Another controller cannot operate the active player's rifle")
	reload_button.device = 2
	game._unhandled_input(reload_button)
	expect(game.player.reload_left>0,"The assigned gamepad reloads the rifle")
	game.player.reload_left = 0
	game.player.ammo = 30
	game.player.pad = -1
	# Use the real camera ray and collision shapes, with an isolated robot in front.
	for bot in game.bots.duplicate(): bot.free()
	game.bots.clear()
	var bot = game.Bot.new()
	bot.game = game
	bot.position = Vector3(0,0.1,18)
	game.add_child(bot)
	game.bots.append(bot)
	await physics_frame
	await physics_frame
	game.player.camera.look_at(bot.global_position+Vector3(0,1.2,0))
	game.player.shoot()
	expect(bot.health==66 and game.player.ammo==29,"Camera ray hits robot and consumes exactly one round")
	game.player.shoot()
	expect(bot.health==66 and game.player.ammo==29,"Fire cooldown prevents duplicate hits")
	# Solid cover blocks the same ray and projectile path.
	var wall = game.Art.box(game,Vector3(0,1.4,21),Vector3(3,2.8,0.4),"888888",true)
	await physics_frame
	await physics_frame
	game.player.fire_left = 0
	game.player.shoot()
	expect(bot.health==66,"Rifle cannot damage a robot through hard cover")
	game.enemy_shot(Vector3(0,1.2,19),Vector3.BACK)
	game.advance_projectiles(0.5)
	expect(game.player.shield==100 and game.projectiles.is_empty(),"Swept enemy projectile hits cover rather than player")
	wall.free()
	await physics_frame
	await physics_frame
	game.player.camera.look_at(bot.global_position+Vector3(0,1.85,0))
	game.player.fire_left = 0
	game.player.shoot()
	expect(bot.health==6,"Headshots deal additional damage")
	game.player.fire_left = 0
	game.player.shoot()
	expect(game.kills==1 and game.bots.is_empty(),"Elimination removes the target and increments score once")
	await process_frame
	game.player.ammo = 0
	game.player.fire_left = 0
	game.player.shoot()
	expect(game.player.reload_left>0 and game.player.ammo==0,"Empty rifle starts a timed reload")
	game.player.tick(0.8)
	expect(game.player.ammo==0,"Reload cannot refill early")
	game.player.tick(0.81)
	expect(game.player.ammo==30,"Reload refills a completed magazine")
	game.player.hurt(125)
	expect(game.player.shield==0 and game.player.health==75,"Shield absorbs damage before health")
	game.spawn_pickup(game.player.position,"health")
	game.spawn_pickup(game.player.position,"shield")
	game._physics_process(0.01)
	expect(game.player.health==100 and game.player.shield==40,"Walking into pickups restores capped health and shield")
	game.player.position = Vector3(0,0.01,24)
	game.player.velocity = Vector3.ZERO
	game.player.camera.rotation = Vector3.ZERO
	for i in 5:
		await physics_frame
		game.player.tick(1.0/60)
	game.deploy_cover()
	expect(game.covers.size()==1 and game.cover_charges==2,"Deploying cover creates collision and spends a charge")
	await physics_frame
	await physics_frame
	game.deploy_cover()
	expect(game.covers.size()==1 and game.cover_charges==2,"Overlapping cover is refused without spending a charge")
	var old_time: float = game.time
	var old_reload: float = game.player.reload_left
	game.pause_match()
	game._physics_process(2)
	expect(game.time==old_time and game.player.reload_left==old_reload and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Pause freezes simulation and releases mouse")
	game.resume_match()
	expect(not game.player.trigger_armed,"Resume requires releasing fire before another shot")
	expect(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Resume never captures the pointer")
	game.player.pad = 99
	game._controller_connection(99,false)
	expect(game.phase=="paused" and game.player.pad==-1,"Active gamepad disconnect pauses the match")
	game.resume_match()
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	expect(game.phase=="paused","Focus loss pauses the match")
	game.resume_match()
	game.player.position = Vector3(55,0.1,0)
	game._physics_process(1.01)
	expect(game.player.shield==28,"Storm applies timed damage outside the safe circle")
	game.player.hurt(1000)
	expect(game.phase=="result" and not game.victory and game.hud.panel.visible,"Lethal damage presents defeat and retry")
	game.start_match()
	expect(game.player.health==100 and game.player.shield==100 and game.kills==0 and game.covers.is_empty(),"Retry fully resets the match")
	# Advance every wave through real elimination callbacks to the win condition.
	for wave in 3:
		expect(game.bots.size()==4+wave*2,"Each wave spawns its expected reinforcements")
		for enemy in game.bots.duplicate(): enemy.take_hit(1000)
		await process_frame
		game._physics_process(3.1)
	expect(game.phase=="result" and game.victory and game.kills==18,"Clearing all 18 robots wins the three-wave match")
	game.start_match()
	game.player.pad = -1
	game.control_mode = "mouse"
	game.player.camera.rotation.x = 1.35
	var connect_button := InputEventJoypadButton.new()
	connect_button.device = 2
	connect_button.button_index = JOY_BUTTON_A
	connect_button.pressed = true
	game._input(connect_button)
	expect(game.player.pad==2 and game.control_mode=="controller" and game.player.camera.rotation.x==0,"Menu button claims its controller before GUI consumption and levels the camera")
	for i in 600: game.player.controller_look(Vector2(0,-1),1.0/60)
	expect(game.player.camera.rotation.x==0 and not game.player.look_ready,"Stale non-neutral axis cannot drive camera into the sky on activation")
	game.player.controller_look(Vector2.ZERO,1.0/60)
	for i in 600: game.player.controller_look(Vector2(0.1,-0.12),1.0/60)
	expect(game.player.look_ready and game.player.camera.rotation.x==0,"Neutral and small stick drift leave the view level for ten simulated seconds")
	game.player.controller_look(Vector2(0,-1),0.05)
	expect(game.player.camera.rotation.x>0,"Intentional up-stick input looks up after neutral")
	game.player.controller_look(Vector2(0,1),0.05)
	expect(absf(game.player.camera.rotation.x)<0.001,"Down-stick input can bring the camera back from looking up")
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(20000,-20000)
	motion.button_mask = MOUSE_BUTTON_MASK_RIGHT
	game._unhandled_input(motion)
	expect(absf(game.player.camera.rotation.x)<0.001,"Mouse warp or drag cannot change controller camera")
	game.player.camera.rotation.x = 1.35
	connect_button.button_index = JOY_BUTTON_RIGHT_STICK
	game._unhandled_input(connect_button)
	expect(game.player.camera.rotation.x==0 and not game.player.look_ready,"R3 levels the view and requires a neutral stick again")
	game.control_mode = "mouse"
	motion.button_mask = 0
	game._unhandled_input(motion)
	expect(game.player.camera.rotation.x==0,"Free mouse movement does not look around")
	motion.button_mask = MOUSE_BUTTON_MASK_RIGHT
	motion.relative = Vector2(10,10)
	game._unhandled_input(motion)
	expect(game.player.camera.rotation.x<0 and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Right-drag enables mouse look without capturing the pointer")
	game.control_mode = "controller"
	game.player.look_ready = true
	game.pause_match()
	game.resume_match()
	expect(not game.player.look_ready and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Controller focus recovery waits for neutral and preserves free pointer")
	game.player.pad = -1
	game.control_mode = "mouse"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			game.start_match()
			game.banner_left = 0
			game.player.position = Vector3(2,0.1,24)
			game.player.rotation = Vector3.ZERO
			game.player.camera.look_at(Vector3(0,2,-4))
			game.hud.queue_redraw()
			for i in 20: await process_frame
			await RenderingServer.frame_post_draw
			expect(root.get_texture().get_image().save_png(argument.trim_prefix("--capture="))==OK,"Rendered gameplay screenshot saved")
			game.phase = "menu"
			game.hud.show_menu()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(argument.trim_prefix("--capture=").replace(".png","-menu.png"))
	game.clear_match()
	await process_frame
	await process_frame
	if not failures: print("Sunbreak checks passed: %d physics/combat/lifecycle assertions." % checks)
	quit(1 if failures else 0)
