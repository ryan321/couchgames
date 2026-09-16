extends RefCounted
## Original procedural scenery: no downloaded art or engine dependencies.
static var materials: Dictionary = {}
static var box_meshes: Dictionary = {}

static func material(color: String, metal := 0.0, glow := 0.0) -> StandardMaterial3D:
	var key := color + str(metal) + str(glow)
	if materials.has(key): return materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color)
	mat.roughness = 0.7 if metal == 0.0 else 0.3
	mat.metallic = metal
	if glow > 0:
		mat.emission_enabled = true
		mat.emission = Color(color)
		mat.emission_energy_multiplier = glow
	materials[key] = mat
	return mat

static func mesh(parent: Node3D, shape: Mesh, at: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = shape
	node.material_override = mat
	parent.add_child(node)
	node.position = at
	return node

static func box(parent: Node3D, at: Vector3, size: Vector3, color: String, solid := false, metal := 0.0) -> MeshInstance3D:
	var shape := beveled_box(size)
	var node := mesh(parent, shape, at, material(color, metal))
	if size.length()>2.0 and metal==0: node.material_override = paint_material(color)
	if solid:
		var body := StaticBody3D.new()
		node.add_child(body)
		var collision := CollisionShape3D.new()
		var bounds := BoxShape3D.new()
		bounds.size = size
		collision.shape = bounds
		body.add_child(collision)
	return node

static func beveled_box(size: Vector3) -> ArrayMesh:
	# A narrow chamfer catches the sun along armor, roof, and weapon edges.
	if box_meshes.has(size): return box_meshes[size]
	var half := size*0.5
	var bevel := minf(0.045,minf(size.x,minf(size.y,size.z))*0.13)
	var inner := half-Vector3.ONE*bevel
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	# Six faces, twelve edges, and eight corners form a closed convex surface.
	for axis in 3:
		for sign_value in [-1.0,1.0]:
			var normal := Vector3.ZERO
			normal[axis] = sign_value
			var points: Array[Vector3] = []
			for pair in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
				var point := Vector3.ZERO
				point[axis] = half[axis]*sign_value
				point[(axis+1)%3] = inner[(axis+1)%3]*pair.x
				point[(axis+2)%3] = inner[(axis+2)%3]*pair.y
				points.append(point)
			append_face(vertices,normals,points,normal)
	for axis in 3:
		var a := (axis+1)%3
		var b := (axis+2)%3
		for sa in [-1.0,1.0]:
			for sb in [-1.0,1.0]:
				var points: Array[Vector3] = []
				for pair in [Vector2(-1,0),Vector2(1,0),Vector2(1,1),Vector2(-1,1)]:
					var point := Vector3.ZERO
					point[axis] = inner[axis]*pair.x
					point[a] = (half[a] if pair.y==0 else inner[a])*sa
					point[b] = (inner[b] if pair.y==0 else half[b])*sb
					points.append(point)
				var normal := Vector3.ZERO
				normal[a] = sa
				normal[b] = sb
				append_face(vertices,normals,points,normal.normalized())
	for x in [-1.0,1.0]:
		for y in [-1.0,1.0]:
			for z in [-1.0,1.0]:
				var sign_vector := Vector3(x,y,z)
				var points: Array[Vector3] = []
				for axis in 3:
					var point := inner*sign_vector
					point[axis] = half[axis]*sign_vector[axis]
					points.append(point)
				append_face(vertices,normals,points,sign_vector.normalized())
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	box_meshes[size] = result
	return result

static func append_face(vertices: PackedVector3Array, normals: PackedVector3Array, points: Array[Vector3], normal: Vector3) -> void:
	if (points[1]-points[0]).cross(points[2]-points[0]).dot(normal)>0: points.reverse()
	for i in range(1,points.size()-1):
		for index in [0,i,i+1]:
			vertices.append(points[index])
			normals.append(normal)

static func sphere(parent: Node3D, at: Vector3, size: Vector3, color: String) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = 1
	shape.height = 2
	shape.radial_segments = 12
	shape.rings = 6
	var node := mesh(parent, shape, at, material(color))
	node.scale = size
	return node

static func cylinder(parent: Node3D, at: Vector3, bottom: float, top: float, height: float, color: String, solid := false) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.bottom_radius = bottom
	shape.top_radius = top
	shape.height = height
	shape.radial_segments = 16
	var node := mesh(parent, shape, at, material(color))
	if solid: node.create_convex_collision()
	return node

static func paint_material(color: String) -> ShaderMaterial:
	var key := "paint_"+color
	if materials.has(key): return materials[key]
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://examples/sunbreak/shaders/paint.gdshader")
	mat.set_shader_parameter("tint",Color(color))
	mat.set_shader_parameter("detail_map",preload("res://examples/sunbreak/assets/rock_albedo.jpg"))
	mat.set_shader_parameter("normal_map",preload("res://examples/sunbreak/assets/rock_normal.jpg"))
	materials[key] = mat
	return mat

static func rock_material() -> ShaderMaterial:
	if materials.has("rock_surface"): return materials["rock_surface"]
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://examples/sunbreak/shaders/surface.gdshader")
	mat.set_shader_parameter("albedo_map",preload("res://examples/sunbreak/assets/rock_albedo.jpg"))
	mat.set_shader_parameter("normal_map",preload("res://examples/sunbreak/assets/rock_normal.jpg"))
	mat.set_shader_parameter("arm_map",preload("res://examples/sunbreak/assets/rock_arm.jpg"))
	mat.set_shader_parameter("tint",Color("b6c4b4"))
	materials["rock_surface"] = mat
	return mat

static func segment(parent: Node3D, from: Vector3, to: Vector3, radius: float, color: String, metal := 0.0) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius*0.72
	shape.bottom_radius = radius
	shape.height = from.distance_to(to)
	shape.radial_segments = 12
	var node := mesh(parent,shape,(from+to)*0.5,material(color,metal))
	node.quaternion = Quaternion(Vector3.UP,(to-from).normalized())
	return node

static func leaf_mesh() -> ArrayMesh:
	var data := []
	data.resize(Mesh.ARRAY_MAX)
	data[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(0,0,0),Vector3(-0.24,0.38,0.02),Vector3(0,0.45,0.12),Vector3(0,0,0),Vector3(0,0.45,0.12),Vector3(0.24,0.38,0.02),Vector3(-0.24,0.38,0.02),Vector3(0,0.82,0),Vector3(0,0.45,0.12),Vector3(0,0.45,0.12),Vector3(0,0.82,0),Vector3(0.24,0.38,0.02)])
	var normals := PackedVector3Array()
	for i in 12: normals.append(Vector3(0,0.3,1).normalized())
	data[Mesh.ARRAY_NORMAL] = normals
	var shape := ArrayMesh.new()
	shape.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,data)
	return shape

