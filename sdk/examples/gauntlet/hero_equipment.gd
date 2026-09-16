extends RefCounted
## Small modeled accessories with bevels and curved profiles, shared across player instances.
static var blades: Dictionary = {}

static func blade(view: Node3D, parent: Node3D, axe: bool) -> void:
	var key := "axe" if axe else "sword"
	if not blades.has(key):
		var outline := PackedVector2Array([Vector2(-0.03,0.58),Vector2(0.09,0.51),Vector2(0.29,0.48),Vector2(0.37,0.56),Vector2(0.40,0.70),Vector2(0.35,0.85),Vector2(0.13,0.81),Vector2(-0.03,0.75)]) if axe else PackedVector2Array([Vector2(-0.04,0.20),Vector2(0.04,0.20),Vector2(0.04,0.73),Vector2(0,0.90),Vector2(-0.04,0.73)])
		var center := Vector2.ZERO
		for point in outline: center += point
		center /= outline.size()
		var indices := Geometry2D.triangulate_polygon(outline)
		var builder := SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		for side in [-1.0,1.0]:
			for i in range(0,indices.size(),3):
				for j in ([0,1,2] if side>0 else [2,1,0]):
					var point := center+(outline[indices[i+j]]-center)*0.83
					builder.add_vertex(Vector3(point.x,point.y,side*0.024))
			for i in outline.size():
				var a := outline[i]
				var b := outline[(i+1)%outline.size()]
				var inside_a := center+(a-center)*0.83
				var inside_b := center+(b-center)*0.83
				var vertices := [Vector3(a.x,a.y,0),Vector3(b.x,b.y,0),Vector3(inside_b.x,inside_b.y,side*0.024),Vector3(a.x,a.y,0),Vector3(inside_b.x,inside_b.y,side*0.024),Vector3(inside_a.x,inside_a.y,side*0.024)]
				if side<0: vertices.reverse()
				for point: Vector3 in vertices: builder.add_vertex(point)
		builder.generate_normals()
		var metal: StandardMaterial3D = view.material(Color("b8cbd7"),0.8).duplicate()
		metal.cull_mode = BaseMaterial3D.CULL_DISABLED
		builder.set_material(metal)
		blades[key] = builder.commit()
	var item := MeshInstance3D.new()
	item.mesh = blades[key]
	parent.add_child(item)

static func bow(view: Node3D, parent: Node3D) -> void:
	# An open recurved stave, with a separate taut string, rather than a closed hoop.
	var points := PackedVector3Array([Vector3(0,-0.44,0.03),Vector3(0,-0.36,-0.05),Vector3(0,-0.23,-0.13),Vector3(0,0,-0.08),Vector3(0,0.23,-0.13),Vector3(0,0.36,-0.05),Vector3(0,0.44,0.03)])
	for i in points.size()-1: segment(view,parent,points[i],points[i+1],0.023,Color("855330"))
	segment(view,parent,points[0],points[points.size()-1],0.003,Color("e5d7b1"))
	segment(view,parent,Vector3(0,-0.08,-0.08),Vector3(0,0.08,-0.08),0.03,Color("45382d"))
	for side in [-1,1]: view.ring(parent,Vector3(0,side*0.1,-0.08),0.025,0.006,Color("c8a765"))

static func segment(view: Node3D, parent: Node3D, a: Vector3, b: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var item: MeshInstance3D = view.cylinder(parent,(a+b)*0.5,radius,a.distance_to(b),color)
	item.quaternion = Quaternion(Vector3.UP,(b-a).normalized())
	return item
