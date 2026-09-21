extends RefCounted
## Original carnival-lot geometry. No external models or textures.

static func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.88
	return result


static func mesh(parent: Node3D, shape: Mesh, at: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = shape
	instance.material_override = material(color)
	instance.position = at
	parent.add_child(instance)
	return instance


static func box(parent: Node3D, at: Vector3, size: Vector3, color: Color, solid := false) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	var result := mesh(parent, shape, at, color)
	if solid:
		_collision(parent, _box_shape(size), at)
	return result


static func _box_shape(size: Vector3) -> BoxShape3D:
	var shape := BoxShape3D.new()
	shape.size = size
	return shape


static func cylinder(parent: Node3D, at: Vector3, radius: float, height: float, color: Color, solid := false) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 48 if radius > 8.0 else 16
	var result := mesh(parent, shape, at, color)
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
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("f2c07a")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("ffe6c2")
	settings.ambient_light_energy = 0.42
	settings.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = settings
	root.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_color = Color("fff1d0")
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	root.add_child(sun)
	cylinder(root, Vector3(0, -0.55, 0), 48.0, 1.1, Color("d7b07a"), true)
	cylinder(root, Vector3(0, 0.02, 0), 18.0, 0.06, Color("c45c4a"))
	cylinder(root, Vector3(0, 0.05, 0), 16.6, 0.05, Color("f4e2b8"))
	for i in 8:
		var angle := i * TAU / 8.0
		var at := Vector3(cos(angle) * 22.0, 1.2, sin(angle) * 22.0)
		box(root, at, Vector3(3.6, 2.4, 3.6), Color("e8d3a4"), true)
		box(root, at + Vector3(0, 1.85, 0), Vector3(3.9, 0.18, 3.9), Color("c45c4a"))
	for i in 4:
		var angle := i * TAU / 4.0 + 0.4
		var at := Vector3(cos(angle) * 11.0, 0.7, sin(angle) * 11.0)
		box(root, at, Vector3(4.8, 1.4, 2.2), Color("6aa4c8"), true)
		box(root, at + Vector3(0, 0.85, 0), Vector3(5.0, 0.16, 2.4), Color("f0d48a"))
	var ramps := [
		[Vector3(8.5, 0.45, 0), Vector3(6.0, 0.9, 2.4)],
		[Vector3(-8.5, 0.45, 0), Vector3(6.0, 0.9, 2.4)],
		[Vector3(0, 0.45, 8.5), Vector3(2.4, 0.9, 6.0)],
		[Vector3(0, 0.45, -8.5), Vector3(2.4, 0.9, 6.0)],
	]
	for ramp in ramps:
		box(root, ramp[0], ramp[1], Color("c98a5a"), true)
	for at in [Vector3(15, 0.55, 15), Vector3(-15, 0.55, 15), Vector3(15, 0.55, -15), Vector3(-15, 0.55, -15)]:
		box(root, at, Vector3(1.6, 1.1, 1.6), Color("8b5a3c"), true)
		box(root, at + Vector3(1.7, 0.35, 0.2), Vector3(1.2, 0.7, 1.2), Color("a56b45"), true)
	for i in 6:
		var angle := i * TAU / 6.0 + 0.2
		_tent(root, Vector3(cos(angle) * 34.0, 0, sin(angle) * 34.0), Color("d4533e") if i % 2 == 0 else Color("3d7ea6"))
	var pads: Array[Vector3] = [
		Vector3(0, 0.1, 0), Vector3(20, 0.1, 0), Vector3(-20, 0.1, 0),
		Vector3(0, 0.1, 20), Vector3(0, 0.1, -20)]
	for at in pads:
		cylinder(root, at + Vector3(0, 0.08, 0), 1.35, 0.16, Color("7dffc3"))
	var loot: Array[Vector3] = []
	for i in 8:
		var angle := i * TAU / 8.0 + 0.18
		loot.append(Vector3(cos(angle) * 14.5, 0.35, sin(angle) * 14.5))
	var spawns: Array[Vector3] = []
	for i in 8:
		var angle := i * TAU / 8.0
		spawns.append(Vector3(cos(angle) * 28.0, 0.2, sin(angle) * 28.0))
	return {"pads": pads, "loot": loot, "spawns": spawns}


static func _tent(root: Node3D, at: Vector3, stripe: Color) -> void:
	box(root, at + Vector3(0, 1.1, 0), Vector3(4.2, 2.2, 4.2), Color("f3e4c6"), true)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.05
	cone.bottom_radius = 2.6
	cone.height = 2.2
	mesh(root, cone, at + Vector3(0, 3.3, 0), stripe)