static func foliage(parent: Node3D, count: int, tint: Color) -> MultiMeshInstance3D:
	var result := MultiMeshInstance3D.new()
	result.multimesh = MultiMesh.new()
	result.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	result.multimesh.use_custom_data = true
	result.multimesh.mesh = leaf_mesh()
	result.multimesh.instance_count = count
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://examples/sunbreak/shaders/foliage.gdshader")
	mat.set_shader_parameter("base_color",tint)
	result.material_override = mat
	parent.add_child(result)
	return result

static func tree(parent: Node3D, at: Vector3, size: float, rng: RandomNumberGenerator) -> void:
	var trunk := cylinder(parent,at+Vector3(0,size*1.3,0),size*0.18,size*0.1,size*2.6,"645e42",true)
	trunk.material_override = rock_material()
	var leaves := foliage(parent,420,Color("648d32"))
	for branch in 6:
		var angle := branch*TAU/6+rng.randf()*0.5
		var end := at+Vector3(cos(angle)*1.45,2.4+rng.randf()*1.1,sin(angle)*1.45)*size
		segment(parent,at+Vector3(0,size*1.65,0),end,size*0.075,"716343")
		for i in 70:
			var spread := Vector3(rng.randf_range(-1,1),rng.randf_range(-0.5,0.7),rng.randf_range(-1,1))
			var point := end+spread*size
			var basis := Basis.from_euler(Vector3(rng.randf_range(-1.5,1.5),rng.randf()*TAU,rng.randf_range(-1.5,1.5)))
			basis = basis.scaled(Vector3.ONE*rng.randf_range(0.65,1.25)*size)
			leaves.multimesh.set_instance_transform(branch*70+i,Transform3D(basis,point))
			leaves.multimesh.set_instance_custom_data(branch*70+i,Color(rng.randf(),0,0))

