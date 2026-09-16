extends Node3D
## Presentation only. All gameplay, navigation and hit tests remain in the 2D simulation.
const Props = preload("res://examples/gauntlet/environment_assets.gd")
const Level = preload("res://examples/gauntlet/level.gd")
var environment_settings: Environment
var high_quality := true
var overview := false
const DEFAULT_CAMERA_SIZE := 14.0
var camera_target := Vector3(10,0,14)
var game: Node
var camera: Camera3D
var key_light: DirectionalLight3D
var architecture: Node3D
var actors: Dictionary = {}
var gates: Dictionary = {}
var objects: Dictionary = {}
var effects: Array[MeshInstance3D] = []
var torches: Array[Node3D] = []
var materials: Dictionary = {}
var model_meshes: Dictionary = {}
var visibility := preload("res://examples/gauntlet/party_visibility.gd").new()
var party_fog: Node3D
var portal: Node3D
var particle_mesh := SphereMesh.new()

func material(color: Color, metallic := 0.0, emission := 0.0) -> StandardMaterial3D:
	var key := "%s/%.2f/%.2f" % [color.to_html(),metallic,emission]
	if materials.has(key): return materials[key]
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.75 if metallic==0 else 0.3
	result.metallic = metallic
	if emission>0:
		result.emission_enabled = true
		result.emission = color
		result.emission_energy_multiplier = emission
	materials[key] = result
	return result

func mesh(parent: Node3D, shape: Mesh, at: Vector3, color: Color, metal := 0.0, glow := 0.0) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh = shape
	item.material_override = material(color,metal,glow)
	item.position = at
	parent.add_child(item)
	return item

func box(parent: Node3D, at: Vector3, size: Vector3, color: Color, metal := 0.0) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return mesh(parent,shape,at,color,metal)

func ball(parent: Node3D, at: Vector3, size: Vector3, color: Color, glow := 0.0) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = 0.5
	shape.height = 1
	shape.radial_segments = 16
	shape.rings = 8
	var item := mesh(parent,shape,at,color,0,glow)
	item.scale = size
	return item

func cylinder(parent: Node3D, at: Vector3, radius: float, height: float, color: Color, top := -1.0, metal := 0.0) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.bottom_radius = radius
	shape.top_radius = radius if top<0 else top
	shape.height = height
	shape.radial_segments = 16
	return mesh(parent,shape,at,color,metal)

func ring(parent: Node3D, at: Vector3, radius: float, thickness: float, color: Color, glow := 0.0) -> MeshInstance3D:
	var shape := TorusMesh.new()
	shape.inner_radius = radius-thickness
	shape.outer_radius = radius+thickness
	shape.rings = 32
	shape.ring_segments = 8
	return mesh(parent,shape,at,color,0.3,glow)

func at3(at: Vector2, height := 0.0) -> Vector3:
	return Vector3(at.x/32,height,at.y/32)

func _ready() -> void:
	particle_mesh.radius = 0.5
	particle_mesh.height = 1
	particle_mesh.radial_segments = 12
	particle_mesh.rings = 6
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	environment_settings = settings
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("0d1922")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("779bc1")
	settings.ambient_light_energy = 0.20
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	settings.tonemap_exposure = 1.05
	settings.glow_enabled = true
	settings.glow_intensity = 0.55
	settings.glow_bloom = 0.03
	if RenderingServer.get_current_rendering_method()=="forward_plus":
		settings.ssao_enabled = true
		settings.ssao_radius = 1.3
		settings.ssao_intensity = 1.8
		settings.ssao_detail = 0.4
		settings.volumetric_fog_enabled = true
		settings.volumetric_fog_density = 0.0025
		settings.volumetric_fog_albedo = Color("80a0b3")
		settings.volumetric_fog_length = 50
		settings.volumetric_fog_ambient_inject = 0.3
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("233444")
	sky_material.sky_horizon_color = Color("9aacae")
	sky_material.ground_bottom_color = Color("171d22")
	sky_material.ground_horizon_color = Color("9b8a6c")
	sky.sky_material = sky_material
	settings.sky = sky
	settings.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	key_light = sun
	sun.rotation_degrees = Vector3(-52,-35,0)
	sun.light_color = Color("ffdcad")
	sun.light_energy = 0.55
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80
	add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-30,155,0)
	rim.light_color = Color("8fc5e1")
	rim.light_energy = 0.45
	add_child(rim)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 17.6
	camera.position = Vector3(20,28,33)
	add_child(camera)
	camera.look_at(Vector3(20,0,10))
	camera.current = true
	camera.size = 10.0
	update_camera(1.0)
	party_fog = preload("res://examples/gauntlet/party_fog.gd").new()
	party_fog.policy = visibility
	add_child(party_fog)

