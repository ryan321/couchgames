extends Node3D
## Shared Blender meshes with lightweight, instance-local limb animation.
const Cast = preload("res://examples/gauntlet/cast_assets.gd")
static var palette: ShaderMaterial
var model: Node3D
var kind := "ghost"
var arms: Array[Node3D] = []
var legs: Array[Node3D] = []
var calves: Array[Node3D] = []
var tail: Node3D
var stride := 0.0
var movement := 0.0
var swing := 0.0
var last_attack := 0

func configure(enemy_kind: String) -> void:
	kind = enemy_kind
	model = Cast.instance(Cast.CREATURES[kind])
	add_child(model)
	if not palette:
		palette = ShaderMaterial.new()
		palette.shader = preload("res://examples/gauntlet/shaders/creature_palette.gdshader")
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		mesh.material_override = palette
	for side in ["L","R"]:
		arms.append(model.find_child("Arm_"+side+"*",true,false))
		if kind!="ghost":
			var thigh: Node3D = model.find_child("Leg_"+side+"*",true,false)
			var calf: Node3D = model.find_child("Calf_"+side+"*",true,false)
			# Preserve authored rest coordinates when establishing the knee hierarchy.
			var rest := calf.transform
			calf.owner = null
			calf.get_parent().remove_child(calf)
			thigh.add_child(calf)
			calf.transform = thigh.transform.affine_inverse()*rest
			legs.append(thigh)
			calves.append(calf)
	tail = model.find_child("Tail*",true,false)

func present(state: Dictionary, distance: float, delta: float, clock: float, playing: bool) -> void:
	if not playing or delta<=0: return
	var speed := minf(distance/maxf(delta,0.001),3.0)
	movement = lerpf(movement,clampf(speed/1.5,0,1),1.0-exp(-delta*14))
	stride += minf(distance,0.2)*7.0
	var attack: int = state.get("attack_serial",0)
	if attack!=last_attack:
		swing = 1.0
		last_attack = attack
	swing = move_toward(swing,0,delta*3.5)
	var phase := clock*2.0+float(state.id)
	if kind=="ghost":
		model.position.y = sin(phase)*0.055
		model.rotation.z = sin(phase*.65)*.025
		model.rotation.x = -movement*.07-sin(swing*PI)*.06
		for i in arms.size():
			arms[i].rotation.x = sin(phase+i)*0.08-sin(swing*PI)*0.6
			arms[i].rotation.z = (-1 if i==0 else 1)*(0.06+sin(phase*0.7)*0.035)
	else:
		model.position.y = absf(sin(stride))*0.018*movement
		model.rotation.z = sin(stride)*.025*movement
		model.rotation.x = movement*.05-sin(swing*PI)*.055
		if tail:
			tail.rotation.y = sin(phase*.8)*.13+sin(stride)*movement*.09
			tail.rotation.x = sin(phase*.65)*.05
		for i in legs.size():
			var step := sin(stride+i*PI)*movement
			legs[i].rotation.x = step*0.36
			calves[i].rotation.x = -maxf(0,-step)*.58
			arms[i].rotation.x = -step*0.28-sin(swing*PI)*(0.9 if i==1 else 0.35)
			arms[i].rotation.z = (-1 if i==0 else 1)*0.045
