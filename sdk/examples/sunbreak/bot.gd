extends CharacterBody3D
const Soldier = preload("res://examples/sunbreak/soldier.gd")
var game: Node3D
var health := 100
var cooldown := 2.0
var charge := 0.0
var age := 0.0
var side := 1.0
var body: Node3D
var eye: MeshInstance3D
var flash_left := 0.0
var path := PackedVector3Array()
var path_index := 0
var route_left := 0.0
var seen_revision := -1
var stagger := 0.0

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
	body = Soldier.new()
	add_child(body)
	eye = body.visor

func tick(delta: float) -> void:
	if health<=0: return
	age += delta
	stagger = maxf(0,stagger-delta)
	var offset: Vector3 = game.player.global_position-global_position
	offset.y = 0
	var distance := offset.length()
	if distance<0.01: return
	var direction := offset/distance
	rotation.y = lerp_angle(rotation.y,atan2(-direction.x,-direction.z),1-exp(-delta*7))
	var from := global_position+Vector3(0,1.5,0)
	var target: Vector3 = game.player.global_position+Vector3(0,1.0,0)
	var query := PhysicsRayQueryParameters3D.create(from,target,1|2)
	var ray := get_world_3d().direct_space_state.intersect_ray(query)
	var visible_target: bool = not ray.is_empty() and ray.collider==game.player
	var travel := Vector3.ZERO
	route_left -= delta
	if not visible_target or distance>18:
		if game.navigation.ready and (route_left<=0 or seen_revision!=game.navigation.revision):
			path = game.navigation.route(position,game.player.position)
			path_index = 1 if path.size()>1 else 0
			route_left = 0.7+fmod(age,0.4)
			seen_revision = game.navigation.revision
		while path_index<path.size() and Vector2(path[path_index].x-position.x,path[path_index].z-position.z).length()<0.8: path_index += 1
		travel = (path[path_index]-position).normalized() if path_index<path.size() else direction
		travel.y = 0
	elif distance<8:
		travel = -direction*0.65
	elif fmod(age+side,5.5)<3.3:
		travel = (Vector3(-direction.z,0,direction.x)*side+direction*0.25).normalized()*0.65
	# Separation and forward probes prevent bunching and stop at cover while replanning.
	for ally in game.bots:
		if ally==self: continue
		var separation: Vector3 = position-ally.position
		separation.y = 0
		if separation.length_squared()<2.25 and separation.length_squared()>0.01:
			travel += separation.normalized()*(1.5-separation.length())*1.1
	travel = travel.limit_length()
	var obstacle := PhysicsRayQueryParameters3D.create(from,from+travel*1.25,1)
	if not get_world_3d().direct_space_state.intersect_ray(obstacle).is_empty():
		travel = Vector3.ZERO
		route_left = 0
	var speed := 3.1 if distance>18 else 2.5
	if charge>0: speed *= 0.4
	if stagger>0: speed *= 0.2
	velocity.x = move_toward(velocity.x,travel.x*speed,delta*8)
	velocity.z = move_toward(velocity.z,travel.z*speed,delta*8)
	velocity.y -= delta*22
	var previous := position
	move_and_slide()
	var actual := (position-previous)/maxf(delta,0.001)
	body.advance(delta,actual,charge>0)
	cooldown -= delta
	if cooldown<=0 and visible_target and distance<40 and stagger==0:
		charge += delta
		if charge>=0.65:
			var muzzle: Vector3 = body.muzzle.global_position
			game.enemy_shot(muzzle,(target-muzzle).normalized())
			body.fire()
			game.spark(muzzle,"ffac69")
			cooldown = 1.7+fmod(age,0.8)
			charge = 0
	else: charge = 0

func tick_death(delta: float) -> void:
	body.advance(delta,Vector3.ZERO,false)

func take_hit(amount: int) -> void:
	if health<=0: return
	health = maxi(0,health-amount)
	stagger = 0.22
	charge = 0
	if health==0:
		collision_layer = 0
		collision_mask = 0
		body.die()
		game.eliminated(self)
	else: body.hit()