func batch_boxes(parent: Node3D, transforms: Array[Transform3D], size: Vector3, color: Color) -> void:
	if transforms.is_empty(): return
	var floor_surface := size.y<0.10
	var shape: Mesh
	if floor_surface:
		shape = BoxMesh.new()
		shape.size = size
	else:
		shape = Props.geometry("DressedStone")
	var stone := StandardMaterial3D.new()
	var prefix := "res://examples/gauntlet/assets/"+("monastery_stone_floor" if floor_surface else "medieval_wall_01")
	stone.albedo_texture = load(prefix+"_albedo.jpg")
	stone.normal_enabled = true
	stone.normal_texture = load(prefix+"_normal.jpg")
	stone.normal_scale = 1.25
	stone.ao_enabled = true
	stone.ao_texture = load(prefix+"_arm.jpg")
	stone.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	stone.roughness_texture = stone.ao_texture
	stone.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	stone.albedo_color = color.lerp(Color.WHITE,0.66 if floor_surface else 0.45)
	stone.uv1_triplanar = true
	stone.uv1_world_triplanar = true
	stone.uv1_scale = Vector3.ONE*(0.38 if floor_surface else 0.65)
	stone.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = shape
	batch.instance_count = transforms.size()
	for i in transforms.size():
		var transform := transforms[i]
		if not floor_surface: transform.basis = transform.basis*Basis.from_scale(size)
		batch.set_instance_transform(i,transform)
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = batch
	instance.material_override = stone
	parent.add_child(instance)

