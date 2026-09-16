extends RefCounted
## Small offline arena grid sampled from real static collision, including deployed walls.
var grid := AStarGrid2D.new()
var ready := false
var revision := 0

func rebuild(world: Node3D) -> void:
	grid.region = Rect2i(-29,-29,59,59)
	grid.cell_size = Vector2(2,2)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	var shape := SphereShape3D.new()
	shape.radius = 0.7
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	var physics := world.get_world_3d().direct_space_state
	for z in range(-29,30):
		for x in range(-29,30):
			var at := Vector3(x*2,1,z*2)
			query.transform.origin = at
			grid.set_point_solid(Vector2i(x,z),Vector2(at.x,at.z).length()>54 or not physics.intersect_shape(query,1).is_empty())
	ready = true
	revision += 1

func nearest(at: Vector3) -> Vector2i:
	var cell := Vector2i(roundi(at.x/2),roundi(at.z/2))
	cell = cell.clamp(Vector2i(-29,-29),Vector2i(29,29))
	if not grid.is_point_solid(cell): return cell
	for radius in range(1,7):
		for offset in [Vector2i(radius,0),Vector2i(-radius,0),Vector2i(0,radius),Vector2i(0,-radius),Vector2i(radius,radius),Vector2i(-radius,-radius)]:
			var candidate: Vector2i = cell+offset
			if grid.region.has_point(candidate) and not grid.is_point_solid(candidate): return candidate
	return cell

func route(from: Vector3, to: Vector3) -> PackedVector3Array:
	var result := PackedVector3Array()
	if not ready: return result
	var start := nearest(from)
	var end := nearest(to)
	if grid.is_point_solid(start) or grid.is_point_solid(end): return result
	for point in grid.get_point_path(start,end): result.append(Vector3(point.x,0,point.y))
	return result
