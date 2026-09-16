extends Node3D
const Art = preload("res://examples/sunbreak/art.gd")
var flash: MeshInstance3D
var magazine: Node3D
var support: Node3D
var slide: MeshInstance3D
var recoil_position := 0.0
var recoil_velocity := 0.0
var sway := Vector2.ZERO
var last_look := Vector2.ZERO
var initialized := false

func _ready() -> void:
	# Machined receiver, floating handguard, buffer tube, and compact stock.
	Art.box(self,Vector3(0,0,0),Vector3(0.13,0.14,0.34),"30434c",false,0.8)
	Art.box(self,Vector3(0.001,0.01,-0.07),Vector3(0.139,0.085,0.30),"d3d7c9",false,0.6)
	Art.box(self,Vector3(0,-0.071,0.035),Vector3(0.11,0.07,0.23),"597078",false,0.7)
	Art.segment(self,Vector3(0,0.007,0.16),Vector3(0,0.007,0.34),0.039,"2c4149",0.8)
	Art.box(self,Vector3(0,-0.025,0.32),Vector3(0.115,0.17,0.17),"405761",false,0.65)
	Art.box(self,Vector3(0,-0.03,0.41),Vector3(0.125,0.19,0.025),"22363c")
	Art.box(self,Vector3(0,-0.09,0.1),Vector3(0.07,0.18,0.08),"263b41").rotation.x = -0.25
	Art.box(self,Vector3(0,-0.12,0.0),Vector3(0.09,0.018,0.10),"74847e",false,0.8)
	Art.box(self,Vector3(0,-0.09,-0.045),Vector3(0.09,0.065,0.012),"74847e",false,0.8)
	Art.box(self,Vector3(0,-0.086,0.025),Vector3(0.012,0.045,0.016),"acb9b3",false,0.8)
	Art.box(self,Vector3(0,0.008,-0.31),Vector3(0.11,0.12,0.30),"425b66",false,0.7)
	Art.segment(self,Vector3(0,0.01,-0.30),Vector3(0,0.01,-0.58),0.024,"20333c",0.9)
	Art.segment(self,Vector3(0,0.01,-0.57),Vector3(0,0.01,-0.63),0.037,"8b9b96",0.85)
	Art.segment(self,Vector3(0,0.01,-0.63),Vector3(0,0.01,-0.643),0.027,"172a30")
	for x in [-0.058,0.058]:
		for i in 5:
			Art.box(self,Vector3(x,0.023,-0.20-i*0.047),Vector3(0.007,0.035,0.023),"152c36")
		for z in [-0.13,0.105]:
			Art.sphere(self,Vector3(x*1.25,0.027,z),Vector3.ONE*0.008,"b4bfb4").material_override = Art.material("b4bfb4",0.9)
		var stripe := Art.box(self,Vector3(x*1.22,-0.012,-0.01),Vector3(0.007,0.016,0.095),"7cd9cf")
		stripe.material_override = Art.material("7cd9cf",0.2,0.4)
	for i in 13: Art.box(self,Vector3(0,0.08,0.105-i*0.04),Vector3(0.095,0.012,0.019),"263b46",false,0.8)
	# Open reflex sight, with a thin lens and visible mounting feet.
	for x in [-0.041,0.041]: Art.box(self,Vector3(x,0.138,0.02),Vector3(0.016,0.10,0.03),"40545c",false,0.8)
	Art.box(self,Vector3(0,0.188,0.02),Vector3(0.095,0.016,0.03),"40545c",false,0.8)
	Art.box(self,Vector3(0,0.09,0.02),Vector3(0.105,0.018,0.07),"263b46",false,0.8)
	var lens := Art.box(self,Vector3(0,0.142,0.021),Vector3(0.068,0.074,0.004),"80acaa")
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.35,0.7,0.66,0.13)
	glass.roughness = 0.1
	lens.material_override = glass
	Art.sphere(self,Vector3(0,0.14,0.026),Vector3.ONE*0.002,"ffaf72").material_override = Art.material("ffaf72",0,2)
	slide = Art.box(self,Vector3(0.075,0.03,0.08),Vector3(0.015,0.035,0.045),"293b43",false,0.8)
	magazine = Node3D.new()
	add_child(magazine)
	magazine.position = Vector3(0,-0.14,-0.07)
	Art.box(magazine,Vector3.ZERO,Vector3(0.078,0.19,0.105),"4b6570",false,0.6)
	for i in 4: Art.box(magazine,Vector3(0,0.045-i*0.035,0.055),Vector3(0.067,0.012,0.008),"253e49")
	Art.box(magazine,Vector3(0,-0.1,0),Vector3(0.095,0.025,0.12),"c5b394",false,0.4)
	# Articulated-looking gloves with individual knuckles and curved fingers.
	var right := hand(Vector3(0.025,-0.145,0.12),false)
	Art.segment(right,Vector3(0.045,-0.025,0.07),Vector3(0.08,-0.06,0.3),0.057,"3c6166")
	Art.segment(right,Vector3(0.055,-0.03,0.095),Vector3(0.06,-0.04,0.16),0.059,"b3c0ac")
	support = hand(Vector3(-0.022,-0.10,-0.28),true)
	Art.segment(support,Vector3(-0.045,-0.035,0.065),Vector3(-0.17,-0.16,0.33),0.055,"3c6166")
	Art.segment(support,Vector3(-0.04,-0.03,0.065),Vector3(-0.067,-0.055,0.12),0.058,"b3c0ac")
	flash = Art.sphere(self,Vector3(0,0.01,-0.68),Vector3(0.055,0.055,0.15),"ffe9ba")
	flash.material_override = Art.material("ffe9ba",0,3)
	flash.visible = false

