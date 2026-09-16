extends Node3D
## Presentation only. All gameplay, navigation and hit tests remain in the 2D simulation.
const Level = preload("res://examples/gauntlet/level.gd")
var game: Node
var camera: Camera3D
var architecture: Node3D
var actors: Dictionary = {}
var objects: Dictionary = {}
var effects: Array[MeshInstance3D] = []
var torches: Array[Node3D] = []
var materials: Dictionary = {}
var model_meshes: Dictionary = {}
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
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("0d1922")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("98bccf")
	settings.ambient_light_energy = 0.28
	settings.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58,-28,0)
	sun.light_color = Color("ffdcad")
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80
	add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-30,155,0)
	rim.light_color = Color("8fc5e1")
	rim.light_energy = 0.22
	add_child(rim)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 17.6
	camera.position = Vector3(20,28,33)
	add_child(camera)
	camera.look_at(Vector3(20,0,10))
	camera.current = true

func batch_boxes(parent: Node3D, transforms: Array[Transform3D], size: Vector3, color: Color) -> void:
	if transforms.is_empty(): return
	var shape := BoxMesh.new()
	shape.size = size
	var stone := ShaderMaterial.new()
	stone.shader = preload("res://examples/gauntlet/shaders/stone.gdshader")
	stone.set_shader_parameter("stone_color",color)
	shape.material = stone
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = shape
	batch.instance_count = transforms.size()
	for i in transforms.size(): batch.set_instance_transform(i,transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = batch
	parent.add_child(instance)

func rebuild() -> void:
	if architecture:
		remove_child(architecture)
		architecture.queue_free()
	for actor: Node3D in actors.values(): actor.queue_free()
	actors.clear()
	objects.clear()
	torches.clear()
	architecture = Node3D.new()
	add_child(architecture)
	box(architecture,Vector3(20,-0.42,10),Vector3(40.6,0.7,20.6),Color("283c49"))
	box(architecture,Vector3(20,-0.06,10),Vector3(40,0.15,20),Color("202f38"))
	for variant in 5:
		var tiles: Array[Transform3D] = []
		var bricks: Array[Transform3D] = []
		var crowns: Array[Transform3D] = []
		for y in Level.HEIGHT:
			for x in Level.WIDTH:
				var cell := Vector2i(x,y)
				if (x*17+y*31)%5 != variant: continue
				var at := Vector3(x+0.5,0,y+0.5)
				tiles.append(Transform3D(Basis.IDENTITY,at))
				if game.walls.has(cell):
					bricks.append(Transform3D(Basis.IDENTITY,at+Vector3(0,0.27,0)))
					bricks.append(Transform3D(Basis.IDENTITY,at+Vector3(0,0.60,0)))
					crowns.append(Transform3D(Basis.IDENTITY,at+Vector3(0,0.82,0)))
		batch_boxes(architecture,tiles,Vector3(0.973,0.09,0.973),Color("35434a").lightened(variant*0.013))
		batch_boxes(architecture,bricks,Vector3(0.97,0.30,0.97),Color("475967").lightened(variant*0.017))
		batch_boxes(architecture,crowns,Vector3(0.965,0.12,0.965),Color("6c777b").lightened(variant*0.012))
	# Brass inlaid room emblems and broken masonry give the floor a sense of place.
	for cell in [Vector2i(6,12),Vector2i(19,6),Vector2i(19,13),Vector2i(34,5)]:
		var at := at3(Level.center(cell),0.07)
		ring(architecture,at,1.3,0.018,Color("988459"))
		ring(architecture,at,1.15,0.014,Color("988459"))
		for i in 8:
			var spoke := box(architecture,at+Vector3(sin(i*PI/4)*0.9,0,cos(i*PI/4)*0.9),Vector3(0.08,0.02,0.26),Color("ad965f"),0.4)
			spoke.rotation.y = i*PI/4
	for cell in [Vector2i(4,4),Vector2i(6,5),Vector2i(8,8),Vector2i(16,4),Vector2i(23,15),Vector2i(30,8),Vector2i(35,15)]:
		var at := at3(Level.center(cell),0.9)
		cylinder(architecture,at+Vector3(0,0.16,0),0.4,0.32,Color("9babae"),0.34)
		box(architecture,at+Vector3(0,0.37,0),Vector3(0.84,0.1,0.84),Color("c0b58d"),0.2)
	for cell in [Vector2i(1,7),Vector2i(11,11),Vector2i(13,2),Vector2i(25,16),Vector2i(27,10),Vector2i(38,4)]:
		var holder := Node3D.new()
		holder.position = at3(Level.center(cell))
		architecture.add_child(holder)
		cylinder(holder,Vector3(0,0.42,0),0.13,0.8,Color("4e4540"),-1,0.7)
		cylinder(holder,Vector3(0,0.86,0),0.15,0.2,Color("ae8250"),0.27,0.6)
		var flame := ball(holder,Vector3(0,1.12,0),Vector3(0.3,0.62,0.3),Color("ffbd60"),2.0)
		ball(flame,Vector3(0,0.03,0),Vector3(0.5,0.8,0.5),Color("fff6ce"),2.0)
		torches.append(flame)
		if torches.size()%2==0:
			var light := OmniLight3D.new()
			light.position.y = 1.5
			light.light_color = Color("ffb65b")
			light.light_energy = 1.2
			light.omni_range = 5
			holder.add_child(light)
	for cell in [Vector2i(3,3),Vector2i(7,6),Vector2i(9,9),Vector2i(17,8),Vector2i(23,16),Vector2i(32,10),Vector2i(36,16)]:
		for i in 4:
			var at := at3(Level.center(cell))+Vector3(sin(i*12.3)*0.32,0.06,cos(i*7.1)*0.32)
			var rubble := box(architecture,at,Vector3(0.13+i*0.025,0.10,0.12),Color("687479"))
			rubble.rotation.y = i*1.7
	portal = Node3D.new()
	portal.position = at3(Level.EXIT)
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
		cylinder(tower,Vector3(0,0.15,0),0.65,0.26,Color("4c485f"))
		cylinder(tower,Vector3(0,0.40,0),0.46,0.32,Color("897b91"),0.37)
		for side in 4:
			var a := side*PI/2+PI/4
			var pillar := box(tower,Vector3(sin(a)*0.35,0.85,cos(a)*0.35),Vector3(0.13,0.90,0.13),Color("a39aa7"),0.3)
			pillar.rotation.z = -sin(a)*0.15
		var crystal := ball(tower,Vector3(0,1.05,0),Vector3(0.48,0.65,0.48),Color("bc53d0") if generator.kind=="ghost" else Color("e77738"),0.6)
		objects["crystal-%d"%i] = crystal
		objects["generator-%d"%i] = tower

func hero_model(kind: int) -> Node3D:
	var root := Node3D.new()
	var color := Color(Level.CLASSES[kind].color)
	var skin := Color("efd2ae")
	var leather := Color("574641")
	# Articulated legs, layered tunic, breastplate and cape.
	for side in [-1,1]:
		var leg := Node3D.new()
		leg.name = "LegL" if side==-1 else "LegR"
		leg.position = Vector3(side*0.13,0.30,0)
		root.add_child(leg)
		cylinder(leg,Vector3(0,-0.03,0),0.095,0.30,color.darkened(0.3))
		ball(leg,Vector3(0,-0.23,0.06),Vector3(0.22,0.18,0.34),leather)
	cylinder(root,Vector3(0,0.61,0),0.27,0.53,color,0.22)
	box(root,Vector3(0,0.65,0.26),Vector3(0.32,0.34,0.12),Color("d2ccbb") if kind in [0,1] else color.lightened(0.18),0.4 if kind<2 else 0)
	var cape := box(root,Vector3(0,0.63,-0.19),Vector3(0.44,0.55,0.07),color.darkened(0.36))
	cape.rotation.x = -0.20
	cylinder(root,Vector3(0,0.45,0),0.275,0.08,leather)
	box(root,Vector3(0,0.45,0.27),Vector3(0.10,0.10,0.025),Color("f0c76d"),0.7)
	ball(root,Vector3(0,1.02,0),Vector3(0.44,0.47,0.43),skin)
	for side in [-1,1]:
		ball(root,Vector3(side*0.095,1.06,0.204),Vector3(0.047,0.063,0.025),Color("25313b"))
		ball(root,Vector3(side*0.30,0.75,0),Vector3(0.22,0.23,0.27),color.lightened(0.25))
		ball(root,Vector3(side*0.32,0.54,0.10),Vector3(0.13,0.19,0.14),skin)
	match kind:
		0:
			ball(root,Vector3(0,1.20,0),Vector3(0.48,0.22,0.46),Color("bac9ce"))
			for side in [-1,1]:
				var horn := cylinder(root,Vector3(side*0.28,1.26,0),0.07,0.35,Color("f3dfb5"),0.01)
				horn.rotation.z = -side*0.7
			cylinder(root,Vector3(0.4,0.62,0.20),0.035,0.95,leather)
			box(root,Vector3(0.4,1.03,0.20),Vector3(0.4,0.25,0.075),Color("c1d2d6"),0.7)
		1:
			ball(root,Vector3(0,1.19,0),Vector3(0.46,0.18,0.45),Color("e7c57b"))
			for side in [-1,1]:
				var wing := ball(root,Vector3(side*0.27,1.27,0),Vector3(0.12,0.37,0.16),Color("e3ece5"))
				wing.rotation.z = -side*0.4
			var shield := cylinder(root,Vector3(-0.38,0.62,0.18),0.29,0.08,Color("b8d3db"),-1,0.65)
			shield.rotation.x = PI/2
			ball(root,Vector3(-0.38,0.62,0.24),Vector3(0.12,0.12,0.07),Color("e5c26f"))
			box(root,Vector3(0.37,0.90,0.17),Vector3(0.065,0.75,0.045),Color("e5eeed"),0.8)
			box(root,Vector3(0.37,0.63,0.17),Vector3(0.22,0.04,0.07),Color("e5c26f"),0.7)
		2:
			cylinder(root,Vector3(0,1.19,0),0.34,0.06,color)
			cylinder(root,Vector3(0,1.43,0),0.25,0.48,color,0.015)
			ball(root,Vector3(0,0.88,0.19),Vector3(0.26,0.30,0.14),Color("ebdfd5"))
			cylinder(root,Vector3(0.4,0.7,0.13),0.035,1.3,leather)
			ball(root,Vector3(0.4,1.39,0.13),Vector3(0.19,0.27,0.19),Color("c6a1ff"),1.2)
		3:
			cylinder(root,Vector3(0,1.30,0),0.27,0.35,color,0.025).rotation.z = -0.3
			for side in [-1,1]: ball(root,Vector3(side*0.25,1.01,0),Vector3(0.19,0.10,0.1),skin)
			var bow := ring(root,Vector3(0.38,0.70,0.2),0.30,0.025,Color("d7b779"))
			bow.rotation.z = PI/2
	bake_meshes(root,"hero-%d"%kind)
	bake_meshes(root.get_node("LegL"),"leg-%d"%kind)
	bake_meshes(root.get_node("LegR"),"leg-%d"%kind)
	root.set_meta("class",kind)
	return root

func enemy_model(kind: String) -> Node3D:
	var root := Node3D.new()
	if model_meshes.has("enemy-"+kind):
		var instance := MeshInstance3D.new()
		instance.mesh = model_meshes["enemy-"+kind]
		root.add_child(instance)
		return root
	if kind=="ghost":
		ball(root,Vector3(0,0.65,0),Vector3(0.5,0.7,0.5),Color("bbcfdf"),0.3)
		cylinder(root,Vector3(0,0.37,0),0.33,0.35,Color("c6d5e0"),0.21)
		for side in [-1,1]: ball(root,Vector3(side*0.1,0.78,0.22),Vector3(0.07,0.11,0.04),Color("242940"))
	else:
		var color := Color("a0a680") if kind=="grunt" else Color("c66651")
		ball(root,Vector3(0,0.54,0),Vector3(0.6,0.65,0.4),color)
		ball(root,Vector3(0,0.96,0),Vector3(0.42,0.43,0.39),color.lightened(0.1))
		for side in [-1,1]:
			ball(root,Vector3(side*0.18,0.14,0.04),Vector3(0.2,0.25,0.3),Color("4f514b"))
			ball(root,Vector3(side*0.30,0.64,0),Vector3(0.22,0.34,0.28),color)
			ball(root,Vector3(side*0.085,1.0,0.185),Vector3(0.05,0.045,0.03),Color("ffdc8b"),1)
			if kind=="demon":
				var horn := cylinder(root,Vector3(side*0.2,1.2,0),0.07,0.38,Color("efcc9f"),0.008)
				horn.rotation.z = side*0.4
		if kind=="grunt":
			box(root,Vector3(0,0.7,0.2),Vector3(0.43,0.28,0.06),Color("596869"),0.4)
			cylinder(root,Vector3(0.40,0.7,0.12),0.09,0.75,Color("7e6250"),0.16)
	bake_meshes(root,"enemy-"+kind)
	return root

func pickup_model(kind: String) -> Node3D:
	var root := Node3D.new()
	match kind:
		"gold":
			box(root,Vector3(0,0.17,0),Vector3(0.46,0.30,0.33),Color("80523b"))
			box(root,Vector3(0,0.34,0),Vector3(0.47,0.12,0.34),Color("d8ae59"),0.65)
			box(root,Vector3(0,0.19,0.18),Vector3(0.08,0.12,0.035),Color("ffe1a1"),0.6)
		"key":
			var hoop := ring(root,Vector3(-0.1,0.32,0),0.14,0.045,Color("ffdc7b"),0.3)
			hoop.rotation.x = PI/2
			box(root,Vector3(0.13,0.32,0),Vector3(0.4,0.07,0.07),Color("ffdc7b"),0.65)
			box(root,Vector3(0.30,0.23,0),Vector3(0.07,0.18,0.07),Color("ffdc7b"),0.65)
		"potion":
			ball(root,Vector3(0,0.25,0),Vector3(0.3,0.36,0.3),Color("b298e6"),0.3)
			cylinder(root,Vector3(0,0.48,0),0.06,0.12,Color("e2cfac"))
			cylinder(root,Vector3(0,0.40,0),0.10,0.10,Color("b8dbe4"))
		"food":
			cylinder(root,Vector3(0,0.08,0),0.34,0.06,Color("d3c6a5"),-1,0.35)
			ball(root,Vector3(0,0.21,0),Vector3(0.43,0.26,0.35),Color("c89154"))
			ball(root,Vector3(0.16,0.22,0.13),Vector3(0.12,0.12,0.22),Color("f1d1a0"))
	return root

func _process(_delta: float) -> void:
	if not architecture: return
	var seen := {}
	for id: int in game.heroes:
		var hero: Dictionary = game.heroes[id]
		var key := "hero-%d"%id
		seen[key] = true
		if actors.has(key) and actors[key].get_meta("class")!=hero.hero_class:
			actors[key].queue_free()
			actors.erase(key)
		if not actors.has(key):
			var model := hero_model(hero.hero_class)
			add_child(model)
			actors[key] = model
			var label := Label3D.new()
			label.name = "Number"
			label.text = "%02d"%id
			label.position = Vector3(0,1.95,0)
			label.font_size = 50
			label.pixel_size = 0.008
			label.outline_size = 12
			label.modulate = Color(Level.CLASSES[hero.hero_class].color).lightened(0.3)
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			model.add_child(label)
			var halo := ring(model,Vector3(0,0.10,0),0.4,0.025,Color(Level.CLASSES[hero.hero_class].color),0.5)
			halo.name = "Halo"
		var actor: Node3D = actors[key]
		actor.position = at3(hero.pos)
		actor.rotation.y = atan2(hero.face.x,hero.face.y)
		actor.rotation.z = PI/2 if hero.hp<=0 else 0.0
		var progress := clampf((game.clock-float(hero.get("exit_at",game.clock)))/0.45,0,1) if hero.escaped else 0.0
		actor.scale = Vector3.ONE*maxf(0.001,1.0-progress)*1.15
		actor.visible = progress<1.0
		if hero.hp>0 and not hero.escaped:
			actor.get_node("LegL").rotation.x = sin(hero.walk)*0.55
			actor.get_node("LegR").rotation.x = -sin(hero.walk)*0.55
			actor.position.y = absf(sin(hero.walk))*0.025
		actor.get_node("Number").text = "%02d%s" % [id," +" if hero.hp<=0 else ""]
	for enemy: Dictionary in game.enemies:
		var key := "enemy-%d"%enemy.id
		seen[key] = true
		if not actors.has(key):
			actors[key] = enemy_model(enemy.kind)
			add_child(actors[key])
		var actor: Node3D = actors[key]
		var position3 := at3(enemy.pos)
		var direction := position3-actor.position
		if Vector2(direction.x,direction.z).length()>0.003: actor.rotation.y = atan2(direction.x,direction.z)
		actor.position = position3
		actor.position.y = sin(game.clock*4+enemy.id)*0.08 if enemy.kind=="ghost" else absf(sin(game.clock*7+enemy.id))*0.025
	for pickup: Dictionary in game.pickups:
		var key := "pickup-%s-%s" % [pickup.kind,pickup.pos]
		seen[key] = true
		if not actors.has(key):
			actors[key] = pickup_model(pickup.kind)
			add_child(actors[key])
		actors[key].position = at3(pickup.pos)
		if pickup.kind in ["key","potion"]:
			actors[key].position.y = 0.08+sin(game.clock*2+pickup.pos.x)*0.04
			actors[key].rotation.y = game.clock*0.6
	for cell: Vector2i in game.doors:
		var key := "door-%s"%cell
		seen[key] = true
		if not actors.has(key):
			var door := Node3D.new()
			add_child(door)
			door.position = at3(Level.center(cell))
			for bar in 4: box(door,Vector3(0,0.46,-0.4+bar*0.26),Vector3(0.19,0.9,0.07),Color("ba9253"),0.65)
			box(door,Vector3(0,0.82,0),Vector3(0.24,0.08,0.99),Color("d5b877"),0.6)
			box(door,Vector3(0,0.23,0),Vector3(0.24,0.08,0.99),Color("d5b877"),0.6)
			actors[key] = door
	for key: String in actors.keys():
		if not seen.has(key):
			actors[key].queue_free()
			actors.erase(key)
	for i in game.generators.size():
		var crystal: Node3D = objects.get("crystal-%d"%i)
		if crystal:
			crystal.visible = game.generators[i].hp>0
			crystal.rotation.y = game.clock
			crystal.position.y = 1.05+sin(game.clock*3+i)*0.09
			objects["generator-%d"%i].scale.y = 1.0 if game.generators[i].hp>0 else 0.3
	for i in torches.size():
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
			effect.mesh = particle_mesh
			var shot: Dictionary = game.shots[i]
			effect.position = at3(shot.pos,0.7)
			effect.scale = Vector3(0.12,0.12,0.28)
			effect.rotation.y = atan2(shot.velocity.x,shot.velocity.y)
			effect.material_override = material(Color("fca266") if shot.owner==0 else Color("e8dbad"),0,1.5)
		elif i<game.shots.size()+game.sparks.size():
			var spark: Dictionary = game.sparks[i-game.shots.size()]
			var radius: float = (1.0-spark.life/0.65)*6.25 if spark.kind=="magic" else (1.0-spark.life/0.35)*0.65
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
