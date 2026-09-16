extends Node3D
const Art = preload("res://examples/sunbreak/art.gd")
const Player = preload("res://examples/sunbreak/player.gd")
const Bot = preload("res://examples/sunbreak/bot.gd")
const Hud = preload("res://examples/sunbreak/hud.gd")
var player: CharacterBody3D
var hud: Control
var sound: Node
var phase := "menu"
var bots: Array[CharacterBody3D] = []
var projectiles: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var covers: Array[Node3D] = []
var wave := 0
var kills := 0
var time := 0.0
var wave_wait := 0.0
var storm_radius := 54.0
var storm: MeshInstance3D
var storm_tick := 0.0
var cover_charges := 3
var hit_left := 0.0
var damage_left := 0.0
var banner_left := 0.0
var banner := ""
var victory := false
var control_mode := "mouse"
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	DisplayServer.window_set_title("SUNBREAK · Single-player island skirmish")
	get_viewport().msaa_3d = Viewport.MSAA_2X
	rng.seed = 621
	# This game's FPS actions are local; the SDK still checks the shared runtime.
	get_node("/root/Platform").input.set_process_input(false)
	Art.create_world(self)
	player = Player.new()
	player.game = self
	add_child(player)
	player.reset()
	sound = preload("res://examples/sunbreak/sound.gd").new()
	add_child(sound)
	var shape := CylinderMesh.new()
	shape.top_radius = 1
	shape.bottom_radius = 1
	shape.height = 60
	shape.radial_segments = 128
	shape.cap_top = false
	shape.cap_bottom = false
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://examples/sunbreak/shaders/storm.gdshader")
	storm = Art.mesh(self,shape,Vector3(0,25,0),mat)
	storm.scale = Vector3(storm_radius,1,storm_radius)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	hud = Hud.new()
	hud.game = self
	canvas.add_child(hud)
	Input.joy_connection_changed.connect(_controller_connection)
	hud.show_menu()

func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Art.materials.clear()
	Art.box_meshes.clear()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and phase == "playing": pause_match()

func _controller_connection(device: int, connected: bool) -> void:
	if not connected and player.pad == device:
		player.pad = -1
		if phase == "playing": pause_match()

func select_controller(device: int) -> void:
	if player.pad>=0 and player.pad!=device: return
	if player.pad!=device or control_mode!="controller":
		player.pad = device
		control_mode = "controller"
		player.reset_look()
		player.trigger_armed = false

func _input(event: InputEvent) -> void:
	# Observe controller ownership before focused menu buttons consume A/Cross.
	if event is InputEventJoypadButton and event.pressed:
		select_controller(event.device)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			var fullscreen := DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif event.keycode == KEY_ESCAPE:
			if phase=="playing": pause_match()
			elif phase=="paused": resume_match()
		elif phase=="playing":
			if event.physical_keycode==KEY_SPACE: player.jump_queued = true
			if event.physical_keycode==KEY_R: player.reload()
			if event.physical_keycode==KEY_Q: deploy_cover()
	if event is InputEventMouseButton and event.pressed and phase=="playing" and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
		control_mode = "mouse"
	if event is InputEventMouseMotion and phase=="playing" and control_mode=="mouse" and event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		player.look_by(event.relative*0.0013)
	if event is InputEventJoypadButton and event.pressed:
		select_controller(event.device)
		if event.device!=player.pad: return
		if event.button_index==JOY_BUTTON_START:
			if phase=="playing": pause_match()
			elif phase=="paused": resume_match()
		elif phase=="playing":
			if event.button_index==JOY_BUTTON_A: player.jump_queued = true
			if event.button_index==JOY_BUTTON_X: player.reload()
			if event.button_index==JOY_BUTTON_Y: deploy_cover()
			if event.button_index==JOY_BUTTON_RIGHT_STICK: player.reset_look()
		elif event.button_index==JOY_BUTTON_A:
			if phase=="paused": resume_match()
			else: start_match()