func rebuild() -> void:
	visibility.configure(Vector2i(game.map.width,game.map.height),game.walls)
	if architecture:
		remove_child(architecture)
		architecture.queue_free()
	for actor: Node3D in actors.values(): actor.queue_free()
	actors.clear()
	gates.clear()
	objects.clear()
	torches.clear()
	architecture = Node3D.new()
	add_child(architecture)
	if game.level_index==0:
		box(architecture,Vector3(game.map.width*0.5,-0.42,game.map.height*0.5),Vector3(game.map.width+0.6,0.7,game.map.height+0.6),Color("283c49"))
		box(architecture,Vector3(game.map.width*0.5,-0.06,game.map.height*0.5),Vector3(game.map.width,0.15,game.map.height),Color("202f38"))
	for variant in 5:
		var tiles: Array[Transform3D] = []
		var bricks: Array[Transform3D] = []
		var crowns: Array[Transform3D] = []
		for y in game.map.height:
			for x in game.map.width:
				var cell := Vector2i(x,y)
				if game.map.has("visible_cells") and not game.map.visible_cells.has(cell): continue
				if (x*17+y*31)%5 != variant: continue
				var at := Vector3(x+0.5,0,y+0.5)
				tiles.append(Transform3D(Basis.IDENTITY,at))
				if game.walls.has(cell):
					var foreground: bool = y==game.map.height-1 or (game.map.has("floor") and game.map.floor.has(cell+Vector2i.UP) and not game.map.floor.has(cell+Vector2i.DOWN))
					var wall_scale := 0.35 if foreground else 1.0
					var wall_basis := Basis.from_scale(Vector3(1,wall_scale,1))
					bricks.append(Transform3D(wall_basis,at+Vector3(0,0.27*wall_scale,0)))
					bricks.append(Transform3D(wall_basis,at+Vector3(0,0.60*wall_scale,0)))
					crowns.append(Transform3D(wall_basis,at+Vector3(0,0.82*wall_scale,0)))
		batch_boxes(architecture,tiles,Vector3(1.003,0.09,1.003),Color("35434a").lightened(variant*0.013))
		batch_boxes(architecture,bricks,Vector3(0.97,0.30,0.97),Color(game.map.stone).lightened(variant*0.017))
		batch_boxes(architecture,crowns,Vector3(0.965,0.12,0.965),Color("6c777b").lightened(variant*0.012))
	build_room_floors()
	for cell in game.map.columns:
		var at := at3(Level.center(cell),0.9)
		cylinder(architecture,at+Vector3(0,0.16,0),0.4,0.32,Color("9babae"),0.34)
		box(architecture,at+Vector3(0,0.37,0),Vector3(0.84,0.1,0.84),Color("c0b58d"),0.2)
	for cell in game.map.torches:
		var holder := Node3D.new()
		holder.position = at3(Level.center(cell))
		architecture.add_child(holder)
		holder.add_child(Props.instance("EmberBrazier",0.85))
		var flame := Node3D.new()
		flame.position.y = 0.90
		holder.add_child(flame)
		for angle in [0.0,PI/2]:
			var shape := QuadMesh.new()
			shape.size = Vector2(0.58,0.85)
			var fire := MeshInstance3D.new()
			fire.mesh = shape
			fire.position.y = 0.42
			fire.rotation.y = angle
			fire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var fire_material := ShaderMaterial.new()
			fire_material.shader = preload("res://examples/gauntlet/shaders/flame.gdshader")
			fire.material_override = fire_material
			flame.add_child(fire)
		torches.append(flame)
		var light := OmniLight3D.new()
		light.position.y = 1.6
		light.light_color = Color("ffab48")
		light.light_energy = 3.2
		light.omni_range = 6.5
		holder.add_child(light)
	build_set_dressing()
	build_wall_details()
	for cell in ([Vector2i(3,3),Vector2i(7,6),Vector2i(9,9),Vector2i(17,8),Vector2i(23,16),Vector2i(32,10),Vector2i(36,16)] if game.level_index==0 else game.map.emblems):
		for i in 4:
			var at := at3(Level.center(cell))+Vector3(sin(i*12.3)*0.32,0.06,cos(i*7.1)*0.32)
			var rubble := box(architecture,at,Vector3(0.13+i*0.025,0.10,0.12),Color("687479"))
			rubble.rotation.y = i*1.7
	portal = Node3D.new()
	portal.position = at3(game.map.exit)
	architecture.add_child(portal)
	cylinder(portal,Vector3(0,0.11,0),1.0,0.16,Color("536d71"))
	cylinder(portal,Vector3(0,0.22,0),0.85,0.12,Color("859a94"))
	var arch := ring(portal,Vector3(0,1.0,0),0.88,0.15,Color("b6ad87"))
	arch.rotation.x = PI/2
	var magic := ring(portal,Vector3(0,1.0,0.025),0.73,0.055,Color("84efd1"),2.2)
	magic.rotation.x = PI/2
	objects["portal_ring"] = magic
	var veil_shape := PlaneMesh.new()
	veil_shape.size = Vector2(1.43,1.43)
	var veil := MeshInstance3D.new()
	veil.mesh = veil_shape
	var veil_material := ShaderMaterial.new()
	veil_material.shader = preload("res://examples/gauntlet/shaders/portal.gdshader")
	veil.material_override = veil_material
	veil.position = Vector3(0,1.0,0.04)
	veil.rotation.x = PI/2
	portal.add_child(veil)
	for side in [-1,1]:
		box(portal,Vector3(side*0.91,0.57,0),Vector3(0.25,1.15,0.38),Color("748687"))
		ball(portal,Vector3(side*0.91,1.28,0),Vector3(0.18,0.25,0.18),Color("9dffe0"),2)
	var label := Label3D.new()
	label.text = "EXIT"
	label.position = Vector3(0,2.25,0)
	label.font_size = 50
	label.pixel_size = 0.009
	label.outline_size = 10
	label.modulate = Color("c0ffe5")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	portal.add_child(label)
	for i in game.generators.size():
		var generator: Dictionary = game.generators[i]
		var tower := Node3D.new()
		tower.position = at3(generator.pos)
		architecture.add_child(tower)
		tower.add_child(Props.instance("SummoningAltar"))
		var crystal := ball(tower,Vector3(0,1.05,0),Vector3(0.48,0.65,0.48),Color("bc53d0") if generator.kind=="ghost" else Color("e77738"),0.6)
		objects["crystal-%d"%i] = crystal
		objects["generator-%d"%i] = tower

