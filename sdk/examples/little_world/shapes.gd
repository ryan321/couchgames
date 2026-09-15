extends RefCounted
## Small, original procedural art kit. No external models or textures required.

static func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.9
	return result


static func mesh(parent: Node3D, shape: Mesh, at: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = shape
	instance.material_override = material(color)
	instance.position = at
	parent.add_child(instance)
	return instance


static func ball(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = 0.5
	shape.height = 1.0
	shape.radial_segments = 16
	shape.rings = 8
	var result := mesh(parent, shape, at, color)
	result.scale = size
	return result


static func box(parent: Node3D, at: Vector3, size: Vector3, color: Color, solid := false) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	var result := mesh(parent, shape, at, color)
	if solid:
		var collision := BoxShape3D.new()
		collision.size = size
		_add_collision(parent, collision, at)
	return result


static func cylinder(parent: Node3D, at: Vector3, radius: float, height: float,
		color: Color, solid := false, top_radius := -1.0) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius if top_radius < 0.0 else top_radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 48 if radius > 5.0 else 16
	var result := mesh(parent, shape, at, color)
	if solid:
		var collision := CylinderShape3D.new()
		collision.radius = radius
		collision.height = height
		_add_collision(parent, collision, at)
	return result


static func _add_collision(parent: Node3D, shape: Shape3D, at: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = at
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
