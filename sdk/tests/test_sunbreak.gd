extends SceneTree
var checks := 0
var failures := 0

class ControlledPlayer:
	extends "res://examples/sunbreak/player.gd"
	var axes: Dictionary = {}
	func pad_axis(axis: int) -> float:
		return axes.get(axis,0.0)
	func pad_button(_button: int) -> bool:
		return false

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
	var yaw_before: float = game.player.rotation.y
	for i in 600: game.player.controller_look(Vector2(0.85,-0.20),1.0/60)
	expect(absf(game.player.camera.rotation.x)<0.001 and absf(game.player.rotation.y-yaw_before)>1,"Horizontal look with vertical stick offset cannot drift skyward")
	game.player.controller_look(Vector2(0,-0.85),0.05)
	var released_pitch: float = game.player.camera.rotation.x
	for i in 600: game.player.controller_look(Vector2(0.12,-0.18),1.0/60)
	expect(is_equal_approx(game.player.camera.rotation.x,released_pitch),"Releasing the look stick stops rotation immediately without residual velocity")
	game.player.camera.rotation.x = 0
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
	game.start_match()
	await physics_frame
	await physics_frame
	game.navigation.rebuild(game)
	var route: PackedVector3Array = game.navigation.route(Vector3(14,0,-3),Vector3(14,0,-20))
	expect(route.size()>3,"Navigation routes around a building instead of driving straight through it")
	var blocked := false
	for point in route:
		if game.navigation.grid.is_point_solid(Vector2i(roundi(point.x/2),roundi(point.z/2))): blocked = true
	expect(not blocked,"Every route waypoint clears inflated static collision")
	var actor = game.bots[0].body
	expect(actor.skeleton.get_bone_count()>40 and actor.tree.active,"Enemy uses a live humanoid rig and animation tree")
	var knee: int = actor.skeleton.find_bone("calf_l")
	actor.advance(0.05,Vector3(0,0,-3),false)
	var pose: Quaternion = actor.skeleton.get_bone_pose_rotation(knee)
	actor.advance(0.21,Vector3(0,0,-3),false)
	expect(pose.angle_to(actor.skeleton.get_bone_pose_rotation(knee))>0.05,"Actual knee bones articulate during locomotion")
	for i in 30: actor.advance(1.0/60,Vector3.ZERO,false)
	expect(actor.speed<0.03,"Locomotion blends down smoothly when enemy stops")
	var upright := true
	var head: int = actor.skeleton.find_bone("Head")
	var pelvis: int = actor.skeleton.find_bone("pelvis")
	for direction in [Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]:
		for i in 120:
			if i==30: actor.hit()
			actor.advance(1.0/60,direction*3,false)
			var torso: Vector3 = actor.skeleton.get_bone_global_pose(head).origin-actor.skeleton.get_bone_global_pose(pelvis).origin
			upright = upright and torso.normalized().y>0.8
	expect(upright,"Strafing, backpedaling, and hit reactions keep the live soldier upright")
	var target = game.bots[0]
	target.take_hit(20)
	expect(target.stagger>0 and target.charge==0,"A real hit interrupts enemy charge and starts stagger")
	target.take_hit(1000)
	expect(target.collision_layer==0 and target.body.dead and not target in game.bots,"Dead enemies leave combat immediately while their fall animation continues")
	var death_pose: Quaternion = target.body.skeleton.get_bone_pose_rotation(knee)
	target.tick_death(0.35)
	expect(death_pose.angle_to(target.body.skeleton.get_bone_pose_rotation(knee))>0.01,"Death animation advances on the actual rig")
	var model = game.player.weapon
	var view_pitch: float = game.player.camera.rotation.x
	model.kick()
	model.present(1.0/60,Vector2.ZERO,0,false,false,0,0)
	expect(model.recoil_position>0 and game.player.camera.rotation.x==view_pitch,"Rifle spring recoils without changing the aiming direction")
	for i in 120: model.present(1.0/60,Vector2.ZERO,0,false,false,0,0)
	expect(model.recoil_position<0.001,"Recoil settles without persistent drift")
	model.present(0.1,Vector2.ZERO,0,false,false,1.1,0)
	expect(model.magazine.position.y < -0.25,"Reload extracts the modeled magazine")
	model.present(0.1,Vector2.ZERO,0,false,false,0,0)
	expect(model.magazine.visible and is_equal_approx(model.magazine.position.y,-0.14),"Reload completion reseats the magazine")
	var paused_time: float = actor.tree.get("parameters/stride/scale")
	game.pause_match()
	game._physics_process(1)
	expect(actor.tree.get("parameters/stride/scale")==paused_time,"Paused game does not advance locomotion state")
	expect(game.batched_meshes>200,"Static scenery batches hundreds of meshes while combat collision still passes")
	var rocks := get_nodes_in_group("sunbreak_rocks")
	var solid_rocks := 0
	var ray_rocks := 0
	for rock in rocks:
		var body: StaticBody3D = rock.get_child(0)
		var collider: CollisionShape3D = body.get_child(0)
		if collider.shape is ConvexPolygonShape3D and body.collision_layer&1: solid_rocks += 1
		var center: Vector3 = rock.global_position
		var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(center+Vector3.UP*10,center,1))
		if not hit.is_empty(): ray_rocks += 1
	expect(rocks.size()==66 and solid_rocks==66 and ray_rocks==66,"All 34 island rocks and 32 coastal outcrops retain solid convex collision after batching")
	# Sweep the actual player capsule toward a rotated/scaled rock above the ground.
	var obstacle = game.Art.sphere(game,Vector3(0,1,35),Vector3(2,1.5,1.2),"888888")
	obstacle.rotation.y = 0.6
	obstacle.create_convex_collision()
	await physics_frame
	await physics_frame
	var sweep: Transform3D = game.player.global_transform
	sweep.origin = Vector3(0,0.05,39)
	expect(game.player.test_move(sweep,Vector3(0,0,-7)),"Actual player capsule cannot pass through a rotated and scaled rock")
	obstacle.free()
	game.quality = 1
	expect(game.render_scale_for(Vector2i(5120,2880))<=0.375,"Balanced graphics caps 5K displays at 1080p internal rendering")
	expect(game.render_scale_for(Vector2i(1280,720))==1.0,"Small windows render at native resolution")
	game.cycle_quality()
	expect(game.quality==2 and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Changing graphics keeps the mouse free")
	game.quality = 1
	game.apply_render_quality()
	game.resume_match()
	var walker = game.bots[0]
	for other in game.bots.duplicate():
		if other!=walker:
			game.bots.erase(other)
			other.free()
	walker.position = Vector3(14,0.1,-3)
	walker.velocity = Vector3.ZERO
	walker.cooldown = 1000
	game.player.position = Vector3(14,0.1,-20)
	await physics_frame
	await physics_frame
	var starting: Vector3 = walker.position
	for i in 180:
		await physics_frame
		walker.tick(0.05)
	expect(walker.position.distance_to(starting)>5 and walker.position.y>-0.2,"Actual enemy body navigates past building cover instead of sticking to its wall")
	# Feed movement/fire through the player's real tick and physics, with neutral
	# right-stick axes. This isolates camera presentation from hardware reports.
	var original_player = game.player
	var controlled := ControlledPlayer.new()
	controlled.game = game
	game.add_child(controlled)
	game.player = controlled
	game.control_mode = "controller"
	controlled.reset()
	controlled.camera.rotation.x = 0.3
	controlled.look_ready = true
	var max_distance := 0.0
	var jumped := false
	var pitch_stable := true
	for i in 180:
		controlled.axes[JOY_AXIS_LEFT_X] = 0.7 if i<90 else -0.7
		controlled.axes[JOY_AXIS_TRIGGER_RIGHT] = 0.0 if i==0 else 1.0
		if i in [20,100]: controlled.jump_queued = true
		await physics_frame
		controlled.tick(1.0/60)
		max_distance = maxf(max_distance,absf(controlled.position.x))
		jumped = jumped or controlled.velocity.y>4
		pitch_stable = pitch_stable and absf(controlled.camera.rotation.x-0.3)<0.00001
	expect(max_distance>1 and jumped and controlled.ammo<30,"Controller simulation actually moves, jumps, and fires through the normal player tick")
	expect(pitch_stable,"Moving, jumping, and firing together cannot change camera pitch with a neutral right stick")
	controlled.axes[JOY_AXIS_RIGHT_Y] = -0.7
	controlled.tick(1.0/60)
	expect(controlled.camera.rotation.x>0.3,"Deliberate look still works while moving and firing")
	controlled.axes[JOY_AXIS_RIGHT_Y] = 0.0
	var stopped_pitch := controlled.camera.rotation.x
	for i in 60:
		await physics_frame
		controlled.tick(1.0/60)
	expect(absf(controlled.camera.rotation.x-stopped_pitch)<0.00001,"Releasing look stops pitch changes while movement and fire continue")
	game.player = original_player
	controlled.free()
	original_player.camera.current = true
	game.control_mode = "mouse"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			game.start_match()
			game.banner_left = 0
			game.player.position = Vector3(2,0.1,24)
			game.player.rotation = Vector3.ZERO
			game.player.camera.look_at(Vector3(0,2,-4))
			game.bots[0].position = Vector3(4,0,15)
			game.bots[0].rotation.y = PI
			game.bots[0].body.advance(0.2,Vector3(0,0,2),false)
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