static func building(parent: Node3D, at: Vector3, yaw: float, color: String) -> void:
	var house := Node3D.new()
	parent.add_child(house)
	house.position = at
	house.rotation.y = yaw
	box(house, Vector3(0, 1.7, 0), Vector3(8, 3.4, 6), color, true)
	box(house, Vector3(0, 0.3, 0), Vector3(8.4, 0.6, 6.4), "e5d4ad", true).material_override = rock_material()
	box(house, Vector3(0, 3.35, 0), Vector3(8.5, 0.3, 6.5), "fff0cc")
	for side in [-1, 1]:
		var roof := box(house, Vector3(side * 2.05, 4.1, 0), Vector3(4.6, 0.24, 7), "365b69")
		roof.rotation.z = side * -0.32
		for k in 12:
			var seam := box(house, Vector3(side * 2.05, 4.24, -3.25 + k * 0.59), Vector3(4.6, 0.08, 0.04), "59818b")
			seam.rotation.z = side * -0.32
	for x in [-2.6, 2.6]:
		box(house, Vector3(x, 2, 3.03), Vector3(1.5, 1.55, 0.1), "f8e8bb")
		box(house, Vector3(x, 2, 3.1), Vector3(1.25, 1.3, 0.1), "224b60", false, 0.35)
		box(house, Vector3(x, 2, 3.17), Vector3(0.08, 1.3, 0.08), "fff0cc")
		box(house, Vector3(x, 1.9, 3.17), Vector3(1.3, 0.08, 0.08), "fff0cc")
		box(house, Vector3(x, 1.12, 3.2), Vector3(1.85, 0.16, 0.5), "fff0cc")
	box(house, Vector3(0, 1.3, 3.05), Vector3(1.4, 2.5, 0.12), "284956")
	box(house, Vector3(0, 2.8, 4), Vector3(3, 0.15, 2.2), "efb65d")
	for x in [-1.4, 1.4]: cylinder(house, Vector3(x, 1.4, 4.8), 0.065, 0.065, 2.8, "fff0cc")
	box(house, Vector3(2, 5, -1), Vector3(0.6, 1.4, 0.7), color)
	for y in 8:
		for side in [-1,1]:
			box(house,Vector3(0,0.55+y*0.35,side*3.015),Vector3(7.95,0.018,0.016),color)
	box(house,Vector3(0,0.09,3.7),Vector3(2.3,0.18,1.1),"b8b8a2",true)
	for x in [-0.45,-0.15,0.15,0.45]: box(house,Vector3(x,1.25,3.13),Vector3(0.28,2.25,0.05),"53767a")
	box(house,Vector3(0.46,1.2,3.18),Vector3(0.06,0.13,0.05),"f2c573",false,0.8)
	for x in [-1.1,1.1]:
		box(house,Vector3(x,2.15,3.12),Vector3(0.23,0.42,0.24),"304d59",false,0.5)
		var lamp := box(house,Vector3(x,2.18,3.26),Vector3(0.14,0.25,0.03),"ffe4a4")
		lamp.material_override = material("ffe4a4",0,0.7)
	var sign_board := box(house,Vector3(0,3.16,3.2),Vector3(2.5,0.5,0.14),"345f69")
	var sign_text := Label3D.new()
	sign_text.text = "SUNLIT  /  OUTPOST"
	sign_text.font_size = 44
	sign_text.pixel_size = 0.0035
	sign_text.modulate = Color("fff0cc")
	sign_text.outline_size = 0
	sign_board.add_child(sign_text)
	sign_text.position.z = 0.08