func hero_model(kind: int, color_index := -1) -> Node3D:
	var actor := preload("res://examples/gauntlet/hero_actor.gd").new()
	actor.configure(self,kind,color_index)
	return actor

func enemy_model(kind: String) -> Node3D:
	var actor := preload("res://examples/gauntlet/enemy_actor.gd").new()
	actor.configure(kind)
	return actor

func pickup_model(kind: String, key_color := "gold") -> Node3D:
	var root := Node3D.new()
	match kind:
		"gold": root.add_child(Props.instance("VaultChest",0.48))
		"key":
			var key := Props.instance("RunicKey",1.15)
			root.add_child(key)
			for part: MeshInstance3D in key.find_children("*","MeshInstance3D",true,false):
				part.material_override = material(Level.Campaign.KEY_COLORS[key_color],0.55,0.3)
		"potion": root.add_child(Props.instance("JadePotion",0.62))
		"food": root.add_child(Props.instance("FeastPlatter",1.15))
	return root

func key_label(parent: Node3D, color: String, height: float, offset := Vector3.ZERO) -> void:
	var label := Label3D.new()
	label.text = color.capitalize()
	label.position = offset+Vector3.UP*height
	label.font_size = 26
	label.pixel_size = 0.009
	label.outline_size = 7
	label.modulate = Level.Campaign.KEY_COLORS[color]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)

