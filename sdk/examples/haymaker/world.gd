extends RefCounted
## Grapital-inspired city plaza: original meshes with generated PBR textures.

const Art = preload("res://examples/haymaker/assets.gd")

static func material(color: Color, roughness := 0.82, emission := 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	if emission > 0.0:
		result.emission_enabled = true
		result.emission = color
		result.emission_energy_multiplier = emission
	return result


static func mesh(parent: Node3D, shape: Mesh, at: Vector3, color: Color, roughness := 0.82) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = shape
	instance.material_override = material(color, roughness)
	instance.position = at
	parent.add_child(instance)
	return instance


static func apply_mat(node: MeshInstance3D, mat: Material) -> MeshInstance3D:
	node.material_override = mat
	return node


static func box(parent: Node3D, at: Vector3, size: Vector3, color: Color, solid := false, roughness := 0.82) -> MeshInstance3D:
	return textured_box(parent, at, size, material(color, roughness), solid)


static func textured_box(parent: Node3D, at: Vector3, size: Vector3, mat: Material, solid := false) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = shape
	instance.material_override = mat
	instance.position = at
	parent.add_child(instance)
	if solid:
		_collision(parent, _box_shape(size), at)
	return instance


static func _box_shape(size: Vector3) -> BoxShape3D:
	var shape := BoxShape3D.new()
	shape.size = size
	return shape


static func cylinder(parent: Node3D, at: Vector3, radius: float, height: float, color: Color, solid := false, roughness := 0.82) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 48 if radius > 8.0 else 20
	var instance := MeshInstance3D.new()
	instance.mesh = shape
	instance.material_override = material(color, roughness)
	instance.position = at
	parent.add_child(instance)
	if solid:
		var collision := CylinderShape3D.new()
		collision.radius = radius
		collision.height = height
		_collision(parent, collision, at)
	return instance


static func _collision(parent: Node3D, shape: Shape3D, at: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = at
	var node := CollisionShape3D.new()
	node.shape = shape
	body.add_child(node)
	parent.add_child(body)


static func build(root: Node3D) -> Dictionary:
	_environment(root)
	var ground := CylinderMesh.new()
	ground.top_radius = 48.0
	ground.bottom_radius = 48.0
	ground.height = 1.1
	ground.radial_segments = 72
	var ground_mesh := MeshInstance3D.new()
	ground_mesh.mesh = ground
	ground_mesh.position = Vector3(0, -0.55, 0)
	ground_mesh.material_override = Art.painted("asphalt.jpg", Color("d8c4b0"), 0.9, 0.08)
	root.add_child(ground_mesh)
	var ground_shape := CylinderShape3D.new()
	ground_shape.radius = 48.0
	ground_shape.height = 1.1
	_collision(root, ground_shape, Vector3(0, -0.55, 0))
	var plaza := CylinderMesh.new()
	plaza.top_radius = 17.2
	plaza.bottom_radius = 17.2
	plaza.height = 0.12
	plaza.radial_segments = 64
	var plaza_mesh := MeshInstance3D.new()
	plaza_mesh.mesh = plaza
	plaza_mesh.position = Vector3(0, 0.06, 0)
	plaza_mesh.material_override = Art.painted("canvas.jpg", Color("fff6e4"), 0.7, 0.14)
	root.add_child(plaza_mesh)
	_wrestling_ring(root)
	for i in 8:
		var angle := i * TAU / 8.0
		var at := Vector3(cos(angle) * 22.0, 0, sin(angle) * 22.0)
		_city_block(root, at, angle, i)
	for i in 6:
		var angle := i * TAU / 6.0 + 0.2
		_shop(root, Vector3(cos(angle) * 34.0, 0, sin(angle) * 34.0), angle, i)
	_bell_tower(root, Vector3(0, 0, -31))
	_bleachers(root)
	var pads: Array[Vector3] = [
		Vector3(0, 0.1, 0), Vector3(20, 0.1, 0), Vector3(-20, 0.1, 0),
		Vector3(0, 0.1, 20), Vector3(0, 0.1, -20)]
	for at in pads:
		_jump_pad(root, at)
	var loot: Array[Vector3] = []
	for i in 8:
		var angle := i * TAU / 8.0 + 0.18
		var spot := Vector3(cos(angle) * 14.5, 0.35, sin(angle) * 14.5)
		loot.append(spot)
		_crate(root, spot)
	var spawns: Array[Vector3] = []
	for i in 8:
		var angle := i * TAU / 8.0
		spawns.append(Vector3(cos(angle) * 28.0, 0.2, sin(angle) * 28.0))
	return {"pads": pads, "loot": loot, "spawns": spawns}


static func _environment(root: Node3D) -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("4aa7d4")
	sky_mat.sky_horizon_color = Color("ffe0b5")
	sky_mat.ground_bottom_color = Color("3b2418")
	sky_mat.ground_horizon_color = Color("c47b4a")
	sky_mat.sky_curve = 0.12
	sky_mat.sun_angle_max = 7.0
	sky.sky_material = sky_mat
	settings.sky = sky
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	settings.ambient_light_color = Color("ffe0c0")
	settings.ambient_light_energy = 0.48
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	settings.glow_enabled = true
	settings.glow_intensity = 0.5
	settings.ssao_enabled = true
	settings.ssao_radius = 1.6
	settings.ssao_intensity = 1.2
	settings.fog_enabled = true
	settings.fog_light_color = Color("f0d2a8")
	settings.fog_density = 0.0014
	environment.environment = settings
	root.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -38, 0)
	sun.light_color = Color("ffe2b0")
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 110.0
	root.add_child(sun)


static func _wrestling_ring(root: Node3D) -> void:
	textured_box(root, Vector3(0, 0.42, 0), Vector3(9.2, 0.84, 9.2), Art.painted("canvas.jpg", Color("fff3dc"), 0.65, 0.2), true)
	var posts := [Vector3(4.2, 1.15, 4.2), Vector3(-4.2, 1.15, 4.2), Vector3(4.2, 1.15, -4.2), Vector3(-4.2, 1.15, -4.2)]
	var colors: Array[Color] = [Color("e24b4b"), Color("3d8fd4"), Color("f0c43a"), Color("3cba8b")]
	for i in posts.size():
		cylinder(root, posts[i], 0.22, 1.7, colors[i], true, 0.4)
		mesh(root, SphereMesh.new(), posts[i] + Vector3(0, 0.95, 0), colors[i], 0.3).scale = Vector3(0.38, 0.22, 0.38)
	for height in [0.55, 0.95, 1.35]:
		_rope(root, Vector3(4.2, height, 4.2), Vector3(-4.2, height, 4.2), Color("ff4d8d"))
		_rope(root, Vector3(-4.2, height, 4.2), Vector3(-4.2, height, -4.2), Color("3d8fd4"))
		_rope(root, Vector3(-4.2, height, -4.2), Vector3(4.2, height, -4.2), Color("3cba8b"))
		_rope(root, Vector3(4.2, height, -4.2), Vector3(4.2, height, 4.2), Color("f0c43a"))
	var canopy := CylinderMesh.new()
	canopy.top_radius = 0.2
	canopy.bottom_radius = 3.4
	canopy.height = 1.4
	var roof := MeshInstance3D.new()
	roof.mesh = canopy
	roof.position = Vector3(0, 3.4, 0)
	roof.material_override = Art.painted("metal.jpg", Color("ff8aa0"), 0.45, 0.5)
	root.add_child(roof)


static func _rope(root: Node3D, a: Vector3, b: Vector3, color: Color) -> void:
	var mid := (a + b) * 0.5
	var length := a.distance_to(b)
	var bar := CylinderMesh.new()
	bar.top_radius = 0.05
	bar.bottom_radius = 0.05
	bar.height = length
	var node := MeshInstance3D.new()
	node.mesh = bar
	node.material_override = material(color, 0.35)
	node.position = mid
	if length > 0.05:
		node.basis = Basis.looking_at((b - a).normalized(), Vector3.UP)
		node.rotate_object_local(Vector3.RIGHT, PI / 2.0)
	root.add_child(node)


static func _city_block(root: Node3D, at: Vector3, angle: float, index: int) -> void:
	var tall := 4.4 + (index % 3) * 1.3
	var wall := Art.painted("brick.jpg" if index % 2 == 0 else "plaster.jpg", Color.WHITE, 0.78, 0.28)
	textured_box(root, at + Vector3(0, tall / 2.0, 0), Vector3(5.2, tall, 5.2), wall, true)
	textured_box(root, at + Vector3(0, tall + 0.12, 0), Vector3(5.6, 0.24, 5.6), Art.painted("metal.jpg", Color("f2c15a"), 0.4, 0.4), false)
	_windows(root, at, tall, angle)
	_poster(root, at + Vector3(cos(angle) * -2.7, 1.8, sin(angle) * -2.7), angle + PI, index)
	var lamp := at + Vector3(cos(angle) * 3.4, 2.6, sin(angle) * 3.4)
	mesh(root, SphereMesh.new(), lamp, Color("ffd27a"), 0.2).scale = Vector3(0.32, 0.32, 0.32)
	var light := OmniLight3D.new()
	light.position = lamp
	light.light_color = Color("ffc56a")
	light.light_energy = 1.3
	light.omni_range = 9.0
	root.add_child(light)


static func _windows(root: Node3D, at: Vector3, tall: float, angle: float) -> void:
	var face := Vector3(cos(angle) * -2.62, 0, sin(angle) * -2.62)
	for story in 2:
		for side in [-1.1, 1.1]:
			var y := 1.15 + story * 1.55
			if y > tall - 0.6:
				continue
			var offset := Vector3(-sin(angle) * side, y, cos(angle) * side)
			textured_box(root, at + face + offset, Vector3(0.12, 0.9, 0.82), Art.emit(Color("7ad7ff"), 0.35), false)


static func _poster(root: Node3D, at: Vector3, angle: float, index: int) -> void:
	var names := ["fighter_heavy.jpg", "fighter_athletic.jpg", "fighter_compact.jpg", "fighter_tall.jpg"]
	var quad := QuadMesh.new()
	quad.size = Vector2(1.7, 2.2)
	var node := MeshInstance3D.new()
	node.mesh = quad
	node.material_override = Art.poster(names[index % names.size()])
	node.position = at
	node.rotation.y = angle
	root.add_child(node)


static func _shop(root: Node3D, at: Vector3, angle: float, index: int) -> void:
	var mat := Art.painted("plaster.jpg", Color("ffe7c8") if index % 2 == 0 else Color("c5f0ea"), 0.76, 0.3)
	textured_box(root, at + Vector3(0, 1.35, 0), Vector3(5.0, 2.7, 5.0), mat, true)
	textured_box(root, at + Vector3(0, 2.85, 0), Vector3(5.4, 0.22, 5.4), Art.painted("metal.jpg", Color("e24b4b") if index % 2 == 0 else Color("2f7db5"), 0.42, 0.45), false)
	var awning := BoxMesh.new()
	awning.size = Vector3(3.2, 0.12, 1.4)
	var shade := MeshInstance3D.new()
	shade.mesh = awning
	shade.position = at + Vector3(cos(angle) * -2.4, 2.15, sin(angle) * -2.4)
	shade.rotation.y = angle
	shade.material_override = Art.painted("canvas.jpg", Color("ff6b8a"), 0.55, 0.5)
	root.add_child(shade)


static func _bell_tower(root: Node3D, at: Vector3) -> void:
	textured_box(root, at + Vector3(0, 2.2, 0), Vector3(3.4, 4.4, 3.4), Art.painted("plaster.jpg", Color("fff0d8"), 0.75, 0.25), true)
	textured_box(root, at + Vector3(0, 4.55, 0), Vector3(3.8, 0.3, 3.8), Art.painted("metal.jpg", Color("e24b4b"), 0.4, 0.4), false)
	mesh(root, SphereMesh.new(), at + Vector3(0, 5.3, 0), Color("f0c43a"), 0.25).scale = Vector3(1.1, 1.1, 1.1)
	var light := OmniLight3D.new()
	light.position = at + Vector3(0, 5.2, 0)
	light.light_color = Color("ffd36a")
	light.light_energy = 2.2
	light.omni_range = 14.0
	root.add_child(light)


static func _jump_pad(root: Node3D, at: Vector3) -> void:
	cylinder(root, at + Vector3(0, 0.12, 0), 1.35, 0.22, Color("c9a24a"), false, 0.35)
	var disc := CylinderMesh.new()
	disc.top_radius = 1.12
	disc.bottom_radius = 1.12
	disc.height = 0.08
	var glow := MeshInstance3D.new()
	glow.mesh = disc
	glow.position = at + Vector3(0, 0.26, 0)
	glow.material_override = Art.emit(Color("7dffc3"), 1.8)
	root.add_child(glow)
	var sticker := QuadMesh.new()
	sticker.size = Vector2(2.2, 2.2)
	var art := MeshInstance3D.new()
	art.mesh = sticker
	art.position = at + Vector3(0, 0.31, 0)
	art.rotation_degrees = Vector3(-90, 0, 0)
	art.material_override = Art.poster("jumppad.jpg")
	root.add_child(art)


static func _crate(root: Node3D, at: Vector3) -> void:
	var sticker := QuadMesh.new()
	sticker.size = Vector2(1.05, 1.05)
	var art := MeshInstance3D.new()
	art.mesh = sticker
	art.position = at + Vector3(0, 0.35, 0)
	var mat := Art.poster("crate.jpg")
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	art.material_override = mat
	root.add_child(art)


static func _bleachers(root: Node3D) -> void:
	for side in [-1.0, 1.0]:
		for row in 4:
			var height := 0.45 + row * 0.42
			textured_box(root, Vector3(side * 40.0, height / 2.0, 0), Vector3(3.2, height, 18.0 - row * 2.0),
				Art.painted("plaster.jpg", Color("c9a07a"), 0.8, 0.22), true)