static func create_world(parent: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 87234
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("236c9f")
	sky_mat.sky_horizon_color = Color("c2d2d0")
	sky_mat.ground_horizon_color = Color("bee5dc")
	sky_mat.sky_curve = 0.18
	sky_mat.sun_angle_max = 6
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c5e5ff")
	env.ambient_light_energy = 0.32
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.ssao_enabled = true
	env.ssao_radius = 2
	env.ssao_intensity = 1.3
	env.fog_enabled = true
	env.fog_light_color = Color("addbd9")
	env.fog_density = 0.0015
	env_node.environment = env
	parent.add_child(env_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-32, -32, 0)
	sun.light_color = Color("ffe6af")
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 110
	parent.add_child(sun)
	var water_shape := PlaneMesh.new()
	water_shape.size = Vector2(1800, 1800)
	water_shape.subdivide_width = 100
	water_shape.subdivide_depth = 100
	var water_mat := ShaderMaterial.new()
	water_mat.shader = preload("res://examples/sunbreak/shaders/water.gdshader")
	mesh(parent, water_shape, Vector3(0, -2.1, 0), water_mat)
	cylinder(parent, Vector3(0, -2.5, 0), 68, 60, 4, "d9c393")
	var island := cylinder(parent, Vector3(0, -0.6, 0), 60, 60, 1.2, "8baf4c", true)
	var ground := ShaderMaterial.new()
	ground.shader = preload("res://examples/sunbreak/shaders/ground.gdshader")
	ground.set_shader_parameter("ground_color",preload("res://examples/sunbreak/assets/grass_albedo.jpg"))
	ground.set_shader_parameter("ground_normal",preload("res://examples/sunbreak/assets/grass_normal.jpg"))
	ground.set_shader_parameter("ground_arm",preload("res://examples/sunbreak/assets/grass_arm.jpg"))
	island.material_override = ground
	building(parent, Vector3(-14, 0, -9), 0.12, "e99270")
	building(parent, Vector3(14, 0, -11), -0.18, "5dabb1")
	building(parent, Vector3(-16, 0, 13), PI * 0.5, "e6c579")
	building(parent, Vector3(17, 0, 12), -PI * 0.5, "b1bfa0")
	# Communications tower anchors the center and serves as hard cover.
	cylinder(parent, Vector3(0, 0.25, 0), 4.3, 4.3, 0.5, "e7d7af", true)
	cylinder(parent, Vector3(0, 1.6, 0), 1.9, 1.4, 2.7, "f0e3c6", true)
	cylinder(parent, Vector3(0, 4.8, 0), 0.75, 0.6, 5, "578591", true)
	for y in [3.3, 6.5, 7.5]: cylinder(parent, Vector3(0, y, 0), 1.3, 1.3, 0.18, "edb762")
	var beacon := sphere(parent, Vector3(0, 8, 0), Vector3.ONE * 0.65, "70ffe0")
	beacon.material_override = material("70ffe0", 0.2, 2.5)
	for i in 24:
		var angle := rng.randf() * TAU
		var radius := rng.randf_range(34, 54)
		tree(parent, Vector3(cos(angle) * radius, 0, sin(angle) * radius), rng.randf_range(1.2, 2.1), rng)
	for i in 34:
		var angle := rng.randf() * TAU
		var radius := rng.randf_range(37, 61)
		var at := Vector3(cos(angle) * radius, -0.15, sin(angle) * radius)
		var rock := sphere(parent, at, Vector3(rng.randf_range(1, 3), rng.randf_range(0.5, 1.8), rng.randf_range(1, 2)), "9daaa0")
		rock.rotation.y = angle
		rock.material_override = rock_material()
		rock.create_convex_collision()
		rock.add_to_group("sunbreak_rocks")
	for at in [Vector3(-6,0,12), Vector3(7,0,-8), Vector3(24,0,-2), Vector3(-26,0,-3), Vector3(7,0,18), Vector3(-7,0,-21)]:
		box(parent, at + Vector3(0,0.75,0), Vector3(2.4,1.5,1.4), "678b82", true)
		for x in [-0.85,0.85]: box(parent, at + Vector3(x,0.76,0), Vector3(0.13,1.58,1.48), "e9cc8b")
		box(parent, at + Vector3(0,1.55,0), Vector3(2.5,0.15,1.5), "a1ba9a")
	# Distant silhouettes and clustered clouds create depth without downloaded assets.
	for i in 22:
		var at := Vector3(rng.randf_range(-230,230), rng.randf_range(65,90), rng.randf_range(-230,230))
		for k in 3: sphere(parent, at + Vector3(k*8, k%2*2, 0), Vector3(13,3.5,5), "f8f2dc")
	# Thousands of wind-animated leaves are batched, rather than separate scene nodes.
	var grass := foliage(parent,36000,Color("739644"))
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 36000:
		var at := Vector3(rng.randf_range(-54,54),0,rng.randf_range(-54,54))
		if Vector2(at.x,at.z).length()>56 or absf(at.x)<4 or absf(at.z)<4: at.y = -5
		var basis := Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3(0.075,rng.randf_range(0.22,0.65),0.12))
		grass.multimesh.set_instance_transform(i,Transform3D(basis,at))
		grass.multimesh.set_instance_custom_data(i,Color(rng.randf(),0,0))
