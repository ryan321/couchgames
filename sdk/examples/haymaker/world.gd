extends RefCounted
## Carnival lot: procedural meshes plus Forward+ lighting. No downloaded art packs.

static func material(color: Color, roughness := 0.82, emission := 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	result.metallic = 0.0
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


static func box(parent: Node3D, at: Vector3, size: Vector3, color: Color, solid := false, roughness := 0.82) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	var result := mesh(parent, shape, at, color, roughness)
	if solid:
		_collision(parent, _box_shape(size), at)
	return result


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
	var result := mesh(parent, shape, at, color, roughness)
	if solid:
		var collision := CylinderShape3D.new()
		collision.radius = radius
		collision.height = height
		_collision(parent, collision, at)
	return result


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
	ground.radial_segments = 64
	var ground_mesh := MeshInstance3D.new()
	ground_mesh.mesh = ground
	ground_mesh.position = Vector3(0, -0.55, 0)
	var ground_mat := ShaderMaterial.new()
	ground_mat.shader = load("res://examples/haymaker/shaders/ground.gdshader")
	ground_mesh.material_override = ground_mat
	root.add_child(ground_mesh)
	var ground_shape := CylinderShape3D.new()
	ground_shape.radius = 48.0
	ground_shape.height = 1.1
	_collision(root, ground_shape, Vector3(0, -0.55, 0))
	for i in 8:
		var angle := i * TAU / 8.0
		var at := Vector3(cos(angle) * 22.0, 1.15, sin(angle) * 22.0)
		box(root, at, Vector3(3.8, 2.3, 3.8), Color("c8a06a"), true, 0.7)
		box(root, at + Vector3(0, 1.28, 0), Vector3(4.1, 0.16, 4.1), Color("8b2e24"), false, 0.45)
		_lantern(root, at + Vector3(0, 2.55, 0), Color("ffc56a"))
	for i in 4:
		var angle := i * TAU / 4.0 + 0.4
		var at := Vector3(cos(angle) * 11.0, 0.7, sin(angle) * 11.0)
		box(root, at, Vector3(5.0, 1.4, 2.3), Color("3e6f8f"), true, 0.55)
		box(root, at + Vector3(0, 0.86, 0), Vector3(5.2, 0.14, 2.5), Color("e8c15a"), false, 0.4)
	var ramps := [
		[Vector3(8.5, 0.45, 0), Vector3(6.0, 0.9, 2.4)],
		[Vector3(-8.5, 0.45, 0), Vector3(6.0, 0.9, 2.4)],
		[Vector3(0, 0.45, 8.5), Vector3(2.4, 0.9, 6.0)],
		[Vector3(0, 0.45, -8.5), Vector3(2.4, 0.9, 6.0)],
	]
	for ramp in ramps:
		box(root, ramp[0], ramp[1], Color("9a6a42"), true, 0.78)
	for at in [Vector3(15, 0.55, 15), Vector3(-15, 0.55, 15), Vector3(15, 0.55, -15), Vector3(-15, 0.55, -15)]:
		box(root, at, Vector3(1.7, 1.15, 1.7), Color("6b3d28"), true, 0.7)
		box(root, at + Vector3(1.8, 0.38, 0.15), Vector3(1.25, 0.75, 1.25), Color("7a4a32"), true, 0.7)
	for i in 6:
		var angle := i * TAU / 6.0 + 0.2
		_tent(root, Vector3(cos(angle) * 34.0, 0, sin(angle) * 34.0), i % 2 == 0)
	_bleachers(root)
	var pads: Array[Vector3] = [
		Vector3(0, 0.1, 0), Vector3(20, 0.1, 0), Vector3(-20, 0.1, 0),
		Vector3(0, 0.1, 20), Vector3(0, 0.1, -20)]
	for at in pads:
		var pad := cylinder(root, at + Vector3(0, 0.08, 0), 1.35, 0.16, Color("7dffc3"), false, 0.25)
		pad.material_override = material(Color("7dffc3"), 0.25, 0.8)
	var loot: Array[Vector3] = []
	for i in 8:
		var angle := i * TAU / 8.0 + 0.18
		loot.append(Vector3(cos(angle) * 14.5, 0.35, sin(angle) * 14.5))
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
	sky_mat.sky_top_color = Color("f4a056")
	sky_mat.sky_horizon_color = Color("ffd1a0")
	sky_mat.ground_bottom_color = Color("3b2418")
	sky_mat.ground_horizon_color = Color("c47b4a")
	sky_mat.sky_curve = 0.14
	sky_mat.sun_angle_max = 8.0
	sky.sky_material = sky_mat
	settings.sky = sky
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	settings.ambient_light_color = Color("ffd8b0")
	settings.ambient_light_energy = 0.42
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	settings.glow_enabled = true
	settings.glow_intensity = 0.55
	settings.ssao_enabled = true
	settings.ssao_radius = 1.8
	settings.ssao_intensity = 1.4
	settings.fog_enabled = true
	settings.fog_light_color = Color("f0c090")
	settings.fog_density = 0.0018
	environment.environment = settings
	root.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -42, 0)
	sun.light_color = Color("ffd19a")
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 110.0
	root.add_child(sun)


static func _lantern(root: Node3D, at: Vector3, color: Color) -> void:
	mesh(root, SphereMesh.new(), at, color, 0.2).scale = Vector3(0.28, 0.28, 0.28)
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = color
	light.light_energy = 1.6
	light.omni_range = 8.0
	light.shadow_enabled = false
	root.add_child(light)


static func _tent(root: Node3D, at: Vector3, red: bool) -> void:
	box(root, at + Vector3(0, 1.1, 0), Vector3(4.4, 2.2, 4.4), Color("efe0c4"), true, 0.78)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.05
	cone.bottom_radius = 2.7
	cone.height = 2.3
	var roof := MeshInstance3D.new()
	roof.mesh = cone
	roof.position = at + Vector3(0, 3.35, 0)
	var canvas := ShaderMaterial.new()
	canvas.shader = load("res://examples/haymaker/shaders/canvas.gdshader")
	canvas.set_shader_parameter("stripe_a", Color("c62822") if red else Color("1f5f8a"))
	canvas.set_shader_parameter("stripe_b", Color("f4ead2"))
	roof.material_override = canvas
	root.add_child(roof)
	_lantern(root, at + Vector3(0, 2.4, 1.8), Color("ffb45a"))


static func _bleachers(root: Node3D) -> void:
	for side in [-1.0, 1.0]:
		for row in 4:
			var height := 0.45 + row * 0.42
			box(root, Vector3(side * 40.0, height / 2.0, 0), Vector3(3.2, height, 18.0 - row * 2.0), Color("6d4a32"), true, 0.75)
