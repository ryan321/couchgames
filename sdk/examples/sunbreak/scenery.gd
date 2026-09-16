extends RefCounted
const Art = preload("res://examples/sunbreak/art.gd")

static func rock(parent: Node3D, at: Vector3, size: Vector3, seed_value: int, solid := true) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = 1
	sphere.height = 2
	sphere.radial_segments = 18
	sphere.rings = 10
	var arrays := sphere.get_mesh_arrays()
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 2.7
	for i in points.size():
		points[i] *= 1+noise.get_noise_3dv(points[i])*0.35
		points[i].y = maxf(points[i].y,-0.75)
	arrays[Mesh.ARRAY_VERTEX] = points
	var source := ArrayMesh.new()
	source.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var builder := SurfaceTool.new()
	builder.create_from(source,0)
	builder.generate_normals()
	var node := Art.mesh(parent,builder.commit(),at,Art.rock_material())
	node.scale = size
	if solid:
		node.create_convex_collision()
		node.add_to_group("sunbreak_rocks")
	return node

static func dress(parent: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 906
	# Coastal outcrops replace a perfectly flat island silhouette.
	for i in 32:
		var angle := i*TAU/32
		var radius := rng.randf_range(58,66)
		rock(parent,Vector3(cos(angle)*radius,-1.9,sin(angle)*radius),Vector3(rng.randf_range(3,6),rng.randf_range(1,4),rng.randf_range(2,5)),i+45)
	for i in 9:
		var angle := i*TAU/9+0.3
		rock(parent,Vector3(cos(angle)*235,-13,sin(angle)*235),Vector3(45,rng.randf_range(24,50),35),i+110,false)
	for at in [Vector3(-9,0,-16),Vector3(10,0,15),Vector3(22,0,-18),Vector3(-24,0,19)]:
		var group := Node3D.new()
		parent.add_child(group)
		group.position = at
		group.rotation.y = rng.randf()*TAU
		# Boarded supply pallets, steel cases, and tied cargo straps.
		for i in 5: Art.box(group,Vector3(-0.6+i*0.3,0.12,0),Vector3(0.24,0.20,1.4),"7b7050")
		for j in 2:
			var pos := Vector3(0,0.53+j*0.66,0)
			Art.box(group,pos,Vector3(1.25,0.63,0.85),"4a6870",true,0.4)
			for x in [-0.5,0.5]: Art.box(group,pos+Vector3(x,0,0),Vector3(0.055,0.68,0.9),"b5b198",false,0.5)
			for x in [-0.37,0.37]: Art.box(group,pos+Vector3(x,0.1,0.44),Vector3(0.10,0.07,0.018),"e1bb7b",false,0.5)
		Art.cylinder(group,Vector3(1.2,0.51,0.25),0.36,0.36,1.02,"986d54",true)
		for y in [0.15,0.75]: Art.cylinder(group,Vector3(1.2,y,0.25),0.37,0.37,0.055,"425559")
	for x in [-8.5,8.5]:
		for z in [-4.5,5]:
			var at := Vector3(x,0,z)
			Art.cylinder(parent,at+Vector3(0,1.8,0),0.07,0.055,3.6,"536a6b",true)
			Art.segment(parent,at+Vector3(0,3.6,0),at+Vector3(-signf(x)*0.65,3.8,0),0.05,"4a6268",0.5)
			var light_at := at+Vector3(-signf(x)*0.65,3.73,0)
			Art.box(parent,light_at,Vector3(0.48,0.1,0.32),"3d525a",false,0.6)
			Art.box(parent,light_at-Vector3(0,0.057,0),Vector3(0.38,0.02,0.24),"ffdda0").material_override = Art.material("ffdda0",0,1.5)
	# Cloth banners across the plaza: strong silhouettes and a little local motion.
	for sign_x in [-1,1]:
		var from := Vector3(sign_x*8.5,3.55,-4.5)
		var to := Vector3(sign_x*8.5,3.55,5)
		for i in 16:
			var t := i/16.0
			var a := from.lerp(to,t)-Vector3(0,sin(t*PI)*0.45,0)
			var b := from.lerp(to,(i+1)/16.0)-Vector3(0,sin((i+1)/16.0*PI)*0.45,0)
			Art.segment(parent,a,b,0.012,"5a645c")
			if i%2==0:
				var flag := PrismMesh.new()
				flag.size = Vector3(0.48,0.7,0.014)
				var cloth := Art.mesh(parent,flag,a-Vector3(0,0.34,0),Art.material("cf9567" if i%4==0 else "719e9d"))
				cloth.rotation = Vector3(0,PI/2,PI)
	# Low shrubs and broad tropical leaves at the edge of each building.
	for at in [Vector3(-19,0,-5),Vector3(20,0,-7),Vector3(-19,0,19),Vector3(21,0,18),Vector3(-28,0,8),Vector3(27,0,22)]:
		var bush := Art.foliage(parent,100,Color("427e57"))
		for i in 100:
			var angle := rng.randf()*TAU
			var pos: Vector3 = at+Vector3(cos(angle)*rng.randf()*1.3,rng.randf()*0.8,sin(angle)*rng.randf()*1.3)
			var basis := Basis.from_euler(Vector3(rng.randf_range(-0.6,0.6),angle,rng.randf_range(-0.5,0.5))).scaled(Vector3.ONE*0.65)
			bush.multimesh.set_instance_transform(i,Transform3D(basis,pos))
			bush.multimesh.set_instance_custom_data(i,Color(rng.randf(),0,0))

static func batch_static(parent: Node3D) -> int:
	# Merge static scenery by material/vertex format; keep original collision and labels.
	var groups: Dictionary = {}
	var pending: Array[Node] = [parent]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		for child in node.get_children(): pending.append(child)
		if not node is MeshInstance3D or node.mesh==null or node.mesh is PlaneMesh: continue
		if node.mesh.get_surface_count()!=1: continue
		var mesh_node: MeshInstance3D = node
		var mat: Material = mesh_node.material_override
		if mat==null: continue
		var arrays := mesh_node.mesh.surface_get_arrays(0)
		var key := str(mat.get_instance_id())+str(arrays[Mesh.ARRAY_TEX_UV]!=null)+str(arrays[Mesh.ARRAY_TANGENT]!=null)
		if not groups.has(key): groups[key] = {"material":mat,"nodes":[]}
		groups[key].nodes.append(mesh_node)
	var merged := 0
	for entry in groups.values():
		if entry.nodes.size()<3: continue
		var builder := SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		for node: MeshInstance3D in entry.nodes:
			builder.append_from(node.mesh,0,parent.global_transform.affine_inverse()*node.global_transform)
			# Removing only the mesh retains child labels and static physics bodies.
			node.mesh = null
			merged += 1
		var result := MeshInstance3D.new()
		result.mesh = builder.commit()
		result.material_override = entry.material
		parent.add_child(result)
	return merged