func clear_match() -> void:
	for bot in bots: bot.free()
	bots.clear()
	for collection in [projectiles,effects,pickups]:
		for entry in collection:
			if is_instance_valid(entry.node): entry.node.free()
		collection.clear()
	for cover in covers: cover.free()
	covers.clear()

func start_match() -> void:
	clear_match()
	player.reset()
	wave = 0
	kills = 0
	time = 0
	storm_radius = 54
	storm_tick = 0
	cover_charges = 3
	damage_left = 0
	hit_left = 0
	wave_wait = 0
	phase = "playing"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.hide_menu()
	for at in [Vector3(-6,0,8),Vector3(8,0,4),Vector3(-5,0,-14),Vector3(22,0,4)]: spawn_pickup(at,"shield")
	next_wave()

func next_wave() -> void:
	wave += 1
	banner = "WAVE %02d   /   %s" % [wave,["FIRST CONTACT","REINFORCEMENTS","LAST STAND"][wave-1]]
	banner_left = 3.5
	sound.effect("wave")
	for i in (wave*2+2):
		var angle := float(i)*TAU/(wave*2+2)+0.4
		var bot := Bot.new()
		bot.game = self
		bot.position = Vector3(cos(angle)*28,0.1,sin(angle)*28)
		bot.cooldown = 2.0+i*0.27
		bot.side = 1 if i%2==0 else -1
		add_child(bot)
		bots.append(bot)

func pause_match() -> void:
	phase = "paused"
	player.trigger_armed = false
	player.jump_queued = false
	player.look_ready = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_menu()

func resume_match() -> void:
	phase = "playing"
	player.trigger_armed = false
	player.look_ready = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.hide_menu()

func finish(won: bool) -> void:
	phase = "result"
	victory = won
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if won: sound.effect("win")
	hud.show_menu()

func _physics_process(delta: float) -> void:
	if phase != "playing":
		hud.queue_redraw()
		return
	time += delta
	hit_left = maxf(0,hit_left-delta)
	damage_left = maxf(0,damage_left-delta)
	banner_left = maxf(0,banner_left-delta)
	player.tick(delta)
	if phase!="playing": return
	for bot in bots: bot.tick(delta)
	advance_projectiles(delta)
	if phase!="playing": return
	for i in range(effects.size()-1,-1,-1):
		effects[i].life -= delta
		if effects[i].life<=0:
			effects[i].node.queue_free()
			effects.remove_at(i)
	for i in range(pickups.size()-1,-1,-1):
		var item: Dictionary = pickups[i]
		item.node.rotation.y += delta*1.5
		item.node.position.y = 0.85+sin(time*2+float(i))*0.15
		if player.position.distance_to(item.node.position)<1.7:
			var needed: bool = player.shield<100 if item.kind=="shield" else player.health<100
			if needed:
				if item.kind=="shield": player.shield = minf(100,player.shield+40)
				else: player.health = minf(100,player.health+35)
				sound.effect("pickup")
				item.node.queue_free()
				pickups.remove_at(i)
	storm_radius = maxf(18,54-time*0.10)
	storm.scale = Vector3(storm_radius,1,storm_radius)
	if Vector2(player.position.x,player.position.z).length()>storm_radius:
		storm_tick += delta
		if storm_tick>=1:
			storm_tick -= 1
			player.hurt(12)
	else: storm_tick = 0
	if bots.is_empty() and phase=="playing":
		wave_wait += delta
		if wave_wait>=3:
			wave_wait = 0
			if wave>=3: finish(true)
			else:
				player.shield = minf(100,player.shield+25)
				next_wave()
	hud.queue_redraw()

func eliminated(bot: CharacterBody3D) -> void:
	bots.erase(bot)
	kills += 1
	cover_charges = mini(3,cover_charges+1)
	spark(bot.position+Vector3.UP,"ffc378")
	spawn_pickup(bot.position,"health" if kills%3==0 else "shield")
	if bots.is_empty():
		banner = "SECTOR CLEAR" if wave<3 else "ISLAND SECURED"
		banner_left = 3

