extends RefCounted
## Tailored surfaces in the character's rest space, mounted on the matching bones.
static func loft(parent: Node3D, profile: Array[Vector4], color: Color, folds := 0.0, start := 0.0, end := TAU, center_z := 0.0, sway := 0.0) -> MeshInstance3D:
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sections := 64
	for row in profile.size()-1:
		for section in sections:
			for corner: Vector2i in [Vector2i(0,0),Vector2i(1,1),Vector2i(1,0),Vector2i(0,0),Vector2i(0,1),Vector2i(1,1)]:
				var u := float(section+corner.x)/sections
				var v := float(row+corner.y)/(profile.size()-1)
				var p := profile[row+corner.y]
				var angle := lerpf(start,end,u)
				var pleat := 1.0+sin(angle*16.0)*folds
				builder.set_uv(Vector2(u,v))
				builder.add_vertex(Vector3(p.x+sin(angle)*p.z*pleat,p.y,center_z+cos(angle)*p.w*pleat))
	builder.generate_normals()
	var material := ShaderMaterial.new()
	material.shader = preload("res://examples/gauntlet/shaders/cloth.gdshader")
	material.set_shader_parameter("cloth_color",color)
	material.set_shader_parameter("sway",sway)
	builder.set_material(material)
	var item := MeshInstance3D.new()
	item.mesh = builder.commit()
	parent.add_child(item)
	return item

static func wizard(view: Node3D, actor: Node3D, crown: Node3D, chest: Node3D) -> void:
	var blue: Color = actor.garment_color
	var trim := Color("8c7953")
	# Fit the measured head (about 0.18 m wide), with a modest brim and soft bent crown.
	var brim := loft(crown,[Vector4(0,1.745,0.205,0.18),Vector4(0,1.755,0.17,0.15),Vector4(0,1.77,0.105,0.12)],blue,0.018,0,TAU,-0.012)
	brim.name = "FeltBrim"
	loft(crown,[Vector4(0,1.755,0.105,0.12),Vector4(0,1.83,0.102,0.11),Vector4(-0.01,1.94,0.078,0.085),Vector4(-0.035,2.04,0.051,0.056),Vector4(-0.08,2.095,0.029,0.032),Vector4(-0.13,2.09,0.012,0.014),Vector4(-0.15,2.055,0.002,0.003)],blue,0.025,0,TAU,-0.012)
	loft(crown,[Vector4(0,1.77,0.11,0.124),Vector4(0,1.803,0.108,0.12)],Color("58493b"),0,0,TAU,-0.012)
	view.box(crown,Vector3(-0.01,1.785,0.112),Vector3(0.032,0.023,0.01),trim,0.65)
	# A layered beard gives the face an older silhouette without covering the eyes.
	loft(crown,[Vector4(0,1.26,0.018,0.035),Vector4(0,1.37,0.055,0.07),Vector4(0,1.52,0.10,0.09),Vector4(0,1.62,0.11,0.055)],Color("aaa292"),0.045,-PI/2,PI/2,0.095)
	var skirt := Node3D.new()
	skirt.name = "RobeSkirt"
	# Follow hip translation in present(), without pitching the entire skirt with the pelvis.
	actor.skeleton.add_child(skirt)
	actor.robe_skirt = skirt
	loft(skirt,[Vector4(0,0.16,0.40,0.34),Vector4(0,0.42,0.36,0.30),Vector4(0,0.76,0.28,0.23),Vector4(0,1.03,0.225,0.18)],blue,0.05,0.16,TAU-0.16,0,0.6).name = "LongRobe"
	loft(skirt,[Vector4(0,0.17,0.407,0.347),Vector4(0,0.20,0.405,0.345)],trim,0.05,0.16,TAU-0.16,0,0.6).name = "RobeTrim"
	loft(chest,[Vector4(0,1.0,0.23,0.185),Vector4(0,1.15,0.25,0.19),Vector4(0,1.39,0.28,0.18),Vector4(0,1.48,0.19,0.13),Vector4(0,1.52,0.10,0.09)],blue,0.025)
	loft(chest,[Vector4(0,1.045,0.238,0.195),Vector4(0,1.105,0.245,0.20)],Color("4b3b2e"))
	view.box(chest,Vector3(0,1.075,0.203),Vector3(0.075,0.05,0.018),trim,0.6)
	for side in [-1,1]:
		var border: MeshInstance3D = view.box(chest,Vector3(side*0.085,1.31,0.184),Vector3(0.018,0.31,0.014),trim)
		border.rotation.z = side*0.25
	view.ball(chest,Vector3(0,1.38,0.205),Vector3(0.047,0.067,0.022),Color("89a7a8"))

static func valkyrie(view: Node3D, crown: Node3D) -> void:
	# Open brow and swept-back hair reveal the female head; paired braids read at the game camera distance.
	var hair := Color("88603b")
	var hair_material: StandardMaterial3D = view.material(hair)
	hair_material.roughness = 0.93
	var back := loft(crown,[Vector4(0,1.49,0.09,0.09),Vector4(0,1.65,0.10,0.113),Vector4(0,1.72,0.086,0.10)],hair,0.025,0.95,TAU-0.95,-0.015)
	back.material_override = hair_material
	var top := loft(crown,[Vector4(0,1.72,0.086,0.10),Vector4(0,1.76,0.063,0.076),Vector4(0,1.785,0.03,0.04),Vector4(0,1.793,0.001,0.001)],hair,0.025,0,TAU,-0.015)
	top.material_override = hair_material
	for side in [-1,1]:
		for link in 7:
			var t := float(link)/6.0
			var center := Vector3(side*(0.102+0.022*sin(t*PI)),1.65-t*0.36,0.015+t*0.09)
			var radius := lerpf(0.033,0.018,t)
			for strand in [-1,1]:
				var offset := Vector3(strand*radius*0.27,0,cos(link*PI+strand)*0.01)
				view.ball(crown,center+offset,Vector3(radius*1.1,0.071,radius),hair.lightened(0.05 if strand==1 else 0.0))
		view.ring(crown,Vector3(side*0.102,1.30,0.105),0.018,0.006,Color("b7a174"))

static func helmet(view: Node3D, crown: Node3D, kind: int) -> void:
	# Close-fitting skullcap follows the head's oval section, without a flared rim.
	var cap := loft(crown,[Vector4(0,1.70,0.098,0.116),Vector4(0,1.745,0.095,0.111),Vector4(0,1.79,0.066,0.078),Vector4(0,1.819,0.028,0.036),Vector4(0,1.825,0.001,0.001)],Color.WHITE,0,0,TAU,-0.008)
	cap.material_override = view.material(Color("73838b") if kind==0 else Color("8a8775"),0.50)
	var band := loft(crown,[Vector4(0,1.70,0.10,0.118),Vector4(0,1.713,0.10,0.118)],Color.WHITE,0,0,TAU,-0.008)
	band.material_override = view.material(Color("aaa28c"),0.55)