func hand(at: Vector3, left: bool) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	root.position = at
	Art.sphere(root,Vector3.ZERO,Vector3(0.057,0.044,0.073),"263e46")
	Art.box(root,Vector3(0,0.023,0.008),Vector3(0.065,0.025,0.085),"58737a")
	for i in 4:
		var x := -0.035+i*0.022
		Art.segment(root,Vector3(x,0.015,-0.025),Vector3(x,0.028,-0.067),0.011,"36525b")
		Art.segment(root,Vector3(x,0.028,-0.067),Vector3(x,-0.012,-0.080),0.010,"263b42")
		Art.sphere(root,Vector3(x,0.027,-0.048),Vector3(0.013,0.01,0.016),"7e9697")
	Art.segment(root,Vector3(-0.05 if left else 0.05,0,0.01),Vector3(-0.065 if left else 0.065,0.015,-0.028),0.016,"425c65")
	return root

func kick() -> void:
	recoil_velocity += 2.8

func present(delta: float, look: Vector2, speed: float, aiming: bool, sprinting: bool, reload_left: float, phase: float) -> void:
	if not initialized:
		last_look = look
		initialized = true
	var change := Vector2(angle_difference(last_look.x,look.x),look.y-last_look.y)
	last_look = look
	sway = sway.lerp(change.limit_length(0.06),1-exp(-delta*14))
	# Bounded damped spring affects only the viewmodel, never the aim camera.
	var step := minf(delta,0.033)
	recoil_velocity += (-180*recoil_position-22*recoil_velocity)*step
	recoil_position = clampf(recoil_position+recoil_velocity*step,0,0.065)
	var blend := 1-exp(-delta*12)
	var target := Vector3(0.22,-0.22,-0.48)
	if aiming: target = Vector3(0,-0.14,-0.37)
	var tilt := Vector3.ZERO
	if sprinting:
		target += Vector3(0.045,-0.13,0.04)
		tilt = Vector3(-0.22,0.3,0.22)
	var weight: float = minf(speed/6.4,1)*(0.15 if aiming else 1)
	target += Vector3(sin(phase)*0.012,absf(cos(phase))*0.013,0)*weight
	target += Vector3(-sway.x*0.6,-sway.y*0.6,recoil_position)
	tilt += Vector3(recoil_position*1.0+sway.y*0.6,-sway.x,sway.x*0.5)
	var progress := 1-reload_left/1.6
	var reload_weight: float = sin(progress*PI) if reload_left>0 else 0.0
	target += Vector3(0.035,-0.07,0.08)*reload_weight
	tilt += Vector3(0.15,0,-0.32)*reload_weight
	position = position.lerp(target,blend)
	rotation = rotation.lerp(tilt,blend)
	var extract: float = smoothstep(0.05,0.28,progress)*(1-smoothstep(0.58,0.85,progress)) if reload_left>0 else 0.0
	magazine.position = Vector3(0,-0.14-extract*0.24,-0.07+extract*0.03)
	magazine.rotation.z = extract*-0.15
	magazine.visible = not (reload_left>0 and progress>0.36 and progress<0.55)
	support.position = Vector3(-0.022,-0.10,-0.28).lerp(Vector3(-0.035,-0.24-extract*0.16,-0.065),reload_weight)
	slide.position.z = 0.08-recoil_position*0.8
