extends SceneTree
## Review five phases of the actual weapon/hand pose, each with a target in front.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.mode = Window.MODE_WINDOWED
	var stage := Node3D.new()
	root.add_child(stage)
	var view: Node3D = load("res://examples/gauntlet/dungeon_view.gd").new()
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("182632")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_energy = .6
	world.environment.ambient_light_color = Color("a3b6c5")
	stage.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45,150,0)
	light.light_energy = 1.2
	stage.add_child(light)
	var actors: Array[Node3D] = []
	var times := [0.0,.14,.22,.32,.54]
	for i in times.size():
		var hero: Node3D = view.hero_model(0)
		hero.position = Vector3((2-i)*3.0,0,0)
		hero.scale = Vector3.ONE*1.05
		stage.add_child(hero)
		hero.managed = true
		actors.append(hero)
		var enemy: Node3D = view.enemy_model("grunt")
		enemy.position = hero.position+Vector3(0,0,1.24)
		enemy.rotation.y = PI
		stage.add_child(enemy)
		view.box(stage,hero.position+Vector3(0,-.09,.55),Vector3(2.7,.15,3.2),Color("33444b"))
		var label := Label3D.new()
		label.text = ["READY","WINDUP","CONTACT","FOLLOW THROUGH","RECOVERY"][i]
		label.position = hero.position+Vector3(0,0,-1.3)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 28
		label.pixel_size = .01
		stage.add_child(label)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 8.0
	camera.position = Vector3(0,12,-11)
	camera.look_at(Vector3(0,.4,.5))
	camera.current = true
	for frame in 12:
		for i in actors.size():
			var state := {"pos":Vector2.ZERO,"face":Vector2.DOWN,"attack_face":Vector2.DOWN,"hp":100,"escaped":false,"attack_serial":1,"attack_started":0.0,"hit_serial":0,"magic_serial":0}
			actors[i].present(state,0,true,times[i])
		await process_frame
	await RenderingServer.frame_post_draw
	print("Axe review: ",root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../art/gauntlet/axe_sweep.png")))
	stage.queue_free();view.free()
	await process_frame
	quit()