func _process(delta: float) -> void:
	if not architecture: return
	update_camera(delta)
	visibility.update(game.heroes,game.phase,game.map.exit,game.doors)
	party_fog.present(camera,game.clock)
	var seen := {}
	for id: int in game.heroes:
		var hero: Dictionary = game.heroes[id]
		var key := "hero-%d"%id
		seen[key] = true
		if actors.has(key) and (actors[key].get_meta("class")!=hero.hero_class or actors[key].get_meta("color_index")!=hero.color_index):
			actors[key].queue_free()
			actors.erase(key)
		if not actors.has(key):
			var model := hero_model(hero.hero_class,hero.color_index)
			add_child(model)
			actors[key] = model
			var label := Label3D.new()
			label.name = "Number"
			label.text = "%02d"%id
			label.position = Vector3(0,2.30,0)
			label.font_size = 50
			label.pixel_size = 0.008
			label.outline_size = 12
			label.modulate = game.color_for(hero).lightened(0.3)
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			model.add_child(label)
			var halo := ring(model,Vector3(0,0.10,0),0.4,0.025,game.color_for(hero),0.5)
			halo.name = "Halo"
		var actor: Node3D = actors[key]
		actor.position = at3(hero.pos)
		var progress := clampf((game.clock-float(hero.get("exit_at",game.clock)))/0.45,0,1) if hero.escaped else 0.0
		actor.scale = Vector3.ONE*maxf(0.001,1.0-progress)*1.05
		actor.visible = progress<1.0
		actor.present(hero,delta,game.phase=="playing",game.elapsed)
		actor.damage_feedback.present(hero,game.elapsed)
		actor.get_node("Number").text = "%02d%s" % [id," +" if hero.hp<=0 else ""]
	for enemy: Dictionary in game.enemies:
		var key := "enemy-%d"%enemy.id
		seen[key] = true
		if not actors.has(key):
			actors[key] = enemy_model(enemy.kind)
			add_child(actors[key])
			var feedback := preload("res://examples/gauntlet/damage_feedback.gd").new()
			feedback.name = "DamageFeedback"
			actors[key].add_child(feedback)
			feedback.configure(actors[key],true,1.60 if enemy.kind=="ghost" else 1.88)
		var actor: Node3D = actors[key]
		var position3 := at3(enemy.pos)
		var direction := position3-actor.position
		if game.phase=="playing" and Vector2(direction.x,direction.z).length()>0.003:
			actor.rotation.y = lerp_angle(actor.rotation.y,atan2(direction.x,direction.z),1.0-exp(-delta*12.0))
		actor.visible = visibility.visibility_at(enemy.pos/32.0)>0
		actor.position = position3
		actor.present(enemy,Vector2(direction.x,direction.z).length(),delta,game.clock,game.phase=="playing")
		var feedback: Node3D = actor.get_node("DamageFeedback")
		feedback.present(enemy,game.elapsed)
		actor.scale = Vector3.ONE+Vector3(0.04,-0.065,0.04)*feedback.recoil
		actor.rotation.z = feedback.recoil*0.045
	for pickup: Dictionary in game.pickups:
		var key := "pickup-%s-%s" % [pickup.kind,pickup.pos]
		seen[key] = true
		if not actors.has(key):
			actors[key] = pickup_model(pickup.kind,pickup.get("key_color","gold"))
			add_child(actors[key])
			if pickup.kind=="key":
				var color: String = pickup.get("key_color","gold")
				key_label(actors[key],color,0.95)
				for part in actors[key].get_children():
					if part is MeshInstance3D: part.material_override = material(Level.Campaign.KEY_COLORS[color],0.5,0.4)
		actors[key].visible = visibility.visibility_at(pickup.pos/32.0)>0
		actors[key].position = at3(pickup.pos)
		if pickup.kind in ["key","potion"]:
			actors[key].position.y = 0.08+sin(game.clock*2+pickup.pos.x)*0.04
			actors[key].rotation.y = game.clock*0.6
	for gate: Node3D in gates.values():
		var unlocked: bool = gate.cells.all(func(cell): return not game.doors.has(cell))
		gate.visible = gate.cells.any(func(cell): return visibility.visibility_at(Vector2(cell)+Vector2.ONE*.5)>0)
		gate.present(unlocked,delta if game.phase=="playing" else 0.0)
	for key: String in actors.keys():
		if not seen.has(key):
			actors[key].queue_free()
			actors.erase(key)
	portal.visible = visibility.visibility_at(game.map.exit/32.0)>0
	for i in game.generators.size():
		objects["generator-%d"%i].visible = visibility.visibility_at(game.generators[i].pos/32.0)>0
		var crystal: Node3D = objects.get("crystal-%d"%i)
		if crystal:
			crystal.visible = game.generators[i].hp>0
			crystal.rotation.y = game.clock
			crystal.position.y = 1.05+sin(game.clock*3+i)*0.09
			objects["generator-%d"%i].scale.y = 1.0 if game.generators[i].hp>0 else 0.3
	for i in torches.size():
		var holder: Node3D = torches[i].get_parent()
		holder.visible = visibility.visibility_at(Vector2(holder.position.x,holder.position.z))>0
		torches[i].scale.y = 0.62+sin(game.clock*9+i)*0.06
	# Reuse a bounded pool for bullets, portal motes and expanding spell rings.
	var needed: int = mini(220,game.shots.size()+game.sparks.size()+12)
	while effects.size()<needed:
		var effect := ball(self,Vector3.ZERO,Vector3.ONE*0.1,Color("ffeeac"),1.5)
		effects.append(effect)
	for i in effects.size():
		var effect := effects[i]
		effect.visible = i<needed
		if i>=needed: continue
		if i<game.shots.size():
			var shot: Dictionary = game.shots[i]
			var arrow: bool = shot.get("kind","")=="arrow" or (shot.owner>0 and shot.get("hero_class",0)==3)
			effect.position = at3(shot.pos,1.15 if shot.owner>0 else 0.7)
			effect.rotation = Vector3(0,atan2(shot.velocity.x,shot.velocity.y),0)
			if arrow:
				effect.mesh = arrow_mesh()
				effect.scale = Vector3.ONE
				effect.material_override = null
			else:
				effect.mesh = particle_mesh
				effect.scale = Vector3(0.095,0.095,0.42) if shot.owner>0 else Vector3(0.14,0.14,0.24)
				effect.material_override = material(Color("fca266") if shot.owner==0 else Color("8dbedb"),0,1.0)
		elif i<game.shots.size()+game.sparks.size():
			var spark: Dictionary = game.sparks[i-game.shots.size()]
			var radius: float = Level.magic_radius(spark.life)/32.0 if spark.kind=="magic" else (1.0-spark.life/0.35)*0.65
			if not effect.mesh is TorusMesh:
				var torus := TorusMesh.new()
				torus.inner_radius = 0.95; torus.outer_radius = 1.0; torus.rings = 32; torus.ring_segments = 6
				effect.mesh = torus
			effect.position = at3(spark.pos,0.15)
			effect.scale = Vector3(maxf(0.01,radius),0.12,maxf(0.01,radius))
			effect.rotation = Vector3.ZERO
			effect.material_override = material(spark.color,0,1)
		else:
			effect.mesh = particle_mesh
			effect.material_override = material(Color("8affe0"),0,1.5)
			var angle: float = game.clock*0.75+i*TAU/12
			effect.position = portal.position+Vector3(cos(angle)*0.66,1+sin(angle)*0.66,0.03)
			effect.scale = Vector3.ONE*0.055

	for effect in effects:
		if effect.visible: effect.visible = visibility.visibility_at(Vector2(effect.position.x,effect.position.z))>0

