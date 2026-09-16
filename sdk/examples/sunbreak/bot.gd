extends CharacterBody3D
const Art = preload("res://examples/sunbreak/art.gd")
var game: Node3D
var health := 100
var cooldown := 2.0
var charge := 0.0
var age := 0.0
var side := 1.0
var body: Node3D
var eye: MeshInstance3D
var legs: Array[Node3D] = []
var flash_left := 0.0

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 4
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.48
	capsule.height = 2.0
	collider.shape = capsule
	collider.position.y = 1
	add_child(collider)
	body = Node3D.new()
	add_child(body)
	Art.box(body,Vector3(0,1.22,0),Vector3(0.72,0.65,0.4),"ad645f",false,0.5)
	Art.box(body,Vector3(0,1.28,-0.23),Vector3(0.48,0.35,0.07),"efb781",false,0.6)
	Art.sphere(body,Vector3(0,1.85,0),Vector3(0.4,0.32,0.3),"dcd9bd")
	eye = Art.box(body,Vector3(0,1.86,-0.29),Vector3(0.55,0.09,0.04),"ff654e")
	eye.material_override = Art.material("ff654e",0,2)
	for x in [-0.49,0.49]:
		Art.sphere(body,Vector3(x,1.4,0),Vector3(0.22,0.23,0.23),"eac38e")
		Art.box(body,Vector3(x,1.09,-0.13),Vector3(0.19,0.46,0.23),"384e59",false,0.4)
	Art.box(body,Vector3(0.48,1.06,-0.45),Vector3(0.19,0.21,0.58),"293d49",false,0.8)
	for x in [-0.22,0.22]:
		var leg := Node3D.new()
		body.add_child(leg)
		leg.position = Vector3(x,0.92,0)
		Art.box(leg,Vector3(0,-0.38,0),Vector3(0.23,0.65,0.23),"405c62",false,0.4)
		Art.box(leg,Vector3(0,-0.78,-0.09),Vector3(0.3,0.18,0.42),"d9caab")
		legs.append(leg)

func tick(delta: float) -> void:
	age += delta
	flash_left = maxf(0,flash_left-delta)
	body.scale = Vector3.ONE * (1.06 if flash_left>0 else 1.0)
	var offset: Vector3 = game.player.global_position-global_position
	offset.y = 0
	var distance := offset.length()
	if distance<0.01: return
	var direction := offset/distance
	rotation.y = lerp_angle(rotation.y,atan2(-direction.x,-direction.z),delta*6)
	var from := global_position+Vector3(0,1.5,0)
	var target: Vector3 = game.player.global_position+Vector3(0,1.0,0)
	var query := PhysicsRayQueryParameters3D.create(from,target,1|2)
	var ray := get_world_3d().direct_space_state.intersect_ray(query)
	var visible_target: bool = not ray.is_empty() and ray.collider == game.player
	var travel := direction if distance>14 or not visible_target else Vector3(-direction.z,0,direction.x)*side*0.6
	# Probe body-height obstacles; deterministically steer around hard cover.
	var obstacle := PhysicsRayQueryParameters3D.create(from,from+travel*2.5,1)
	if not get_world_3d().direct_space_state.intersect_ray(obstacle).is_empty():
		travel = Vector3(-direction.z,0,direction.x)*side
	velocity.x = travel.x*3.2
	velocity.z = travel.z*3.2
	velocity.y -= delta*22
	move_and_slide()
	for i in 2: legs[i].rotation.x = sin(age*8+i*PI)*0.4*minf(1,Vector2(velocity.x,velocity.z).length())
	cooldown -= delta
	if cooldown<=0 and visible_target and distance<40:
		charge += delta
		eye.scale = Vector3.ONE*(1+charge*1.5)
		if charge>=0.65:
			game.enemy_shot(from,(target-from).normalized())
			cooldown = 1.7 + fmod(age,0.8)
			charge = 0
			eye.scale = Vector3.ONE
	else:
		charge = 0
		eye.scale = Vector3.ONE

func take_hit(amount: int) -> void:
	if health<=0: return
	health = maxi(0,health-amount)
	flash_left = 0.12
	if health==0:
		game.eliminated(self)
		queue_free()
