extends CharacterBody3D

const Shapes = preload("res://examples/little_world/shapes.gd")
const SPEED := 6.5
const GRAVITY := 23.0
const JUMP_SPEED := 9.0

var player_id := 1
var color := Color("ed7559")
var spawn := Vector3.ZERO
var input_service: Node
var camera: Camera3D
var model: Node3D
var feet: Array[MeshInstance3D] = []
var number: Label3D
var _time := 0.0
var _coyote := 0.0
var _jump_buffer := 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 # Characters cannot block or push one another off the island.
	floor_snap_length = 0.25
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.45
	collision.shape = capsule
	collision.position.y = 0.74
	add_child(collision)
	model = Node3D.new()
	add_child(model)
	var body := CapsuleMesh.new()
	body.radius = 0.4
	body.height = 1.15
	Shapes.mesh(model, body, Vector3(0, 0.93, 0), color)
	# Face points toward local +Z. Big cream cheeks and dark eyes read from the couch.
	Shapes.ball(model, Vector3(0, 1.05, 0.31), Vector3(0.64, 0.45, 0.23), Color("fff4db"))
	for side in [-1.0, 1.0]:
		Shapes.ball(model, Vector3(side * 0.135, 1.1, 0.423), Vector3(0.09, 0.12, 0.065), Color("253c46"))
		feet.append(Shapes.ball(model, Vector3(side * 0.23, 0.16, 0.1), Vector3(0.29, 0.3, 0.43), Color("314957")))
		Shapes.ball(model, Vector3(side * 0.43, 0.7, 0), Vector3(0.22, 0.37, 0.24), color.lightened(0.12))
	Shapes.ball(model, Vector3(0.1, 1.57, 0), Vector3(0.18, 0.25, 0.18), color.lightened(0.3))
	number = Label3D.new()
	number.text = str(player_id).pad_zeros(2)
	number.position.y = 2.15
	number.font_size = 56
	number.pixel_size = 0.01
	number.outline_size = 12
	number.modulate = Color("fff9e9")
	number.outline_modulate = Color("243c4b")
	number.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(number)
	respawn()


func _physics_process(delta: float) -> void:
	_time += delta
	var connected: bool = input_service.players.has(player_id) and input_service.players[player_id]["connected"]
	var movement: Vector2 = input_service.movement(player_id)
	var right := camera.global_basis.x
	var back := camera.global_basis.z
	right.y = 0
	back.y = 0
	var direction := right.normalized() * movement.x + back.normalized() * movement.y
	velocity.x = move_toward(velocity.x, direction.x * SPEED, 35.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * SPEED, 35.0 * delta)
	_coyote = 0.1 if is_on_floor() else maxf(0, _coyote - delta)
	_jump_buffer = maxf(0, _jump_buffer - delta)
	if input_service.consume_jump(player_id) and connected:
		_jump_buffer = 0.12
	if not connected:
		_jump_buffer = 0.0
	if _jump_buffer > 0 and _coyote > 0:
		velocity.y = JUMP_SPEED
		_coyote = 0.0
		_jump_buffer = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	if position.y < -8.0:
		respawn()
	if direction.length() > 0.1:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(direction.x, direction.z), 12.0 * delta)
	var stride := sin(_time * 16.0) * minf(movement.length(), 1.0)
	for i in feet.size():
		feet[i].position.y = 0.16 + maxf(0, stride * (1 if i == 0 else -1)) * 0.18 if is_on_floor() else 0.3
	model.position.y = absf(stride) * 0.035 if is_on_floor() else 0.0
	model.rotation.z = -stride * 0.035
	number.text = str(player_id).pad_zeros(2) if connected else "%02d · RECONNECT" % player_id
	number.modulate = Color("fff9e9") if connected else Color("ffcf8b")


func respawn() -> void:
	position = spawn
	velocity = Vector3.ZERO
	_coyote = 0.0
	_jump_buffer = 0.0