func bake_meshes(parent: Node3D, key: String) -> void:
	# Bake fixed details to one vertex-colored mesh; keep the animated leg nodes separate.
	# Reuse these meshes across all heroes/monsters instead of submitting each eye/boot.
	if not model_meshes.has(key):
		var builder := SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		for child in parent.get_children():
			if not child is MeshInstance3D: continue
			var arrays: Array = child.mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var color: Color = child.material_override.albedo_color
			var normal_basis: Basis = child.transform.basis.inverse().transposed()
			for index in indices:
				builder.set_color(color.srgb_to_linear())
				builder.set_normal((normal_basis*normals[index]).normalized())
				builder.add_vertex(child.transform*vertices[index])
		builder.index()
		var surface := StandardMaterial3D.new()
		surface.vertex_color_use_as_albedo = true
		surface.roughness = 0.75
		builder.set_material(surface)
		model_meshes[key] = builder.commit()
	for child in parent.get_children():
		if child is MeshInstance3D:
			parent.remove_child(child)
			child.free()
	var instance := MeshInstance3D.new()
	instance.mesh = model_meshes[key]
	parent.add_child(instance)

func update_camera(delta: float) -> void:
	if not camera: return
	# Fallen teammates still need rescuing; only escaped/disconnected heroes leave the frame.
	var party: Array = game.heroes.values().filter(func(hero): return not hero.escaped)
	var low := Vector2(3,12)
	var high := Vector2(9,18)
	if not party.is_empty():
		low = party[0].pos/32.0
		high = low
		for hero: Dictionary in party:
			low = low.min(hero.pos/32.0)
			high = high.max(hero.pos/32.0)
	elif game.phase=="complete":
		low = game.map.exit/32.0
		high = low
	var aspect := float(get_viewport().size.x)/maxf(1,get_viewport().size.y)
	var desired := maxf(DEFAULT_CAMERA_SIZE,maxf((high.x-low.x)/aspect+5.0,(high.y-low.y)*0.77+5.0))
	var center := (low+high)*0.5
	if overview:
		desired = maxf(game.map.height*0.77+7.0,(game.map.width+6.0)/aspect)
		center = Vector2(game.map.width,game.map.height)*0.5
	var half_x := desired*aspect*0.5
	var half_z := desired/1.54
	center.x = clampf(center.x,half_x-1,game.map.width+1-half_x) if half_x<(game.map.width+2)*0.5 else game.map.width*0.5
	center.y = clampf(center.y,half_z-1,game.map.height+1-half_z) if half_z<(game.map.height+2)*0.5 else game.map.height*0.5
	var weight := minf(1,delta*3.0)
	camera_target = camera_target.lerp(Vector3(center.x,0.5,center.y),weight)
	camera.size = lerpf(camera.size,desired,weight)
	camera.position = camera_target+Vector3(0,28,24)
	camera.look_at(camera_target)
	# Smooth recentering/zoom-in, but expand immediately if that smoothing would crop anyone.
	# Measure both feet and labels in the actual camera basis, with a 10% edge margin.
	var required := DEFAULT_CAMERA_SIZE
	for hero: Dictionary in party:
		for height in [0.0,2.4]:
			var offset := at3(hero.pos,height)-camera_target
			required = maxf(required,absf(camera.global_basis.y.dot(offset))*2.0/0.90)
			required = maxf(required,absf(camera.global_basis.x.dot(offset))*2.0/(aspect*0.90))
	camera.size = maxf(camera.size,required)