func spawn_pickup(at: Vector3, kind: String) -> void:
	var item := Node3D.new()
	add_child(item)
	item.position = at+Vector3(0,0.85,0)
	var color := "65e9ef" if kind=="shield" else "a8ee79"
	var core := Art.cylinder(item,Vector3.ZERO,0.2,0.2,0.5,color)
	core.material_override = Art.material(color,0.2,1.2)
	Art.cylinder(item,Vector3(0,0.29,0),0.23,0.23,0.09,"eee3b9")
	Art.cylinder(item,Vector3(0,-0.29,0),0.23,0.23,0.09,"eee3b9")
	pickups.append({"node":item,"kind":kind})

func deploy_cover() -> void:
	if phase!="playing" or cover_charges<=0 or not player.is_on_floor(): return
	var forward: Vector3 = -player.basis.z
	var at: Vector3 = player.position+forward*3.5+Vector3(0,1.1,0)
	var bounds := BoxShape3D.new()
	bounds.size = Vector3(3.4,2.2,0.35)
	var check := PhysicsShapeQueryParameters3D.new()
	check.shape = bounds
	check.transform = Transform3D(player.basis,at)
	check.collision_mask = 1|2|4
	if not get_world_3d().direct_space_state.intersect_shape(check).is_empty():
		banner = "COVER BLOCKED — FIND OPEN GROUND"
		banner_left = 1.5
		return
	var cover := Node3D.new()
	add_child(cover)
	cover.position = at
	cover.rotation.y = player.rotation.y
	Art.box(cover,Vector3.ZERO,bounds.size,"4d7885",true,0.6)
	for x in [-1.5,0,1.5]: Art.box(cover,Vector3(x,0,0),Vector3(0.09,2.3,0.48),"e5c681",false,0.5)
	Art.box(cover,Vector3(0,0.72,-0.19),Vector3(2.9,0.07,0.04),"8bffe4")
	covers.append(cover)
	if covers.size()>6: covers.pop_front().queue_free()
	cover_charges -= 1
	sound.effect("build")

func enemy_shot(at: Vector3, direction: Vector3) -> void:
	var bolt := Art.sphere(self,at,Vector3.ONE*0.13,"ff805f")
	bolt.material_override = Art.material("ff805f",0,3)
	projectiles.append({"node":bolt,"velocity":direction*19,"life":5.0})

func advance_projectiles(delta: float) -> void:
	for i in range(projectiles.size()-1,-1,-1):
		var shot: Dictionary = projectiles[i]
		var from: Vector3 = shot.node.position
		var to: Vector3 = from+shot.velocity*delta
		var ray := PhysicsRayQueryParameters3D.create(from,to,1|2)
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		shot.life -= delta
		if not hit.is_empty() or shot.life<=0:
			if not hit.is_empty():
				spark(hit.position,"ffba79")
				if hit.collider==player: player.hurt(13)
			shot.node.queue_free()
			projectiles.remove_at(i)
		else: shot.node.position = to

func tracer(from: Vector3, to: Vector3, color: String) -> void:
	var length := from.distance_to(to)
	if length<0.01: return
	var shape := CylinderMesh.new()
	shape.top_radius = 0.012
	shape.bottom_radius = 0.012
	shape.height = length
	var beam := Art.mesh(self,shape,(from+to)*0.5,Art.material(color,0,2))
	var direction := (to-from).normalized()
	beam.quaternion = Quaternion(Vector3.UP,direction)
	effects.append({"node":beam,"life":0.055})

func spark(at: Vector3, color: String) -> void:
	var node := Art.sphere(self,at,Vector3.ONE*0.14,color)
	node.material_override = Art.material(color,0,2)
	effects.append({"node":node,"life":0.1})
