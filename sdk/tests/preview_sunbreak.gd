extends SceneTree
## Deterministic art review; arranged enemies and camera are not a gameplay playthrough.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://examples/sunbreak/island.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	game.set_process_input(false)
	game.set_process_unhandled_input(false)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--quality="): game.quality = clampi(int(argument.trim_prefix("--quality=")),0,2)
	game.apply_render_quality()
	game.start_match()
	game.banner_left = 0
	game.player.position = Vector3(2,0.1,24)
	game.player.camera.look_at(Vector3(0,2,-4))
	game.bots[0].position = Vector3(4,0,16)
	game.bots[0].rotation.y = PI
	var frames := PackedFloat32Array()
	for i in 150:
		var start := Time.get_ticks_usec()
		for bot in game.bots: bot.body.advance(1.0/60,Vector3(0,0,2.4),false)
		game.player.weapon.present(1.0/60,Vector2.ZERO,0,false,false,0,0)
		await process_frame
		if i>29: frames.append((Time.get_ticks_usec()-start)/1000.0)
	await RenderingServer.frame_post_draw
	var destination := "/tmp/sunbreak-enhanced.png"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="): destination = argument.trim_prefix("--capture=")
	root.get_texture().get_image().save_png(destination)
	frames.sort()
	var total := 0.0
	for value in frames: total += value
	print(JSON.stringify({"preview_frames":frames.size(),"mean_ms":total/frames.size(),"p95_ms":frames[int(frames.size()*0.95)],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),"viewport":str(root.size),"render_scale":root.scaling_3d_scale,"merged_meshes":game.batched_meshes}))
	game.hud.visible = false
	game.player.weapon.visible = false
	game.player.camera.global_position = Vector3(4.8,1.48,19.5)
	game.player.camera.look_at(Vector3(4,1.1,16))
	game.player.camera.fov = 55
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(destination.replace(".png","-soldier.png"))
	game.clear_match()
	await process_frame
	quit()