func toggle_overview() -> void:
	overview = not overview
	update_camera(1.0)
	game.announce("FULL DUNGEON VIEW" if overview else "AUTOMATIC PARTY CAMERA")

func toggle_quality() -> void:
	high_quality = not high_quality
	if RenderingServer.get_current_rendering_method()=="forward_plus":
		environment_settings.ssao_enabled = high_quality
		environment_settings.volumetric_fog_enabled = high_quality
		get_viewport().scaling_3d_scale = 1.0 if high_quality else 0.75
	get_viewport().msaa_3d = Viewport.MSAA_2X if high_quality else Viewport.MSAA_DISABLED
	key_light.shadow_enabled = high_quality
	environment_settings.glow_enabled = high_quality
	game.announce("CINEMATIC LIGHTING" if high_quality else "PERFORMANCE LIGHTING")

func build_set_dressing() -> void:
	# Every tall support sits on an existing solid tile; floor ornament stays below feet.
	var columns: Array[Transform3D] = []
	for cell in ([Vector2i(0,3),Vector2i(0,8),Vector2i(0,13),Vector2i(12,13),Vector2i(12,16),Vector2i(26,4),Vector2i(26,7),Vector2i(39,3),Vector2i(39,8),Vector2i(39,13)] if game.level_index==0 else game.map.columns):
		if game.map.get("door_sites",game.doors).keys().any(func(site): return Vector2(site).distance_to(Vector2(cell))<2.0): continue
		var at := at3(Level.center(cell))
		columns.append(Transform3D(Basis.IDENTITY,at+Vector3(0,1.05,0)))
		for y in [0.14,1.86,2.03]:
			box(architecture,at+Vector3(0,y,0),Vector3(0.94,0.14,0.94),Color("747c7c"))
		for y in [0.28,1.7]:
			ring(architecture,at+Vector3(0,y,0),0.35,0.04,Color("a89563"))
	batch_boxes(architecture,columns,Vector3(0.62,1.65,0.62),Color.WHITE)
	# One unobstructed, persistent gate per lock. Open passages keep their color and state label.
	var sites: Dictionary = game.map.get("door_sites",game.doors)
	for group: int in game.map.door_colors:
		var cells: Array = sites.keys().filter(func(cell): return sites[cell]==group)
		if cells.is_empty(): continue
		var gate := preload("res://examples/gauntlet/gate_view.gd").new()
		architecture.add_child(gate)
		gate.configure(self,cells,game.map.door_colors[group],game.map.get("door_axes",{}).get(group,true))
		gate.present(cells.all(func(cell): return not game.doors.has(cell)),1.0)
		gates[group] = gate
	if game.level_index>0: return
	# Worn runner and embroidered borders distinguish the entrance hall.
	var cloth := material(Color("522b32"))
	cloth.roughness = 1.0
	box(architecture,Vector3(5.5,0.056,15.1),Vector3(2.0,0.015,6.0),Color("522b32"))
	for side in [-1,1]:
		box(architecture,Vector3(5.5+side*0.90,0.067,15.1),Vector3(0.024,0.008,5.9),Color("a68b54"))
		for z in 18:
			var stitch := box(architecture,Vector3(5.5+side*0.81,0.071,12.3+z*0.32),Vector3(0.07,0.008,0.07),Color("aa905c"))
			stitch.rotation.y = PI/4
	for at in [Vector3(0.94,1.20,5.5),Vector3(12.94,1.20,2.5),Vector3(26.94,1.20,11.5)]:
		box(architecture,at,Vector3(0.025,1.35,0.64),Color("522b32"))
		box(architecture,at+Vector3(0,0.72,0),Vector3(0.06,0.045,0.85),Color("b49860"),0.6)
		for side in [-1,1]: box(architecture,at+Vector3(0.02,0,side*0.28),Vector3(0.012,1.32,0.018),Color("c1a564"))

