extends Node3D
## Depth-aware fog in the dungeon viewport: walls, heads and raised props use their true X/Z.
var policy: RefCounted
var screen := MeshInstance3D.new()
var fog := ShaderMaterial.new()

func _ready() -> void:
	fog.shader = preload("res://examples/gauntlet/shaders/party_fog.gdshader")
	fog.render_priority = 127
	var quad := QuadMesh.new()
	quad.size = Vector2(2,2)
	quad.flip_faces = true
	screen.mesh = quad
	screen.material_override = fog
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	screen.extra_cull_margin = 1000
	screen.position.z = -1
	add_child(screen)

func floor_point(camera: Camera3D, pixel: Vector2) -> Vector2:
	var origin := camera.project_ray_origin(pixel)
	var direction := camera.project_ray_normal(pixel)
	var point := origin-direction*(origin.y/direction.y)
	return Vector2(point.x,point.z)

func present(camera: Camera3D, clock: float) -> void:
	global_transform = camera.global_transform
	screen.visible = policy.active
	if not screen.visible: return
	var viewport_size := Vector2(camera.get_viewport().size)
	var origin := floor_point(camera,Vector2.ZERO)
	fog.set_shader_parameter("ground_origin",origin)
	fog.set_shader_parameter("ground_dx",floor_point(camera,Vector2(viewport_size.x,0))-origin)
	fog.set_shader_parameter("ground_dy",floor_point(camera,Vector2(0,viewport_size.y))-origin)
	var centers := PackedVector2Array(policy.centers)
	var count := centers.size()
	centers.resize(16)
	fog.set_shader_parameter("centers",centers)
	fog.set_shader_parameter("player_count",count)
	fog.set_shader_parameter("clear_radius",policy.CLEAR_RADIUS)
	fog.set_shader_parameter("outer_radius",policy.OUTER_RADIUS)
	fog.set_shader_parameter("clock",clock)
