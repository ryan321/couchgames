extends SceneTree
## Run with the SDK project and an installed renderer. Saves a review image, then exits.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1500,1000)
	root.msaa_3d = Viewport.MSAA_4X
	root.mode = Window.MODE_WINDOWED
	root.title = "Gauntlet cast · art review"
	var stage := Node3D.new()
	root.add_child(stage)
	var factory: Node3D = load("res://examples/gauntlet/dungeon_view.gd").new()
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("202c36")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("accbd9")
	world.environment.ambient_light_energy = 0.32
	world.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment.glow_enabled = true
	world.environment.ssao_enabled = true
	world.environment.ssao_radius = 0.6
	world.environment.ssao_intensity = 1.4
	stage.add_child(world)
	for pair in [[Vector3(-45,-30,0),Color("ffe1bd"),1.1],[Vector3(-25,140,0),Color("98c6ec"),0.7]]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = pair[0]
		light.light_color = pair[1]
		light.light_energy = pair[2]
		light.shadow_enabled = true
		stage.add_child(light)
	factory.box(stage,Vector3(0,-0.22,0),Vector3(30,0.15,20),Color("28343d"))
	var heroes: Array[Node3D] = []
	var creatures: Array[Node3D] = []
	for kind in 4:
		var hero: Node3D = factory.hero_model(kind)
		hero.position = Vector3((kind-1.5)*2.2,0,1.45)
		hero.rotation.y = -0.16
		stage.add_child(hero)
		heroes.append(hero)
		hero.managed = true
		hero.motion.tree.advance(0.02)
		if kind==0: hero.axe_motion.present(hero)
		factory.box(stage,hero.position-Vector3(0,0.09,0),Vector3(1.65,0.17,1.55),Color("3d4f59"))
		label(stage,["WARRIOR","VALKYRIE","WIZARD","ELF"][kind],hero.position+Vector3(0,-0.08,1.0))
	var kinds := ["ghost","grunt","demon"]
	for index in 3:
		var creature: Node3D = factory.enemy_model(kinds[index])
		creature.position = Vector3((index-1)*2.4,0,-2.0)
		creature.rotation.y = -0.16
		stage.add_child(creature)
		creatures.append(creature)
		factory.box(stage,creature.position-Vector3(0,0.09,0),Vector3(1.65,0.17,1.55),Color("3d4f59"))
		label(stage,["WRAITH","RAIDER","DEMON"][index],creature.position+Vector3(0,1.95,0))
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6.4
	camera.position = Vector3(2.8,8,13)
	camera.look_at(Vector3(0,.7,-.2))
	camera.current = true
	for frame in 16: await process_frame
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://../art/gauntlet/cast/in_game_cast.png")
	var error := root.get_texture().get_image().save_png(path)
	print("Cast render saved: ",path," (",error,")")
	var states: Array[Dictionary] = []
	for kind in 4:
		states.append({"pos":Vector2.ZERO,"face":Vector2.DOWN,"hp":100,"escaped":false,"attack_serial":0,"hit_serial":0,"magic_serial":0})
	for frame in 22:
		for kind in 4:
			states[kind].pos += Vector2(0,1.5)
			if frame==14: states[kind].attack_serial = 1
			heroes[kind].present(states[kind],1.0/60,true)
		for i in 3: creatures[i].present({"id":i,"attack_serial":1 if frame>=14 else 0},.04,1.0/60,frame/60.0,true)
		await process_frame
	await RenderingServer.frame_post_draw
	var motion_path := ProjectSettings.globalize_path("res://../art/gauntlet/cast/in_game_motion.png")
	var motion_error := root.get_texture().get_image().save_png(motion_path)
	print("Motion render saved: ",motion_path," (",motion_error,")")
	stage.queue_free()
	factory.free()
	await process_frame
	quit(error if error else motion_error)
func label(parent: Node3D, text: String, at: Vector3) -> void:
	var item := Label3D.new()
	item.text = text
	item.font_size = 34
	item.pixel_size = 0.006
	item.modulate = Color("b9cbd1")
	item.position = at
	item.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(item)