func arrow_mesh() -> ArrayMesh:
	if not model_meshes.has("arrow"):
		var root := Node3D.new()
		var shaft := cylinder(root,Vector3.ZERO,0.013,0.64,Color("9b7146"))
		shaft.rotation.x = PI/2
		var tip := cylinder(root,Vector3(0,0,0.36),0.046,0.13,Color("becad0"),0.0,0.7)
		tip.rotation.x = PI/2
		box(root,Vector3(0,0,-0.25),Vector3(0.16,0.015,0.13),Color("d7d3bc"))
		box(root,Vector3(0,0,-0.25),Vector3(0.015,0.16,0.13),Color("d7d3bc"))
		bake_meshes(root,"arrow")
		root.free()
	return model_meshes["arrow"]

func build_room_floors() -> void:
	# Low, varied floor motifs only where the whole inset fits existing walkable tiles.
	for index in game.map.emblems.size():
		var cell: Vector2i = game.map.emblems[index]
		var clear := true
		for dy in range(-1,2):
			for dx in range(-1,2):
				var tile := cell+Vector2i(dx,dy)
				if game.walls.has(tile) or game.map.get("door_sites",game.doors).has(tile): clear = false
		if not clear: continue
		var at := at3(Level.center(cell),0.06)
		var motif: int = (index+game.level_index)%4
		if motif==0:
			# Bronze and jade mosaic, with an open central diamond.
			for side in [-1,1]:
				for axis in 2:
					var offset := Vector3(side*1.03,0,0) if axis==0 else Vector3(0,0,side*1.03)
					box(architecture,at+offset,Vector3(.035,.012,2.08) if axis==0 else Vector3(2.08,.012,.035),Color("887754"),.4)
			for side in [-1,1]:
				for z in [-1,1]:
					var tile := box(architecture,at+Vector3(side*.65,.008,z*.65),Vector3(.26,.012,.26),Color("47736f"))
					tile.rotation.y = PI/4
		elif motif==1:
			var cloth: Color = [Color("522b32"),Color("214b48"),Color("3d3858")][game.level_index]
			box(architecture,at,Vector3(1.6,.014,2.45),cloth)
			for side in [-1,1]:
				box(architecture,at+Vector3(side*.70,.011,0),Vector3(.03,.008,2.30),Color("a58a54"))
				for n in 11:
					box(architecture,at+Vector3((n-5)*.13,.008,side*1.24),Vector3(.025,.009,.12),Color("9a865f"))
		elif motif==2:
			for side in [-1,1]:
				var grate := Props.instance("FloorGrate")
				grate.position = at+Vector3(side*.57,-.025,0)
				architecture.add_child(grate)
		else:
			for n in 7:
				var slab := box(architecture,at+Vector3(sin(n*2.4)*.85,.003,cos(n*2.4)*.85),Vector3(.38,.012,.29),Color("687876").darkened(n*.018))
				slab.rotation.y = n*.71

func build_wall_details() -> void:
	# Dress existing solid masonry only, away from gates. No new invisible floor obstacles.
	var sites: Dictionary = game.map.get("door_sites",game.doors)
	for cell: Vector2i in game.walls:
		if (cell.x*13+cell.y*7)%19!=0: continue
		if sites.keys().any(func(site): return Vector2(site).distance_to(Vector2(cell))<2.5): continue
		var south := cell+Vector2i.DOWN
		if game.walls.has(south) or south.y>=game.map.height: continue
		if game.map.has("floor") and not game.map.floor.has(south): continue
		var prop := Props.instance("CeramicUrn" if (cell.x+cell.y)%2==0 else "OakBarrel",0.65)
		prop.position = at3(Level.center(cell),.89)
		prop.rotation.y = cell.x*.7
		architecture.add_child(prop)
		var relief := Props.instance("WingRelief",.78)
		relief.position = at3(Level.center(cell),.03)+Vector3(0,0,.48)
		architecture.add_child(relief)
